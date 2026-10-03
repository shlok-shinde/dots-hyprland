pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Hands the Liquid Glass settings (on/off, Clear / Tinted, edge highlights)
 * to the compositor's glass plugin: right away through hyprctl, and for every
 * later Hyprland start or config reload through a small Lua file that
 * hypr/hyprland/liquidglass.lua reads.
 */
Singleton {
    id: root

    readonly property var settings: Config.options.appearance.liquidGlass
    readonly property bool enabled: settings.enable
    readonly property real tinted: settings.mode === "tinted" ? Math.max(0, Math.min(1, settings.tintAmount)) : 0
    readonly property real edgeHighlight: Math.max(0, settings.edgeHighlight)
    readonly property string statePath: FileUtils.trimFileProtocol(`${Directories.state}/user/generated/liquidglass.lua`)

    // Called once at startup (shell.qml), which also brings the singleton up.
    function load() {
        applyTimer.restart();
    }

    onEnabledChanged: applyTimer.restart()
    onTintedChanged: applyTimer.restart()
    onEdgeHighlightChanged: applyTimer.restart()

    Timer { // a slider drag sends one update, not dozens
        id: applyTimer
        interval: 120
        onTriggered: root.apply()
    }

    function apply() {
        const on = root.enabled ? "true" : "false";
        const fields = `enabled = ${on}, layers = { enabled = ${on} }, tinted = ${root.tinted.toFixed(3)}, edge_highlight = ${root.edgeHighlight.toFixed(3)}`;
        stateFile.setText(`-- written by the shell (Settings > Liquid glass); read by hypr/hyprland/liquidglass.lua\nreturn { ${fields} }\n`);
        Quickshell.execDetached(["hyprctl", "eval", `if hl.plugin.hyprglass then hl.plugin.hyprglass.config({ ${fields} }) end`]);
    }

    FileView {
        id: stateFile
        path: root.statePath
    }
}
