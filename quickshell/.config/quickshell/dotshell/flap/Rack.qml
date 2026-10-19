import QtQuick

// The top strip or the side rail in Split-Flap: one long departure board
// housing, near black, its 2 px grey rim where it meets the desktop (the
// strip's bottom, the rail's left), under the bar's lit square dots
// (DotSurface.bare). Crisp.
//   Rack { anchors.fill: parent; place: "strip" }
Item {
    id: bar

    property string place: "strip"
    readonly property bool vertical: place === "rail"

    Rectangle {
        anchors.fill: parent
        color: Ink.housing
    }
    Rectangle {
        y: bar.vertical ? 0 : parent.height - 2
        width: bar.vertical ? 2 : parent.width
        height: bar.vertical ? parent.height : 2
        color: Ink.rim
    }
}
