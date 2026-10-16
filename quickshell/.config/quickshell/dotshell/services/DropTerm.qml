pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Dropdown terminal (Super X): one persistent Ghostty window that is
// parked on a silent workspace when hidden, pulled onto the current one
// when shown, and hidden as soon as it loses focus: once it has had focus,
// any other window (or none) taking it hides it. A click on the empty
// desktop moves no focus in Hyprland, so panes/World.qml reports those
// (clickedAway()).
// panes/WindowFx.qml plays the open / close dots for its moves.
Singleton {
    id: root

    readonly property string cls: "dotshell.dropdown"   // must be a valid GTK app id for Ghostty
    readonly property string clsRe: "dotshell\\.dropdown"
    readonly property string parking: "dotshell-dropdown"

    property bool hidden: true
    // The window's address ("0x…"), once known.
    property string address: ""
    // Focused since it was shown: only then does losing focus hide it (it is
    // not focused yet between the move and the focus dispatch, or while a
    // new one maps).
    property bool hadFocus: false

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
                if (win)
                    root.address = win.address;

                // Decide from where the window really is, not from `hidden`:
                // the flag resets when the shell restarts, the window does not.
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
        Hypr.moveTo("name:" + ws, false, `class:^(${clsRe})$`);
        hidden = false;
        hadFocus = false;
        Hypr.focusWindow(`class:^(${clsRe})$`);
    }

    function hide(): void {
        Hypr.moveTo("name:" + parking, false, `class:^(${clsRe})$`);
        hidden = true;
        hadFocus = false;
    }

    function clickedAway(): void {
        if (!hidden && hadFocus)
            hide();
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "openwindow") {
                const f = event.data.split(",");
                if ((f[2] ?? "").toLowerCase() === root.cls)
                    root.address = "0x" + f[0];
                return;
            }
            if (event.name === "closewindow") {
                if ("0x" + event.data === root.address) {
                    root.address = "";
                    root.hidden = true;
                }
                return;
            }
            if (root.hidden)
                return;
            if (event.name === "activewindowv2") {
                // Empty: nothing focused.
                const a = event.data ? "0x" + event.data : "";
                if (a === root.address)
                    root.hadFocus = true;
                else if (root.hadFocus)
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
