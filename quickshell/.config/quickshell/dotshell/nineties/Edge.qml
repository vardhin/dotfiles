import QtQuick
import QtQuick.Effects
import qs

// The top strip's or side rail's edge in 90s Nights: a 3 px orchid rule
// where the bar meets the desktop (the strip's bottom, the rail's left),
// glowing faintly
// back over the dot glass. The only casing the bar has; docked items sit
// bare on the glass. Fill it over the whole bar window.
//   Edge { anchors.fill: parent; place: "strip" }
Item {
    id: edge

    property string place: "strip"
    readonly property bool vertical: place === "rail"
    readonly property color tint: Ink.blue

    // The spill, faint, a dozen px into the bar.
    Rectangle {
        y: edge.vertical ? 0 : edge.height - height
        width: edge.vertical ? Math.min(14, edge.width) : edge.width
        height: edge.vertical ? edge.height : Math.min(14, edge.height)
        visible: Tokens.neon
        gradient: Gradient {
            orientation: edge.vertical ? Gradient.Horizontal : Gradient.Vertical
            GradientStop {
                position: 0
                color: edge.vertical ? Qt.rgba(edge.tint.r, edge.tint.g, edge.tint.b, 0.15) : "transparent"
            }
            GradientStop {
                position: 1
                color: edge.vertical ? "transparent" : Qt.rgba(edge.tint.r, edge.tint.g, edge.tint.b, 0.15)
            }
        }
    }
    Item {
        anchors.fill: parent
        layer.enabled: edge.visible && Tokens.neon
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: edge.tint
            shadowBlur: 0.5
            blurMax: 12
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }
        Rectangle {
            y: edge.vertical ? 0 : edge.height - 3
            width: edge.vertical ? 3 : edge.width
            height: edge.vertical ? edge.height : 3
            color: edge.tint
        }
    }
}
