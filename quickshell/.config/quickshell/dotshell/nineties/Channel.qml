import QtQuick
import QtQuick.Effects
import qs
import qs.tokyo as T

// A channel button, crisp and leaning 10° (Workspaces): a violet slab lit
// along its top, its number big over its name in Audiowide (pink when the
// channel has windows, dim when empty). `on` is the channel you are on:
// white → yellow, dark words, a hot pink glow. A click runs `action`.
//   Channel { width: 60; height: 46; number: "2"; name: "WEB"; on: true; action: "ws 2" }
Item {
    id: ch

    property string number: ""
    property string name: ""
    property bool on: false
    property bool used: true
    property bool urgent: false
    property string action: ""

    readonly property color ink: on ? Ink.night : urgent ? Ink.red : used ? Ink.pink : Ink.dim

    Item {
        id: face
        width: ch.width
        height: ch.height
        y: hit.pressed ? 1 : 0
        antialiasing: true
        transform: Lean {
            item: face
        }
        layer.enabled: ch.on && Tokens.neon
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Ink.pink
            shadowBlur: 0.55
            blurMax: 14
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }
        Rectangle {
            antialiasing: true
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: ch.on ? Ink.c("#ffffff", "#ffffff") : Ink.tileHi
                }
                GradientStop {
                    position: 1
                    color: ch.on ? Ink.yellow : Ink.tileLo
                }
            }
            Rectangle {
                antialiasing: true
                visible: !ch.on
                width: parent.width
                height: 1
                color: Ink.tileLine
            }
            Rectangle {
                antialiasing: true
                visible: hit.containsMouse && !ch.on
                anchors.fill: parent
                color: Qt.rgba(1, 1, 1, 0.08)
            }
        }
        Column {
            anchors.centerIn: parent
            spacing: -1
            Pen {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ch.number
                size: Math.round(Math.min(ch.height * 0.36, 18))
                slanted: true
                color: ch.ink
            }
            Pen {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, ch.width - 6)
                text: ch.name
                size: Math.round(Math.min(ch.height * 0.2, 9))
                spacing: 1
                color: ch.ink
            }
        }
    }
    T.Hit {
        id: hit
        anchors.fill: parent
        action: ch.action
    }
}
