import QtQuick
import qs.vfd as Vfd
import qs.tokyo as Tokyo
import qs.vapor as Vw
import qs.flap as Fl

// A clickable word on the strip ("VOL 45"). `dim` drops it to the low
// brightness level; `wheel(up)` fires on scroll.
Item {
    id: root

    property string text
    property color color: Tokens.slot0
    property bool dim: false
    signal clicked
    signal middleClicked
    signal wheel(bool up)

    // VFD: the display's 5x7 cells, teal when dim.
    readonly property bool vfd: Tokens.era === "vfd"

    // Tokyo Night: 5x7 too, the label violet and the reading cyan.
    readonly property bool tokyo: Tokens.era === "tokyo"
    readonly property int cut: text.lastIndexOf(" ")
    // Vaporwave: 5x7 too, the label deep violet and the reading ink, on the taskbar.
    readonly property bool vapor: Tokens.era === "vapor"
    // Split-Flap: 5x7 too, the label grey small print, the reading off-white.
    readonly property bool flap: Tokens.era === "flap"

    width: vfd ? cells.implicitWidth : tokyo || vapor || flap ? neon.implicitWidth : label.implicitWidth
    height: parent ? parent.height : Tokens.fontPx

    DotText {
        id: label
        visible: !root.vfd && !root.tokyo && !root.vapor && !root.flap
        text: root.text
        color: root.color
        opacity: root.dim ? 0.5 : 1
    }
    MatrixText {
        id: cells
        visible: root.vfd
        y: Math.floor((root.height - 7) / 2)
        width: implicitWidth
        height: 7
        text: root.text.toUpperCase()
        color: root.dim ? Vfd.Ink.teal : root.color
    }
    Row {
        id: neon
        visible: root.tokyo || root.vapor || root.flap
        y: Math.floor((root.height - 7) / 2)
        height: 7
        opacity: root.dim ? 0.45 : 1
        MatrixText {
            visible: root.cut > 0
            width: implicitWidth
            height: 7
            text: root.text.slice(0, root.cut + 1).toUpperCase()
            color: root.flap ? Fl.Ink.label : root.vapor ? Vw.Ink.label : Tokyo.Ink.violet
        }
        MatrixText {
            width: implicitWidth
            height: 7
            text: root.text.slice(root.cut + 1).toUpperCase()
            color: root.flap ? (root.cut > 0 && !root.dim ? Fl.Ink.white : Fl.Ink.label) : root.vapor ? (root.cut > 0 && !root.dim ? Vw.Ink.ink : Vw.Ink.label) : root.cut > 0 && !root.dim ? Tokyo.Ink.cyan : Tokyo.Ink.violet
        }
    }

    // Hover: underline, same as the workspace focus mark.
    Rectangle {
        visible: mouse.containsMouse
        y: root.height - 1
        width: root.width
        height: 1
        color: root.color
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => mouse.button === Qt.MiddleButton ? root.middleClicked() : root.clicked()
        onWheel: event => root.wheel(event.angleDelta.y > 0)
    }
}
