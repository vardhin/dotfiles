pragma Singleton

import QtQuick
import Quickshell

// Vaporwave's desktop, from the panel design canvas (dot-shell-panels.html,
// the VAPORWAVE boards): every panel is a Windows 95 window in lilac, its
// title bar a violet-pink-cyan sunset, its readouts sunk into dark dot
// screens. The bevel's white, deep violet and mid violet, the sunset's
// three hues, the screens' yellow, and VT323, the face of every crisp word
// (fonts/, OFL).
Singleton {
    // The window: lilac face, its bevel lit from the top left.
    readonly property color face: "#c9b8e8"
    readonly property color hi: "#ffffff"
    readonly property color shade: "#3d1d63"
    readonly property color mid: "#8a6fb8"
    // Ink on the face, labels a step lighter.
    readonly property color ink: "#130a24"
    readonly property color label: "#3d1d63"
    // The sunset.
    readonly property color violet: "#b967ff"
    readonly property color pink: "#ff71ce"
    readonly property color cyan: "#01cdfe"
    // The screens: dark glass, unlit dots, and what they light in.
    readonly property color glass: "#130a24"
    readonly property color unlit: "#2d1b4e"
    readonly property color yellow: "#fffb96"
    // Trouble: a low cell, a recording.
    readonly property color red: "#ff3d7f"
    // The screens' faint cyan grid.
    readonly property color grid: Qt.rgba(1 / 255, 205 / 255, 254 / 255, 0.25)
    // A window held back (do not disturb): the whole thing in grey.
    readonly property color dimFace: "#6e6a78"

    readonly property string family: vt.status === FontLoader.Ready ? vt.name : "monospace"

    FontLoader {
        id: vt
        source: Qt.resolvedUrl("../fonts/VT323.ttf")
    }
}
