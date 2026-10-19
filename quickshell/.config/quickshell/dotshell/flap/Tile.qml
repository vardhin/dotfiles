import QtQuick

// One flap tile, crisp: the lighter top half, the hinge, the darker
// bottom half, corners rounded 2 px. `lit` is the picked tile in yellow.
// Its letter goes in dots over it (Flaps.qml); the hinge is drawn over
// the letter by `Hinge`.
//   Tile { width: 21; height: 27; lit: true }
Item {
    id: tile

    property bool lit: false
    property color face: lit ? Ink.yellow : Ink.upper
    property color low: lit ? Ink.yellowDeep : Ink.lower

    Rectangle {
        anchors.fill: parent
        radius: 2
        gradient: Gradient {
            GradientStop {
                position: 0
                color: tile.face
            }
            GradientStop {
                position: 0.49
                color: tile.face
            }
            GradientStop {
                position: 0.495
                color: tile.low
            }
            GradientStop {
                position: 1
                color: tile.low
            }
        }
    }
}
