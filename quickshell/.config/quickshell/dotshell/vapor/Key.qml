import QtQuick
import qs.tokyo as T

// A Windows 95 push button, crisp: lilac, raised, its word in VT323; held
// down it sinks; picked (`on`) it is the design's hot pink. A click runs
// `action` and fires tap(). `glyph` draws a transport icon instead
// (prev, next, play, pause, stop, rec).
//   Key { width: 70; height: 22; text: "1 H"; on: true; action: "caffeine for 60" }
Item {
    id: key

    property string text: ""
    property string glyph: ""
    property bool on: false
    property string action: ""
    property real textPx: 16
    property color fill: on ? Ink.pink : Ink.face
    property color ink: Ink.ink
    signal tap

    Rectangle {
        anchors.fill: parent
        color: key.fill
        opacity: key.enabled ? 1 : 0.6
    }
    Rectangle {
        visible: hit.containsMouse && !key.on
        anchors.fill: parent
        anchors.margins: 2
        color: Qt.rgba(1, 1, 1, 0.18)
    }
    Bevel {
        anchors.fill: parent
        sunk: hit.pressed
    }
    // A thin dark rule round it, like the design's 1 px #3d1d63 border.
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 1
        border.color: Ink.shade
        opacity: 0.55
    }
    Pen {
        visible: key.glyph === ""
        anchors.fill: parent
        anchors.leftMargin: 3
        anchors.rightMargin: 3
        anchors.topMargin: hit.pressed ? 1 : 0
        horizontalAlignment: Text.AlignHCenter
        text: key.text
        size: key.textPx
        color: key.ink
    }
    Glyph {
        visible: key.glyph !== ""
        anchors.centerIn: parent
        anchors.verticalCenterOffset: hit.pressed ? 1 : 0
        width: Math.min(14, key.height - 8)
        height: width
        kind: key.glyph
        color: key.glyph === "rec" || key.glyph === "stop" ? Ink.red : key.ink
    }
    T.Hit {
        id: hit
        anchors.fill: parent
        action: key.action
        onTap: key.tap()
    }
}
