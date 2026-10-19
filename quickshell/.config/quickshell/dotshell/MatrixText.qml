import QtQuick
import "Matrix.js" as Matrix

// Dot-matrix text for DotSurface canvases (1 px = 1 dot): each character in
// its own fixed cell, like a VFD or a character LCD. `ghost` lights the cell
// dots a character leaves off, faintly, the way an unlit VFD grid still shows
// through the smoked glass; with `cells` every cell across the width shows,
// not only the ones under a character. Too long with `scroll`: the text steps
// through the cells one character at a time.
//
//   MatrixText { text: "TRACK TITLE"; width: 90; ghost: Tokens.unlit; cells: true; scroll: true }
Canvas {
    id: root

    property string text: ""
    property string font: "5x7"
    property color color: Tokens.slot0
    // The faint unlit cell dots; transparent for none.
    property color ghost: "transparent"
    // Show every cell that fits across the width, lit or not.
    property bool cells: false
    // Dots between cells.
    property int gap: 1
    // Each font dot drawn as size x size dots.
    property int size: 1
    // Of which the lit part (from the top left): less than `size` spaces the
    // font's dots apart, like a dot-matrix display's big digits.
    property int dot: size
    // left | right | center, when the text is shorter than the width.
    property string align: "left"
    // Step through the text when it does not fit.
    property bool scroll: false
    property int stepMs: 320
    // Karaoke: only the first `litChars` characters in `color`, the rest in
    // `rest` (-1: all lit).
    property int litChars: -1
    property color rest: color
    // Show the text from this character on (>= 0), instead of scrolling by
    // time: a karaoke line keeps the part being sung in view.
    property int follow: -1

    readonly property var face: Matrix.font(font)
    readonly property string shown: Matrix.fold(text)
    readonly property int advance: (face.w + gap) * size
    readonly property int capacity: Math.max(0, Math.floor((width + gap * size) / advance))
    readonly property bool running: scroll && follow < 0 && shown.length > capacity && visible
    property int offset: 0

    implicitWidth: Math.max(0, shown.length * advance - gap * size)
    implicitHeight: face.h * size
    antialiasing: false
    renderTarget: Canvas.Image

    onShownChanged: {
        offset = 0;
        requestPaint();
    }
    onColorChanged: requestPaint()
    onGhostChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onOffsetChanged: requestPaint()
    onCellsChanged: requestPaint()
    onAlignChanged: requestPaint()
    onLitCharsChanged: requestPaint()
    onRestChanged: requestPaint()
    onFollowChanged: requestPaint()
    onDotChanged: requestPaint()

    Timer {
        interval: root.stepMs
        repeat: true
        running: root.running
        onRunningChanged: if (!running) root.offset = 0
        onTriggered: root.offset = (root.offset + 1) % (root.shown.length + 3)
    }

    // The characters in view, one per cell.
    function inView(): string {
        if (follow >= 0)
            return shown.slice(follow, follow + (capacity || shown.length));
        if (!running)
            return shown.slice(0, capacity || shown.length);
        const loop = shown + "   " + shown;
        return loop.slice(offset, offset + capacity);
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const f = face, s = size, adv = advance;
        const w = inView();
        const n = cells ? capacity : w.length;
        const used = Math.max(0, n * adv - gap * s);
        const x0 = align === "right" ? width - used : align === "center" ? Math.floor((width - used) / 2) : 0;
        const lead = cells && align === "right" ? n - w.length : 0;
        const on = String(color), off = String(ghost), later = String(rest);
        const first = follow >= 0 ? follow : 0;
        const ghosting = ghost.a > 0;
        for (let i = 0; i < n; i++) {
            const ch = i - lead >= 0 ? w[i - lead] : undefined;
            const g = ch !== undefined ? f.g[ch] ?? null : null;
            const cx = x0 + i * adv;
            for (let r = 0; r < f.h; r++) {
                for (let c = 0; c < f.w; c++) {
                    const lit = g !== null && g[r][c];
                    if (!lit && !ghosting)
                        continue;
                    const sung = litChars < 0 || first + i - lead < litChars;
                    ctx.fillStyle = lit ? (sung ? on : later) : off;
                    ctx.fillRect(cx + c * s, r * s, root.dot, root.dot);
                }
            }
        }
    }
}
