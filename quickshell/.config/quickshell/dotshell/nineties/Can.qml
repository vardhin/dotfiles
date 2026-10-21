import QtQuick

// The battery as a chrome can, crisp (Battery): a chrome shell banded at
// its waist, the dark well inside, the charge lit across it blue → pink →
// yellow (red when low), the chrome nub, and a yellow bolt over it while
// charging.
//   Can { width: 120; height: 62; level: 0.72 }
Item {
    id: cell

    property real level: 0
    property bool low: false
    property bool charging: false
    readonly property real v: Math.max(0, Math.min(1, level))
    readonly property real nub: Math.max(5, Math.round(width * 0.066))

    // The nub.
    Rectangle {
        x: cell.width - cell.nub
        y: Math.round(cell.height * 0.32)
        width: cell.nub
        height: Math.round(cell.height * 0.36)
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
    }
    // The shell.
    Rectangle {
        id: shell
        width: cell.width - cell.nub
        height: cell.height
        radius: 6
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Ink.chromeHi
            }
            GradientStop {
                position: 0.5
                color: Ink.chromeMid
            }
            GradientStop {
                position: 0.52
                color: Ink.chromeLo
            }
            GradientStop {
                position: 1
                color: Ink.chromeEnd
            }
        }
        Rectangle {
            id: well
            anchors.fill: parent
            anchors.margins: 4
            radius: 3
            color: Ink.night
            Rectangle {
                x: 3
                y: 3
                height: well.height - 6
                width: Math.max(cell.v > 0 ? 2 : 0, Math.round((well.width - 6) * cell.v))
                gradient: Gradient {
                    orientation: cell.low ? Gradient.Vertical : Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: cell.low ? Ink.c("#e8a49a", "#e8a49a") : Ink.blue
                    }
                    GradientStop {
                        position: cell.low ? 1 : 0.6
                        color: cell.low ? Ink.red : Ink.pink
                    }
                    GradientStop {
                        position: 1
                        color: cell.low ? Ink.red : Ink.yellow
                    }
                }
                Behavior on width {
                    NumberAnimation {
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
    // The bolt.
    Pen {
        visible: cell.charging
        anchors.horizontalCenter: shell.horizontalCenter
        y: -Math.round(cell.height * 0.2)
        text: "⚡"
        size: Math.round(cell.height * 0.36)
        color: Ink.yellow
        style: Text.Outline
        styleColor: Ink.pink
    }
}
