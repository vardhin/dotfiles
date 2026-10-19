import QtQuick
import qs
import "../Hardware.js" as Hardware

// The stereo's head unit: a brushed gunmetal plate, lit along its top edge,
// with the display window sunk into it (the design's `.pn`): smoked glass,
// a black lip and a shadow falling in from the top. Only the window is
// dots; children are authored on it in dots, as on any DotSurface. Crisp
// parts that sit on the glass (card rules, the picked row's amber outline,
// hard keys) go in `over`, placed in px from the window's first dot (see
// px()).
//   Unit { MatrixText { text: "CPU" } }
Item {
    id: unit

    // Gunmetal round the window, and the corners, in px.
    property real pad: 8
    property real radius: 10
    property real winRadius: 4
    // How dark the shadow falling in from the top is.
    property real shade: 0.8
    // Room on the plate under the window, in px, for hard keys (`deck`).
    property real foot: 0
    property real footGap: 6
    // Room on the plate right of the window, in px, for a column of keys
    // (`rack`).
    property real side: 0
    property real sideGap: 10

    default property alias content: screen.content
    property alias over: overlay.data
    property alias deck: deckItem.data
    property alias rack: rackItem.data
    readonly property alias cols: screen.cols
    readonly property alias rows: screen.rows
    readonly property alias screen: screen
    readonly property int pitch: Tokens.pitch

    // Dots on the window -> px on `over`.
    function px(dots: real): real {
        return dots * pitch;
    }

    // ── The plate ───────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: unit.radius
        color: Ink.plateEdge
    }
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 1
        radius: unit.radius
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Ink.plateTop
            }
            GradientStop {
                position: 1
                color: Ink.plateBottom
            }
        }
    }

    // ── The window ──────────────────────────────────────────────────
    Item {
        id: win
        anchors.fill: parent
        anchors.margins: unit.pad
        anchors.bottomMargin: unit.pad + (unit.foot > 0 ? unit.foot + unit.footGap : 0)
        anchors.rightMargin: unit.pad + (unit.side > 0 ? unit.side + unit.sideGap : 0)

        Rectangle {
            anchors.fill: parent
            radius: unit.winRadius
            color: Ink.glass
        }
        DotSurface {
            id: screen
            anchors.centerIn: parent
            cols: Math.max(1, Math.floor(parent.width / unit.pitch))
            rows: Math.max(1, Math.floor(parent.height / unit.pitch))
            shape: Hardware.rounded(0, 0, cols, rows, unit.winRadius / unit.pitch)
        }
        // Smoked: the shadow falling in from the top.
        Rectangle {
            anchors.fill: parent
            radius: unit.winRadius
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Ink.c(Qt.rgba(0, 0, 0, unit.shade), Qt.rgba(40 / 255, 60 / 255, 55 / 255, unit.shade * 0.22))
                }
                GradientStop {
                    position: Math.min(0.5, 16 / Math.max(1, win.height))
                    color: "transparent"
                }
            }
        }
        // The black lip.
        Rectangle {
            anchors.fill: parent
            radius: unit.winRadius
            color: "transparent"
            border.width: 1
            border.color: Ink.c("black", "#7f8f89")
        }
        Item {
            id: overlay
            x: screen.x
            y: screen.y
            width: screen.width
            height: screen.height
        }
    }

    // ── Under the window: the keys ──────────────────────────────────
    Item {
        id: deckItem
        x: unit.pad
        y: unit.height - unit.pad - unit.foot
        width: unit.width - unit.pad * 2
        height: unit.foot
    }
    Item {
        id: rackItem
        x: unit.width - unit.pad - unit.side
        y: unit.pad
        width: unit.side
        height: unit.height - unit.pad * 2
    }
}
