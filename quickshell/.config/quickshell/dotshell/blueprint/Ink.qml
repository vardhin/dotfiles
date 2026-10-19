pragma Singleton

import QtQuick
import Quickshell

// Blueprint's drafting sheet, from the panel design canvas
// (dot-shell-panels.html, the BLUEPRINT boards): the blue paper and its
// grid, the pale blue of the rules and labels, the near-white ink and the
// white of what is picked, the faded blue of what is done, and Share Tech
// Mono, the face of every crisp word (fonts/, OFL).
Singleton {
    // The paper and its 12 px grid.
    readonly property color paper: "#0b3a75"
    readonly property color grid: Qt.rgba(169 / 255, 205 / 255, 250 / 255, 0.14)
    // Rules, frames, labels.
    readonly property color line: "#a9cdfa"
    // Light rules between rows.
    readonly property color faint: Qt.rgba(169 / 255, 205 / 255, 250 / 255, 0.35)
    // Ink: the words.
    readonly property color ink: "#e8f1ff"
    // The picked one, big numbers.
    readonly property color white: "#ffffff"
    // Done, other months, kept clear.
    readonly property color done: "#3d72b8"
    // Empty tracks, the art's shadow.
    readonly property color deep: "#123f7a"
    readonly property color pale: "#f2f7ff"
    // Hatching.
    readonly property color hatch: Qt.rgba(232 / 255, 241 / 255, 1, 0.5)
    readonly property color hatchFaint: Qt.rgba(169 / 255, 205 / 255, 250 / 255, 0.18)
    // Trouble: a critical note, a low cell.
    readonly property color warn: "#ff9b8a"

    readonly property string family: mono.status === FontLoader.Ready ? mono.name : "monospace"

    FontLoader {
        id: mono
        source: Qt.resolvedUrl("../fonts/ShareTechMono.ttf")
    }
}
