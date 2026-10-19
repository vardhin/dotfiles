import QtQuick
import qs

// A dark dot screen sunk into the window (the design's `.pn`): the era's
// dot glass with its unlit dots (a DotSurface), as many whole dots as fit,
// centred, behind a one px sunken bevel. Children are authored in dots.
// `grid` rules the design's faint cyan graph paper over it every `step`
// px; `shape` cuts the dots (an SVG path in dots, e.g. a circle).
//   Crt { width: 160; height: 40; MatrixText { text: "21:47"; color: Ink.yellow } }
Item {
    id: screen

    property bool grid: false
    property real step: 14
    property bool bevel: true
    property real radius: 0
    property alias shape: surface.shape
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
    Item {
        visible: screen.grid
        anchors.fill: parent
        anchors.margins: 1
        clip: true
        Repeater {
            model: screen.grid ? Math.ceil(screen.height / screen.step) : 0
            Rectangle {
                required property int index
                y: index * screen.step
                width: parent.width
                height: 1
                color: Ink.grid
            }
        }
        Repeater {
            model: screen.grid ? Math.ceil(screen.width / screen.step) : 0
            Rectangle {
                required property int index
                x: index * screen.step
                width: 1
                height: parent.height
                color: Ink.grid
            }
        }
    }
    Bevel {
        visible: screen.bevel
        anchors.fill: parent
        sunk: true
    }
}
