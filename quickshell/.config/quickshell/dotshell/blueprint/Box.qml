import QtQuick

// A drawn rectangle, crisp: solid (the picked key, a frame) or dashed (a
// key not picked), its rule `line` px wide, drawn inside its bounds.
//   Box { width: 80; height: 20; dashed: true; color: Ink.line }
Item {
    id: box

    property color color: Ink.line
    property real line: 1
    property bool dashed: false
    property color fill: "transparent"

    Rectangle {
        visible: !box.dashed
        anchors.fill: parent
        color: box.fill
        border.width: box.line
        border.color: box.color
    }
    Stroke {
        visible: box.dashed
        anchors.fill: parent
        readonly property real h: box.line / 2
        path: `M ${h} ${h} L ${box.width - h} ${h} L ${box.width - h} ${box.height - h} L ${h} ${box.height - h} Z`
        color: box.color
        line: box.line
        fill: box.fill
        dash: [3, 2]
    }
}
