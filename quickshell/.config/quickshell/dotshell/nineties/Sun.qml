import QtQuick

// The outrun sun: a disc going yellow to hot pink, cut by the horizon
// bands across its lower half (the clock's compact board). Drawn on the
// sign's glass in dots, under the words; the bands leave the unlit dots.
//   Sun { width: 50; height: 50 }
Item {
    id: sun

    // The disc's pieces between the bands, as [top, bottom] fractions.
    property var pieces: [[0, 0.5], [0.56, 0.64], [0.7, 1]]

    opacity: 0.7
    Repeater {
        model: sun.pieces
        Item {
            required property var modelData
            y: Math.round(sun.height * modelData[0])
            width: sun.width
            height: Math.round(sun.height * modelData[1]) - y
            clip: true
            Rectangle {
                y: -parent.y
                width: sun.width
                height: sun.height
                radius: width / 2
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Ink.yellow
                    }
                    GradientStop {
                        position: 0.7
                        color: Ink.pink
                    }
                }
            }
        }
    }
}
