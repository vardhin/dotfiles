import QtQuick
import qs.tokyo as T

// A small yellow tag with its word, crisp (the design's OPEN, REVEAL,
// PASTE, PIN, DEL). A click runs `action` and fires tap().
//   Tag { text: "OPEN"; action: "pane notifs" }
Item {
    id: tag

    property string text: ""
    property string action: ""
    property color fill: Ink.yellow
    signal tap

    implicitWidth: word.implicitWidth + 12
    implicitHeight: 14
    opacity: enabled ? (hit.containsMouse ? 1 : 0.92) : 0.45

    Rectangle {
        anchors.fill: parent
        color: tag.fill
    }
    Print {
        id: word
        anchors.centerIn: parent
        text: tag.text
        size: 8
        spacing: 1
        color: Ink.housing
    }
    T.Hit {
        id: hit
        anchors.fill: parent
        action: tag.action
        onTap: tag.tap()
    }
}
