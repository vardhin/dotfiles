import QtQuick

// Crisp VT323 (the pager's LCD, the camcorder's on-screen display), with
// the OSD's hard 1 px drop shadow when `shade`.
//   Mono { text: "STBY SP"; size: 22; shade: true }
Text {
    property real size: 18
    property bool shade: false

    color: Ink.lcdInk
    font.family: Ink.mono
    font.pixelSize: size
    textFormat: Text.PlainText
    elide: Text.ElideRight
    maximumLineCount: 1
    verticalAlignment: Text.AlignVCenter
    style: shade ? Text.Raised : Text.Normal
    styleColor: "#000000"
}
