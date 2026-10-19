pragma Singleton

import QtQuick
import Quickshell

// Tokyo Night's neon, from the panel design canvas (dot-shell-panels.html,
// the TOKYO NIGHT boards): the three tubes, the deep violet of the unlit
// rules, the alarm red, and Tilt Neon, the sign face (fonts/, OFL).
Singleton {
    readonly property color pink: "#ff3cac"
    readonly property color cyan: "#2de2e6"
    readonly property color violet: "#b388ff"
    // Rules, tracks and the outlines of things that are off.
    readonly property color deep: "#3c146e"
    readonly property color red: "#ff2a4a"
    readonly property color unlit: "#211c46"
    readonly property color glass: "#08071a"
    // The signs' corner: the media sign's pill, half its 168 px height.
    // Rectangle and Glass clamp it, so a shorter sign is a pill too.
    readonly property real curve: 84

    readonly property string family: neon.status === FontLoader.Ready ? neon.name : "sans-serif"

    FontLoader {
        id: neon
        source: Qt.resolvedUrl("../fonts/TiltNeon.ttf")
    }
}
