import QtQuick
import QtQuick.Effects
import qs

// Aero's dot ink: children authored in dots (1 px = 1 dot, as on a
// DotSurface), drawn as glossy bubbles with nothing between them, so they
// sit straight on the sky glass under them (the design's `.dm` with no
// `.pn`; shaders/bubble.frag). Authored alpha carries through: ink at half
// opacity is a faded dot. `glow` is the design's soft blue halo.
// As many whole dots as fit, from the top left.
//   Dots { anchors.fill: parent; Text { text: "9:47"; font.pixelSize: 14 } }
Item {
    id: dots

    property bool glow: true
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

        layer.enabled: dots.glow
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(10 / 255, 100 / 255, 200 / 255, 0.45)
            shadowBlur: 0.25
            blurMax: 8
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }
    }
}
