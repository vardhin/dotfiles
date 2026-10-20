import QtQuick
import QtQuick.Effects
import qs
import qs.tokyo as T

// A rocker switch, crisp (Caffeine): a dark well ruled in deep violet, I
// over O. On, the I half is lit yellow → pink and glows; off, the O half
// sits pressed in violet. A click runs `action`.
//   Rocker { width: 54; height: 80; on: true; action: "caffeine toggle" }
Item {
    id: sw

    property bool on: false
    property string action: ""

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: Ink.night
        border.width: 3
        border.color: Ink.deep
    }
    Column {
        x: 5
        y: 5
        width: sw.width - 10
        Item {
            width: parent.width
            height: (sw.height - 10) / 2
            layer.enabled: sw.on && Tokens.neon
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Ink.pink
                shadowBlur: 0.5
                blurMax: 12
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }
            Rectangle {
                anchors.fill: parent
                radius: 4
                color: Ink.unlit
                gradient: sw.on ? lit : null
                Gradient {
                    id: lit
                    GradientStop {
                        position: 0
                        color: Ink.yellow
                    }
                    GradientStop {
                        position: 1
                        color: Ink.pink
                    }
                }
            }
            Pen {
                anchors.centerIn: parent
                text: "I"
                size: 10
                color: Ink.night
            }
        }
        Item {
            width: parent.width
            height: (sw.height - 10) / 2
            Rectangle {
                anchors.fill: parent
                radius: 4
                color: Ink.unlit
                gradient: sw.on ? null : pressed
                Gradient {
                    id: pressed
                    GradientStop {
                        position: 0
                        color: Ink.tileHi
                    }
                    GradientStop {
                        position: 1
                        color: Ink.tileLo
                    }
                }
            }
            Pen {
                anchors.centerIn: parent
                text: "O"
                size: 10
                color: Ink.dim
            }
        }
    }
    T.Hit {
        anchors.fill: parent
        action: sw.action
    }
}
