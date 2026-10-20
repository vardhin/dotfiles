import QtQuick

// The case's small print, crisp: Silkscreen spaced wide, in brass (the
// design's 7-8 px labels: CPU %, ON BATTERY, PLATES TAKEN TODAY).
//   Print { text: "CPU %" }
Text {
    property real size: 8
    property real spacing: 2

    color: Ink.brass
    font.family: Ink.small
    font.pixelSize: size
    font.letterSpacing: spacing
    textFormat: Text.PlainText
    elide: Text.ElideRight
    maximumLineCount: 1
    verticalAlignment: Text.AlignVCenter
}
