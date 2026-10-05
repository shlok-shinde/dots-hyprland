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
 * Hermes Agent (Nous Research) in the left sidebar. Runs Hermes' own UI
 * backend (tui_gateway, what its TUI, desktop app and dashboard talk to) and
 * speaks its JSON-RPC over stdio, one message per line. So the sidebar gets
 * what those get: every slash command, the agent's questions (approvals,
 * clarify, sudo and secrets), sessions. Hermes brings its own provider, tools,
 * memory and skills; each chat is a Hermes session (`hermes sessions`), and
 * the sidebar reopens the last one after a restart.
 */
Singleton {
    id: root

    property Component entryComponent: HermesEntry {}

    // Is Hermes installed? `hermes` on PATH, or in ~/.local/bin where its installer puts it
    property bool checked: false
    property bool available: false
    property string binary: "hermes"
    property var gatewayCommand: [] // how this installation runs tui_gateway.entry

    // The gateway and the chat
    readonly property bool running: gateway.running
    property bool ready: false // connected, with a session open
    property bool starting: false
    property string sessionId: "" // the live session (this connection's handle)
    property string storedSessionId: "" // the stored one: what `hermes sessions` lists
    property string sessionTitle: ""
    property bool busy: false // a turn is running
    property string activity: "" // what Hermes says it is doing, while busy
    property var info: ({}) // session settings: model, provider, approval mode, ...
    readonly property string currentModelId: root.info.model ?? ""
    readonly property string currentModelName: root.currentModelId.split("/").pop()
    property int contextUsed: 0
    property int contextSize: 0
    property string stderrTail: ""

    // Slash commands: Hermes' catalog, and what the pickers offer
    property var commands: [] // [{ name, description, category, needsArgs }] (built-ins, then skills)
    property var canon: ({}) // "/alias" -> "/command"
    property var sessions: [] // recent chats: [{ id, title, preview, started_at, message_count }]
    property var modelChoices: [] // [{ value, model, provider, providerName, current }]
    signal prefillRequested(string text) // put this in the message box (/undo, a picker)

    // The transcript
    property var entryIds: []
    property var entryById: ({})
    property int entryCounter: 0
    property var toolEntries: ({}) // tool call id -> entry
    property var currentPlan: null
    property bool turnStreamed: false // the running turn has written some reply
    property var waitingInput: [] // typed before Hermes was up

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
                if (!root.available) {
                    root.checked = true;
                    return;
                }
                root.binary = path;
                root.gatewayCommand = [path, "--run-module", "tui_gateway.entry"];
                findGateway.running = true;
            }
        }
    }

    // The installation's own answer to "how do I run this module" (its launcher's machine interface)
    Process {
        id: findGateway
        command: [root.binary, "--print-runtime-command", "--module", "tui_gateway.entry"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const argv = JSON.parse(text);
                    if (Array.isArray(argv) && argv.length > 0)
                        root.gatewayCommand = argv;
                } catch (e) {}
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
        id: gateway
        command: root.gatewayCommand
        workingDirectory: root.home
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => root.handleLine(line)
        }
        stderr: SplitParser { // logs; keep the last line for when it dies
            onRead: line => {
                if (line.trim().length > 0)
                    root.stderrTail = line.trim();
            }
        }
        onExited: (exitCode, exitStatus) => root.handleExit(exitCode)
    }

    // For scripts and keybinds: qs -c ii ipc call hermes ask "what's using my disk?" (or a /command)
    IpcHandler {
        target: "hermes"

        function ask(prompt: string): void {
            GlobalStates.sidebarLeftOpen = true;
            root.submit(prompt);
        }
        function newChat(): void {
            root.newConversation("");
        }
        function stop(): void {
            root.cancel();
        }
    }

    // ---- Public API ---------------------------------------------------------

    // Bring Hermes up (and the last conversation back). Cheap to call again.
    function start() {
        if (!root.available || !root.checked || root.starting)
            return;
        if (gateway.running) { // up, but its chat failed to open: try again
            if (!root.ready)
                root.openSession();
            return;
        }
        root.starting = true;
        root.ready = false;
        root.stderrTail = "";
        gateway.running = true;
    }

    // What the message box sends: a /command, or a message for Hermes
    function submit(text) {
        const trimmed = text.trim();
        if (trimmed.length === 0)
            return;
        if (!root.ready) {
            root.waitingInput = [...root.waitingInput, trimmed];
            root.start();
            return;
        }
        if (root.isCommand(trimmed))
            root.runCommand(trimmed);
        else
            root.sendPrompt(trimmed, "");
    }

    // "/usage" is a command; "/home/me/notes.md says what?" is a message
    function isCommand(text) {
        return /^\/[^\s\/]+(\s|$)/.test(text);
    }

    // display: what the transcript shows instead (a skill's invocation, not its body)
    function sendPrompt(text, display) {
        const entry = root.addEntry({
            kind: "user",
            text: display.length > 0 ? display : text,
            done: true,
            queued: root.busy
        });
        root.request("prompt.submit", {
            session_id: root.sessionId,
            text: text
        }, (result, error) => {
            if (error) {
                entry.queued = false;
                root.addNotice(Translation.tr("Hermes: %1").arg(error.message ?? JSON.stringify(error)));
                return;
            }
            if (result?.status === "steered") {
                entry.queued = false;
                entry.steered = true;
            } else if (result?.status === "queued") {
                entry.queued = true;
            } else if (result?.status === "redirected" || result?.status === "streaming") {
                entry.queued = false;
            }
        });
    }

    function cancel() {
        if (!root.sessionId || !root.busy)
            return;
        root.request("session.interrupt", {
            session_id: root.sessionId
        });
    }

    function newConversation(title) {
        root.cancel();
        if (!root.ready) {
            sessionFile.setText("");
            root.clearEntries();
            root.start();
            return;
        }
        root.newSession(title);
    }

    function resumeConversation(id) {
        if (!id || id === root.storedSessionId)
            return;
        if (!gateway.running || root.starting) {
            sessionFile.setText(id); // opened as soon as Hermes is up
            root.start();
            return;
        }
        root.resumeSession(id, false);
    }

    function deleteConversation(id) {
        if (id === root.storedSessionId) {
            root.addNotice(Translation.tr("That's the chat you're in: start a new one first (%1new)").arg("/"));
            return;
        }
        root.request("session.delete", {
            session_id: id
        }, (result, error) => {
            if (error) {
                root.addNotice(Translation.tr("Couldn't delete that chat: %1").arg(error.message ?? ""));
                return;
            }
            root.sessions = root.sessions.filter(session => session.id !== id);
        });
    }

    function refreshSessions() {
        if (!root.ready)
            return;
        root.request("session.list", {
            limit: 50
        }, (result, error) => {
            if (!error && result)
                root.sessions = result.sessions ?? [];
        });
    }

    function refreshModels() {
        if (!root.ready || root.modelChoices.length > 0)
            return;
        root.request("model.options", {
            session_id: root.sessionId
        }, (result, error) => {
            if (error || !result)
                return;
            const choices = [];
            for (const provider of result.providers ?? []) {
                if (provider.authenticated === false)
                    continue;
                for (const model of provider.models ?? [])
                    choices.push({
                        value: `${model} --provider ${provider.slug} --session`,
                        model: model,
                        provider: provider.slug,
                        providerName: provider.name ?? provider.slug,
                        current: model === result.model && provider.slug === result.provider
                    });
            }
            root.modelChoices = choices;
        });
    }

    // Hermes' completions for a command's arguments ("/personality c" -> concise, creative):
    // callback(items: [{ text, display, meta }], replaceFrom)
    function complete(text, callback) {
        if (!root.ready)
            return;
        root.request("complete.slash", {
            session_id: root.sessionId,
            text: text
        }, (result, error) => {
            if (!error && result)
                callback(result.items ?? [], result.replace_from ?? text.length);
        });
    }

    // optionId "" = the question went away unanswered
    function answerPermission(entry, optionId) {
        if (entry.answer !== "")
            return;
        entry.answer = optionId === "" ? "cancelled" : optionId;
        root.respond(entry.requestId, {
            choice: optionId === "" ? "deny" : optionId
        });
    }

    // answers: qid -> string (or [string] for multi-select); null = skip them all
    function answerClarify(entry, answers) {
        if (entry.answer !== "")
            return;
        entry.answer = answers === null ? "cancelled" : "answered";
        entry.answers = answers ?? ({});
        root.respond(entry.requestId, answers === null ? {} : {
            answers: answers
        });
    }

    // value "" = skipped
    function answerSecret(entry, value) {
        if (entry.answer !== "")
            return;
        entry.answer = value.length > 0 ? "given" : "skipped";
        root.respond(entry.requestId, {
            value: value
        });
    }

    function entries() {
        return root.entryIds.map(id => root.entryById[id]);
    }

    // ---- Slash commands -----------------------------------------------------

    // The canonical command for what was typed: an alias, or an unambiguous start ("/us" -> "/usage")
    function resolveCommand(name) {
        const typed = `/${name.toLowerCase()}`;
        if (root.canon[typed])
            return root.canon[typed];
        const names = root.commands.map(command => command.name);
        if (names.includes(typed))
            return typed;
        const prefixed = [...new Set(names.filter(n => n.startsWith(typed)).map(n => root.canon[n] ?? n))];
        return prefixed.length === 1 ? prefixed[0] : typed;
    }

    function runCommand(text) {
        const space = text.search(/\s/);
        const typedName = (space < 0 ? text : text.slice(0, space)).slice(1);
        const arg = space < 0 ? "" : text.slice(space + 1).trim();
        const name = root.resolveCommand(typedName).slice(1);

        // The ones that change the sidebar itself, or that Hermes' TUI and app handle on their side
        switch (name) {
        case "new":
            root.newConversation(arg);
            return;
        case "clear":
            root.newConversation("");
            return;
        case "resume":
        case "sessions":
            if (arg.length === 0 || arg === "new") {
                if (arg === "new")
                    root.newConversation("");
                else
                    root.prefillRequested("/resume ");
                return;
            }
            root.resumeByQuery(arg);
            return;
        case "model":
            if (arg.length === 0) {
                root.prefillRequested("/model ");
                return;
            }
            root.setConfig("model", arg.replace("--tui-session", "--session"), name, true);
            return;
        case "yolo":
            root.setConfig("yolo", undefined, name, true);
            return;
        case "fast":
        case "busy":
        case "verbose":
            if (arg.length === 0 && name !== "verbose")
                root.showConfig(name);
            else
                root.setConfig(name, arg.length > 0 ? arg : "cycle", name, name !== "busy");
            return;
        case "reasoning":
            root.setReasoning(arg);
            return;
        case "title":
            root.request("session.title", arg.length > 0 ? {
                session_id: root.sessionId,
                title: arg
            } : {
                session_id: root.sessionId
            }, (result, error) => {
                if (error)
                    return root.addNotice(Translation.tr("/title: %1").arg(error.message ?? ""));
                if (arg.length > 0)
                    root.sessionTitle = result?.title ?? arg;
                root.addNotice((result?.title ?? "").length > 0 ? Translation.tr("Title: %1").arg(result.title) : Translation.tr("This chat has no title yet"));
            });
            return;
        case "stop":
            root.request("process.stop", {
                session_id: root.sessionId
            }, (result, error) => root.addNotice(error ? Translation.tr("/stop: %1").arg(error.message ?? "") : Translation.tr("Stopped %1 background process(es)").arg(result?.killed ?? 0)));
            return;
        case "bg":
        case "btw":
            if (arg.length === 0)
                return root.addNotice(Translation.tr("Usage: /%1 <prompt>").arg(name));
            root.addEntry({
                kind: "user",
                text: `/${name} ${arg}`,
                done: true
            });
            root.request(name === "bg" ? "prompt.background" : "prompt.btw", {
                session_id: root.sessionId,
                text: arg
            }, (result, error) => {
                if (error)
                    root.addNotice(`/${name}: ${error.message ?? ""}`);
            });
            return;
        case "branch":
            root.request("session.branch", {
                session_id: root.sessionId,
                name: arg
            }, (result, error) => {
                if (error || !result?.session_id)
                    return root.addNotice(Translation.tr("/branch: %1").arg(error?.message ?? ""));
                root.switchTo(result.session_id, result.stored_session_id, result.info ?? {});
                root.sessionTitle = result.title ?? "";
                root.addNotice(Translation.tr("Branched into a new chat: %1").arg(result.title ?? ""));
            });
            return;
        case "copy":
            root.copyReply(arg.length > 0 ? parseInt(arg) : 1);
            return;
        case "paste":
            root.attach("clipboard.paste", {
                session_id: root.sessionId
            });
            return;
        case "image":
            if (arg.length === 0)
                return root.addNotice(Translation.tr("Usage: /image <path>"));
            root.attach("image.attach", {
                session_id: root.sessionId,
                path: arg.replace(/^~/, root.home)
            });
            return;
        case "prompt":
            root.addNotice(Translation.tr("Write it here: Shift+Enter starts a new line"));
            return;
        case "quit":
            GlobalStates.sidebarLeftOpen = false;
            return;
        case "update":
            Quickshell.execDetached(["bash", "-c", `${Config.options.apps.terminal} -e bash -c '${root.binary} update; read -p "Press Enter to close"'`]);
            return;
        case "redraw":
        case "mouse":
        case "density":
        case "statusbar":
        case "indicator":
        case "logs":
            root.addNotice(Translation.tr("/%1 is about Hermes' terminal UI: nothing to change here").arg(name));
            return;
        }
        root.execCommand(name, arg);
    }

    // Everything else runs in Hermes, as in its TUI: slash.exec, and command.dispatch for
    // the ones it hands back (skills, quick and plugin commands)
    function execCommand(name, arg) {
        const command = arg.length > 0 ? `${name} ${arg}` : name;
        root.request("slash.exec", {
            session_id: root.sessionId,
            command: command
        }, (result, error) => {
            if (error) {
                if (error.code === 4018 || error.code === 4011) {
                    root.request("command.dispatch", {
                        session_id: root.sessionId,
                        name: name,
                        arg: arg
                    }, (dispatched, dispatchError) => {
                        if (dispatchError)
                            root.addNotice(dispatchError.message.startsWith("not a quick") ? Translation.tr("Unknown command /%1 (%2 lists them)").arg(name).arg("/help") : `/${name}: ${dispatchError.message}`);
                        else
                            root.handleDirective(dispatched ?? {}, name, arg);
                    });
                    return;
                }
                root.addNotice(`/${name}: ${error.message ?? JSON.stringify(error)}`);
                return;
            }
            if (result?.type) {
                root.handleDirective(result, name, arg);
                return;
            }
            const output = result?.output ?? "";
            root.addOutput(`/${command}`, result?.warning ? `warning: ${result.warning}\n${output}` : output);
        });
    }

    function handleDirective(directive, name, arg) {
        // /undo and /retry rewind the conversation first: show it as Hermes now has it
        if (name === "undo" || name === "retry")
            root.reloadHistory(() => root.applyDirective(directive, name, arg));
        else
            root.applyDirective(directive, name, arg);
    }

    function reloadHistory(then) {
        root.request("session.history", {
            session_id: root.sessionId
        }, (result, error) => {
            if (!error && result) {
                root.clearEntries();
                root.replay(result.messages ?? []);
            }
            then();
        });
    }

    function applyDirective(directive, name, arg) {
        if (directive.notice?.trim())
            root.addNotice(directive.notice.trim());
        switch (directive.type) {
        case "exec":
        case "plugin":
            root.addOutput(`/${name}${arg.length > 0 ? " " + arg : ""}`, directive.output ?? "");
            break;
        case "alias":
            root.runCommand(`/${directive.target}${arg.length > 0 ? " " + arg : ""}`);
            break;
        case "skill":
        case "send":
            if (directive.message?.trim())
                root.sendPrompt(directive.message, directive.display?.trim() ?? (directive.type === "skill" ? `/${name}${arg.length > 0 ? " " + arg : ""}` : ""));
            break;
        case "prefill":
            if (directive.message)
                root.prefillRequested(directive.message);
            break;
        }
    }

    function resumeByQuery(query) {
        root.request("session.list", {
            limit: 100
        }, (result, error) => {
            const sessions = result?.sessions ?? [];
            const lower = query.toLowerCase();
            const match = sessions.find(s => s.id === query) ?? sessions.find(s => s.id.startsWith(query)) ?? sessions.find(s => (s.title ?? "").toLowerCase() === lower) ?? sessions.find(s => (s.title ?? "").toLowerCase().includes(lower));
            // Not listed (an old one, or one this profile hides): let Hermes look it up
            root.resumeConversation(match ? match.id : query);
        });
    }

    function setConfig(key, value, commandName, sessionScoped) {
        const params = {
            key: key
        };
        if (value !== undefined)
            params.value = value;
        if (sessionScoped)
            params.session_id = root.sessionId;
        root.request("config.set", params, (result, error) => {
            if (error)
                return root.addNotice(`/${commandName}: ${error.message ?? ""}`);
            if (result?.info)
                root.applyInfo(result.info);
            if (key === "model" && result?.value)
                root.info = Object.assign({}, root.info, {
                    model: result.value
                });
            const value = result?.value;
            const shown = value === true || value === "1" || value === "true" ? "on" : value === false || value === "0" || value === "false" ? "off" : (value ?? "");
            root.addNotice(`/${commandName}: ${shown}${result?.deferred ? Translation.tr(" (from the next turn)") : ""}${result?.warning ? "\n" + result.warning : ""}`);
        });
    }

    function showConfig(key) {
        root.request("config.get", {
            key: key,
            session_id: root.sessionId
        }, (result, error) => root.addNotice(error ? `/${key}: ${error.message ?? ""}` : `/${key}: ${result?.display ?? result?.value ?? ""}`));
    }

    function setReasoning(arg) {
        const words = arg.split(/\s+/).filter(word => word.length > 0);
        const params = {
            key: "reasoning",
            session_id: root.sessionId,
            value: words.filter(word => word !== "--global" && word !== "--session").join(" ")
        };
        if (words.includes("--global"))
            params.scope = "global";
        if (params.value.length === 0 && !params.scope)
            return root.showConfig("reasoning");
        root.request("config.set", params, (result, error) => {
            if (error)
                return root.addNotice(`/reasoning: ${error.message ?? ""}`);
            if (result?.info)
                root.applyInfo(result.info);
            root.addNotice(`/reasoning: ${result?.value ?? ""}${result?.warning ? "\n" + result.warning : ""}`);
        });
    }

    function copyReply(n) {
        const replies = root.entries().filter(entry => entry.kind === "assistant" && entry.text.length > 0 && entry.label.length === 0);
        const reply = replies[replies.length - Math.max(1, n || 1)];
        if (!reply)
            return root.addNotice(Translation.tr("No reply to copy"));
        Quickshell.clipboardText = reply.text;
        root.addNotice(Translation.tr("Copied the reply"));
    }

    function attach(method, params) {
        root.request(method, params, (result, error) => {
            if (error || !result?.attached)
                return root.addNotice(error?.message ?? result?.message ?? Translation.tr("Nothing to attach"));
            root.addNotice(Translation.tr("Attached %1 for your next message").arg(result.name ?? result.path ?? Translation.tr("an image")));
        });
    }

    // ---- JSON-RPC -----------------------------------------------------------

    property int nextRequestId: 1
    property var pendingRequests: ({})

    function send(message) {
        gateway.write(JSON.stringify(message) + "\n");
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

    function respond(id, result) {
        root.send({
            jsonrpc: "2.0",
            id: id,
            result: result
        });
    }

    function handleLine(line) {
        let message;
        try {
            message = JSON.parse(line);
        } catch (e) {
            return; // not protocol traffic
        }
        if (message.method === "event") {
            root.handleEvent(message.params ?? {});
            return;
        }
        if (message.method !== undefined) {
            if (message.id !== undefined)
                root.handleServerRequest(message);
            return;
        }
        const callback = root.pendingRequests[message.id];
        delete root.pendingRequests[message.id];
        if (callback)
            callback(message.result ?? null, message.error ?? null);
    }

    // ---- Lifecycle ----------------------------------------------------------

    // gateway.ready: say we answer its questions, learn its commands, open the chat
    function connected() {
        root.request("client.capabilities", {
            server_requests: true
        });
        root.request("commands.catalog", {}, (result, error) => {
            if (!error && result)
                root.applyCatalog(result);
        });
        root.openSession();
    }

    function openSession() {
        root.starting = true;
        const lastSession = (sessionFile.text() ?? "").trim();
        if (lastSession.length > 0)
            root.resumeSession(lastSession, true);
        else
            root.newSession("");
    }

    function newSession(title) {
        root.starting = true;
        root.ready = false; // what you type meanwhile waits for the new chat
        const previous = root.sessionId;
        root.request("session.create", {
            cwd: root.home
        }, (result, error) => {
            if (error || !result) {
                root.starting = false;
                root.addNotice(Translation.tr("Hermes couldn't open a chat: %1").arg(error?.message ?? ""));
                return;
            }
            root.clearEntries();
            root.switchTo(result.session_id, result.stored_session_id, result.info ?? {});
            root.closeSession(previous);
            root.sessionTitle = "";
            if (title.length > 0)
                root.runCommand(`/title ${title}`);
            root.becomeReady();
        });
    }

    // quiet: reopening the last chat at startup; if it is gone, just start fresh
    function resumeSession(id, quiet) {
        root.starting = true;
        root.ready = false;
        const previous = root.sessionId;
        root.request("session.resume", {
            session_id: id
        }, (result, error) => {
            if (error || !result?.session_id) {
                if (quiet) {
                    root.newSession("");
                    return;
                }
                root.starting = false;
                root.ready = previous.length > 0;
                root.addNotice(Translation.tr("Couldn't open that chat: %1").arg(error?.message ?? ""));
                return;
            }
            root.clearEntries();
            root.switchTo(result.session_id, result.resumed ?? id, result.info ?? {});
            if (previous !== result.session_id)
                root.closeSession(previous);
            root.sessionTitle = result.info?.title ?? "";
            root.replay(result.messages ?? []);
            root.becomeReady();
        });
    }

    function switchTo(liveId, storedId, info) {
        root.sessionId = liveId;
        root.storedSessionId = storedId ?? "";
        root.busy = false;
        root.activity = "";
        root.contextUsed = 0;
        root.applyInfo(info);
        sessionFile.setText(root.storedSessionId);
    }

    function closeSession(liveId) {
        if (liveId && liveId.length > 0 && liveId !== root.sessionId)
            root.request("session.close", {
                session_id: liveId
            });
    }

    function becomeReady() {
        root.starting = false;
        root.ready = true;
        const waiting = root.waitingInput;
        root.waitingInput = [];
        for (const text of waiting)
            root.submit(text);
    }

    function handleExit(exitCode) {
        root.ready = false;
        root.starting = false;
        root.busy = false;
        root.activity = "";
        root.sessionId = "";
        root.pendingRequests = ({});
        root.finishEntries();
        const why = root.stderrTail.length > 0 ? `\n${root.stderrTail}` : "";
        root.addNotice(Translation.tr("Hermes stopped (exit code %1). Send a message to start it again.").arg(exitCode) + why);
    }

    function applyInfo(info) {
        if (!info || Object.keys(info).length === 0)
            return;
        root.info = Object.assign({}, root.info, info);
        if (info.title)
            root.sessionTitle = info.title;
        if (info.usage)
            root.applyUsage(info.usage);
        if (info.running !== undefined)
            root.busy = info.running;
    }

    function applyUsage(usage) {
        if (!usage)
            return;
        if (usage.context_used !== undefined && usage.context_used !== null)
            root.contextUsed = usage.context_used;
        if (usage.context_max)
            root.contextSize = usage.context_max;
    }

    function applyCatalog(catalog) {
        const described = {};
        for (const pair of catalog.pairs ?? [])
            described[pair[0]] = pair[1];
        const commands = [];
        for (const category of catalog.categories ?? []) {
            for (const pair of category.pairs ?? [])
                commands.push({
                    name: pair[0],
                    description: pair[1],
                    category: category.name,
                    needsArgs: /\(usage: \S+ </.test(pair[1]) // "/bg <prompt>" needs one; "/usage [reset]" doesn't
                });
        }
        for (const name of Object.keys(catalog.skills ?? {}).sort())
            commands.push({
                name: name,
                description: described[name] ?? Translation.tr("Skill"),
                category: "Skills",
                needsArgs: false
            });
        root.commands = commands;
        root.canon = catalog.canon ?? {};
    }

    // ---- What Hermes sends --------------------------------------------------

    function handleEvent(params) {
        const type = params.type ?? "";
        const payload = params.payload ?? {};
        if (type === "gateway.ready") {
            root.connected();
            return;
        }
        if (type === "sessions.changed") {
            root.refreshSessions();
            return;
        }
        if (params.session_id !== root.sessionId)
            return;
        switch (type) {
        case "message.start":
            root.busy = true;
            root.turnStreamed = false;
            root.startQueuedPrompt();
            break;
        case "message.delta":
            root.appendAssistantText(payload.text ?? "", false);
            break;
        case "reasoning.delta":
        case "reasoning.available":
            root.appendAssistantText(payload.text ?? "", true);
            break;
        case "thinking.delta": // a status line ("contemplating..."), not reasoning
            if ((payload.text ?? "").trim().length > 0)
                root.activity = payload.text.trim();
            break;
        case "status.update":
            if ((payload.text ?? "").trim().length > 0)
                root.activity = payload.text.trim();
            break;
        case "message.interim":
            if (payload.already_streamed)
                root.sealAssistant();
            else if ((payload.text ?? "").length > 0)
                root.addEntry({
                    kind: "assistant",
                    text: payload.text,
                    done: true
                });
            break;
        case "message.complete":
            root.completeTurn(payload);
            break;
        case "tool.generating":
            root.activity = Translation.tr("Preparing %1…").arg(payload.name ?? "");
            break;
        case "tool.start":
            root.startTool(payload);
            break;
        case "tool.complete":
            root.completeTool(payload);
            break;
        case "todo.updated":
            root.updatePlan(payload.todos ?? []);
            break;
        case "subagent.start":
            root.startTool({
                tool_id: payload.subagent_id ?? `${payload.goal}-${payload.task_index}`,
                name: "delegate_task",
                context: payload.goal ?? ""
            });
            break;
        case "subagent.complete":
            root.completeTool({
                tool_id: payload.subagent_id ?? `${payload.goal}-${payload.task_index}`,
                name: "delegate_task",
                summary: payload.summary ?? payload.text ?? "",
                failed: ["failed", "error", "timeout"].includes(payload.status ?? "")
            });
            break;
        case "session.info":
            root.applyInfo(payload);
            break;
        case "session.usage":
            root.applyUsage(payload.usage);
            break;
        case "session.title":
            root.sessionTitle = payload.title ?? root.sessionTitle;
            break;
        case "notice":
            root.addNotice(payload.message ?? "");
            break;
        case "error":
            root.addNotice(Translation.tr("Hermes: %1").arg(payload.message ?? ""));
            break;
        case "notification.show":
            if (payload.level === "error" || payload.level === "warning")
                root.addNotice(payload.text ?? "");
            else
                root.activity = payload.text ?? root.activity;
            break;
        case "btw.complete":
        case "background.complete":
            root.addEntry({
                kind: "assistant",
                label: type === "btw.complete" ? "btw" : Translation.tr("background"),
                text: payload.question ? `*${payload.question}*\n\n${payload.text ?? ""}` : (payload.text ?? ""),
                done: true
            });
            break;
        case "request.cancel":
            root.withdrawRequests([payload.id]);
            break;
        case "approval.cancelled":
            root.withdrawRequests(payload.request_ids ?? []);
            break;
        }
    }

    function handleServerRequest(message) {
        const params = message.params ?? {};
        if (params.session_id !== undefined && params.session_id !== root.sessionId) {
            root.sendError(message.id, "Not this sidebar's chat");
            return;
        }
        let entry = null;
        switch (message.method) {
        case "approval":
            entry = root.addEntry({
                kind: "permission",
                requestId: message.id,
                title: params.description ?? "",
                input: params.command ?? "",
                name: params.tool_name ?? "",
                options: (params.choices ?? ["once", "deny"]).map(choice => ({
                            optionId: choice,
                            name: root.approvalLabel(choice),
                            kind: choice === "deny" ? "reject" : "allow"
                        })),
                answer: ""
            });
            break;
        case "clarify":
            entry = root.addEntry({
                kind: "clarify",
                requestId: message.id,
                questions: params.questions ?? [],
                answers: params.answers ?? {},
                answer: ""
            });
            break;
        case "sudo":
        case "secret":
            entry = root.addEntry({
                kind: "secret",
                requestId: message.id,
                envVar: params.env_var ?? "",
                title: message.method === "sudo" ? Translation.tr("Hermes needs your sudo password") : (params.prompt ?? params.env_var ?? ""),
                input: params.command ?? "",
                answer: ""
            });
            break;
        default: // desktop-app bridges (preview, terminal and window reads, vault): not here
            root.sendError(message.id, "Not supported by this client");
            return;
        }
        root.activity = Translation.tr("Waiting for your answer");
        if (!GlobalStates.sidebarLeftOpen)
            Quickshell.execDetached(["notify-send", "-a", "Hermes", Translation.tr("Hermes is asking"), entry.kind === "clarify" ? (entry.questions[0]?.question ?? "") : (entry.title.length > 0 ? entry.title : Translation.tr("Open the left sidebar to answer"))]);
    }

    function sendError(id, text) {
        root.send({
            jsonrpc: "2.0",
            id: id,
            error: {
                code: -32601,
                message: text
            }
        });
    }

    function approvalLabel(choice) {
        switch (choice) {
        case "once":
            return Translation.tr("Allow once");
        case "session":
            return Translation.tr("Allow for this chat");
        case "always":
            return Translation.tr("Always allow");
        case "deny":
            return Translation.tr("Deny");
        default:
            return choice;
        }
    }

    // Hermes took its question back (the turn was stopped, or it timed out)
    function withdrawRequests(ids) {
        for (const entry of root.entries()) {
            if (entry.answer === "" && ids.includes(entry.requestId))
                entry.answer = "cancelled";
        }
    }

    function startQueuedPrompt() {
        const held = root.entries().find(entry => entry.kind === "user" && entry.queued);
        if (held)
            held.queued = false;
    }

    function appendAssistantText(chunk, isThought) {
        if (chunk.length === 0)
            return;
        const last = root.lastEntry();
        let entry = last && last.kind === "assistant" && !last.done && last.label.length === 0 ? last : null;
        if (entry && isThought && entry.text.length > 0)
            entry = null; // reasoning after a reply is the next segment's
        if (!entry)
            entry = root.addEntry({
                kind: "assistant",
                done: false
            });
        if (isThought) {
            entry.thought += chunk;
        } else {
            entry.text += chunk;
            root.turnStreamed = true;
        }
    }

    function sealAssistant() {
        const last = root.lastEntry();
        if (last && last.kind === "assistant")
            last.done = true;
    }

    function completeTurn(payload) {
        root.busy = false;
        root.activity = "";
        // Providers that don't stream hand the whole reply over here
        const text = typeof payload.text === "string" ? payload.text : "";
        if (!root.turnStreamed && text.trim().length > 0)
            root.addEntry({
                kind: "assistant",
                text: text,
                thought: payload.reasoning ?? "",
                done: true
            });
        root.applyUsage(payload.usage);
        if (payload.status === "interrupted")
            root.addNotice(Translation.tr("Stopped"));
        else if (payload.status === "error" && !root.turnStreamed && text.trim().length === 0)
            root.addNotice(Translation.tr("Hermes ran into an error (its log: hermes logs)"));
        if (payload.warning)
            root.addNotice(payload.warning);
        root.finishEntries();
    }

    function toolKindOf(name) {
        if (["terminal", "process", "execute_code"].includes(name))
            return "execute";
        if (["read_file", "skill_view", "session_search"].includes(name))
            return "read";
        if (["write_file", "patch", "skill_manage", "memory"].includes(name))
            return "edit";
        if (["search_files", "web_search", "tool_search"].includes(name))
            return "search";
        if (name.startsWith("browser") || name === "web_extract")
            return "fetch";
        if (name === "delegate_task")
            return "agent";
        return "other";
    }

    function argsText(args) {
        if (!args || Object.keys(args).length === 0)
            return "";
        if (typeof args.command === "string")
            return args.command;
        return "```json\n" + JSON.stringify(args, null, 2) + "\n```";
    }

    function startTool(payload) {
        const name = payload.name ?? "";
        // Shown by their own cards: the question, the todo list
        if (name === "clarify" || name === "todo")
            return;
        const entry = root.addEntry({
            kind: "tool",
            toolCallId: payload.tool_id ?? "",
            name: name,
            title: (payload.context ?? "").length > 0 ? `${name}: ${payload.context}` : name,
            toolKind: root.toolKindOf(name),
            status: "in_progress",
            input: payload.args_text ?? root.argsText(payload.args),
            done: false
        });
        root.toolEntries[entry.toolCallId] = entry;
    }

    function completeTool(payload) {
        if (payload.todos)
            root.updatePlan(payload.todos);
        const entry = root.toolEntries[payload.tool_id ?? ""];
        if (!entry)
            return;
        const result = payload.result;
        const failed = payload.failed || (result && typeof result === "object" && (result.success === false || (result.error ?? null) !== null && result.error !== ""));
        entry.status = failed ? "failed" : "completed";
        if ((payload.inline_diff ?? "").length > 0)
            entry.output = "```diff\n" + payload.inline_diff + "\n```";
        else if ((payload.result_text ?? "").length > 0)
            entry.output = payload.result_text;
        else if ((payload.summary ?? "").length > 0)
            entry.output = payload.summary;
        else if (result !== undefined && result !== null)
            entry.output = typeof result === "string" ? result : "```json\n" + JSON.stringify(result, null, 2) + "\n```";
        entry.done = true;
    }

    function updatePlan(todos) {
        if (!root.currentPlan || root.currentPlan.done)
            root.currentPlan = root.addEntry({
                kind: "plan",
                done: false
            });
        root.currentPlan.planEntries = todos.map(todo => ({
                    content: todo.content ?? todo.text ?? "",
                    status: todo.status ?? "pending"
                }));
    }

    // A resumed chat, as Hermes stored it. Its own notes to the model show as notices
    function replay(messages) {
        for (const message of messages) {
            switch (message.display_kind ?? "") {
            case "hidden":
                continue;
            case "auto_continue":
                root.addNotice(Translation.tr("Hermes picked up a turn that was cut off"));
                continue;
            case "model_switch": {
                const model = (message.text ?? "").match(/changed to (\S+) via provider (\S+)/);
                root.addNotice(model ? Translation.tr("Model for this chat: %1 (%2)").arg(model[1]).arg(model[2]) : Translation.tr("The model changed"));
                continue;
            }
            case "process_complete":
                root.addNotice(message.display_metadata?.display_text ?? Translation.tr("A background process finished"));
                continue;
            case "failed_turn":
                root.addNotice(message.text ?? "");
                continue;
            case "steer":
                root.addEntry({
                    kind: "user",
                    text: (message.text ?? "").replace(/^\[OUT-OF-BAND USER MESSAGE[^\]]*\]\s*/, ""),
                    steered: true,
                    done: true
                });
                continue;
            }
            switch (message.role) {
            case "user":
                root.addEntry({
                    kind: "user",
                    text: message.text ?? "",
                    done: true
                });
                break;
            case "assistant":
                if ((message.text ?? "").length > 0 || (message.reasoning ?? "").length > 0)
                    root.addEntry({
                        kind: "assistant",
                        text: message.text ?? "",
                        thought: message.reasoning ?? "",
                        done: true
                    });
                break;
            case "tool":
                if (message.name === "clarify" || message.name === "todo")
                    break;
                root.addEntry({
                    kind: "tool",
                    toolCallId: message.tool_call_id ?? "",
                    name: message.name ?? "",
                    title: (message.context ?? "").length > 0 ? `${message.name}: ${message.context}` : (message.name ?? ""),
                    toolKind: root.toolKindOf(message.name ?? ""),
                    status: "completed",
                    input: root.argsText(message.args),
                    done: true
                });
                break;
            }
        }
        root.finishEntries();
    }

    // ---- Transcript helpers -------------------------------------------------

    function addEntry(properties) {
        // Whatever Hermes said before this is complete (its reasoning before a tool call, say)
        const previous = root.lastEntry();
        if (previous && previous.kind === "assistant" && properties.kind !== "assistant")
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

    function addOutput(label, text) {
        root.addEntry({
            kind: "output",
            label: label,
            text: text.length > 0 ? text : Translation.tr("(no output)"),
            done: true
        });
    }

    function lastEntry() {
        const count = root.entryIds.length;
        return count > 0 ? root.entryById[root.entryIds[count - 1]] : null;
    }

    // The turn is over: settle whatever is still streaming. Questions stay open: Hermes
    // withdraws them itself when they go away.
    function finishEntries() {
        for (const entry of root.entries()) {
            if (entry.kind === "user")
                entry.queued = entry.queued && root.busy;
            if (entry.kind !== "permission" && entry.kind !== "clarify" && entry.kind !== "secret")
                entry.done = true;
        }
    }

    function clearEntries() {
        root.retiredEntries = [...root.retiredEntries, ...root.entries()];
        root.entryIds = [];
        root.entryById = ({});
        root.toolEntries = ({});
        root.currentPlan = null;
        retireTimer.restart();
    }

    // Cleared entries are destroyed a moment later, once the list's delegates
    // (still animating out) have let go of them
    property var retiredEntries: []
    Timer {
        id: retireTimer
        interval: 2000
        onTriggered: {
            for (const entry of root.retiredEntries)
                entry.destroy();
            root.retiredEntries = [];
        }
    }
}
