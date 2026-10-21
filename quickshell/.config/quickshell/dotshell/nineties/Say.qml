import QtQuick

// Big neon words in dots: Audiowide italic, `size` dots tall, on a dot
// canvas (1 px = 1 dot). Small words read better in the 5x7 pixel font:
// use MatrixText (or Word, which picks) for those.
//   Say { text: "72%"; size: 14 }
Text {
    property real size: 14
    property real spacing: 0
    property bool slanted: true

    color: Ink.yellow
    font.family: Ink.family
    font.italic: false
    font.pixelSize: Math.max(4, size)
    font.letterSpacing: spacing
    textFormat: Text.PlainText
    elide: Text.ElideRight
    maximumLineCount: 1
}
