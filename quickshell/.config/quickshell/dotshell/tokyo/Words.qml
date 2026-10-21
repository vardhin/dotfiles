import QtQuick
import qs

// A word on the glass in the biggest dot font that fits `room` dots: the
// 5x7 pixel font when it fits, else the 3x5 small print (capitals). Set
// `small` to always use the 3x5 one. A leading Japanese word (通知 · ...)
// has no 3x5 glyphs: it stays in the pixel font's fallback, in front.
//   Words { text: "11.2G"; room: 22; color: Ink.violet; align: "center" }
Item {
    id: words

    property string text: ""
    property color color: Ink.pink
    // The Japanese word in front: the lantern orange.
    property color leadColor: Ink.orange
    property int room: 9999
    property bool small: false
    // left | center | right, within `width`.
    property string align: "left"
    property bool scroll: false

    readonly property bool big: !small && text.length * Tokens.charDots <= room + 1
    readonly property string cjk: (text.match(/^[⺀-鿿豈-﫿　-ヿ]+/) ?? [""])[0]
    // Room is short: the English alone, without the Japanese in front.
    readonly property bool lead: cjk !== "" && cjk.length * 9 + (text.length - cjk.length) * 4 <= room
    readonly property string rest: lead ? text.slice(cjk.length) : text.slice(cjk.length).replace(/^\s*·\s*/, "")

    readonly property real leadW: leadText.visible ? Math.ceil(leadText.implicitWidth) + 2 : 0

    implicitWidth: big ? pixel.implicitWidth : Math.min(leadW + tiny.implicitWidth, room)
    implicitHeight: big ? Tokens.fontPx : 7

    DotText {
        id: pixel
        visible: words.big
        width: words.width
        height: Tokens.fontPx
        text: words.text
        color: words.color
        elide: Text.ElideRight
        horizontalAlignment: words.align === "center" ? Text.AlignHCenter : words.align === "right" ? Text.AlignRight : Text.AlignLeft
    }
    Text {
        id: leadText
        visible: !words.big && words.lead
        y: -1
        height: 8
        verticalAlignment: Text.AlignVCenter
        text: words.cjk
        color: words.leadColor
        font.family: Ink.family
        font.pixelSize: 8
    }
    MatrixText {
        id: tiny
        visible: !words.big
        x: words.leadW
        y: Math.round((words.implicitHeight - 5) / 2)
        width: Math.max(0, words.width - words.leadW)
        height: implicitHeight
        font: "3x5"
        text: words.rest
        color: words.color
        align: words.align
        scroll: words.scroll
    }
}
