pragma Singleton

import QtQuick
import Quickshell
import qs

// 90s Nights, Quiet Storm: a bedroom in 1997 past midnight, glow-in-the-dark
// stars on the ceiling, a lava lamp, slow jams on the radio turned low.
// Every panel is still a slanted dot-glass sign (skewed 10°), now in a quiet
// 2 px orchid rim; big words in upright Audiowide, pale orchid into orchid;
// small print orchid, readings the pale green of a glow star, marks rose.
// The notebook and slips are dark paper with cream ink. Warm
// aubergine glass and cream ink, deep jewel colours, a soft glow. The gadgets stay
// (a pager with a green LCD, a camcorder's viewfinder, notebook paper,
// sticky slips). The role names are the old boards' (pink was the marks,
// blue the small print, yellow the readings). Audiowide for the signs,
// VT323 for LCD/OSD text (fonts/, OFL).
Singleton {
    // A color in the era's own tone and in its other one (the `tone` token,
    // Palettes.js): every color here, and every literal in the panels, is
    // a pair, the second authored for the other (daytime) glass.
    function c(own: var, other: var): color {
        return Tokens.flipped ? (other === undefined ? Tokens.ink(own) : other) : own;
    }

    // Rose (marks), orchid (small print, the rim), glow star (readings),
    // the alarm coral, lava orange, cream.
    readonly property color pink: c("#e57ba9", "#b8466f")
    readonly property color blue: c("#c776c4", "#8a3f88")
    readonly property color yellow: c("#dff57e", "#5f6e2a")
    readonly property color red: c("#ff7a6b", "#b5523f")
    readonly property color orange: c("#ff9a5c", "#b8603e")
    readonly property color white: c("#f6ead8", "#2a1f30")
    readonly property color sky: c("#e8b4e4", "#a0609e")
    // Deep violet (dim tracks, card rules), magenta, the dim key word.
    readonly property color deep: c("#3a2a42", "#d9cfd6")
    readonly property color magenta: c("#8a4a8a", "#e3cfe0")
    readonly property color dim: c("#7a6680", "#a898a8")
    // The dot glass (`.pn`) and its unlit dots; dark ink on a lit key.
    readonly property color glass: c("#120d17", "#f4ede4")
    readonly property color unlit: c("#2a1f30", "#e6ddd2")
    readonly property color night: c("#120d17", "#120d17")
    // Unlit channel tiles (workspaces), their top light.
    readonly property color tileHi: c("#3a2c44", "#efe6ea")
    readonly property color tileLo: c("#2a1f30", "#e6dde4")
    readonly property color tileLine: c("#5e4e66", "#ffffff")
    // Chrome (slider caps, the battery's can, transport keys).
    readonly property color chromeHi: c("#f6ead8", "#ffffff")
    readonly property color chromeMid: c("#8a7f8c", "#a39aa6")
    readonly property color chromeLo: c("#3a3040", "#5e5462")
    readonly property color chromeEnd: c("#b8acb4", "#d6ccd2")

    // Notebook paper and sticky slips, and their ink.
    readonly property color paper: c("#1f1727", "#fffaf0")
    readonly property color slip: c("#2a1f33", "#fdf8ec")
    readonly property color paperInk: c("#f6ead8", "#3a2a42")
    readonly property color paperDone: c("#7a6680", "#8a7a8c")
    readonly property color paperRule: c(Qt.rgba(199 / 255, 118 / 255, 196 / 255, 0.28), Qt.rgba(138 / 255, 63 / 255, 136 / 255, 0.3))
    readonly property color paperMargin: c(Qt.rgba(229 / 255, 123 / 255, 169 / 255, 0.6), Qt.rgba(184 / 255, 70 / 255, 111 / 255, 0.4))
    readonly property color highlight: c(Qt.rgba(223 / 255, 245 / 255, 126 / 255, 0.16), Qt.rgba(214 / 255, 240 / 255, 110 / 255, 0.4))
    readonly property color slipInk: c("#f6ead8", "#2a1f30")
    readonly property color slipTime: c("#c776c4", "#8a3f88")
    readonly property color shadow: c("#0e0a12", "#2a1f30")

    // The pager: magenta case, green LCD, its ink.
    readonly property color caseA: c("#3a2a42", "#c9a6c4")
    readonly property color caseB: c("#8a4a8a", "#e3cfe0")
    readonly property color caseC: c("#2a1f30", "#b08aac")
    readonly property color lcdHi: c("#9bd7c0", "#b4e6d2")
    readonly property color lcdLo: c("#6fb8a0", "#8ccbb4")
    readonly property color lcdInk: c("#0a2a22", "#0a2a22")
    readonly property color lcdSoft: c("#1f5a4a", "#2a6a58")
    readonly property color lcdRim: c("#120d17", "#2a1f30")

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

    // The rim: one quiet orchid (kept as stops; the strip forms run it across).
    readonly property var rim: [[0, blue], [1, blue]]
    // Big words: pale orchid into orchid. The clock: cream, pale orchid, orchid.
    readonly property var sunset: [[0, sky], [1, blue]]
    readonly property var chrome: [[0, white], [0.5, sky], [1, blue]]
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
