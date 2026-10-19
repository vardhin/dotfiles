import QtQuick
import QtQuick.Effects
import qs.tokyo as T

// A glossy Aero button, crisp: an optional glyph over its word in Varela
// Round. `look` is the design's kinds: "plain" (white, blue word), "lit"
// (the picked one: sky, navy word, a sky rim), "red" and "green" (a lit
// bubble, white word), "ghost" (just a faint rim). A click runs `action`.
//   Key { width: 70; height: 44; glyph: "●"; text: "REC"; look: "red"; action: "capture rec area" }
Item {
    id: key

    property string text: ""
    property string glyph: ""
    property string look: "plain"
    property string action: ""
    property real radius: 12
    property real textPx: 12
    signal tap

    readonly property bool bubble: look === "red" || look === "green"
    readonly property color ink: bubble ? "white" : look === "lit" ? Ink.navy : Ink.blue

    Rectangle {
        anchors.fill: parent
        radius: key.radius
        visible: key.look !== "ghost"
        gradient: Gradient {
            GradientStop {
                position: 0
                color: key.look === "red" ? "#ffb3b3" : key.look === "green" ? "#b9f0a8" : Ink.c("white", "#2a4a70")
            }
            GradientStop {
                position: key.bubble ? 0.7 : 1
                color: key.look === "red" ? "#c8323c" : key.look === "green" ? Ink.green : key.look === "lit" ? Ink.plate2 : Ink.ice
            }
        }
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: key.look === "red" ? Qt.rgba(200 / 255, 50 / 255, 60 / 255, 0.5) : key.look === "green" ? Qt.rgba(35 / 255, 150 / 255, 60 / 255, 0.5) : Ink.shade(key.look === "lit" ? 0.4 : 0.25)
            shadowBlur: 0.2
            blurMax: 8
            shadowVerticalOffset: 1
            shadowHorizontalOffset: 0
        }
    }
    Rectangle {
        anchors.fill: parent
        radius: key.radius
        color: key.look === "ghost" ? Ink.c(Qt.rgba(1, 1, 1, 0.25), Qt.rgba(1, 1, 1, 0.08)) : "transparent"
        visible: key.look === "lit" || key.look === "ghost"
        border.width: 1
        border.color: key.look === "lit" ? Ink.sky : Ink.pale
    }
    // The bubble's shine.
    Rectangle {
        visible: key.bubble
        x: 4
        y: 2
        width: parent.width - 8
        height: parent.height * 0.42
        radius: Math.min(key.radius, height / 2)
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

    Column {
        anchors.centerIn: parent
        spacing: 0
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: key.glyph !== ""
            text: key.glyph
            color: key.ink
            font.family: Ink.family
            font.pixelSize: Math.round(key.textPx * 1.35)
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: key.text !== ""
            text: key.text
            color: key.ink
            font.family: Ink.family
            font.pixelSize: key.textPx
        }
    }

    T.Hit {
        anchors.fill: parent
        action: key.action
        onTap: key.tap()
    }
}
