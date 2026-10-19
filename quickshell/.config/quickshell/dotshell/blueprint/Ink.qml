pragma Singleton

import QtQuick
import Quickshell
import qs

// Blueprint's drafting sheet, from the panel design canvas
// (dot-shell-panels.html, the BLUEPRINT boards): the blue paper and its
// grid, the pale blue of the rules and labels, the near-white ink and the
// white of what is picked, the faded blue of what is done, and Share Tech
// Mono, the face of every crisp word (fonts/, OFL).
Singleton {
    // A color in the era's own tone and in its other one (the `tone` token,
    // Palettes.js): every color here, and every literal in the panels, is
    // a pair, the second authored for the other glass.
    function c(own: var, other: var): color {
        return Tokens.flipped ? (other === undefined ? Tokens.ink(own) : other) : own;
    }

    // The paper and its 12 px grid.
    readonly property color paper: c("#0b3a75", "#f3efe2")
    readonly property color grid: c(Qt.rgba(169 / 255, 205 / 255, 250 / 255, 0.14), Qt.rgba(42 / 255, 74 / 255, 160 / 255, 0.1))
    // Rules, frames, labels.
    readonly property color line: c("#a9cdfa", "#3a5fb0")
    // Light rules between rows.
    readonly property color faint: c(Qt.rgba(169 / 255, 205 / 255, 250 / 255, 0.35), Qt.rgba(58 / 255, 95 / 255, 176 / 255, 0.28))
    // Ink: the words.
    readonly property color ink: c("#e8f1ff", "#1c2f6e")
    // The picked one, big numbers.
    readonly property color white: c("#ffffff", "#0f1f55")
    // Done, other months, kept clear.
    readonly property color done: c("#3d72b8", "#9aaad0")
    // Empty tracks, the art's shadow.
    readonly property color deep: c("#123f7a", "#dcd8ca")
    readonly property color pale: c("#f2f7ff", "#23397d")
    // Hatching.
    readonly property color hatch: c(Qt.rgba(232 / 255, 241 / 255, 1, 0.5), Qt.rgba(28 / 255, 47 / 255, 110 / 255, 0.45))
    readonly property color hatchFaint: c(Qt.rgba(169 / 255, 205 / 255, 250 / 255, 0.18), Qt.rgba(58 / 255, 95 / 255, 176 / 255, 0.15))
    // Trouble: a critical note, a low cell.
    readonly property color warn: c("#ff9b8a", "#b8372a")

    readonly property string family: mono.status === FontLoader.Ready ? mono.name : "monospace"

    FontLoader {
        id: mono
        source: Qt.resolvedUrl("../fonts/ShareTechMono.ttf")
    }
}
