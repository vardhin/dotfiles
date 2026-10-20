import QtQuick
import qs

// A dot screen in the case (the design's `.pn`): near-black glass with its
// unlit dots (a DotSurface), as many whole dots as fit, centred, ruled in
// brass. Children are authored in dots.
//   Glass { width: 160; height: 40; MatrixText { text: "21:47" } }
Item {
    id: screen

    property alias shape: surface.shape
    property bool ruled: true
    property real radius: 4
    readonly property alias cols: surface.cols
    readonly property alias rows: surface.rows
    readonly property alias surface: surface
    default property alias content: surface.content

    Rectangle {
        anchors.fill: parent
        radius: screen.radius
        color: Ink.glass
    }
    DotSurface {
        id: surface
        anchors.centerIn: parent
        cols: Math.max(1, Math.floor((screen.width - 2) / Tokens.pitch))
        rows: Math.max(1, Math.floor((screen.height - 2) / Tokens.pitch))
    }
    Rectangle {
        visible: screen.ruled
        anchors.fill: parent
        radius: screen.radius
        color: "transparent"
        border.width: 1
        border.color: Ink.brass
    }
}
