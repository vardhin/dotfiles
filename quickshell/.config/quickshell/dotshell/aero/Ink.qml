pragma Singleton

import QtQuick
import Quickshell

// Frutiger Aero's sky glass, from the panel design canvas
// (dot-shell-panels.html, the FRUTIGER AERO boards): navy ink and its
// blues, the grass green of what is on, the warm orange of a hot reading,
// the glass plate's stops round its horizon, and Varela Round, the face
// of the crisp words (fonts/, OFL).
Singleton {
    // Ink, darkest first.
    readonly property color navy: "#0b3f80"
    readonly property color blue: "#1f7fd1"
    readonly property color sky: "#62c3ee"
    // Small print on white cards.
    readonly property color mist: "#62a8d0"
    readonly property color pale: "#cdeaf8"
    readonly property color ice: "#e8f6fd"
    // Empty tracks.
    readonly property color track: "#c2e3f5"
    // On: the grass.
    readonly property color green: "#23963c"
    readonly property color lime: "#8fe07a"
    // Hot: gauge needles, the warm bar.
    readonly property color orange: "#ff8a2a"
    readonly property color peach: "#ffd29a"
    readonly property color red: "#ff5a2a"
    // Instrument faces: the dark glass of the gauges and graph cards.
    readonly property color slate: "#3a4a5c"
    readonly property color night: "#0b1622"

    // The plate: white at the top, a sky horizon across the middle.
    readonly property color plate0: "#ffffff"
    readonly property color plate1: "#d7f0ff"
    readonly property color plate2: "#9fd8f5"
    readonly property color plate3: "#e8f6fd"
    readonly property color shadow: Qt.rgba(11 / 255, 63 / 255, 128 / 255, 0.35)

    readonly property string family: varela.status === FontLoader.Ready ? varela.name : "sans-serif"

    FontLoader {
        id: varela
        source: Qt.resolvedUrl("../fonts/VarelaRound.ttf")
    }
}
