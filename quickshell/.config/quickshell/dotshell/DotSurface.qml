import QtQuick
import QtQuick.Shapes

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
//
// `shape` (an SVG path in dots, see Shapes.js) cuts the panel to that outline:
// dots outside it are not drawn at all, not even as unlit dots.
//
// Era cascade: when Tokens.flipStarting fires, the canvas is grabbed into
// `oldBuffer` before the era swaps; dot.frag then turns each dot over from the
// old snapshot (and old era uniforms) to the live canvas as Tokens.flip runs.
Item {
    id: root

    function shapeCode(s: string): real {
        return s === "square" ? 1 : s === "bubble" ? 2 : 0;
    }

    property int cols: 1
    property int rows: 1
    property int pitch: Tokens.pitch

    // false renders the canvas raw (crisp), scaled to the same size.
    property bool dot: true
    // true maps luma onto the era ramp (photos, album art); false keeps authored colors.
    property bool imageMode: false
    // Flat: square, gapless, glowless dots in true color. A panel's "raw"
    // look for drawn content (pixels, text): exact pixels, still cut to `shape`.
    property bool flat: false
    // SVG path in canvas dots; "" = the whole rectangle.
    property string shape: ""
    // How lit the lit dots are, 0 .. 1: below 1 they blend toward the unlit
    // dot (the wallpaper board sits at 0.55).
    property real gain: 1
    // Opacity of the glass between the dots (frosted panes: under 1, so the
    // compositor's blur shows through).
    property real glassAlpha: 1
    // Image mode: spread the four era levels (or the color depth) with a 4x4
    // ordered dither, so album art keeps its shading on a coarse board.
    property bool dither: false

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

    // The shape, rasterized one texel per dot (sampled at dot centers).
    Shape {
        id: outline
        width: root.cols
        height: root.rows
        visible: false
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            fillColor: "white"
            PathSvg {
                path: root.shape
            }
        }
    }

    ShaderEffectSource {
        id: maskBuffer
        sourceItem: root.shape ? outline : null
        live: true
        smooth: false
        textureSize: Qt.size(root.cols, root.rows)
        width: 0
        height: 0
        visible: false
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

    // The canvas as it was in the old era, grabbed once per cascade.
    ShaderEffectSource {
        id: oldBuffer
        sourceItem: root.dot && !root.flat ? canvas : null
        live: false
        smooth: false
        textureSize: Qt.size(root.cols, root.rows)
        width: 0
        height: 0
        visible: false
    }

    // Only surfaces on screen at the swap have an old picture to flip from;
    // one that appears mid-cascade just shows the new era.
    property bool grabbed: false

    Connections {
        target: Tokens
        function onFlipStarting() {
            root.grabbed = root.dot && !root.flat && root.visible;
            if (root.grabbed)
                oldBuffer.scheduleUpdate();
        }
    }

    ShaderEffect {
        anchors.fill: parent
        visible: root.dot
        blending: true

        property variant source: buffer
        property size grid: Qt.size(root.cols, root.rows)
        property real dotSize: root.flat ? 1.2 : Tokens.dotSize   // >1: no seams at fractional pitch
        property real depth: root.flat ? 24 : Tokens.depthBits
        property real imageMode: root.imageMode ? 1 : 0
        property real shape: root.flat ? 1 : root.shapeCode(Tokens.current.shape)
        property real glow: root.flat ? 0 : Tokens.current.glow
        property color unlitColor: Tokens.unlit
        property color gapColor: Qt.rgba(Tokens.glass.r, Tokens.glass.g, Tokens.glass.b, root.glassAlpha)
        property color ramp0: Tokens.current.ramp[0]
        property color ramp1: Tokens.current.ramp[1]
        property color ramp2: Tokens.current.ramp[2]
        property color ramp3: Tokens.current.ramp[3]
        property real gain: root.gain
        property real dither: root.dither ? 1 : 0
        property real useMask: root.shape ? 1 : 0
        property variant mask: root.shape ? maskBuffer : buffer

        // Cascade. Flat surfaces (raw drawn content) do not flip.
        readonly property var was: Tokens.previous
        property real flip: root.grabbed ? Tokens.flip : 1
        property real oldShape: root.flat ? 1 : root.shapeCode(was.shape)
        property real oldGlow: root.flat ? 0 : was.glow
        property color oldUnlit: was.unlit
        property color oldGap: was.glass
        property color oldRamp0: was.ramp[0]
        property color oldRamp1: was.ramp[1]
        property color oldRamp2: was.ramp[2]
        property color oldRamp3: was.ramp[3]
        property variant oldSource: root.dot && !root.flat ? oldBuffer : buffer

        fragmentShader: Qt.resolvedUrl("shaders/dot.frag.qsb")
    }

    // Above the dots, in screen px: pictures shown as they are (PlainArt).
    Item {
        id: plain
        anchors.fill: parent
    }
    readonly property alias plainLayer: plain
}
