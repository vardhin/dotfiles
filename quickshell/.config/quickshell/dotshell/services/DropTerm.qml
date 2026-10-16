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
                let win = null;
                try {
                    win = JSON.parse(text).find(c => (c.class || c.initialClass || "").toLowerCase() === root.cls) ?? null;
                } catch (e) {}

                // Decide from where the window really is, not from `hidden`:
                // the flag resets when the shell restarts, the window does not.
                root.graceUntil = Date.now() + 1500;
                if (!win) {
                    root.hidden = false;
                    // gtk-single-instance=false: a new process, so the class sticks
                    // even when another Ghostty is already running.
                    Quickshell.execDetached(["ghostty", "--gtk-single-instance=false", "--class=" + root.cls, "--title=Dropdown", "--background-opacity=0.95"]);
                } else if (win.workspace?.name !== Hyprland.focusedWorkspace?.name) {
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
                // An empty class is a window still mapping (often the dropdown itself).
                if (focusedClass !== "" && focusedClass !== root.cls)
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
