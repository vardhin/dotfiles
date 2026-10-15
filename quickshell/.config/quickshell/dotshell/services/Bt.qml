pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Bluetooth over BlueZ. Pairing devices that need a PIN goes through the
// "MORE" button (bluetoothctl in a terminal), which brings its own agent.
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool present: adapter !== null
    readonly property bool powered: adapter?.enabled ?? false
    readonly property bool scanning: adapter?.discovering ?? false

    readonly property var devices: adapter ? [...adapter.devices.values].filter(d => d.name || d.deviceName).sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || (a.name || "").localeCompare(b.name || "")) : []
    readonly property var connected: devices.filter(d => d.connected)

    function setEnabled(on: bool): void {
        if (adapter)
            adapter.enabled = on;
    }

    function scan(): void {
        if (!adapter?.enabled)
            return;
        adapter.discovering = true;
        scanStop.restart();
    }

    Timer {
        id: scanStop
        interval: 15000
        onTriggered: {
            if (root.adapter)
                root.adapter.discovering = false;
        }
    }

    function toggle(dev: var): void {
        if (dev.connected)
            dev.disconnect();
        else if (dev.paired)
            dev.connect();
        else
            dev.pair();
    }
}
