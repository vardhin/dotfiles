pragma Singleton

import QtQuick
import Quickshell
import qs

// Nixie's desktop, from the panel design canvas (dot-shell-panels.html, the
// NIXIE boards): every panel is a piece of valve-era kit in a walnut case.
// The wood runs in grain bands, a brass rule just inside its edge and a dark
// one inside that; on it sit glass tubes with honeycomb mesh and a cold
// orange digit over a dim "8", brass keys, ivory paper and meter faces.
// Expanded, the case holds one dark dot screen ruled in brass. Nixie One
// for the big glowing words, Silkscreen for the brass small print, Share
// Tech Mono for typed slips (fonts/, OFL).
Singleton {
    // A color in the era's own tone and in its other one (the `tone` token,
    // Palettes.js): every color here, and every literal in the panels, is
    // a pair, the second authored for the other glass.
    function c(own: var, other: var): color {
        return Tokens.flipped ? (other === undefined ? Tokens.ink(own) : other) : own;
    }

    // The walnut case: its grain bands, the brass rule and the dark one.
    readonly property color woodA: c("#3a1d0e", "#d9b98c")
    readonly property color woodB: c("#5a2e16", "#e8cfa6")
    readonly property color woodC: c("#3e1f0f", "#dcbf94")
    readonly property color brass: c("#b8863b", "#9a6a24")
    readonly property color brassHi: c("#f3d18a", "#f6dfa8")
    readonly property color brassLo: c("#8a5a1e", "#8a5a1e")
    readonly property color edge: c("#3a1d0e", "#c49c66")
    // The tubes: glass, its rim, the mesh, the unlit 8.
    readonly property color tubeHi: c(Qt.rgba(1, 170 / 255, 110 / 255, 0.14), Qt.rgba(1, 1, 1, 0.55))
    readonly property color tubeLo: c(Qt.rgba(1, 170 / 255, 110 / 255, 0.03), Qt.rgba(1, 1, 1, 0.2))
    readonly property color tubeMid: c(Qt.rgba(1, 170 / 255, 110 / 255, 0.10), Qt.rgba(1, 1, 1, 0.45))
    readonly property color tubeRim: c(Qt.rgba(1, 200 / 255, 150 / 255, 0.3), Qt.rgba(122 / 255, 70 / 255, 30 / 255, 0.35))
    readonly property color mesh: c(Qt.rgba(1, 150 / 255, 80 / 255, 0.12), Qt.rgba(122 / 255, 70 / 255, 30 / 255, 0.12))
    readonly property color ghost: c("#3a1a0a", "#d6bf98")
    // What glows: the digits, the cathode orange, its amber and deep tones.
    readonly property color digit: c("#ffc285", "#a8400c")
    readonly property color orange: c("#ff7a1a", "#b4460f")
    readonly property color amber: c("#ffb366", "#8a5a2b")
    readonly property color deep: c("#c2410c", "#7a2e0a")
    readonly property color red: c("#ff3a1a", "#c4321a")
    // An unlit digit (a tube switched off), dim tracks in the strip.
    readonly property color off: c("#5a2e16", "#c9a87a")
    // Dot screens (`.pn`): near-black glass, its unlit dots.
    readonly property color glass: c("#0a0503", "#f4ece0")
    readonly property color unlit: c("#2b130a", "#e6d9c6")
    // Cards drawn on a screen: a faint warm rule and fill.
    readonly property color cardRim: c(Qt.rgba(1, 200 / 255, 150 / 255, 0.3), Qt.rgba(122 / 255, 70 / 255, 30 / 255, 0.35))
    readonly property color cardFill: c(Qt.rgba(1, 170 / 255, 110 / 255, 0.05), Qt.rgba(180 / 255, 70 / 255, 15 / 255, 0.05))
    // Ivory paper and the ink on it.
    readonly property color paper: c("#efe2c4", "#fbf5e8")
    readonly property color paperHi: c("#f3e3c0", "#fffaf0")
    readonly property color paperLo: c("#d8c49a", "#e6d6b4")
    readonly property color paperInk: c("#3a1d0e", "#3a1d0e")
    readonly property color paperSoft: c("#8a5a1e", "#8a5a1e")
    readonly property color paperDone: c("#a08a6a", "#a8957a")
    readonly property color paperPick: c(Qt.rgba(1, 122 / 255, 26 / 255, 0.18), Qt.rgba(1, 122 / 255, 26 / 255, 0.16))
    readonly property color paperWarm: c("#ffd29a", "#ffe0b8")

    // Strip/rail form inks (Docked.qml): readings, small print, marks,
    // alarms, dim tracks, the bar under them.
    readonly property color ink: digit
    readonly property color label: brass
    readonly property color pink: orange
    readonly property color mid: off
    readonly property color face: woodB

    readonly property string family: nixie.status === FontLoader.Ready ? nixie.name : "serif"
    readonly property string small: silk.status === FontLoader.Ready ? silk.name : "monospace"
    readonly property string mono: stm.status === FontLoader.Ready ? stm.name : "monospace"

    FontLoader {
        id: nixie
        source: Qt.resolvedUrl("../fonts/NixieOne.ttf")
    }
    FontLoader {
        id: silk
        source: Qt.resolvedUrl("../fonts/Silkscreen.ttf")
    }
    FontLoader {
        id: stm
        source: Qt.resolvedUrl("../fonts/ShareTechMono.ttf")
    }
}
