pragma Singleton

import QtQuick
import Quickshell
import qs

// Night Vision, from the panel design canvas (dot-shell-panels.html, the
// NIGHT VISION boards): a Gen III scope's P43 phosphor. Every panel is one
// green dot screen (the era's own DotSurface: glass #040a03, unlit #0d260b)
// in a rounded eyepiece, darkened toward its rim; compact panels are an
// elliptic pill, expanded ones a CRT's squircle with a dark inner ring. On
// the glass: words in dots, lit green #7dff6a, bright #d6ffc9 for readings,
// dim #2fae2a for small print; crisp parts are thin green rules (#2b8a22),
// white boxes round the picked row, white reticle corners and crosshairs,
// and solid lit keys with dark words. Share Tech Mono (fonts/, OFL).
Singleton {
    // A color in the era's own tone and in its other one (the `tone` token,
    // Palettes.js: a daylight scope, sand and olive drab).
    function c(own: var, other: var): color {
        return Tokens.flipped ? (other === undefined ? Tokens.ink(own) : other) : own;
    }

    // The phosphor: lit, bright (readings, the picked one), dim (small print).
    readonly property color lit: c("#7dff6a", "#3f5a1a")
    readonly property color bright: c("#d6ffc9", "#262b14")
    readonly property color dim: c("#2fae2a", "#5c6b2e")
    // Thin rules round cards and keys; the deep green of dim tracks, the
    // inner ring and unlit bar cells.
    readonly property color rule: c("#2b8a22", "#7a7a4a")
    readonly property color deep: c("#0f3a0c", "#c4bd98")
    // The glass and its unlit dots; dark words on a lit key.
    readonly property color glass: c("#040a03", "#e9e4d0")
    readonly property color unlit: c("#0d260b", "#d8d2ba")
    readonly property color night: c("#040a03", "#f3efe0")
    // The eyepiece's darkening toward the rim, and the faint green bloom
    // at its middle.
    readonly property color shade: c(Qt.rgba(0, 0, 0, 0.75), Qt.rgba(38 / 255, 43 / 255, 20 / 255, 0.22))
    readonly property color bloom: c(Qt.rgba(125 / 255, 1, 106 / 255, 0.08), Qt.rgba(1, 1, 1, 0.12))
    readonly property color hover: c(Qt.rgba(125 / 255, 1, 106 / 255, 0.14), Qt.rgba(63 / 255, 90 / 255, 26 / 255, 0.12))

    // Strip/rail form inks (Docked.qml): readings, small print, marks,
    // alarms, dim tracks, the bar under them.
    readonly property color ink: bright
    readonly property color label: dim
    readonly property color pink: lit
    readonly property color red: bright
    readonly property color mid: deep
    readonly property color face: glass

    readonly property string family: mono.status === FontLoader.Ready ? mono.name : "monospace"

    FontLoader {
        id: mono
        source: Qt.resolvedUrl("../fonts/ShareTechMono.ttf")
    }
}
