pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs

// Night warmth as a Hyprland screen shader (shaders/warm.glsl), replacing
// hyprsunset. Phase 6 folds it into the glass screen shader as a uniform.
// State is the `night` token, so it survives restarts.
Singleton {
    id: root

    readonly property bool on: Tokens.night
    readonly property string shader: String(Qt.resolvedUrl("../shaders/warm.glsl")).replace(/^file:\/\//, "")

    function apply(): void {
        Quickshell.execDetached(["hyprctl", "keyword", "decoration:screen_shader", on ? shader : "[[EMPTY]]"]);
    }

    function toggle(): void {
        Tokens.toggleNight();
    }

    onOnChanged: apply()
    Component.onCompleted: apply()

    // A config reload resets the shader; put it back.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded")
                root.apply();
        }
    }
}
