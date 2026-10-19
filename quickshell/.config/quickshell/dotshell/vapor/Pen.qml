import QtQuick

// A crisp word in VT323, the window's own hand: title bars, labels, keys.
// `size` in px (the design's 14 .. 18).
//   Pen { text: "CPU Usage" }
Text {
    property real size: 15

    color: Ink.ink
    font.family: Ink.family
    font.pixelSize: size
    textFormat: Text.PlainText
    elide: Text.ElideRight
    maximumLineCount: 1
    verticalAlignment: Text.AlignVCenter
}
