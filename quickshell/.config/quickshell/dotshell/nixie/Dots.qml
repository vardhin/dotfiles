import QtQuick
import QtQuick.Effects
import qs

// Nixie's dot ink outside a screen: children authored in dots (1 px = 1 dot,
// as on a DotSurface), drawn as round lit dots with nothing between them,
// straight on the wood, the paper or a tube (the design's `.dm` with its
// `.glow`; shaders/bubble.frag), haloed in cathode orange. `soft` keeps the
// halo faint (dark ink on ivory paper). Authored alpha carries through.
// As many whole dots as fit, from the top left.
//   Dots { anchors.fill: parent; Say { text: "38"; size: 9 } }
Item {
    id: dots

    property bool glow: true
    property bool soft: false
    readonly property int pitch: Tokens.pitch
    readonly property int cols: Math.max(1, Math.floor(width / pitch))
    readonly property int rows: Math.max(1, Math.floor(height / pitch))

    default property alias content: canvas.data
    readonly property alias canvas: canvas

    Item {
        id: canvas
        width: dots.cols
        height: dots.rows
        scale: dots.pitch
        transformOrigin: Item.TopLeft
        smooth: false
    }

    ShaderEffectSource {
        id: buffer
        sourceItem: canvas
        hideSource: true
        live: true
        smooth: false
        textureSize: Qt.size(dots.cols, dots.rows)
        width: 0
        height: 0
        visible: false
    }

    ShaderEffect {
        width: dots.cols * dots.pitch
        height: dots.rows * dots.pitch
        blending: true

        property variant source: buffer
        property size grid: Qt.size(dots.cols, dots.rows)
        property real dotSize: Math.max(0.7, Math.min(0.88, Tokens.dotSize))

        fragmentShader: Qt.resolvedUrl("../shaders/bubble.frag.qsb")

        layer.enabled: dots.glow && Tokens.neon
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: dots.soft ? Ink.c(Qt.rgba(1, 122 / 255, 26 / 255, 0.35), Qt.rgba(180 / 255, 70 / 255, 15 / 255, 0.12)) : Ink.c(Qt.rgba(1, 122 / 255, 26 / 255, 0.85), Qt.rgba(180 / 255, 70 / 255, 15 / 255, 0.25))
            shadowBlur: dots.soft ? 0.2 : 0.35
            blurMax: 10
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }
    }
}
