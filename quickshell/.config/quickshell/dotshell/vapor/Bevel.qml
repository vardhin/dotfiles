import QtQuick

// The Windows 95 bevel, crisp: `line` px of light on two sides and shade on
// the other two. Raised (a key, the window) lights the top left; sunk (a
// screen, a field, the well) lights the bottom right. `outer` adds the
// window's second, mid violet ring inside the shade.
//   Bevel { anchors.fill: parent; sunk: true }
Item {
    id: bevel

    property bool sunk: false
    property real line: 1
    property color light: Ink.hi
    property color dark: Ink.shade
    property color outer: "transparent"
    readonly property color tl: sunk ? dark : light
    readonly property color br: sunk ? light : dark

    Rectangle {
        width: parent.width
        height: bevel.line
        color: bevel.tl
    }
    Rectangle {
        width: bevel.line
        height: parent.height
        color: bevel.tl
    }
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: bevel.line
        color: bevel.br
    }
    Rectangle {
        anchors.right: parent.right
        width: bevel.line
        height: parent.height
        color: bevel.br
    }
    // The window's second ring, just inside the shade.
    Rectangle {
        visible: bevel.outer.a > 0
        x: bevel.line
        anchors.bottom: parent.bottom
        anchors.bottomMargin: bevel.line
        width: parent.width - bevel.line * 2
        height: bevel.line
        color: bevel.outer
    }
    Rectangle {
        visible: bevel.outer.a > 0
        y: bevel.line
        anchors.right: parent.right
        anchors.rightMargin: bevel.line
        width: bevel.line
        height: parent.height - bevel.line * 2
        color: bevel.outer
    }
}
