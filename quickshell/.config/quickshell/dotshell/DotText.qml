import QtQuick

// Pixel-font text for DotSurface canvases: 1 font pixel = 1 dot.
// Fills its parent's height and centers the 7-dot capitals in it.
Text {
    height: parent ? parent.height : Tokens.fontPx
    verticalAlignment: Text.AlignVCenter
    font.family: Tokens.font
    font.pixelSize: Tokens.fontPx
    font.hintingPreference: Font.PreferFullHinting
    renderType: Text.NativeRendering
    antialiasing: false
    color: Tokens.slot0
}
