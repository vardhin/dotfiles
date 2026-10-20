import QtQuick
import qs

// The seek bar as a run of chevrons in dots (1 px = 1 dot): those played
// lit yellow and pink in turn, the rest deep violet (the media boards'
// ▶▶▶ bar). `value` 0..1.
//   Chevrons { width: 80; height: 5; value: 0.42 }
Row {
    id: run

    property real value: 0
    readonly property int n: Math.max(1, Math.floor((width + 1) / 5))
    readonly property int lit: Math.round(Math.max(0, Math.min(1, value)) * n)

    spacing: 1
    Repeater {
        model: run.n
        MatrixText {
            required property int index
            width: 3
            height: 5
            y: Math.round((run.height - 5) / 2)
            font: "3x5"
            text: "▸"
            color: index < run.lit ? (index % 2 ? Ink.pink : Ink.yellow) : Ink.deep
        }
    }
}
