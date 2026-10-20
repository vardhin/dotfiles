import QtQuick

// Big glowing words in dots: Nixie One, `size` dots tall, inside a Dots
// canvas, a Tube or a Glass (1 px = 1 dot). Small words read better in the
// 5x7 pixel font: use MatrixText for those.
//   Say { text: "38"; size: 12 }
Text {
    property real size: 14
    property real spacing: 0

    color: Ink.digit
    font.family: Ink.family
    font.pixelSize: Math.max(4, size)
    font.letterSpacing: spacing
    textFormat: Text.PlainText
    elide: Text.ElideRight
    maximumLineCount: 1
}
