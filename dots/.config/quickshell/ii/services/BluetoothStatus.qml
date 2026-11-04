pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property bool available: Bluetooth.adapters.values.length > 0
    readonly property bool enabled: Bluetooth.defaultAdapter?.enabled ?? false
    readonly property BluetoothDevice firstActiveDevice: Bluetooth.defaultAdapter?.devices.values.find(device => device.connected) ?? null
    readonly property int activeDeviceCount: Bluetooth.defaultAdapter?.devices.values.filter(device => device.connected).length ?? 0
    readonly property bool connected: Bluetooth.devices.values.some(d => d.connected)

    // BlueZ doesn't save whether Bluetooth is on and powers on every adapter it finds
    // (AutoEnable): at boot, and on waking from sleep, when a USB adapter comes back as
    // a new one. So remember it here, whichever app switches it, and put it back for a
    // few seconds after each of those: a change then is BlueZ's, not the user's.
    property bool restored: false
    property real settleUntil: 0
    readonly property int settleMs: 10000
    function restoreEnabled() {
        if (!Persistent.ready || !Bluetooth.defaultAdapter) return;
        if (!root.restored) {
            root.restored = true;
            if (!Persistent.isNewHyprlandInstance) { // The shell restarted: keep what it is now
                Persistent.states.bluetooth.enabled = Bluetooth.defaultAdapter.enabled;
                return;
            }
        }
        root.settleUntil = Date.now() + root.settleMs;
        root.applySaved();
    }
    function applySaved() {
        if (!Persistent.states.bluetooth.enabled && Bluetooth.defaultAdapter?.enabled)
            Bluetooth.defaultAdapter.enabled = false;
    }
    function load() {} // (shell.qml: so it restores at login with no bar to show it)
    Component.onCompleted: restoreEnabled()
    Connections {
        target: Bluetooth
        function onDefaultAdapterChanged() { // found at boot, back after sleep, plugged in
            Qt.callLater(root.restoreEnabled);
        }
    }
    Connections {
        target: Persistent
        function onReadyChanged() {
            Qt.callLater(root.restoreEnabled);
        }
    }
    Connections {
        target: Bluetooth.defaultAdapter
        function onEnabledChanged() {
            if (!root.restored) return;
            if (Date.now() - root.lastTick > 20000) // woke up before the timer could notice
                root.restoreEnabled();
            else if (Date.now() < root.settleUntil)
                root.applySaved();
            else
                Persistent.states.bluetooth.enabled = Bluetooth.defaultAdapter.enabled;
        }
    }
    // Timers stop while the computer sleeps: a long gap between ticks is a wake-up,
    // in case the adapter came back as the same one
    property real lastTick: Date.now()
    Timer {
        running: root.restored
        repeat: true
        interval: 5000
        onTriggered: {
            const now = Date.now();
            if (now - root.lastTick > 20000)
                root.restoreEnabled();
            root.lastTick = now;
        }
    }

    function sortFunction(a, b) {
        // Ones with meaningful names before MAC addresses
        const macRegex = /^([0-9A-Fa-f]{2}-){5}[0-9A-Fa-f]{2}$/;
        const aIsMac = macRegex.test(a.name);
        const bIsMac = macRegex.test(b.name);
        if (aIsMac !== bIsMac)
            return aIsMac ? 1 : -1;

        // Alphabetical by name
        return a.name.localeCompare(b.name);
    }
    property list<var> connectedDevices: Bluetooth.devices.values.filter(d => d.connected).sort(sortFunction)
    property list<var> pairedButNotConnectedDevices: Bluetooth.devices.values.filter(d => d.paired && !d.connected).sort(sortFunction)
    property list<var> unpairedDevices: Bluetooth.devices.values.filter(d => !d.paired && !d.connected).sort(sortFunction)
    property list<var> friendlyDeviceList: [
        ...connectedDevices,
        ...pairedButNotConnectedDevices,
        ...unpairedDevices
    ]
}
