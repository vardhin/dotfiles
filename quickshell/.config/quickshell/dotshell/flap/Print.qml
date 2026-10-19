import QtQuick

// The housing's small print, crisp: Silkscreen, spaced wide, in the
// board's grey (the design's 8 px labels: SYSTEM STATUS, ● NOMINAL, keys).
//   Print { text: "SYSTEM STATUS" }
Text {
    property real size: 8
    property real spacing: 2

    color: Ink.label
    font.family: Ink.small
    font.pixelSize: size
    font.letterSpacing: spacing
    textFormat: Text.PlainText
    elide: Text.ElideRight
    maximumLineCount: 1
    verticalAlignment: Text.AlignVCenter
}
