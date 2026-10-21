import QtQuick
import QtQuick.Effects

// The top strip's or side rail's edge in Tokyo Night: one blue neon tube
// where the bar meets the desktop (the strip's bottom, the rail's left),
// glowing back over the bar's glass (the Drag & dock board's bar: a 1 px
// line and its faint spill). The only casing the bar has; docked
// items sit bare on the glass. Fill it over the whole bar window.
//   Edge { anchors.fill: parent; place: "strip" }
Item {
    id: edge

    property string place: "strip"
    readonly property bool vertical: place === "rail"

    // The spill, faint, a dozen px into the bar.
    Rectangle {
        x: edge.vertical ? 0 : 0
        y: edge.vertical ? 0 : edge.height - height
        width: edge.vertical ? Math.min(14, edge.width) : edge.width
        height: edge.vertical ? edge.height : Math.min(14, edge.height)
        gradient: Gradient {
            orientation: edge.vertical ? Gradient.Horizontal : Gradient.Vertical
            GradientStop {
                position: 0
                color: edge.vertical ? Ink.c(Qt.rgba(122 / 255, 162 / 255, 247 / 255, 0.14), Qt.rgba(46 / 255, 125 / 255, 233 / 255, 0.12)) : "transparent"
            }
            GradientStop {
                position: 1
                color: edge.vertical ? "transparent" : Ink.c(Qt.rgba(122 / 255, 162 / 255, 247 / 255, 0.14), Qt.rgba(46 / 255, 125 / 255, 233 / 255, 0.12))
            }
        }
    }
    // The tube.
    Item {
        anchors.fill: parent
        layer.enabled: edge.visible
        layer.effect: MultiEffect {
            shadowEnabled: Ink.neon
            shadowColor: Ink.pink
            shadowBlur: 0.35
            blurMax: 16
            shadowScale: 1
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }
        Rectangle {
            x: 0
            y: edge.vertical ? 0 : edge.height - 2
            width: edge.vertical ? 2 : edge.width
            height: edge.vertical ? edge.height : 2
            color: Ink.pink
        }
    }
}
