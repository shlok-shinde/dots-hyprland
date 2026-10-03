pragma Singleton
pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.common.functions
import qs.services.hermes
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Hermes Agent (Nous Research) in the left sidebar. Runs `hermes acp` and
 * speaks the Agent Client Protocol to it over stdio (JSON-RPC, one message per
 * line). Hermes brings its own provider, tools, memory and skills; each chat
 * is a Hermes session (it shows up in `hermes sessions`), and the sidebar
 * reopens the last one after a restart.
 */
Singleton {
    id: root

    property Component entryComponent: HermesEntry {}

    // Is Hermes installed? `hermes` on PATH, or in ~/.local/bin where its installer puts it
    property bool checked: false
    property bool available: false
    property string binary: "hermes"

    // The agent
    readonly property bool running: agent.running
    property bool ready: false // initialized, with a session open
    property bool starting: false
    property string sessionId: ""
    property string sessionTitle: ""
    property int promptsInFlight: 0
    readonly property bool busy: promptsInFlight > 0
    property var models: [] // [{ modelId, name, description }]
    property string currentModelId: ""
    readonly property string currentModelName: shortModelName(currentModelId)
    property var commands: [] // Hermes' own slash commands: [{ name, description, hint }]
    property var sessions: [] // recent conversations, for /resume: [{ sessionId, title, updatedAt }]
    property int contextUsed: 0
    property int contextSize: 0
    property string stderrTail: ""

    // The transcript
    property var entryIds: []
    property var entryById: ({})
    property int entryCounter: 0
    property var toolEntries: ({}) // toolCallId -> entry
    property var currentPlan: null
    property bool replaying: false // session/load is streaming an old conversation back
    property var waitingPrompts: [] // typed before Hermes was up

    readonly property string home: FileUtils.trimFileProtocol(Directories.home)
    readonly property string sessionFilePath: FileUtils.trimFileProtocol(`${Directories.state}/user/hermes-session.txt`)

    Component.onCompleted: findBinary.running = true

    Process {
        id: findBinary
        command: ["bash", "-c", "command -v hermes || { [ -x \"$HOME/.local/bin/hermes\" ] && echo \"$HOME/.local/bin/hermes\"; }"]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                root.available = path.length > 0;
                if (root.available)
                    root.binary = path;
                root.checked = true;
            }
        }
    }

    FileView {
        id: sessionFile
        path: root.sessionFilePath
        blockLoading: true
        printErrors: false // there is none before the first chat
    }

    Process {
        id: agent
        command: [root.binary, "acp"]
        workingDirectory: root.home
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => root.handleLine(line)
        }
        stderr: SplitParser { // Hermes logs here; keep the last line for when it dies
            onRead: line => {
                if (line.trim().length > 0)
                    root.stderrTail = line.trim();
            }
        }
        onStarted: root.initialize()
        onExited: (exitCode, exitStatus) => root.handleExit(exitCode)
    }

    // For scripts and keybinds: qs -c ii ipc call hermes ask "what's using my disk?"
    IpcHandler {
        target: "hermes"

        function ask(prompt: string): void {
            GlobalStates.sidebarLeftOpen = true;
            root.sendPrompt(prompt);
        }
        function newChat(): void {
            root.newConversation();
        }
        function stop(): void {
            root.cancel();
        }
    }

    // ---- Public API ---------------------------------------------------------

    // Bring Hermes up (and the last conversation back). Cheap to call again.
    function start() {
        if (!root.available || root.starting)
            return;
        if (agent.running) { // up, but its chat failed to open: try again
            if (!root.ready)
                root.newSession();
            return;
        }
        root.starting = true;
        root.ready = false;
        root.stderrTail = "";
        agent.running = true;
    }

    function sendPrompt(text) {
        if (text.trim().length === 0)
            return;
        if (!root.ready) {
            root.waitingPrompts = [...root.waitingPrompts, text];
            root.start();
            return;
        }
        root.addEntry({
            kind: "user",
            text: text,
            done: true,
            queued: root.busy
        });
        root.submitPrompt(text);
    }

    function cancel() {
        if (!root.sessionId || !root.busy)
            return;
        // ACP: whoever cancels answers the permission questions still open
        for (const entry of root.entries()) {
            if (entry.kind === "permission" && entry.answer === "")
                root.answerPermission(entry, "");
        }
        root.notify("session/cancel", {
            sessionId: root.sessionId
        });
    }

    function newConversation() {
        root.cancel();
        root.clearEntries();
        if (!root.ready) {
            sessionFile.setText("");
            root.start();
            return;
        }
        root.newSession();
    }

    function resumeConversation(id) {
        if (!id || id === root.sessionId)
            return;
        root.cancel();
        if (agent.running) {
            if (!root.starting)
                root.loadSession(id, false);
            return;
        }
        sessionFile.setText(id); // opened as soon as Hermes is up
        root.start();
    }

    function refreshSessions() {
        if (!root.ready)
            return;
        root.request("session/list", {}, (result, error) => {
            if (error || !result)
                return;
            root.sessions = result.sessions ?? [];
            const current = root.sessions.find(session => session.sessionId === root.sessionId);
            if (current?.title && root.sessionTitle.length === 0)
                root.sessionTitle = current.title;
        });
    }

    function setModel(modelId) {
        if (!root.ready || !modelId)
            return;
        root.request("session/set_model", {
            sessionId: root.sessionId,
            modelId: modelId
        }, (result, error) => {
            if (error) {
                root.addNotice(Translation.tr("Couldn't switch to %1: %2").arg(modelId).arg(error.message ?? ""));
                return;
            }
            root.currentModelId = modelId;
            root.addNotice(Translation.tr("Model for this chat: %1").arg(root.shortModelName(modelId)));
        });
    }

    // optionId "" = the question went away unanswered (cancelled turn)
    function answerPermission(entry, optionId) {
        if (entry.answer !== "")
            return;
        entry.answer = optionId === "" ? "cancelled" : optionId;
        root.send({
            jsonrpc: "2.0",
            id: entry.requestId,
            result: {
                outcome: optionId === "" ? {
                    outcome: "cancelled"
                } : {
                    outcome: "selected",
                    optionId: optionId
                }
            }
        });
    }

    function shortModelName(modelId) {
        const model = root.models.find(m => m.modelId === modelId);
        const name = model?.name ?? modelId ?? "";
        const afterProvider = name.includes("·") ? name.split("·").pop().trim() : name;
        return afterProvider.split("/").pop();
    }

    function entries() {
        return root.entryIds.map(id => root.entryById[id]);
    }

    // ---- JSON-RPC -----------------------------------------------------------

    property int nextRequestId: 1
    property var pendingRequests: ({})

    function send(message) {
        agent.write(JSON.stringify(message) + "\n");
    }

    function request(method, params, callback) {
        const id = root.nextRequestId++;
        root.pendingRequests[id] = callback ?? null;
        root.send({
            jsonrpc: "2.0",
            id: id,
            method: method,
            params: params
        });
    }

    function notify(method, params) {
        root.send({
            jsonrpc: "2.0",
            method: method,
            params: params
        });
    }

    function handleLine(line) {
        let message;
        try {
            message = JSON.parse(line);
        } catch (e) {
            return; // not protocol traffic
        }
        if (message.method !== undefined) {
            if (message.id !== undefined)
                root.handleAgentRequest(message);
            else if (message.method === "session/update")
                root.handleUpdate(message.params ?? {});
            return;
        }
        const callback = root.pendingRequests[message.id];
        delete root.pendingRequests[message.id];
        if (callback)
            callback(message.result ?? null, message.error ?? null);
    }

    // ---- Lifecycle ----------------------------------------------------------

    function initialize() {
        root.request("initialize", {
            protocolVersion: 1,
            clientCapabilities: {
                fs: {
                    readTextFile: false,
                    writeTextFile: false
                },
                terminal: false
            },
            clientInfo: {
                name: "illogical-impulse",
                title: "Quickshell sidebar",
                version: "1"
            }
        }, (result, error) => {
            if (error || !result) {
                root.starting = false;
                root.addNotice(Translation.tr("Hermes didn't start: %1").arg(error?.message ?? root.stderrTail));
                return;
            }
            const lastSession = (sessionFile.text() ?? "").trim();
            if (lastSession.length > 0)
                root.loadSession(lastSession, true);
            else
                root.newSession();
        });
    }

    function newSession() {
        root.starting = true;
        root.ready = false; // what you type meanwhile waits for the new chat
        root.request("session/new", {
            cwd: root.home,
            mcpServers: []
        }, (result, error) => {
            if (error || !result) {
                root.starting = false;
                root.addNotice(Translation.tr("Hermes couldn't open a chat: %1").arg(error?.message ?? ""));
                return;
            }
            root.sessionId = result.sessionId;
            root.sessionTitle = "";
            root.contextUsed = 0;
            sessionFile.setText(root.sessionId);
            root.applySessionResult(result);
            root.becomeReady();
        });
    }

    // quiet: reopening the last chat at startup; if it is gone, just start fresh
    function loadSession(id, quiet) {
        root.starting = true;
        root.ready = false;
        root.clearEntries();
        root.sessionId = id;
        root.sessionTitle = "";
        root.contextUsed = 0;
        root.replaying = true;
        root.request("session/load", {
            sessionId: id,
            cwd: root.home,
            mcpServers: []
        }, (result, error) => {
            root.replaying = false;
            root.finishEntries();
            // An unknown id comes back as an empty result, not an error (a chat
            // that never got a message was never saved)
            if (error || !result || Object.keys(result).length === 0) {
                root.clearEntries();
                if (!quiet)
                    root.addNotice(Translation.tr("Couldn't open that chat, starting a new one"));
                root.newSession();
                return;
            }
            sessionFile.setText(id);
            root.applySessionResult(result);
            root.becomeReady();
            root.refreshSessions(); // brings the chat's title back
        });
    }

    function applySessionResult(result) {
        if (!result.models)
            return;
        root.models = result.models.availableModels ?? [];
        root.currentModelId = result.models.currentModelId ?? "";
    }

    function becomeReady() {
        root.starting = false;
        root.ready = true;
        const waiting = root.waitingPrompts;
        root.waitingPrompts = [];
        for (const text of waiting)
            root.sendPrompt(text);
    }

    function submitPrompt(text) {
        root.promptsInFlight++;
        const session = root.sessionId;
        root.request("session/prompt", {
            sessionId: session,
            prompt: [
                {
                    type: "text",
                    text: text
                }
            ]
        }, (result, error) => {
            root.promptsInFlight = Math.max(0, root.promptsInFlight - 1);
            if (session !== root.sessionId)
                return;
            if (error)
                root.addNotice(Translation.tr("Hermes: %1").arg(error.message ?? JSON.stringify(error)));
            else if (result?.stopReason === "cancelled")
                root.addNotice(Translation.tr("Stopped"));
            if (!root.busy)
                root.finishEntries();
        });
    }

    function handleExit(exitCode) {
        root.ready = false;
        root.starting = false;
        root.promptsInFlight = 0;
        root.pendingRequests = ({});
        root.finishEntries();
        const why = root.stderrTail.length > 0 ? `\n${root.stderrTail}` : "";
        root.addNotice(Translation.tr("Hermes stopped (exit code %1). Send a message to start it again.").arg(exitCode) + why);
    }

    // ---- What Hermes sends --------------------------------------------------

    function handleAgentRequest(message) {
        if (message.method === "session/request_permission") {
            const params = message.params ?? {};
            const toolCall = params.toolCall ?? {};
            const entry = root.addEntry({
                kind: "permission",
                requestId: message.id,
                title: toolCall.title ?? "",
                toolKind: toolCall.kind ?? "other",
                input: root.textOf(toolCall.content),
                options: params.options ?? [],
                answer: ""
            });
            if (!GlobalStates.sidebarLeftOpen)
                Quickshell.execDetached(["notify-send", "-a", "Hermes", Translation.tr("Hermes is asking"), entry.title.length > 0 ? entry.title : Translation.tr("Open the left sidebar to answer")]);
            return;
        }
        // We announced no file system or terminal access, so nothing else should come
        root.send({
            jsonrpc: "2.0",
            id: message.id,
            error: {
                code: -32601,
                message: "Not supported by this client"
            }
        });
    }

    function handleUpdate(params) {
        if (params.sessionId !== root.sessionId)
            return;
        const update = params.update ?? {};
        switch (update.sessionUpdate) {
        case "agent_message_chunk":
            root.appendAgentText(update, false);
            break;
        case "agent_thought_chunk":
            root.appendAgentText(update, true);
            break;
        case "user_message_chunk":
            root.addUserText(root.textOf(update.content));
            break;
        case "tool_call":
            root.startToolCall(update);
            break;
        case "tool_call_update":
            root.updateToolCall(update);
            break;
        case "plan":
            root.updatePlan(update.entries ?? []);
            break;
        case "usage_update":
            root.contextUsed = update.used ?? 0;
            root.contextSize = update.size ?? 0;
            break;
        case "session_info_update":
            if (update.title)
                root.sessionTitle = update.title;
            break;
        case "available_commands_update":
            root.commands = (update.availableCommands ?? []).map(command => ({
                        name: command.name,
                        description: command.description ?? "",
                        hint: command.input?.hint ?? ""
                    }));
            break;
        }
    }

    function textOf(content) {
        if (!content)
            return "";
        if (Array.isArray(content))
            return content.map(part => root.textOf(part)).filter(text => text.length > 0).join("\n");
        switch (content.type) {
        case "text":
            return content.text ?? "";
        case "content":
            return root.textOf(content.content);
        case "diff":
            return `${content.path ?? ""}\n${content.newText ?? ""}`;
        default:
            return "";
        }
    }

    function appendAgentText(update, isThought) {
        const chunk = root.textOf(update.content);
        if (chunk.length === 0)
            return;
        const messageId = update.messageId ?? "";
        const last = root.lastEntry();
        let entry = null;
        if (last && last.kind === "assistant" && (!last.done || root.replaying)) {
            // Same message, or (replays carry no ids) more of the same turn; a
            // replayed thought after text is the next message's reasoning
            const sameMessage = messageId.length > 0 ? last.messageId === messageId : !(isThought && last.text.length > 0);
            if (sameMessage)
                entry = last;
        }
        if (!entry)
            entry = root.addEntry({
                kind: "assistant",
                messageId: messageId,
                done: root.replaying
            });
        if (isThought)
            entry.thought += chunk;
        else
            entry.text += chunk;
    }

    function addUserText(text) {
        if (text.length === 0)
            return;
        if (!root.replaying) {
            // A prompt Hermes held back is starting now; it is already in the transcript
            const held = root.entries().find(entry => entry.kind === "user" && entry.queued && entry.text === text);
            if (held) {
                held.queued = false;
                return;
            }
        }
        root.addEntry({
            kind: "user",
            text: text,
            done: true
        });
    }

    function startToolCall(update) {
        const entry = root.addEntry({
            kind: "tool",
            toolCallId: update.toolCallId ?? "",
            title: update.title ?? "",
            toolKind: update.kind ?? "other",
            status: update.status ?? "in_progress",
            input: root.textOf(update.content),
            done: root.replaying
        });
        root.toolEntries[entry.toolCallId] = entry;
    }

    function updateToolCall(update) {
        const entry = root.toolEntries[update.toolCallId];
        if (!entry) {
            root.startToolCall(update);
            return;
        }
        if (update.status)
            entry.status = update.status;
        if (update.title)
            entry.title = update.title;
        if (update.content)
            entry.output = root.textOf(update.content);
    }

    function updatePlan(planEntries) {
        if (!root.currentPlan || root.currentPlan.done)
            root.currentPlan = root.addEntry({
                kind: "plan",
                done: root.replaying
            });
        root.currentPlan.planEntries = planEntries;
    }

    // ---- Transcript helpers -------------------------------------------------

    function addEntry(properties) {
        // Whatever Hermes said before this is complete (its reasoning before a tool call, say)
        const previous = root.lastEntry();
        if (previous && previous.kind === "assistant")
            previous.done = true;
        const id = `${Date.now()}-${root.entryCounter++}`;
        const entry = root.entryComponent.createObject(root, properties);
        root.entryById[id] = entry;
        root.entryIds = [...root.entryIds, id];
        return entry;
    }

    function addNotice(text) {
        root.addEntry({
            kind: "notice",
            text: text,
            done: true
        });
    }

    function lastEntry() {
        const count = root.entryIds.length;
        return count > 0 ? root.entryById[root.entryIds[count - 1]] : null;
    }

    // The turn is over: settle whatever is still streaming or waiting
    function finishEntries() {
        for (const entry of root.entries()) {
            if (entry.kind === "permission" && entry.answer === "")
                entry.answer = "cancelled";
            entry.queued = false; // Hermes ran it, or folded it into the turn
            entry.done = true;
        }
    }

    function clearEntries() {
        const old = root.entries();
        root.entryIds = [];
        root.entryById = ({});
        root.toolEntries = ({});
        root.currentPlan = null;
        for (const entry of old)
            entry.destroy();
    }
}
