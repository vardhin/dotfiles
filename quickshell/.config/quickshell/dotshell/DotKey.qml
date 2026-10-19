import QtQuick
import qs.services

// A key written in dots on a DotSurface canvas (1 px = 1 dot): a word in a
// dot font, like `[|<]` on a terminal, that clicks. `on` inverts it (lit
// box, the word cut out of it in the glass color), the way a TUI shows a
// toggle that is set. Holding or dragging it still lifts the panel through
// `grip` (as DeviceKey does).
//
//   DotKey { text: "[|<]"; color: Tokens.slot0; onAct: Media.previous() }
Item {
    id: key

    property string text: ""
    property string font: "5x7"
    property color color: Tokens.slot0
    // Set: drawn inverted.
    property bool on: false
    property color cut: Tokens.glass
    property var grip: null
    property bool dragged: false

    signal act

    implicitWidth: word.implicitWidth + (on ? 2 : 0)
    implicitHeight: word.implicitHeight
    width: implicitWidth
    height: implicitHeight

    Rectangle {
        visible: key.on
        x: -1
        y: -1
        width: key.width + 2
        height: key.height + 2
        color: key.color
    }
    MatrixText {
        id: word
        x: key.on ? 1 : 0
        width: implicitWidth
        height: implicitHeight
        font: key.font
        text: key.text
        color: key.on ? key.cut : hit.containsMouse && !hit.pressed ? Qt.lighter(key.color, 1.25) : key.color
    }

    MouseArea {
        id: hit
        anchors.fill: parent
        anchors.margins: -1
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => {
            key.dragged = false;
            if (key.grip)
                key.grip("press", hit, mouse);
        }
        onPositionChanged: mouse => {
            if (key.grip && pressed)
                key.grip("move", hit, mouse);
        }
        onReleased: mouse => {
            if (key.grip)
                key.dragged = key.grip("release", hit, mouse);
        }
        onCanceled: {
            if (key.grip)
                key.grip("cancel", hit, null);
        }
        onClicked: if (!key.dragged) key.act()
    }
}
