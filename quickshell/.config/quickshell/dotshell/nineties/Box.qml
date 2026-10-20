import QtQuick
import qs

// A task's check box in dots (1 px = 1 dot): a blue square, `size` dots,
// with a pink ✓ in it once done (Todo).
//   Box { size: 7; done: true }
Item {
    id: box

    property int size: 7
    property bool done: false

    width: size
    height: size
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 1
        border.color: Ink.blue
    }
    MatrixText {
        visible: box.done && box.size >= 7
        x: 1
        y: Math.round((box.size - 5) / 2)
        width: 3
        height: 5
        font: "3x5"
        text: "✓"
        color: Ink.pink
    }
    Rectangle {
        visible: box.done && box.size < 7
        x: 2
        y: 2
        width: box.size - 4
        height: box.size - 4
        color: Ink.pink
    }
}
