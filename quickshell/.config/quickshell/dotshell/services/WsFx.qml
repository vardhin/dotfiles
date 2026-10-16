pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs

// Workspace switches that dissolve (the `wsfx` token). The switch has to go
// through the shell, since the old workspace is snapshotted before Hyprland
// moves: the binds call `dotws go 3` (the `ws` command on the dot socket),
// the strip and the side bar call go() directly. panes/WorkspaceFx.qml takes
// the snapshot, dispatches the switch and plays the dissolve.
//
// While it is on, Hyprland's own workspace animation is off, so the new
// workspace is in place under the dissolve at once.
Singleton {
    id: root

    readonly property bool on: Tokens.wsfx
    // Hyprland's own animation, as hypr/config/decorations.conf has it.
    readonly property string hyprAnim: "workspaces,1,5,breathing,slidefade"

    // A switch to make: "workspace 3", "movetoworkspace e+1", …
    signal requested(string dispatch)

    // `arg`: anything Hyprland's workspace dispatcher takes (3, e+1, previous, empty).
    function go(arg: string): void {
        request("workspace " + arg);
    }
    // Move the focused window there and follow it.
    function move(arg: string): void {
        request("movetoworkspace " + arg);
    }

    function request(d: string): void {
        if (on)
            requested(d);
        else
            Hyprland.dispatch(d);
    }

    function applyAnim(): void {
        Quickshell.execDetached(["hyprctl", "keyword", "animation", on ? "workspaces,0" : hyprAnim]);
    }
    onOnChanged: applyAnim()
    Component.onCompleted: applyAnim()

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded")
                root.applyAnim();
        }
    }
}
