import QtQuick
import QtQuick.Effects

// A neon tube bent into a rounded rectangle: crisp, in screen px, glowing
// both ways (the design's `border` + `box-shadow` outside and in).
//   Tube { anchors.fill: parent; radius: 26; line: 3; color: Ink.pink }
Rectangle {
    id: tube

    property real line: 2
    property color tint: Ink.pink
    // 0 = no glow; 1 = the sign's own tube.
    property real glow: 1
    property color fill: "transparent"

    color: fill
    border.width: line
    border.color: tint
    antialiasing: true

    layer.enabled: glow > 0 && visible
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: tube.tint
        shadowBlur: 0.55 * tube.glow
        blurMax: 20
        shadowScale: 1
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
    }
}
