import QtQuick

// VU-meter bar: a row of dot segments, lit up to `value`.
// Segments past `hot` take the second tube, past 1.0 (over-amplified) the
// accent tube. Unlit segments are simply absent, so the panel's unlit dots
// show through.
Item {
    id: root

    property real value: 0          // 0 .. max
    property real max: 1
    property int segments: 24
    property int segWidth: 2
    property int segHeight: 7
    property real hot: 0.8
    property bool interactive: false
    signal moved(real value)

    implicitWidth: segments * (segWidth + 1) - 1
    implicitHeight: segHeight

    Row {
        spacing: 1

        Repeater {
            model: root.segments

            Rectangle {
                required property int index
                readonly property real at: (index + 1) / root.segments * root.max
                width: root.segWidth
                height: root.segHeight
                visible: root.value >= at - root.max / root.segments / 2
                color: at > 1.0001 ? Tokens.slot2 : at > root.hot ? Tokens.slot1 : Tokens.slot0
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        cursorShape: Qt.PointingHandCursor

        function valueAt(x: real): real {
            return Math.max(0, Math.min(root.max, Math.ceil(x / root.width * root.segments) / root.segments * root.max));
        }

        onPressed: mouse => root.moved(valueAt(mouse.x))
        onPositionChanged: mouse => {
            if (pressed)
                root.moved(valueAt(mouse.x));
        }
        onWheel: wheel => root.moved(Math.max(0, Math.min(root.max, root.value + (wheel.angleDelta.y > 0 ? 1 : -1) * root.max / root.segments)))
    }
}
