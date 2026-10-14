pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Which agent the left sidebar has (Config ai.assistant): Hermes Agent, OpenClaw,
 * or none (no AI page). Not chosen yet, the sidebar asks the first time it
 * opens; picking an agent that isn't installed opens a terminal that installs
 * and sets it up (scripts/ai/setup-assistant.sh), followed here through its
 * status file. An agent installed before this question existed is kept as the
 * choice, without asking.
 */
Singleton {
    id: root

    readonly property string choice: Config.options.ai.assistant
    readonly property bool checked: Hermes.checked && OpenClaw.checked
    readonly property var names: ({
        "hermes": "Hermes Agent",
        "openclaw": "OpenClaw",
    })
    readonly property bool chosenAgentInstalled: root.choice === "hermes" ? Hermes.available
        : root.choice === "openclaw" ? OpenClaw.available : false
    // The sidebar shows the picker (or the setup's progress) instead of a chat
    readonly property bool needsSetup: root.choice === "" || ((root.choice === "hermes" || root.choice === "openclaw") && !root.chosenAgentInstalled)

    property string settingUp: "" // the agent whose setup terminal is open
    property bool setupFailed: false

    readonly property string scriptPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/ai/setup-assistant.sh`)
    readonly property string statusPath: `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/nothing-liquid-assistant-setup`

    onCheckedChanged: root.adopt()
    onChoiceChanged: { // Another pick (here or in the settings) ends a setup that's still showing
        if (root.settingUp !== "" && root.choice !== root.settingUp) {
            root.settingUp = "";
            root.setupFailed = false;
        }
    }
    Connections {
        target: Config
        function onReadyChanged() {
            root.adopt();
        }
    }
    function adopt() {
        if (!root.checked || !Config.ready || root.choice !== "")
            return;
        if (Hermes.available)
            Config.options.ai.assistant = "hermes";
        else if (OpenClaw.available)
            Config.options.ai.assistant = "openclaw";
    }

    // "hermes", "openclaw" or "none"; an agent that isn't there yet gets set up
    function choose(agent) {
        Config.options.ai.assistant = agent;
        root.setupFailed = false;
        if ((agent === "hermes" && !Hermes.available) || (agent === "openclaw" && !OpenClaw.available))
            root.setup(agent);
    }

    function setup(agent) {
        root.settingUp = agent;
        root.setupFailed = false;
        const status = StringUtils.shellSingleQuoteEscape(root.statusPath);
        Quickshell.execDetached(["bash", "-c", `echo '${agent} starting' > '${status}'; ` // (not an earlier attempt's "failed")
            + `${Config.options.apps.terminal} -e bash '${StringUtils.shellSingleQuoteEscape(root.scriptPath)}' ${agent}`]);
    }

    // For scripts: qs -c ii ipc call assistant choose hermes|openclaw|none (or ask: the picker again)
    IpcHandler {
        target: "assistant"

        function choose(agent: string): void {
            if (["hermes", "openclaw", "none"].includes(agent))
                root.choose(agent);
        }
        function ask(): void {
            root.cancelSetup();
        }
    }

    // Back to the picker (the setup was closed, or another agent is wanted)
    function cancelSetup() {
        root.settingUp = "";
        root.setupFailed = false;
        Config.options.ai.assistant = "";
    }

    FileView {
        id: statusFile
        path: root.statusPath
        watchChanges: true
        printErrors: false // there is none before the first setup
        onFileChanged: reload()
        onLoaded: root.readStatus(statusFile.text().trim())
    }

    Timer { // (a watch can miss the file being made)
        running: root.settingUp !== ""
        interval: 2000
        repeat: true
        onTriggered: statusFile.reload()
    }

    function readStatus(line) {
        const [agent, state] = line.split(" ");
        if (!agent || agent !== root.settingUp)
            return;
        if (state === "ok") {
            Hermes.recheck();
            OpenClaw.recheck();
        } else if (state === "failed") {
            root.setupFailed = true;
        }
    }

    // Installed: the sidebar's chat takes over
    onChosenAgentInstalledChanged: {
        if (root.chosenAgentInstalled && root.settingUp === root.choice)
            root.settingUp = "";
    }
}
