import QtQuick

// A line in Nixie One, crisp, in cathode orange (the design's 12-13 px
// lines on the wood: "minutes remaining", "3:41 LEFT", a floor's windows).
//   Pen { text: "minutes remaining" }
Text {
    property real size: 13

    color: Ink.orange
    font.family: Ink.family
    font.pixelSize: size
    textFormat: Text.PlainText
    elide: Text.ElideRight
    maximumLineCount: 1
    verticalAlignment: Text.AlignVCenter
}
