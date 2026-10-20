import QtQuick

// The top strip or the side rail in Nixie: one long walnut case, its grain
// running along the bar, a brass px where it meets the desktop (the strip's
// bottom, the rail's left), under the bar's lit dots (DotSurface.bare).
// Crisp.
//   Rack { anchors.fill: parent; place: "strip" }
Item {
    id: bar

    property string place: "strip"
    readonly property bool vertical: place === "rail"

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: bar.vertical ? Gradient.Vertical : Gradient.Horizontal
            GradientStop {
                position: 0
                color: Ink.woodA
            }
            GradientStop {
                position: 0.5
                color: Ink.woodB
            }
            GradientStop {
                position: 1
                color: Ink.woodA
            }
        }
    }
    Rectangle {
        y: bar.vertical ? 0 : parent.height - 2
        width: bar.vertical ? 2 : parent.width
        height: bar.vertical ? parent.height : 2
        color: Ink.brass
    }
}
