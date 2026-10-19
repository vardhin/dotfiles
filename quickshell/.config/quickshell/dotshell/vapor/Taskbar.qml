import QtQuick

// The top strip or the side rail in Vaporwave: the Windows 95 taskbar, a
// lilac face lit white along its outer edge with the deep violet shade
// (and the mid violet ring) where it meets the desktop (the strip's
// bottom, the rail's left), under the bar's lit-only dots
// (DotSurface.bare). Crisp.
//   Taskbar { anchors.fill: parent; place: "strip" }
Item {
    id: bar

    property string place: "strip"
    readonly property bool vertical: place === "rail"

    Rectangle {
        anchors.fill: parent
        color: Ink.face
    }
    // The light edge away from the desktop.
    Rectangle {
        x: bar.vertical ? parent.width - 1 : 0
        width: bar.vertical ? 1 : parent.width
        height: bar.vertical ? parent.height : 1
        color: Ink.hi
    }
    // The shade at the desktop, and the mid ring just inside it.
    Rectangle {
        y: bar.vertical ? 0 : parent.height - 1
        width: bar.vertical ? 1 : parent.width
        height: bar.vertical ? parent.height : 1
        color: Ink.shade
    }
    Rectangle {
        x: bar.vertical ? 1 : 0
        y: bar.vertical ? 0 : parent.height - 2
        width: bar.vertical ? 1 : parent.width
        height: bar.vertical ? parent.height : 1
        color: Ink.mid
    }
}
