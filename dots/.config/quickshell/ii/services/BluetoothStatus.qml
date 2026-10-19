pragma Singleton
pragma ComponentBehavior: Bound

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

    // Turning off also soft-blocks Bluetooth with rfkill. The adapter's power state isn't
    // saved across reboots and BlueZ's AutoEnable (on by default) powers it back on at boot,
    // but systemd-rfkill restores the rfkill block, so off stays off.
    property bool discoverWhenEnabled: false
    function setEnabled(enabled, discover = false) {
        if (!enabled) {
            if (Bluetooth.defaultAdapter) {
                Bluetooth.defaultAdapter.discovering = false;
                Bluetooth.defaultAdapter.enabled = false;
            }
            Quickshell.execDetached(["rfkill", "block", "bluetooth"]);
            return;
        }
        root.discoverWhenEnabled = discover;
        rfkillUnblock.running = true; // Power on once it's unblocked
    }
    function toggle() {
        root.setEnabled(!root.enabled);
    }

    Process {
        id: rfkillUnblock
        command: ["rfkill", "unblock", "bluetooth"]
        onExited: {
            powerOnTimer.tries = 0;
            powerOnTimer.restart();
        }
    }
    Timer { // BlueZ may need a moment to notice the unblock
        id: powerOnTimer
        property int tries: 0
        interval: 200
        repeat: true
        onTriggered: {
            const adapter = Bluetooth.defaultAdapter;
            if (adapter && !adapter.enabled) adapter.enabled = true;
            if (adapter?.enabled || ++tries >= 10) {
                stop();
                if (adapter?.enabled && root.discoverWhenEnabled) adapter.discovering = true;
            }
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
