pragma Singleton

import QtQuick
import Quickshell
import qs

// Frutiger Aero's sky glass, from the panel design canvas
// (dot-shell-panels.html, the FRUTIGER AERO boards): navy ink and its
// blues, the grass green of what is on, the warm orange of a hot reading,
// the glass plate's stops round its horizon, and Varela Round, the face
// of the crisp words (fonts/, OFL).
Singleton {
    // A color in the era's own tone and in its other one (the `tone` token,
    // Palettes.js): every color here, and every literal in the panels, is
    // a pair, the second authored for the other glass.
    function c(own: var, other: var): color {
        return Tokens.flipped ? (other === undefined ? Tokens.ink(own) : other) : own;
    }

    // Ink, darkest first.
    readonly property color navy: c("#0b3f80", "#dceeff")
    readonly property color blue: c("#1f7fd1", "#5cb6ff")
    readonly property color sky: c("#62c3ee", "#6cc8f2")
    // Small print on white cards.
    readonly property color mist: c("#62a8d0", "#7f9fb8")
    readonly property color pale: c("#cdeaf8", "#1d3550")
    readonly property color ice: c("#e8f6fd", "#142a42")
    // Empty tracks.
    readonly property color track: c("#c2e3f5", "#1a3048")
    // On: the grass.
    readonly property color green: c("#23963c", "#4fd06a")
    readonly property color lime: c("#8fe07a", "#7fd96c")
    // Hot: gauge needles, the warm bar.
    readonly property color orange: c("#ff8a2a", "#ff9a45")
    readonly property color peach: c("#ffd29a", "#7a4a1c")
    readonly property color red: c("#ff5a2a", "#ff6a3d")
    // Instrument faces: the dark glass of the gauges and graph cards.
    readonly property color slate: c("#3a4a5c", "#0c1826")
    readonly property color night: c("#0b1622", "#060d16")

    // The plate: white at the top, a sky horizon across the middle.
    readonly property color plate0: c("#ffffff", "#1d3a5c")
    readonly property color plate1: c("#d7f0ff", "#132a45")
    readonly property color plate2: c("#9fd8f5", "#1d4a73")
    readonly property color plate3: c("#e8f6fd", "#0d1e33")
    readonly property color shadow: shade(0.35)

    // Glass physics per tone: the gloss is a white sheen on sky glass and
    // only a faint one on night glass; shadows are soft navy by day and fall
    // black at night.
    function gloss(a: real): color {
        return Qt.rgba(1, 1, 1, Tokens.flipped ? a * 0.14 : a);
    }
    function shade(a: real): color {
        return Tokens.flipped ? Qt.rgba(0, 0, 0, Math.min(0.85, a * 1.6)) : Qt.rgba(11 / 255, 63 / 255, 128 / 255, a);
    }

    readonly property string family: varela.status === FontLoader.Ready ? varela.name : "sans-serif"

    FontLoader {
        id: varela
        source: Qt.resolvedUrl("../fonts/VarelaRound.ttf")
    }
}
