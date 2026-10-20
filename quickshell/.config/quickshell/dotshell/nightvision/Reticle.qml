import QtQuick
import qs

// A crisp crosshair over a round target: a bright cross through the middle
// and a ring of `ring` × the shorter side (the media panel's art, the
// MEDIA pane's scope).
//   Reticle { anchors.fill: art; ring: 0.42 }
Item {
    id: ret

    property real ring: 0.42
    property real reach: 0.86
    property color color: Ink.bright

    Rectangle {
        anchors.centerIn: parent
        width: 1
        height: ret.height * ret.reach
        color: ret.color
    }
    Rectangle {
        anchors.centerIn: parent
        width: ret.width * ret.reach
        height: 1
        color: ret.color
    }
    Rectangle {
        anchors.centerIn: parent
        width: Math.min(ret.width, ret.height) * ret.ring
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: ret.color
        antialiasing: true
    }
}
