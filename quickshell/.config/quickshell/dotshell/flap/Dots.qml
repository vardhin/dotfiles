import QtQuick
import qs

// Split-Flap's dot ink: children authored in dots (1 px = 1 dot, as on a
// DotSurface), drawn as lit square dots with nothing between them,
// straight on the tiles or the housing under them (the design's `.dm` in
// `.sh-square`; shaders/flap.frag). Authored alpha carries through. As
// many whole dots as fit, from the top left.
//   Dots { anchors.fill: parent; MatrixText { text: "CPU"; color: Ink.dim } }
Item {
    id: dots

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
        property real dotSize: Math.max(0.7, Math.min(0.86, Tokens.dotSize))

        fragmentShader: Qt.resolvedUrl("../shaders/flap.frag.qsb")
    }
}
