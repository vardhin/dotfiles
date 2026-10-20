import QtQuick
import qs

// A card drawn on a screen, crisp: rounded, a faint warm rule and fill (the
// expanded boards' gauges, process cards, floors, timers). `on` rules it in
// the bright digit colour with a glow (the picked one).
//   Card { width: 120; height: 60; on: true }
Rectangle {
    id: card

    property bool on: false

    radius: 8
    color: on ? Ink.c(Qt.rgba(1, 122 / 255, 26 / 255, 0.08), Qt.rgba(180 / 255, 70 / 255, 15 / 255, 0.08)) : Ink.cardFill
    border.width: 1
    border.color: on ? Ink.digit : Ink.cardRim
    Rectangle {
        visible: card.on && Tokens.neon
        anchors.fill: parent
        anchors.margins: -3
        radius: card.radius + 3
        color: "transparent"
        border.width: 3
        border.color: Ink.orange
        opacity: 0.25
    }
}
