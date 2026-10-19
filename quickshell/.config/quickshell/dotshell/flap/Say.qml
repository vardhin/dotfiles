import QtQuick

// Big words in dots: VT323, `size` dots tall, inside a Dots canvas or a
// Glass (1 px = 1 dot). Small words read better in the 5x7 pixel font:
// use MatrixText for those.
//   Say { text: "72%"; size: 16 }
Text {
    property real size: 14
    property real spacing: 0

    color: Ink.white
    font.family: Ink.family
    font.pixelSize: Math.max(4, size)
    font.letterSpacing: spacing
    textFormat: Text.PlainText
    elide: Text.ElideRight
    maximumLineCount: 1
}
