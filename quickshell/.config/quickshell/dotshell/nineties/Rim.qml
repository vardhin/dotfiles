import QtQuick
import QtQuick.Shapes

// A crisp frame in the sunset (yellow → pink → blue, 135°), `thick` px,
// open in the middle so the dots show through (the expanded boards' cards,
// the battery graph, the clipboard's search). `across` runs it 90°.
//   Rim { width: 160; height: 80; thick: 2 }
Shape {
    id: rim

    property real thick: 2
    property bool across: false

    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        strokeWidth: -1
        fillRule: ShapePath.OddEvenFill
        fillGradient: LinearGradient {
            x1: 0
            y1: 0
            x2: rim.width
            y2: rim.across ? 0 : rim.height
            GradientStop {
                position: 0
                color: Ink.yellow
            }
            GradientStop {
                position: 0.5
                color: Ink.pink
            }
            GradientStop {
                position: 1
                color: Ink.blue
            }
        }
        PathSvg {
            readonly property real w: rim.width
            readonly property real h: rim.height
            readonly property real t: rim.thick
            path: "M0 0 H" + w + " V" + h + " H0 Z M" + t + " " + t + " V" + (h - t) + " H" + (w - t) + " V" + t + " Z"
        }
    }
}
