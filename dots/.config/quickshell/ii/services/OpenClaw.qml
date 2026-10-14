pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * OpenClaw in the left sidebar. The sidebar's chat (AiChat) talks to the
 * OpenClaw gateway's OpenAI-style endpoint (gateway.http.endpoints.chatCompletions,
 * on the gateway's port), which runs a whole agent turn: OpenClaw's own model,
 * tools, memory and skills. The gateway's token is read from OpenClaw's config
 * for each request (OpenClawApiStrategy), so it isn't copied anywhere. Ai adds
 * the model once this finds OpenClaw.
 */
Singleton {
    id: root

    property bool checked: false
    property bool available: false
    property string binary: "openclaw"
    readonly property string modelId: "openclaw"
    readonly property string endpoint: "http://localhost:18789/v1/chat/completions" // (the gateway listens on loopback)

    Component.onCompleted: findBinary.running = true

    // Look for OpenClaw again (the sidebar just installed it)
    function recheck() {
        if (root.available || findBinary.running)
            return;
        findBinary.running = true;
    }

    // On PATH, or where its installers put it: install-cli.sh (~/.openclaw), install.sh's npm prefix
    Process {
        id: findBinary
        command: ["bash", "-c", "command -v openclaw || for f in \"$HOME/.openclaw/bin/openclaw\" \"$HOME/.npm-global/bin/openclaw\" \"$HOME/.local/bin/openclaw\"; do [ -x \"$f\" ] && { echo \"$f\"; break; }; done"]
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
}
