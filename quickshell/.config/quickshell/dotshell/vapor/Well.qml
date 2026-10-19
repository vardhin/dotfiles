import QtQuick

// The sunken well an expanded window holds its contents in (the design's
// inset 2 px frame), or, `paper`, a white sunken sheet (Notepad, the
// clipboard, the inbox). Crisp.
//   Well { x: 6; y: win.bodyY + 6; width: ...; height: ...; paper: true }
Item {
    id: well

    property bool paper: false

    Rectangle {
        anchors.fill: parent
        color: well.paper ? Ink.hi : "transparent"
    }
    Bevel {
        anchors.fill: parent
        line: 2
        sunk: true
    }
}
