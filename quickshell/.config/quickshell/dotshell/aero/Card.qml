import QtQuick
import QtQuick.Effects

// A white glass card on the sky (the design's rows and tiles): white going
// ice blue, a soft navy shadow, and an optional sky ring round it for the
// picked one. Crisp; dot words go over it.
//   Card { width: 200; height: 30; ring: true }
Item {
    id: card

    property real radius: 12
    property color from: Ink.c("white", "#1f3d5f")
    property color to: Ink.plate1
    property bool ring: false
    property color ringColor: Ink.sky
    property real lift: 1

    Rectangle {
        anchors.fill: parent
        radius: card.radius
        gradient: Gradient {
            GradientStop {
                position: 0
                color: card.from
            }
            GradientStop {
                position: 1
                color: card.to
            }
        }
        layer.enabled: card.lift > 0
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Ink.shade(0.3)
            shadowBlur: 0.2
            blurMax: 8
            shadowVerticalOffset: card.lift
            shadowHorizontalOffset: 0
        }
    }
    Rectangle {
        visible: card.ring
        anchors.fill: parent
        anchors.margins: -2
        radius: card.radius + 2
        color: "transparent"
        border.width: 2
        border.color: card.ringColor
    }
}
