import QtQuick
import QtQuick.Shapes
import qs

// A Night Vision eyepiece: the green dot screen (the design's `.pn`, the
// era's own DotSurface) cut to a rounded outline and darkened toward its
// rim. Compact, an elliptic pill (the boards' `border-radius: 80px / 70px`);
// `crt`, the expanded boards' squircle (`120px / 60px`) with its dark green
// inner ring. Children are authored in dots on the glass; `over` holds
// crisp parts in px (rules, brackets, keys), drawn above the darkening.
//   Scope { anchors.fill: parent; MatrixText { x: 12; y: 4; text: "VITALS" } }
Item {
    id: scope

    property bool crt: false
    // How dark the rim goes, 0 .. 1 (a pane keeps it lighter).
    property real dark: 1
    // false: the outline and its darkening only (a pane draws its own dots).
    property bool dots: true
    // The corners' radii, px; a pane sets its own (`cornerX`/`cornerY`).
    property real cornerX: 0
    property real cornerY: 0
    readonly property real rx: cornerX > 0 ? cornerX : crt ? Math.min(width * 0.17, 100) : Math.min(width / 2, height * 0.55)
    readonly property real ry: cornerY > 0 ? cornerY : crt ? Math.min(height * 0.14, 50) : height * 0.47
    readonly property alias surface: surface
    readonly property alias over: over
    readonly property int cols: surface.cols
    readonly property int rows: surface.rows
    default property alias content: surface.content

    // Dots on the glass <-> px in the scope (the dot grid sits centred).
    function px(d: real): real {
        return surface.x + d * Tokens.pitch;
    }
    function py(d: real): real {
        return surface.y + d * Tokens.pitch;
    }
    function dx(p: real): int {
        return Math.round((p - surface.x) / Tokens.pitch);
    }
    function dy(p: real): int {
        return Math.round((p - surface.y) / Tokens.pitch);
    }

    // The outline: a rect at (x, y) w x h with elliptic corners rx/ry, in
    // units of k px.
    function path(x: real, y: real, w: real, h: real, a: real, b: real, k: real): string {
        const f = v => (v / k).toFixed(2);
        a = Math.min(a, w / 2);
        b = Math.min(b, h / 2);
        const arc = (ex, ey) => " A " + f(a) + " " + f(b) + " 0 0 1 " + f(ex) + " " + f(ey);
        return "M " + f(x + a) + " " + f(y) + " L " + f(x + w - a) + " " + f(y) + arc(x + w, y + b) + " L " + f(x + w) + " " + f(y + h - b) + arc(x + w - a, y + h) + " L " + f(x + a) + " " + f(y + h) + arc(x, y + h - b) + " L " + f(x) + " " + f(y + b) + arc(x + a, y) + " Z";
    }

    // The glass, smooth along the outline (the dots are cut by whole dots).
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillColor: Ink.glass
            PathSvg {
                path: scope.path(0, 0, scope.width, scope.height, scope.rx, scope.ry, 1)
            }
        }
    }

    DotSurface {
        id: surface
        visible: scope.dots
        cols: Math.max(1, Math.floor(scope.width / Tokens.pitch))
        rows: Math.max(1, Math.floor(scope.height / Tokens.pitch))
        x: Math.floor((scope.width - cols * Tokens.pitch) / 2)
        y: Math.floor((scope.height - rows * Tokens.pitch) / 2)
        // Half a dot in all round, so no dot pokes past the curve.
        shape: scope.path(Tokens.pitch * 0.5 - x, Tokens.pitch * 0.5 - y, scope.width - Tokens.pitch, scope.height - Tokens.pitch, scope.rx, scope.ry, Tokens.pitch)
    }

    // The darkening toward the rim (radial-gradient(ellipse 60% 70%, a
    // faint green bloom → 75% black)), cut to the outline.
    Canvas {
        id: vignette
        anchors.fill: parent
        antialiasing: true
        renderTarget: Canvas.Image
        readonly property string sig: [width, height, scope.rx, scope.ry, scope.dark, Ink.shade, Ink.bloom].join("|")
        onSigChanged: requestPaint()
        onPaint: {
            const c = getContext("2d");
            c.reset();
            const w = width, h = height;
            if (w < 2 || h < 2)
                return;
            const a = Math.min(scope.rx, w / 2), b = Math.min(scope.ry, h / 2), k = 0.5523;
            c.beginPath();
            c.moveTo(a, 0);
            c.lineTo(w - a, 0);
            c.bezierCurveTo(w - a + a * k, 0, w, b - b * k, w, b);
            c.lineTo(w, h - b);
            c.bezierCurveTo(w, h - b + b * k, w - a + a * k, h, w - a, h);
            c.lineTo(a, h);
            c.bezierCurveTo(a - a * k, h, 0, h - b + b * k, 0, h - b);
            c.lineTo(0, b);
            c.bezierCurveTo(0, b - b * k, a - a * k, 0, a, 0);
            c.closePath();
            c.clip();
            // An ellipse 60% x 70% of the box: a circle scaled.
            const R = 0.7 * h, sx = (0.6 * w) / R;
            c.save();
            c.translate(w / 2, h / 2);
            c.scale(sx, 1);
            const g = c.createRadialGradient(0, 0, 0, 0, 0, R);
            const s = Ink.shade, m = Ink.bloom;
            g.addColorStop(0, Qt.rgba(m.r, m.g, m.b, m.a));
            g.addColorStop(1, Qt.rgba(s.r, s.g, s.b, s.a * scope.dark));
            c.fillStyle = g;
            c.fillRect(-w / sx, -h, 2 * w / sx, 2 * h);
            c.restore();
        }
    }

    // The CRT's inner ring (box-shadow: inset 0 0 0 2px).
    Shape {
        visible: scope.crt
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 2
            strokeColor: Ink.deep
            fillColor: "transparent"
            PathSvg {
                path: scope.path(1, 1, scope.width - 2, scope.height - 2, scope.rx - 1, scope.ry - 1, 1)
            }
        }
    }

    Item {
        id: over
        anchors.fill: parent
    }
}
