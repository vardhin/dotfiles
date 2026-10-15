import QtQuick

// One-line text field in dots, with a blinking block cursor.
//   DotInput { mask: true; onAccepted: Net.connectWithPassword(net, text) }
TextInput {
    id: root

    property bool mask: false

    height: Tokens.lineDots
    verticalAlignment: TextInput.AlignVCenter
    font.family: Tokens.font
    font.pixelSize: Tokens.fontPx
    font.hintingPreference: Font.PreferFullHinting
    renderType: Text.NativeRendering
    antialiasing: false
    color: Tokens.slot0
    selectionColor: Tokens.slot1
    selectedTextColor: Tokens.glass
    echoMode: mask ? TextInput.Password : TextInput.Normal
    passwordCharacter: "*"
    clip: true

    cursorDelegate: Rectangle {
        width: Tokens.charDots - 1
        height: 9
        y: 1
        color: Tokens.slot0
        visible: root.activeFocus && blink.lit

        Timer {
            id: blink
            property bool lit: true
            running: root.activeFocus
            interval: 530
            repeat: true
            onTriggered: lit = !lit
        }
    }
}
