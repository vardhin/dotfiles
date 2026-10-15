pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Dropdown terminal (Super X): one persistent Ghostty window that is
// parked on a silent workspace when hidden, pulled onto the current one
// when shown, and hidden again when focus moves elsewhere.
Singleton {
    id: root

    readonly property string cls: "dotshell.dropdown"   // must be a valid GTK app id for Ghostty
    readonly property string clsRe: "dotshell\\.dropdown"
    readonly property string parking: "dotshell-dropdown"

    property bool hidden: true
    property double graceUntil: 0       // ignore focus events right after showing

    function toggle(): void {
        clients.running = true;
    }

    // `hyprctl -j clients` tells whether the window exists yet.
    Process {
        id: clients
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                let exists = false;
                try {
                    exists = JSON.parse(text).some(c => (c.class || c.initialClass || "").toLowerCase() === root.cls);
                } catch (e) {}

                root.graceUntil = Date.now() + 650;
                if (!exists) {
                    root.hidden = false;
                    Quickshell.execDetached(["ghostty", "--class=" + root.cls, "--title=Dropdown", "--background-opacity=0.95"]);
                } else if (root.hidden) {
                    root.show();
                } else {
                    root.hide();
                }
            }
        }
    }

    function show(): void {
        const ws = Hyprland.focusedWorkspace?.name;
        if (!ws)
            return;
        Hyprland.dispatch(`movetoworkspacesilent name:${ws},class:^(${clsRe})$`);
        Hyprland.dispatch(`focuswindow class:^(${clsRe})$`);
        hidden = false;
    }

    function hide(): void {
        Hyprland.dispatch(`movetoworkspacesilent name:${parking},class:^(${clsRe})$`);
        hidden = true;
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (root.hidden || Date.now() < root.graceUntil)
                return;
            if (event.name === "activewindow") {
                const focusedClass = event.data.split(",")[0].toLowerCase();
                if (focusedClass !== root.cls)
                    root.hide();
            } else if (event.name === "workspace") {
                root.hide();
            }
        }
    }

    IpcHandler {
        target: "dropdown"

        function toggle(): void {
            root.toggle();
        }
    }
}
