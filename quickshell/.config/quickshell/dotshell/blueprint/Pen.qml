import QtQuick

// A crisp word in Share Tech Mono, the drafting hand: labels, figure
// captions, table cells. `size` in px (the design's 9 .. 13).
//   Pen { text: "FIG. 4 — LOAD vs TIME (60 s)" }
Text {
    property real size: 10

    color: Ink.line
    font.family: Ink.family
    font.pixelSize: size
    textFormat: Text.PlainText
    elide: Text.ElideRight
    maximumLineCount: 1
    verticalAlignment: Text.AlignVCenter
}
