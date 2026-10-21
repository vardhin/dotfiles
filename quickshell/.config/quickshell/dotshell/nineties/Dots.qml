import QtQuick
import QtQuick.Effects
import qs

// 90s Nights' dot ink off the glass: children authored in dots (1 px = 1
// dot, as on a DotSurface), drawn as round lit dots with nothing between
// them, straight on the paper, a slip, the pager's LCD or the camcorder's
// screen (the design's `.dm` with its `.glow`; shaders/bubble.frag),
// haloed in `halo` (hot pink by default; `soft` keeps it faint, for dark
// ink on paper). Authored alpha carries through.
//   Dots { anchors.fill: parent; MatrixText { text: "TARGET"; color: Ink.white } }
Item {
    id: dots

    property bool glow: true
    property bool soft: false
    property color halo: Ink.pink
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
            shadowColor: Qt.rgba(dots.halo.r, dots.halo.g, dots.halo.b, dots.soft ? 0.35 : 0.85)
            shadowBlur: dots.soft ? 0.12 : 0.2
            blurMax: 10
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }
    }
}
