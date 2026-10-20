import QtQuick

// Crisp Audiowide (the design's small labels off the dots: 38%, CPU,
// ON BATTERY, 42 MIN LEFT, key legends), electric blue by default.
//   Pen { text: "ON BATTERY"; spacing: 2 }
Text {
    property real size: 10
    property real spacing: 0
    property bool slanted: false

    color: Ink.blue
    font.family: Ink.family
    font.italic: slanted
    font.pixelSize: size
    font.letterSpacing: spacing
    textFormat: Text.PlainText
    elide: Text.ElideRight
    maximumLineCount: 1
    verticalAlignment: Text.AlignVCenter
}
