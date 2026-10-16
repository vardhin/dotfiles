import QtQuick
import Quickshell

// Pixel-font text for multi-line layouts (Columns, wrapped bodies).
// Every line is exactly Tokens.lineDots dots tall, so text sits on the dot grid.
// For single-line rows of a fixed height, use DotText (which explains the
// 1/dpr size and dpr scale below).
Item {
    id: root

    property alias text: label.text
    property alias color: label.color
    property alias wrapMode: label.wrapMode
    property alias maximumLineCount: label.maximumLineCount
    property alias elide: label.elide

    readonly property real dpr: QsWindow.window?.devicePixelRatio ?? 1

    implicitWidth: Math.round(label.implicitWidth * dpr)
    implicitHeight: label.lineCount * Tokens.lineDots

    Text {
        id: label
        width: root.width / root.dpr
        scale: root.dpr
        transformOrigin: Item.TopLeft
        font.family: Tokens.font
        font.pixelSize: Tokens.fontPx / root.dpr
        font.hintingPreference: Font.PreferFullHinting
        renderType: Text.NativeRendering
        antialiasing: false
        textFormat: Text.PlainText
        lineHeightMode: Text.FixedHeight
        lineHeight: Tokens.lineDots / root.dpr
        elide: Text.ElideRight
        color: Tokens.slot0
    }
}
