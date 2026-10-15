import QtQuick

// A one-dot outline: marks the active choice or the selected row.
// (Inverse video does not read on LEDs: dark letters on lit dots blur into
// the glow, so selection is a lit frame instead.)
Rectangle {
    color: "transparent"
    border.width: 1
    border.color: Tokens.slot0
}
