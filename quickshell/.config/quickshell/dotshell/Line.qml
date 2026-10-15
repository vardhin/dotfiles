import QtQuick

// One text line of a pane: a label on the left, anything on the right.
//   Line { label: "VOLUME"; DotButton { text: "MUTE" } }
Item {
    id: root

    property string label
    property color labelColor: Tokens.slot0
    default property alias trailing: tail.data

    width: parent ? parent.width : 0
    height: Tokens.lineDots

    DotText {
        width: root.width - tail.width - Tokens.charDots
        text: root.label
        color: root.labelColor
        elide: Text.ElideRight
    }

    Row {
        id: tail
        anchors.right: parent.right
        height: parent.height
        spacing: 3
    }
}
