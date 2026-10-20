import QtQuick

// Big words in dots: Share Tech Mono, `size` dots tall, on the glass (1 px
// = 1 dot): the clock's time, STAYING AWAKE, the battery's percent. Small
// words read better in the 5x7 pixel font: use MatrixText for those.
//   Say { text: "2147"; size: 18 }
Text {
    property real size: 14

    color: Ink.bright
    font.family: Ink.family
    font.pixelSize: Math.max(4, size)
    // Strokes a whole dot wide, so they light instead of fading.
    font.bold: true
    textFormat: Text.PlainText
    elide: Text.ElideRight
    maximumLineCount: 1
    renderType: Text.QtRendering
}
