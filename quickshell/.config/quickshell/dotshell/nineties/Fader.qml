import QtQuick

// A mixing-desk fader, crisp (System): a dark slot ruled in deep violet,
// lit from the foot in blue → pink → yellow up to `level`, and a chrome cap
// riding on it, wider than the slot.
//   Fader { width: 18; height: 80; level: 0.38 }
Item {
    id: f

    property real level: 0
    property bool hot: false
    readonly property real v: Math.max(0, Math.min(1, level))

    Rectangle {
        anchors.fill: parent
        color: Ink.unlit
        border.width: 1
        border.color: Ink.deep
    }
    Rectangle {
        x: 0
        width: f.width
        height: Math.round(f.height * f.v)
        y: f.height - height
        gradient: Gradient {
            GradientStop {
                position: 0
                color: f.hot ? Ink.red : Ink.yellow
            }
            GradientStop {
                position: 0.4
                color: Ink.pink
            }
            GradientStop {
                position: 1
                color: Ink.blue
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: 400
                easing.type: Easing.OutCubic
            }
        }
    }
    // The cap and its shadow.
    Rectangle {
        x: -6
        width: f.width + 12
        height: 8
        y: Math.round(f.height * (1 - f.v)) - 4 + 1
        color: Ink.c(Qt.rgba(0, 0, 0, 0.6), Qt.rgba(0, 0, 0, 0.25))
        Behavior on y {
            NumberAnimation {
                duration: 400
                easing.type: Easing.OutCubic
            }
        }
    }
    Rectangle {
        x: -6
        width: f.width + 12
        height: 8
        y: Math.round(f.height * (1 - f.v)) - 4
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Ink.chromeHi
            }
            GradientStop {
                position: 1
                color: Ink.chromeMid
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: 400
                easing.type: Easing.OutCubic
            }
        }
    }
}
