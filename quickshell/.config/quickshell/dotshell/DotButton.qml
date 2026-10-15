import QtQuick

// A word you can click. Framed when `active`, dim when `enabled` is false,
// underlined on hover.
Item {
    id: root

    property string text
    property color color: Tokens.slot0
    property bool active: false
    property int pad: 2
    signal clicked

    implicitWidth: label.implicitWidth + pad * 2
    implicitHeight: Tokens.lineDots
    opacity: enabled ? 1 : 0.5

    Frame {
        anchors.fill: parent
        visible: root.active
        border.color: root.color
    }

    DotText {
        id: label
        x: root.pad
        text: root.text
        color: root.color
    }

    Rectangle {
        visible: mouse.containsMouse && !root.active
        y: parent.height - 1
        width: parent.width
        height: 1
        color: root.color
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
