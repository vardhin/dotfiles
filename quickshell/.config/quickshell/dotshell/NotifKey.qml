import QtQuick

// A key on a notification card, in dots, in the era's look (NotifLook.js):
// a filled or outlined pill with its word. Plain eras: a DotButton.
//   NotifKey { look: l; text: "OPEN"; onClicked: … }
Item {
    id: key

    property var look: null
    property string text
    property color plain: Tokens.slot2
    property bool active: false
    signal clicked

    implicitWidth: look ? label.implicitWidth + 6 : button.implicitWidth
    implicitHeight: Tokens.lineDots
    opacity: enabled ? 1 : 0.45

    DotButton {
        id: button
        visible: !key.look
        text: key.text
        color: key.plain
        active: key.active
        onClicked: key.clicked()
    }

    Rectangle {
        visible: !!key.look
        anchors.fill: parent
        radius: key.look?.radius ? Math.floor(height / 2) : 0
        color: key.active ? (key.look?.live ?? "transparent") : (key.look?.keyFill ?? "transparent")
        border.width: 1
        border.color: key.active ? (key.look?.live ?? "transparent") : (key.look?.keyRim ?? "transparent")
        opacity: mouse.containsMouse ? 1 : 0.9
    }
    DotText {
        id: label
        visible: !!key.look
        x: 3
        text: key.text
        color: key.active && key.look ? (key.look.fill === "transparent" ? "#000000" : "#ffffff") : (key.look?.keyInk ?? Tokens.slot0)
    }
    MouseArea {
        id: mouse
        visible: !!key.look
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: key.clicked()
    }
}
