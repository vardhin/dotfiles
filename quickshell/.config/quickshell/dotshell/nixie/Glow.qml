import QtQuick
import qs

// A crisp lamp that glows: a filled round rect with a soft halo round it in
// its own colour (the clock's colon dots, the tube bars of System, a lit
// key). Off in the other tone's daylight.
//   Glow { width: 7; height: 7; radius: 3.5; color: Ink.orange }
Rectangle {
    id: lamp

    property real halo: 6

    Repeater {
        model: Tokens.neon ? 3 : 0
        Rectangle {
            required property int index
            readonly property real g: lamp.halo * (index + 1) / 3
            x: -g
            y: -g
            width: lamp.width + g * 2
            height: lamp.height + g * 2
            radius: lamp.radius + g
            color: lamp.color
            opacity: 0.16 - index * 0.04
        }
    }
}
