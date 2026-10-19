pragma Singleton

import QtQuick
import Quickshell
import qs

// Split-Flap's desktop, from the panel design canvas (dot-shell-panels.html,
// the SPLIT-FLAP boards): every panel is a departure board. A near-black
// housing with a grey rim, rows of flap tiles (a lighter top half, a
// darker bottom one, the hinge between), their letters printed in square
// dots: off-white words, yellow readings, orange warnings, red alarms.
// Silkscreen for the housing's small print, VT323 for big words in dots
// (fonts/, OFL).
Singleton {
    // A color in the era's own tone and in its other one (the `tone` token,
    // Palettes.js): every color here, and every literal in the panels, is
    // a pair, the second authored for the other glass.
    function c(own: var, other: var): color {
        return Tokens.flipped ? (other === undefined ? Tokens.ink(own) : other) : own;
    }

    // The housing and its rim.
    readonly property color housing: c("#141414", "#e8e3d6")
    readonly property color rim: c("#2a2a2a", "#c9c2b2")
    // A flap tile: top half, hinge, bottom half.
    readonly property color upper: c("#262626", "#fbf9f3")
    readonly property color seam: c("#0b0b0b", "#b8b1a1")
    readonly property color lower: c("#1e1e1e", "#efebe1")
    // A card inside the housing (expanded boards).
    readonly property color card: c("#212121", "#f5f2ea")
    // The letters.
    readonly property color white: c("#f2f2e6", "#1c1b18")
    readonly property color dim: c("#bdbdb0", "#5a574f")
    readonly property color yellow: c("#ffd400", "#b07d00")
    readonly property color yellowDeep: c("#e6bf00", "#8f6300")
    readonly property color orange: c("#ff8c00", "#c25a00")
    readonly property color red: c("#ff5a36", "#c4321a")
    // The housing's small print.
    readonly property color label: c("#6e6e64", "#8a8475")
    // Dot screens (`.pn`): dark glass and its unlit square dots.
    readonly property color glass: c("#0b0b0b", "#f1ede3")
    readonly property color unlit: c("#1e1e1e", "#e4dfd2")

    readonly property string small: silk.status === FontLoader.Ready ? silk.name : "monospace"
    readonly property string family: vt.status === FontLoader.Ready ? vt.name : "monospace"

    FontLoader {
        id: silk
        source: Qt.resolvedUrl("../fonts/Silkscreen.ttf")
    }
    FontLoader {
        id: vt
        source: Qt.resolvedUrl("../fonts/VT323.ttf")
    }
}
