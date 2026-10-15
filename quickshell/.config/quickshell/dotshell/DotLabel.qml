import QtQuick

// Pixel-font text for multi-line layouts (Columns, wrapped bodies).
// Every line is exactly Tokens.lineDots dots tall, so text sits on the dot grid.
// For single-line rows of a fixed height, use DotText.
Text {
    font.family: Tokens.font
    font.pixelSize: Tokens.fontPx
    font.hintingPreference: Font.PreferFullHinting
    renderType: Text.NativeRendering
    antialiasing: false
    textFormat: Text.PlainText
    lineHeightMode: Text.FixedHeight
    lineHeight: Tokens.lineDots
    elide: Text.ElideRight
    color: Tokens.slot0
}
