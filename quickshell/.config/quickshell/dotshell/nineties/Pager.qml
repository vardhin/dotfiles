import QtQuick

// The pager, crisp (Messages): a magenta candy case, rounded more at the
// top, glossed along its top edge and standing on a dark lip, holding the
// green LCD (ringed in black, shaded at its top). `lcd` is the LCD's rect,
// set by the face; contents go over it.
//   Pager { anchors.fill: parent; lcd: Qt.rect(14, 12, 260, 106) }
Item {
    id: pager

    property rect lcd: Qt.rect(14, 12, width - 28, height - 28)
    property real round: 22
    // Bare: only the LCD (it sits in a sign's glass instead of its case).
    property bool bare: false

    // The lip it stands on.
    Rectangle {
        visible: !pager.bare
        y: 4
        width: parent.width
        height: parent.height - 4
        topLeftRadius: pager.round
        topRightRadius: pager.round
        bottomLeftRadius: pager.round * 0.8
        bottomRightRadius: pager.round * 0.8
        color: Ink.shadow
    }
    Rectangle {
        visible: !pager.bare
        width: parent.width
        height: parent.height - 4
        topLeftRadius: pager.round
        topRightRadius: pager.round
        bottomLeftRadius: pager.round * 0.8
        bottomRightRadius: pager.round * 0.8
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop {
                position: 0
                color: Ink.caseA
            }
            GradientStop {
                position: 0.6
                color: Ink.caseB
            }
            GradientStop {
                position: 1
                color: Ink.caseC
            }
        }
        // 160°: a sideways wash over it.
        Rectangle {
            anchors.fill: parent
            topLeftRadius: parent.topLeftRadius
            topRightRadius: parent.topRightRadius
            bottomLeftRadius: parent.bottomLeftRadius
            bottomRightRadius: parent.bottomRightRadius
            opacity: 0.45
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: Ink.caseA
                }
                GradientStop {
                    position: 0.7
                    color: Ink.caseB
                }
                GradientStop {
                    position: 1
                    color: Ink.caseC
                }
            }
        }
        // The gloss along the top.
        Rectangle {
            x: pager.round * 0.6
            y: 1
            width: parent.width - pager.round * 1.2
            height: 2
            radius: 1
            color: Qt.rgba(1, 1, 1, 0.35)
        }
    }
    // The LCD.
    Rectangle {
        x: pager.lcd.x
        y: pager.lcd.y
        width: pager.lcd.width
        height: pager.lcd.height
        radius: 6
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Ink.lcdHi
            }
            GradientStop {
                position: 1
                color: Ink.lcdLo
            }
        }
        // Shade under the bezel's top.
        Rectangle {
            x: 3
            y: 3
            width: parent.width - 6
            height: 10
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.rgba(0, 0, 0, 0.3)
                }
                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 3
            border.color: Ink.lcdRim
        }
    }
}
