import QtQuick
import qs.tokyo as T

// A camcorder on-screen key, crisp: its word in VT323 in a 1 px box, white
// (`tone` "red" for REC/STOP, "yellow" the picked target); `on` fills it
// yellow with dark words (the expanded menu's picked option).
//   Osd { text: "REC"; tone: "red"; action: "capture rec area" }
Item {
    id: key

    property string text: ""
    property string tone: ""
    property bool on: false
    property string action: ""
    property real textPx: 15
    signal tap

    readonly property color ink: tone === "red" ? Ink.red : tone === "yellow" ? Ink.yellow : Ink.c("#f6ead8", "#f6ead8")

    implicitWidth: word.implicitWidth + 12
    implicitHeight: Math.round(textPx * 1.3)
    opacity: enabled ? 1 : 0.4

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: hit.pressed ? 1 : 0
        color: key.on ? Ink.yellow : hit.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
        border.width: key.on ? 0 : 1
        border.color: key.tone ? key.ink : Qt.rgba(1, 1, 1, 0.5)
        Mono {
            id: word
            anchors.centerIn: parent
            text: key.text
            size: key.textPx
            color: key.on ? Ink.night : key.ink
            shade: !key.on
        }
    }
    T.Hit {
        id: hit
        anchors.fill: parent
        action: key.action
        onTap: key.tap()
    }
}
