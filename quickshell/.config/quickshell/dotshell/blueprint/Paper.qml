import QtQuick

// The drafting sheet every Blueprint panel is: blue paper, a faint 12 px
// grid ruled over it and a pale blue rule round its edge (the design's
// plate). Crisp; dots and drawings go over it.
//   Paper { anchors.fill: parent }
Rectangle {
    id: paper

    property real step: 12
    property bool rim: true

    color: Ink.paper
    border.width: rim ? 1 : 0
    border.color: Ink.line
    clip: true

    Repeater {
        model: Math.max(0, Math.ceil((paper.height - 2) / paper.step))
        Rectangle {
            required property int index
            x: 1
            y: 1 + index * paper.step
            width: paper.width - 2
            height: 1
            color: Ink.grid
        }
    }
    Repeater {
        model: Math.max(0, Math.ceil((paper.width - 2) / paper.step))
        Rectangle {
            required property int index
            x: 1 + index * paper.step
            y: 1
            width: 1
            height: paper.height - 2
            color: Ink.grid
        }
    }
}
