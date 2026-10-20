import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs

// A 90s Nights sign, crisp round dot glass: the 3 px rim in the sunset
// (yellow → pink → blue, 135°) and inside it the dark dot glass (the
// design's `.pn`, a DotSurface). `slant` leans it 10° like the compact
// boards (top edge pushed right by `lean` px, the bottom edge left); off,
// it is the expanded boards' upright rectangle. Children are authored in
// dots on the glass. `inside` holds crisp parts cut to the glass's outline
// (the clock's sunset). `leftAt(y)`/`rightAt(y)` give the glass's inner edges
// in px at a height, so a face keeps its words inside the slant.
//   Plate { anchors.fill: parent; slant: true; MatrixText { text: "CPU" } }
Item {
    id: plate

    property bool slant: true
    property int rim: 3
    property real radius: 0
    // `paper`: cream instead of dot glass (the todo and its strip form).
    property bool paper: false
    // false: the glass without its dots (a pane frame draws its own).
    property bool dots: true
    // The rim's gradient runs across (90°) in the strip forms.
    property bool across: false
    readonly property real lean: slant ? Math.round(height * 0.1763) : 0
    readonly property alias surface: surface
    readonly property alias inside: inside
    readonly property int cols: surface.cols
    readonly property int rows: surface.rows
    default property alias content: surface.content

    // The glass's box inside the rim, px: the rim is `rim` thick across
    // its slanted sides too.
    readonly property real gx: lean * rim / Math.max(1, height) + rim * 1.015
    readonly property real gw: width - gx * 2
    readonly property real gh: height - rim * 2
    readonly property real glean: lean * gh / Math.max(1, height)

    function leftAt(y: real): real {
        return rim * 1.015 + lean * (1 - y / height);
    }
    function rightAt(y: real): real {
        return width - rim * 1.015 - lean * (y / height);
    }
    // A parallelogram, its box at (x, y) w x h, its top edge pushed right by
    // s, in units of k px.
    function path(x: real, y: real, w: real, h: real, s: real, k: real): string {
        const f = v => (v / k).toFixed(2);
        return "M " + f(x + s) + " " + f(y) + " L " + f(x + w) + " " + f(y) + " L " + f(x + w - s) + " " + f(y + h) + " L " + f(x) + " " + f(y + h) + " Z";
    }

    // The upright rim (the slanted one is drawn last, over the glass).
    Rectangle {
        visible: !plate.slant
        anchors.fill: parent
        radius: plate.radius
        gradient: Gradient {
            orientation: plate.across ? Gradient.Horizontal : Gradient.Vertical
            GradientStop {
                position: 0
                color: Ink.yellow
            }
            GradientStop {
                position: 0.45
                color: Ink.pink
            }
            GradientStop {
                position: 1
                color: Ink.blue
            }
        }
        // 135°: a second, horizontal pass laid over at half strength.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            opacity: 0.5
            gradient: Gradient {
                orientation: plate.across ? Gradient.Vertical : Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: Ink.yellow
                }
                GradientStop {
                    position: 0.45
                    color: Ink.pink
                }
                GradientStop {
                    position: 1
                    color: Ink.blue
                }
            }
        }
    }

    // The glass under the dots (and the paper).
    Shape {
        id: glassShape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: plate.slant
        ShapePath {
            strokeWidth: -1
            fillColor: plate.paper ? Ink.paper : Ink.glass
            PathSvg {
                path: plate.slant ? plate.path(plate.gx, plate.rim, plate.gw, plate.gh, plate.glean, 1) : ""
            }
        }
    }
    Rectangle {
        visible: !plate.slant
        x: plate.rim
        y: plate.rim
        width: plate.width - plate.rim * 2
        height: plate.height - plate.rim * 2
        radius: Math.max(0, plate.radius - plate.rim)
        color: plate.paper ? Ink.paper : Ink.glass
    }

    DotSurface {
        id: surface
        visible: !plate.paper && plate.dots
        x: plate.rim
        y: plate.rim
        cols: Math.max(1, Math.floor((plate.width - plate.rim * 2) / Tokens.pitch))
        rows: Math.max(1, Math.floor((plate.height - plate.rim * 2) / Tokens.pitch))
        // Half a dot in from each slanted side, so no dot reaches past the rim.
        shape: plate.slant ? plate.path(plate.gx - plate.rim + Tokens.pitch * 0.5, 0, plate.gw - Tokens.pitch, plate.gh, plate.glean, Tokens.pitch) : ""
    }

    // Crisp parts cut to the glass.
    Item {
        id: inside
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: cut
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0.2
        }
    }
    Item {
        id: cut
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillColor: "white"
                PathSvg {
                    path: plate.slant ? plate.path(plate.gx, plate.rim, plate.gw, plate.gh, plate.glean, 1) : ""
                }
            }
        }
        Rectangle {
            visible: !plate.slant
            x: plate.rim
            y: plate.rim
            width: plate.width - plate.rim * 2
            height: plate.height - plate.rim * 2
            radius: Math.max(0, plate.radius - plate.rim)
        }
    }
    // The slanted rim, a ring drawn over the glass: its smooth inner edge
    // hides the dots' staircase along the slant.
    Shape {
        visible: plate.slant
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillRule: ShapePath.OddEvenFill
            fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: plate.across ? plate.width : plate.width
                y2: plate.across ? 0 : plate.height
                GradientStop {
                    position: 0
                    color: Ink.yellow
                }
                GradientStop {
                    position: 0.4
                    color: Ink.pink
                }
                GradientStop {
                    position: 1
                    color: Ink.blue
                }
            }
            PathSvg {
                path: plate.slant ? plate.path(0, 0, plate.width, plate.height, plate.lean, 1) + " " + plate.path(plate.gx, plate.rim, plate.gw, plate.gh, plate.glean, 1) : ""
            }
        }
    }
}
