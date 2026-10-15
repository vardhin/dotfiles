import QtQuick

// DotSurface: author a pane as plain low-res QML, get LED dots.
//
// Children are laid out on a `cols` x `rows` canvas where 1 px = 1 dot, in era
// colors (Tokens.slot0..2). The canvas is rendered into a cols x rows texture,
// then dot.frag upscales it by `pitch` and applies the dot mask, depth quantize,
// unlit dots and glow. Input still works: the hidden canvas is scaled by `pitch`
// under the effect, so MouseAreas inside it line up with the dots you see.
//
//   DotSurface {
//       cols: 40; rows: 11
//       Text { text: "HELLO"; color: Tokens.slot0; font.family: Tokens.font; font.pixelSize: Tokens.fontPx }
//   }
Item {
    id: root

    property int cols: 1
    property int rows: 1
    property int pitch: Tokens.pitch

    // false renders the canvas raw (crisp), scaled to the same size.
    property bool dot: true
    // true maps luma onto the era ramp (photos, album art); false keeps authored colors.
    property bool imageMode: false

    default property alias content: canvas.data
    readonly property alias canvas: canvas

    implicitWidth: cols * pitch
    implicitHeight: rows * pitch

    Item {
        id: canvas
        width: root.cols
        height: root.rows
        scale: root.pitch
        transformOrigin: Item.TopLeft
        // Raw mode: the canvas itself is what you see, so keep it sharp.
        smooth: false
    }

    ShaderEffectSource {
        id: buffer
        sourceItem: canvas
        hideSource: root.dot
        live: true
        smooth: false                       // nearest: one texel per dot
        textureSize: Qt.size(root.cols, root.rows)
        width: 0
        height: 0
        visible: false
    }

    ShaderEffect {
        anchors.fill: parent
        visible: root.dot
        blending: true

        property variant source: buffer
        property size grid: Qt.size(root.cols, root.rows)
        property real dotSize: Tokens.dotSize
        property real depth: Tokens.depthBits
        property real imageMode: root.imageMode ? 1 : 0
        property real shape: Tokens.current.shape === "square" ? 1 : Tokens.current.shape === "bubble" ? 2 : 0
        property real glow: Tokens.current.glow
        property color unlitColor: Tokens.unlit
        property color gapColor: Tokens.glass
        property color ramp0: Tokens.current.ramp[0]
        property color ramp1: Tokens.current.ramp[1]
        property color ramp2: Tokens.current.ramp[2]
        property color ramp3: Tokens.current.ramp[3]

        fragmentShader: Qt.resolvedUrl("shaders/dot.frag.qsb")
    }
}
