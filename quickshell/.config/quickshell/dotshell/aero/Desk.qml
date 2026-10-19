import QtQuick
import QtQuick.Effects

// One workspace as a little sky-blue desk (the design's Workspaces tiles):
// a blue glass tile, its windows on it as white glass cards where they
// sit, the gloss over its top half, and a grass-green ring with a white
// gap round the one you are on. Crisp.
//   Desk { width: 60; height: 52; wins: geo[2] ?? []; on: true }
Item {
    id: desk

    property var wins: []
    property bool on: false
    property real radius: 10
    // Window cards' inset from the tile edge, in px.
    property real pad: 4

    Rectangle {
        visible: desk.on
        anchors.fill: parent
        anchors.margins: -5
        radius: desk.radius + 5
        color: "transparent"
        border.width: 2
        border.color: Ink.green
    }
    Rectangle {
        visible: desk.on
        anchors.fill: parent
        anchors.margins: -3
        radius: desk.radius + 3
        color: Ink.c("white", "#6cc8f2")
    }
    Rectangle {
        id: tile
        anchors.fill: parent
        radius: desk.radius
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Ink.sky
            }
            GradientStop {
                position: 1
                color: Ink.navy
            }
        }
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Ink.shadow
            shadowBlur: 0.25
            blurMax: 10
            shadowVerticalOffset: 2
            shadowHorizontalOffset: 0
        }
    }
    Item {
        anchors.fill: parent
        anchors.margins: desk.pad
        Repeater {
            model: desk.wins
            Rectangle {
                required property var modelData
                x: modelData.x * parent.width
                y: modelData.y * parent.height
                width: Math.max(2, modelData.w * parent.width - 2)
                height: Math.max(2, modelData.h * parent.height - 2)
                radius: 3
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Ink.c(Qt.rgba(1, 1, 1, 0.95), Qt.rgba(40 / 255, 80 / 255, 125 / 255, 0.9))
                    }
                    GradientStop {
                        position: 1
                        color: Ink.c(Qt.rgba(205 / 255, 240 / 255, 1, 0.8), Qt.rgba(20 / 255, 45 / 255, 75 / 255, 0.85))
                    }
                }
            }
        }
    }
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        height: parent.height * 0.45
        topLeftRadius: desk.radius
        topRightRadius: desk.radius
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Ink.gloss(0.5)
            }
            GradientStop {
                position: 1
                color: Ink.gloss(0)
            }
        }
    }
}
