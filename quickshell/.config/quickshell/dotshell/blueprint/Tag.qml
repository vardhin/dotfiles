import QtQuick
import qs.tokyo as T

// A small boxed word that does something (the design's OPEN, REVEAL,
// Paste): white on a near-white rule, sized to its word. Crisp.
//   Tag { text: "OPEN"; onTap: n.invoke() }
Item {
    id: tag

    property string text: ""
    property string action: ""
    property real textPx: 10
    property bool on: true
    signal tap

    implicitWidth: word.implicitWidth + 8
    implicitHeight: Math.round(textPx * 1.6)

    Rectangle {
        anchors.fill: parent
        color: hit.containsMouse ? Ink.c(Qt.rgba(1, 1, 1, 0.1), Qt.rgba(28 / 255, 47 / 255, 110 / 255, 0.1)) : "transparent"
        border.width: 1
        border.color: tag.on ? Ink.ink : Ink.line
    }
    Pen {
        id: word
        anchors.centerIn: parent
        text: tag.text
        size: tag.textPx
        color: tag.on ? Ink.white : Ink.line
    }
    T.Hit {
        id: hit
        anchors.fill: parent
        action: tag.action
        onTap: tag.tap()
    }
}
