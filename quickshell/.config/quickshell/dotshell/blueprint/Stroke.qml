import QtQuick
import QtQuick.Shapes

// A drawn line or outline, crisp: an SVG path in px, solid or dashed.
//   Stroke { anchors.fill: parent; path: "M 0 34 L 70 34"; color: Ink.ink; line: 1.5 }
//   Stroke { path: "M 22 40 L 140 6"; dash: [4, 3] }
Shape {
    id: stroke

    property string path: ""
    property color color: Ink.ink
    property real line: 1
    // On, off lengths in px; empty for a solid line.
    property var dash: []
    property color fill: "transparent"

    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        strokeColor: stroke.color
        strokeWidth: stroke.line
        fillColor: stroke.fill
        capStyle: ShapePath.FlatCap
        joinStyle: ShapePath.MiterJoin
        strokeStyle: stroke.dash.length ? ShapePath.DashLine : ShapePath.SolidLine
        // Qt counts dashes in stroke widths.
        dashPattern: stroke.dash.length ? stroke.dash.map(v => v / Math.max(0.5, stroke.line)) : [1, 0]
        PathSvg {
            path: stroke.path
        }
    }
}
