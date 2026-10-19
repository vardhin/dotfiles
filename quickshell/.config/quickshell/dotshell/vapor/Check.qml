import QtQuick
import qs.tokyo as T

// A Windows check box, crisp: a white sunken square, ✓ when `on`, and its
// words in VT323 beside it. A click runs `action`.
//   Check { on: true; text: "Keep the screen awake"; action: "caffeine toggle" }
Item {
    id: check

    property bool on: false
    property string text: ""
    property string action: ""
    property real textPx: 17
    property real box: 18

    implicitWidth: box + 8 + words.implicitWidth
    implicitHeight: box

    Rectangle {
        width: check.box
        height: check.box
        color: Ink.hi
        Bevel {
            anchors.fill: parent
            sunk: true
        }
        Pen {
            visible: check.on
            anchors.centerIn: parent
            text: "✓"
            size: check.box
        }
    }
    Pen {
        id: words
        x: check.box + 8
        height: check.box
        text: check.text
        size: check.textPx
    }
    T.Hit {
        anchors.fill: parent
        action: check.action
    }
}
