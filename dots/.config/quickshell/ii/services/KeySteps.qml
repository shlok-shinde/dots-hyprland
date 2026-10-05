pragma Singleton

import qs.modules.common
import QtQuick
import Quickshell

/**
 * One setting for how far the brightness and volume keys step, here and at the
 * login screen. The shell's keys read the config directly; the login screen's
 * key service (Nothing Liquid's sddm/login-keys.py, root, can't read your home)
 * reads a copy the shell keeps in /var/lib/nothing-liquid/keys.json, a file
 * sddm/install.sh hands to you. Without that file this does nothing.
 */
Singleton {
    id: root

    readonly property string file: "/var/lib/nothing-liquid/keys.json"
    readonly property real brightnessStep: Config.options.light.brightnessStep
    readonly property real volumeStep: Config.options.audio.volumeStep

    function load() {
        // Referenced from shell.qml so the copy is written at startup
    }

    onBrightnessStepChanged: writeTimer.restart()
    onVolumeStepChanged: writeTimer.restart()
    Component.onCompleted: writeTimer.restart()

    Timer {
        id: writeTimer
        interval: 500
        onTriggered: {
            const json = JSON.stringify({
                brightnessStep: root.brightnessStep,
                volumeStep: root.volumeStep
            });
            Quickshell.execDetached(["sh", "-c", '[ -w "$1" ] && printf "%s\\n" "$2" > "$1"', "sh", root.file, json]);
        }
    }
}
