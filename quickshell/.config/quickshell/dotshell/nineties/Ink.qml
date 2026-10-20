pragma Singleton

import QtQuick
import Quickshell
import qs

// 90s Nights, from the panel design canvas (dot-shell-panels.html, the
// 90S NIGHTS boards): strip-mall neon. Every panel is a slanted dot-glass
// sign (skewed 10°) in a 3 px rim running yellow → hot pink → electric blue,
// its big words in Audiowide italic filled with that sunset, its small print
// electric blue, its readings yellow. Some panels are the decade's gadgets
// instead: a magenta pager with a green LCD (messages), a camcorder's
// viewfinder (capture), a page of ruled notebook paper (todo), sticky slips
// (clipboard). Audiowide for the neon, VT323 for LCD/OSD text (fonts/, OFL).
Singleton {
    // A color in the era's own tone and in its other one (the `tone` token,
    // Palettes.js): every color here, and every literal in the panels, is
    // a pair, the second authored for the other (daytime) glass.
    function c(own: var, other: var): color {
        return Tokens.flipped ? (other === undefined ? Tokens.ink(own) : other) : own;
    }

    // The neon: hot pink, electric blue, yellow, and the alarm red.
    readonly property color pink: c("#ff2e97", "#e6177d")
    readonly property color blue: c("#1fa8ff", "#0a84d6")
    readonly property color yellow: c("#ffe600", "#d99a00")
    readonly property color red: c("#ff3355", "#d9234a")
    readonly property color orange: c("#ff8c00", "#e07000")
    readonly property color white: c("#ffffff", "#2b1b4a")
    readonly property color sky: c("#a3d8ff", "#5aa8e0")
    // Deep violet (dim tracks, card rules), magenta, the dim key word.
    readonly property color deep: c("#3b0d5c", "#d9c6e6")
    readonly property color magenta: c("#a3157f", "#f7b6d6")
    readonly property color dim: c("#5a3a7e", "#b8a6cc")
    // The dot glass (`.pn`) and its unlit dots; dark ink on a lit key.
    readonly property color glass: c("#0a0514", "#fff6e5")
    readonly property color unlit: c("#22123a", "#efe6d6")
    readonly property color night: c("#0a0514", "#0a0514")
    // Unlit channel tiles (workspaces), their top light.
    readonly property color tileHi: c("#4a2a6e", "#f3e6f8")
    readonly property color tileLo: c("#22123a", "#e2d2ec")
    readonly property color tileLine: c("#7a5aa0", "#ffffff")
    // Chrome (slider caps, the battery's can, transport keys).
    readonly property color chromeHi: c("#ffffff", "#ffffff")
    readonly property color chromeMid: c("#8a8aa0", "#9a9ab0")
    readonly property color chromeLo: c("#3a3a50", "#5a5a70")
    readonly property color chromeEnd: c("#c0c0d0", "#d0d0e0")

    // Notebook paper and sticky slips, and their ink.
    readonly property color paper: c("#fffbea", "#ffffff")
    readonly property color slip: c("#fffbe0", "#fffdf0")
    readonly property color paperInk: c("#3b0d5c", "#3b0d5c")
    readonly property color paperDone: c("#8a6fa8", "#8a6fa8")
    readonly property color paperRule: c(Qt.rgba(31 / 255, 168 / 255, 1, 0.35), Qt.rgba(10 / 255, 132 / 255, 214 / 255, 0.3))
    readonly property color paperMargin: c(Qt.rgba(1, 46 / 255, 151 / 255, 0.5), Qt.rgba(230 / 255, 23 / 255, 125 / 255, 0.45))
    readonly property color highlight: c(Qt.rgba(1, 230 / 255, 0, 0.45), Qt.rgba(245 / 255, 196 / 255, 0, 0.4))
    readonly property color slipInk: c("#0a0514", "#0a0514")
    readonly property color slipTime: c("#1f5aa0", "#1f5aa0")
    readonly property color shadow: c("#0a0514", "#2b1b4a")

    // The pager: magenta case, green LCD, its ink.
    readonly property color caseA: c("#3b0d5c", "#c25aa8")
    readonly property color caseB: c("#a3157f", "#f08ccb")
    readonly property color caseC: c("#22123a", "#a6559a")
    readonly property color lcdHi: c("#9bd7c0", "#b4e6d2")
    readonly property color lcdLo: c("#6fb8a0", "#8ccbb4")
    readonly property color lcdInk: c("#0a2a22", "#0a2a22")
    readonly property color lcdSoft: c("#1f5a4a", "#2a6a58")
    readonly property color lcdRim: c("#0a0514", "#2b1b4a")

    // The camcorder: its body, rim, the viewfinder's violet dark.
    readonly property color camHi: c("#2a2a34", "#d6d6de")
    readonly property color camLo: c("#0a0a10", "#a8a8b4")
    readonly property color camRim: c("#5a5a70", "#ffffff")
    readonly property color camTitle: c("#ffffff", "#1a1a24")

    // Strip/rail form inks (Docked.qml): readings, small print, marks,
    // alarms, dim tracks, the bar under them.
    readonly property color ink: yellow
    readonly property color label: blue
    readonly property color mid: deep
    readonly property color face: glass

    // The rim's sunset, its stops (135°: top left yellow, then pink, blue).
    readonly property var rim: [[0, yellow], [0.4, pink], [1, blue]]
    // Big words: yellow over pink. The clock's chrome: white, sky, a dark
    // horizon, pink, yellow.
    readonly property var sunset: [[0, yellow], [1, pink]]
    readonly property var chrome: [[0, c("#ffffff", "#5aa8e0")], [0.45, sky], [0.5, c("#3b0d5c", "#2b1b4a")], [0.75, pink], [1, yellow]]
    // Readings' columns: blue at the foot, pink, yellow at the top.
    readonly property var column: [[0, yellow], [0.4, pink], [1, blue]]

    readonly property string family: aw.status === FontLoader.Ready ? aw.name : "sans-serif"
    readonly property string mono: vt.status === FontLoader.Ready ? vt.name : "monospace"

    FontLoader {
        id: aw
        source: Qt.resolvedUrl("../fonts/Audiowide.ttf")
    }
    FontLoader {
        id: vt
        source: Qt.resolvedUrl("../fonts/VT323.ttf")
    }
}
