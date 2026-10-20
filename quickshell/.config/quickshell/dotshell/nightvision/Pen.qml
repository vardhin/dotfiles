import QtQuick

// A crisp word in Share Tech Mono, off the dots (a key's word, a thumb's
// caption, the media pane's REC line).
//   Pen { text: "REC ● 480P"; size: 11 }
Text {
    property real size: 11

    color: Ink.bright
    font.family: Ink.family
    font.pixelSize: size
    font.letterSpacing: 1
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
    maximumLineCount: 1
}
