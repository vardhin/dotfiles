import QtQuick
import qs

// One line of state on the ANIME page: a dim name, then what it is.
Item {
    id: sl

    property string label
    property string value
    property color tone: Tokens.slot0

    width: parent ? parent.width : 0
    height: Tokens.lineDots

    DotText {
        text: sl.label
        color: Tokens.slot1
    }
    DotText {
        x: 8 * Tokens.charDots
        width: sl.width - x
        elide: Text.ElideRight
        text: sl.value
        color: sl.tone
    }
}
