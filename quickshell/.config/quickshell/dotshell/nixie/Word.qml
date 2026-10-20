import QtQuick
import qs

// A big glowing word in dots, `dots` tall (1 px = 1 dot): Nixie One when it
// is tall enough to read (13 dots and up), else the 5x7 pixel font scaled
// up by whole dots, so a small tube or a cramped title still reads.
//   Word { text: "38"; dots: 12; color: Ink.digit }
Item {
    id: word

    property string text: ""
    property int dots: 12
    property color color: Ink.digit
    property real spacing: 0
    // "left", "center" or "right" inside the item's width.
    property string align: "left"
    // From how many dots tall Nixie One is used.
    property int serifAt: 13
    readonly property bool serif: dots >= serifAt
    readonly property int k: Math.max(1, Math.floor(dots / 7))

    implicitWidth: serif ? say.implicitWidth : mt.implicitWidth
    implicitHeight: dots

    Say {
        id: say
        visible: word.serif
        width: parent.width
        height: parent.height
        horizontalAlignment: word.align === "center" ? Text.AlignHCenter : word.align === "right" ? Text.AlignRight : Text.AlignLeft
        verticalAlignment: Text.AlignVCenter
        text: word.text
        size: Math.round(word.dots * 1.3)
        spacing: word.spacing
        color: word.color
        elide: Text.ElideNone
    }
    MatrixText {
        id: mt
        visible: !word.serif
        x: word.align === "center" ? Math.round((word.width - width) / 2) : word.align === "right" ? word.width - width : 0
        y: Math.round((word.height - height) / 2)
        width: implicitWidth
        height: 7 * word.k
        size: word.k
        dot: word.k >= 3 ? word.k - 1 : word.k
        text: word.text
        color: word.color
    }
}
