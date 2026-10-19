import QtQuick
import QtQuick.Shapes

// A transport icon, crisp and solid (the design's ⏮ ⏸ ⏭ ■ ●): prev, next,
// play, pause, stop, rec. Drawn in a 10 x 10 box scaled to the item.
//   Glyph { width: 12; height: 12; kind: "pause" }
Shape {
    id: g

    property string kind: "play"
    property color color: Ink.ink

    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        scale: Qt.size(g.width / 10, g.height / 10)
        fillColor: g.color
        strokeColor: "transparent"
        strokeWidth: 0
        PathSvg {
            path: g.kind === "prev" ? "M 0 0 L 2 0 L 2 10 L 0 10 Z M 10 0 L 2.5 5 L 10 10 Z" : g.kind === "next" ? "M 0 0 L 7.5 5 L 0 10 Z M 8 0 L 10 0 L 10 10 L 8 10 Z" : g.kind === "pause" ? "M 1 0 L 4 0 L 4 10 L 1 10 Z M 6 0 L 9 0 L 9 10 L 6 10 Z" : g.kind === "stop" ? "M 1 1 L 9 1 L 9 9 L 1 9 Z" : g.kind === "rec" ? "M 5 1 A 4 4 0 1 1 4.99 1 Z" : "M 1 0 L 10 5 L 1 10 Z"
        }
    }
}
