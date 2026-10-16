import QtQuick
import Quickshell

// Pixel-font text for DotSurface canvases: 1 font pixel = 1 dot.
// Fills its parent's height and centers the 7-dot capitals in it.
//
// Glyphs are rasterized at the window's device pixel ratio, not at canvas
// scale, so at a fractional monitor scale (1.2) an 11 px font comes out
// 13.2 px tall and loses rows when the canvas squeezes it into 11 dots.
// The inner Text is therefore sized 1/dpr and scaled back up by dpr: the
// rasterizer draws exactly 11 device px, which land on exactly 11 dots.
// (fontconfig/…/50-departure-mono.conf turns antialiasing off, so no half-lit
// edge dots.)
//
//   DotText { text: "HELLO"; size: 3 }   // 3x: 21 x 33 dots per glyph
Item {
    id: root

    property alias text: label.text
    property alias color: label.color
    property alias elide: label.elide
    property alias horizontalAlignment: label.horizontalAlignment
    // Whole multiples of the pixel font only; anything else smears.
    property int size: 1

    readonly property real dpr: QsWindow.window?.devicePixelRatio ?? 1

    implicitWidth: Math.round(label.implicitWidth * dpr)
    implicitHeight: Tokens.fontPx * size
    height: parent ? parent.height : implicitHeight

    Text {
        id: label
        width: root.width / root.dpr
        height: root.height / root.dpr
        scale: root.dpr
        transformOrigin: Item.TopLeft
        verticalAlignment: Text.AlignVCenter
        font.family: Tokens.font
        font.pixelSize: Tokens.fontPx * root.size / root.dpr
        font.hintingPreference: Font.PreferFullHinting
        renderType: Text.NativeRendering
        antialiasing: false
        color: Tokens.slot0
    }
}
