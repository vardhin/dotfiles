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
    // A switch to make, as data for services/Hypr.qml: { kind: "go" | "move", arg }.
    signal requested(var req)

    // `arg`: anything Hyprland's workspace dispatcher takes (3, e+1, previous, empty).
    function go(arg: string): void {
        request({ kind: "go", arg: arg });
    }
    // Move the focused window there and follow it.
    function move(arg: string): void {
        request({ kind: "move", arg: arg });
    }

    function request(req: var): void {
        if (on)
            requested(req);
        else
            Hypr.run(req);
    }

    // Hyprland's own workspace animation, as hypr/lua/look.lua has it.
    function applyAnim(): void {
        Hypr.animation("workspaces", !on, 5, "breathing", "slidefade");
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
    // Hypr learns the config language after startup; say it again in that one.
    Connections {
        target: Hypr
        function onKnownChanged() {
            root.applyAnim();
        }
    }
}
