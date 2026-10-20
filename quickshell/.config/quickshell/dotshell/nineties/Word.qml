import QtQuick
import qs

// A neon word in dots, `dots` tall (1 px = 1 dot), filled with a gradient
// (`stops`, top to bottom) or one `color`: Audiowide italic when it is tall
// enough to read (`fontAt` dots and up), else the 5x7 pixel font scaled up
// by whole dots, so a cramped title still reads.
//   Word { text: "SYSTEM"; dots: 14; stops: Ink.sunset }
Item {
    id: word

    property string text: ""
    property int dots: 12
    property color color: Ink.yellow
    property var stops: null
    property real spacing: 0
    // "left", "center" or "right" inside the item's width.
    property string align: "left"
    property int fontAt: 12
    readonly property bool big: dots >= fontAt
    readonly property int k: Math.max(1, Math.floor(dots / 7))
    readonly property int sayW: Math.ceil(say.implicitWidth + dots * 0.25)

    implicitWidth: big ? sayW : mt.implicitWidth
    implicitHeight: dots

    Grad {
        anchors.fill: parent
        stops: word.stops ?? [[0, word.color], [1, word.color]]
        Say {
            id: say
            visible: word.big
            width: parent.width
            height: parent.height
            horizontalAlignment: word.align === "center" ? Text.AlignHCenter : word.align === "right" ? Text.AlignRight : Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
            text: word.text
            size: Math.round(word.dots * 1.3)
            spacing: word.spacing
            color: "white"
            elide: Text.ElideNone
        }
        MatrixText {
            id: mt
            visible: !word.big
            x: word.align === "center" ? Math.round((word.width - width) / 2) : word.align === "right" ? word.width - width : 0
            y: Math.round((word.height - height) / 2)
            width: implicitWidth
            height: 7 * word.k
            size: word.k
            dot: word.k >= 3 ? word.k - 1 : word.k
            text: word.text
            color: "white"
        }
    }
}
