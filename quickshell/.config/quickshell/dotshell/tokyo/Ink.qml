pragma Singleton

import QtQuick
import Quickshell
import qs

// Tokyo Night's neon, from the panel design canvas (dot-shell-panels.html,
// the TOKYO NIGHT boards): the three tubes, the deep violet of the unlit
// rules, the alarm red, and Tilt Neon, the sign face (fonts/, OFL).
Singleton {
    // A color in the era's own tone and in its other one (the `tone` token,
    // Palettes.js): every color here, and every literal in the panels, is
    // a pair, the second authored for the other glass.
    function c(own: var, other: var): color {
        return Tokens.flipped ? (other === undefined ? Tokens.ink(own) : other) : own;
    }
    // Halos: off when the era is drawn light.
    readonly property bool neon: Tokens.neon

    readonly property color pink: c("#ff3cac", "#c92c7f")
    readonly property color cyan: c("#2de2e6", "#007197")
    readonly property color violet: c("#b388ff", "#7847bd")
    // Rules, tracks and the outlines of things that are off.
    readonly property color deep: c("#3c146e", "#c4c8da")
    readonly property color red: c("#ff2a4a", "#e0285c")
    readonly property color unlit: c("#211c46", "#d0d3e0")
    readonly property color glass: c("#08071a", "#e1e2e7")
    // The signs' corner: the media sign's pill, half its 168 px height.
    // Rectangle and Glass clamp it, so a shorter sign is a pill too.
    readonly property real curve: 84

    readonly property string family: neon.status === FontLoader.Ready ? neon.name : "sans-serif"

    FontLoader {
        id: neon
        source: Qt.resolvedUrl("../fonts/TiltNeon.ttf")
    }
}
