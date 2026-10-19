import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// A neon gauge: a dark track round a circle and a glowing arc over it from
// twelve o'clock, `value` of the way round (the design's SVG rings).
//   Ring { width: 92; height: 92; value: 0.38; tint: Ink.cyan }
Item {
    id: ring

    property real value: 0
    property color tint: Ink.cyan
    // Stroke, as a fraction of the diameter (7 of 92 in the design).
    property real weight: 0.076
    readonly property real stroke: Math.max(3, Math.round(width * weight))
    readonly property real r: (Math.min(width, height) - stroke) / 2 - 2

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Ink.unlit
            strokeWidth: ring.stroke
            fillColor: "transparent"
            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: ring.r
                radiusY: ring.r
                startAngle: 0
                sweepAngle: 360
            }
        }
    }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: ring.value > 0.005
        layer.enabled: visible
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: ring.tint
            shadowBlur: 0.35
            blurMax: 12
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }
        ShapePath {
            strokeColor: ring.tint
            strokeWidth: ring.stroke
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: ring.r
                radiusY: ring.r
                startAngle: -90
                sweepAngle: 360 * Math.max(0, Math.min(1, ring.value))
            }
        }
    }
}
