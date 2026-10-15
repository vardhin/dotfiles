pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

// Wi-Fi over NetworkManager. Wired is only reported, not managed.
Singleton {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired) ?? null

    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property bool hardwareEnabled: Networking.wifiHardwareEnabled
    readonly property bool wiredUp: wired?.connected ?? false

    readonly property var networks: wifi ? [...wifi.networks.values].sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength)) : []
    readonly property var active: networks.find(n => n.connected) ?? null

    // Network that just asked for a password; the Wi-Fi pane shows a prompt.
    property var needsPassword: null
    property string lastError: ""

    function setEnabled(on: bool): void {
        Networking.wifiEnabled = on;
    }

    function scan(on: bool): void {
        if (wifi)
            wifi.scannerEnabled = on;
    }

    function connect(net: var): void {
        lastError = "";
        needsPassword = null;
        if (net.connected)
            net.disconnect();
        else
            net.connect();
    }

    function connectWithPassword(net: var, psk: string): void {
        lastError = "";
        needsPassword = null;
        net.connectWithPsk(psk);
    }

    // Every network's failures land here.
    Instantiator {
        model: root.wifi ? root.wifi.networks : null

        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectionFailed(reason) {
                if (reason === ConnectionFailReason.NoSecrets) {
                    root.needsPassword = modelData;
                    root.lastError = modelData.known ? "WRONG PASSWORD" : "";
                } else {
                    root.lastError = "FAILED";
                }
            }
        }
    }

    function securityName(net: var): string {
        return net.security === WifiSecurityType.Open ? "OPEN" : "LOCK";
    }

    function needsPsk(net: var): bool {
        return [WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae].includes(net.security);
    }
}
