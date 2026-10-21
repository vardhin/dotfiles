import QtQuick
import qs.tokyo as T

// A candy pill key, crisp: dark Audiowide on a glossy fill (the pager's
// READ, yellow → orange, and CLEAR, sky → blue; flat yellow for the
// message centre's OPEN / REVEAL tags and the clipboard's Paste / Pin /
// Delete). `on` rings it dark (a mode that is on: HOLD). A click runs
// `action` and fires tap().
//   Pill { text: "READ"; tone: "read"; action: "pane notifs" }
Item {
    id: pill

    property string text: ""
    property string tone: ""
    property bool on: false
    property string action: ""
    property real textPx: 9
    property real radius: height / 2
    signal tap

    readonly property color hi: tone === "read" ? Ink.yellow : tone === "clear" ? Ink.sky : Ink.yellow
    readonly property color foot: tone === "read" ? Ink.orange : tone === "clear" ? Ink.blue : Ink.yellow

    implicitWidth: word.implicitWidth + 12
    implicitHeight: Math.round(textPx * 1.9)
    opacity: enabled ? 1 : 0.45

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: hit.pressed ? 1 : 0
        anchors.bottomMargin: hit.pressed ? -1 : 0
        radius: pill.radius
        border.width: pill.on ? 2 : 0
        border.color: Ink.night
        gradient: Gradient {
            GradientStop {
                position: 0
                color: pill.hi
            }
            GradientStop {
                position: 1
                color: pill.foot
            }
        }
        Rectangle {
            visible: hit.containsMouse
            anchors.fill: parent
            radius: parent.radius
            color: Qt.rgba(1, 1, 1, 0.22)
        }
        Pen {
            id: word
            anchors.centerIn: parent
            text: pill.text
            size: pill.textPx
            color: Ink.night
        }
    }
    T.Hit {
        id: hit
        anchors.fill: parent
        action: pill.action
        onTap: pill.tap()
    }
}
