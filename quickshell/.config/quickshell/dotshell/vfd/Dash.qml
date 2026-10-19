import QtQuick

// The top strip or side rail in VFD: one long head unit across the bar.
// Brushed gunmetal, lit along its top edge (the strip; the rail is lit
// along its left), a black rule where it meets the desktop, and the bar's
// dots in one sunken window of smoked glass (the design's Drag & dock
// board). Under the bar's DotSurface; `Smoke` goes over it for the shadow
// and the lip. `win` is the window, in this item's px.
//   Dash { anchors.fill: parent; place: "strip"; win: Qt.rect(…) }
Item {
    id: dash

    property string place: "strip"
    property rect win
    readonly property bool vertical: place === "rail"

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: dash.vertical ? Gradient.Horizontal : Gradient.Vertical
            GradientStop {
                position: 0
                color: Ink.plateTop
            }
            GradientStop {
                position: 1
                color: Ink.plateBottom
            }
        }
    }
    // The lit edge.
    Rectangle {
        width: dash.vertical ? 1 : parent.width
        height: dash.vertical ? parent.height : 1
        color: Ink.plateEdge
    }
    // Where it meets the desktop.
    Rectangle {
        x: dash.vertical ? 0 : 0
        y: dash.vertical ? 0 : parent.height - 1
        width: dash.vertical ? 1 : parent.width
        height: dash.vertical ? parent.height : 1
        color: Ink.c("black", "#7f8f89")
        visible: !dash.vertical
    }
    // The window's glass, a hair past the dots.
    Rectangle {
        x: dash.win.x - 1
        y: dash.win.y - 1
        width: dash.win.width + 2
        height: dash.win.height + 2
        radius: 4
        color: Ink.glass
    }
}
