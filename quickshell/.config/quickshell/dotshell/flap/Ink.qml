pragma Singleton

import QtQuick
import Quickshell

// Split-Flap's desktop, from the panel design canvas (dot-shell-panels.html,
// the SPLIT-FLAP boards): every panel is a departure board. A near-black
// housing with a grey rim, rows of flap tiles (a lighter top half, a
// darker bottom one, the hinge between), their letters printed in square
// dots: off-white words, yellow readings, orange warnings, red alarms.
// Silkscreen for the housing's small print, VT323 for big words in dots
// (fonts/, OFL).
Singleton {
    // The housing and its rim.
    readonly property color housing: "#141414"
    readonly property color rim: "#2a2a2a"
    // A flap tile: top half, hinge, bottom half.
    readonly property color upper: "#262626"
    readonly property color seam: "#0b0b0b"
    readonly property color lower: "#1e1e1e"
    // A card inside the housing (expanded boards).
    readonly property color card: "#212121"
    // The letters.
    readonly property color white: "#f2f2e6"
    readonly property color dim: "#bdbdb0"
    readonly property color yellow: "#ffd400"
    readonly property color yellowDeep: "#e6bf00"
    readonly property color orange: "#ff8c00"
    readonly property color red: "#ff5a36"
    // The housing's small print.
    readonly property color label: "#6e6e64"
    // Dot screens (`.pn`): dark glass and its unlit square dots.
    readonly property color glass: "#0b0b0b"
    readonly property color unlit: "#1e1e1e"

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
