import QtQuick
import QtQuick.Shapes

// A transport glyph, crisp: prev, next, play, pause, stop, rec, drawn in
// a 16 x 14 box scaled to the item (the design's key SVGs).
//   Glyph { kind: "pause"; width: 10; height: 12; color: Ink.night }
Item {
    id: g

    property string kind: "play"
    property color color: Ink.night
    readonly property string d: ({
            prev: "M0 1 H3 V13 H0 Z M15 1 L4 7 L15 13 Z",
            next: "M1 1 L12 7 L1 13 Z M13 1 H16 V13 H13 Z",
            play: "M2 0 L15 7 L2 14 Z",
            pause: "M2 0 H6 V14 H2 Z M10 0 H14 V14 H10 Z",
            stop: "M2 1 H14 V13 H2 Z",
            rec: "M8 1 A6 6 0 1 1 7.99 1 Z"
        })[kind] ?? ""

    Shape {
        width: 16
        height: 14
        scale: Math.min(g.width / 16, g.height / 14)
        transformOrigin: Item.TopLeft
        x: (g.width - 16 * scale) / 2
        y: (g.height - 14 * scale) / 2
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillColor: g.color
            PathSvg {
                path: g.d
            }
        }
    }
}
