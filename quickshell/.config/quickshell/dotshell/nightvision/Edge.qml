import QtQuick
import qs

// The top strip's or side rail's edge in Night Vision: one px of dim
// phosphor green where the bar meets the desktop (the Drag & dock board's
// `box-shadow: 0 1px 0 #2fae2a`), along the strip's bottom and down the
// rail's left. The only casing the bar has; docked items sit bare on the
// green glass. Fill it over the whole bar window.
//   Edge { anchors.fill: parent; place: "strip" }
Item {
    id: edge

    property string place: "strip"
    readonly property bool vertical: place === "rail"

    Rectangle {
        y: edge.vertical ? 0 : edge.height - 1
        width: edge.vertical ? 1 : edge.width
        height: edge.vertical ? edge.height : 1
        color: Ink.dim
    }
}
