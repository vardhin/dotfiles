import QtQuick

// Big words in dots: Share Tech Mono, `size` dots tall, inside a Dots
// canvas (1 px = 1 dot). Small words read better in the 5x7 pixel font:
// use MatrixText for those.
//   Say { text: "21:47"; size: 18 }
Text {
    property real size: 14

    color: Ink.white
    font.family: Ink.family
    font.pixelSize: Math.max(4, size)
    textFormat: Text.PlainText
    elide: Text.ElideRight
    maximumLineCount: 1
}
