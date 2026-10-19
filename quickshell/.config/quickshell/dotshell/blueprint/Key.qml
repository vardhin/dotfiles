import QtQuick
import qs.tokyo as T

// A Blueprint key, crisp: its word in a dashed pale blue box, or, picked
// (`on`), in a solid white one (the design's 30 M / 1 H / REGION keys).
// A click runs `action` and fires tap().
//   Key { width: 70; height: 20; text: "1 H"; on: true; action: "caffeine for 60" }
Item {
    id: key

    property string text: ""
    property bool on: false
    property string action: ""
    property real textPx: 11
    signal tap

    Box {
        anchors.fill: parent
        dashed: !key.on
        line: key.on ? 1.5 : 1
        color: key.on ? Ink.white : Ink.line
        fill: hit.containsMouse && !key.on ? Ink.c(Qt.rgba(1, 1, 1, 0.06), Qt.rgba(28 / 255, 47 / 255, 110 / 255, 0.06)) : "transparent"
    }
    Pen {
        anchors.fill: parent
        anchors.leftMargin: 3
        anchors.rightMargin: 3
        horizontalAlignment: Text.AlignHCenter
        text: key.text
        size: key.textPx
        color: key.on ? Ink.white : Ink.line
    }
    T.Hit {
        id: hit
        anchors.fill: parent
        action: key.action
        onTap: key.tap()
    }
}
