import QtQuick

// A clickable word on the strip ("VOL 45"). `dim` drops it to the low
// brightness level; `wheel(up)` fires on scroll.
Item {
    id: root

    property string text
    property color color: Tokens.slot0
    property bool dim: false
    signal clicked
    signal middleClicked
    signal wheel(bool up)

    width: label.implicitWidth
    height: parent ? parent.height : Tokens.fontPx

    DotText {
        id: label
        text: root.text
        color: root.color
        opacity: root.dim ? 0.5 : 1
    }

    // Hover: underline, same as the workspace focus mark.
    Rectangle {
        visible: mouse.containsMouse
        y: root.height - 1
        width: root.width
        height: 1
        color: root.color
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => mouse.button === Qt.MiddleButton ? root.middleClicked() : root.clicked()
        onWheel: event => root.wheel(event.angleDelta.y > 0)
    }
}
