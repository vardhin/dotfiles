import QtQuick
import Quickshell

// One-line text field in dots, with a blinking block cursor.
//   DotInput { mask: true; onAccepted: Net.connectWithPassword(net, text) }
// Sized 1/dpr and scaled by dpr like DotText, so glyphs land on whole dots.
// Keys the field does not take (Escape, arrows) reach this FocusScope's Keys.
FocusScope {
    id: root

    property alias text: field.text
    property bool mask: false
    signal accepted

    readonly property real dpr: QsWindow.window?.devicePixelRatio ?? 1

    height: Tokens.lineDots
    implicitWidth: 40

    TextInput {
        id: field
        focus: true
        width: root.width / root.dpr
        height: root.height / root.dpr
        scale: root.dpr
        transformOrigin: Item.TopLeft
        verticalAlignment: TextInput.AlignVCenter
        font.family: Tokens.font
        font.pixelSize: Tokens.fontPx / root.dpr
        font.hintingPreference: Font.PreferFullHinting
        renderType: Text.NativeRendering
        antialiasing: false
        color: Tokens.slot0
        selectionColor: Tokens.slot1
        selectedTextColor: Tokens.glass
        echoMode: root.mask ? TextInput.Password : TextInput.Normal
        passwordCharacter: "*"
        clip: true
        onAccepted: root.accepted()

        // In the unscaled space of the field: divide dots by dpr.
        cursorDelegate: Rectangle {
            width: (Tokens.charDots - 1) / root.dpr
            height: 9 / root.dpr
            y: 1 / root.dpr
            color: Tokens.slot0
            visible: field.activeFocus && blink.lit

            Timer {
                id: blink
                property bool lit: true
                running: field.activeFocus
                interval: 530
                repeat: true
                onTriggered: lit = !lit
            }
        }
    }
}
