pragma Singleton

import QtQuick
import Quickshell
import qs

// Vaporwave's desktop, from the panel design canvas (dot-shell-panels.html,
// the VAPORWAVE boards): every panel is a Windows 95 window in lilac, its
// title bar a violet-pink-cyan sunset, its readouts sunk into dark dot
// screens. The bevel's white, deep violet and mid violet, the sunset's
// three hues, the screens' yellow, and VT323, the face of every crisp word
// (fonts/, OFL).
Singleton {
    // A color in the era's own tone and in its other one (the `tone` token,
    // Palettes.js): every color here, and every literal in the panels, is
    // a pair, the second authored for the other glass.
    function c(own: var, other: var): color {
        return Tokens.flipped ? (other === undefined ? Tokens.ink(own) : other) : own;
    }

    // The window: lilac face, its bevel lit from the top left.
    readonly property color face: c("#c9b8e8", "#f3ecfb")
    readonly property color hi: c("#ffffff", "#ffffff")
    readonly property color shade: c("#3d1d63", "#9a86bd")
    readonly property color mid: c("#8a6fb8", "#c8b6e6")
    // Ink on the face, labels a step lighter.
    readonly property color ink: c("#130a24", "#2a1840")
    readonly property color label: c("#3d1d63", "#5b3f86")
    // The sunset.
    readonly property color violet: c("#b967ff", "#8b3fd9")
    readonly property color pink: c("#ff71ce", "#d63fa3")
    readonly property color cyan: c("#01cdfe", "#0096c7")
    // The screens: dark glass, unlit dots, and what they light in.
    readonly property color glass: c("#130a24", "#fbf7ff")
    readonly property color unlit: c("#2d1b4e", "#ece2f8")
    readonly property color yellow: c("#fffb96", "#a8730a")
    // Trouble: a low cell, a recording.
    readonly property color red: c("#ff3d7f", "#d61f5f")
    // The screens' faint cyan grid.
    readonly property color grid: c(Qt.rgba(1 / 255, 205 / 255, 254 / 255, 0.25), Qt.rgba(0, 150 / 255, 199 / 255, 0.18))
    // A window held back (do not disturb): the whole thing in grey.
    readonly property color dimFace: c("#6e6a78", "#cfcbd6")

    readonly property string family: vt.status === FontLoader.Ready ? vt.name : "monospace"

    FontLoader {
        id: vt
        source: Qt.resolvedUrl("../fonts/VT323.ttf")
    }
}
