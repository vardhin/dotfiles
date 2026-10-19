import QtQuick
import QtQuick.Effects

// Sign lettering on the glass: Tilt Neon, `size` dots tall (1 px = 1 dot,
// so it lands on the LEDs like the design's dot-masked text), with an
// optional halo of dim dots round it (the design's text-shadow).
// Small words read better in the 5x7 pixel font: use DotText for those.
//   Neon { text: "21:47"; size: 20; color: Ink.cyan; halo: true }
Text {
    id: neon

    property real size: 12
    property bool halo: false

    color: Ink.cyan
    font.family: Ink.family
    font.pixelSize: Math.max(4, size)
    font.letterSpacing: 0
    textFormat: Text.PlainText
    elide: Text.ElideRight
    maximumLineCount: 1
    verticalAlignment: Text.AlignVCenter

    layer.enabled: halo && visible && size >= 18
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: neon.color
        shadowBlur: 0.7
        blurMax: 6
        shadowScale: 1.04
        shadowOpacity: 0.85
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
    }
}
