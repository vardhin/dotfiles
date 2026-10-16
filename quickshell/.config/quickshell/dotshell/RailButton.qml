import QtQuick

// One glyph on the side rail you can click. A lit bar on the rail's left
// edge marks it while `active` (its pane is open); hovering lights it dimly.
// As wide as the rail (13 dots: Nerd Font icons are up to 11), one text line
// tall.
Item {
    id: btn
    property string glyph
    property color color: Tokens.slot0
    property bool active: false
    signal clicked

    width: 13
    height: Tokens.lineDots

    Rectangle {
        visible: btn.active || mouse.containsMouse
        width: 1
        height: parent.height
        color: btn.color
        opacity: btn.active ? 1 : 0.5
    }
    DotText {
        x: 1
        width: parent.width - 1
        horizontalAlignment: Text.AlignHCenter
        text: btn.glyph
        color: btn.color
        opacity: mouse.containsMouse || btn.active ? 1 : 0.8
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
