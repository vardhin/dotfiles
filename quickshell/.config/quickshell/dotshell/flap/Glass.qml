import QtQuick
import qs

// A dot screen in the board (the design's `.pn`): dark glass with its
// unlit square dots (a DotSurface), as many whole dots as fit, centred.
// Children are authored in dots.
//   Glass { width: 160; height: 40; MatrixText { text: "21:47"; color: Ink.white } }
Item {
    id: screen

    property alias shape: surface.shape
    readonly property alias cols: surface.cols
    readonly property alias rows: surface.rows
    readonly property alias surface: surface
    default property alias content: surface.content

    Rectangle {
        anchors.fill: parent
        color: Ink.glass
    }
    DotSurface {
        id: surface
        anchors.centerIn: parent
        cols: Math.max(1, Math.floor(screen.width / Tokens.pitch))
        rows: Math.max(1, Math.floor(screen.height / Tokens.pitch))
    }
}
