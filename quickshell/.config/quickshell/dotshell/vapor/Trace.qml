import QtQuick

// A history as a dotted line in a screen (1 px = 1 dot): the newest at the
// right, `values` 0 .. 1 from the bottom, each step drawn as a run of dots
// `weight` thick (the design's CPU and memory lines).
//   Trace { width: 80; height: 30; values: ctx.cpuHist; color: Ink.yellow }
Canvas {
    id: line

    property var values: []
    property color color: Ink.yellow
    property int weight: 1
    property int points: 48

    antialiasing: false
    renderTarget: Canvas.Image
    readonly property var shown: (values ?? []).slice(-points)
    readonly property string sig: [width, height, shown.join(), color, weight].join("|")
    onSigChanged: requestPaint()
    onPaint: {
        const c = getContext("2d");
        c.reset();
        const v = shown, w = Math.floor(width), h = Math.floor(height);
        if (v.length < 2)
            return;
        c.fillStyle = String(color);
        const step = (w - 1) / (points - 1);
        const x0 = w - 1 - (v.length - 1) * step;
        const yOf = f => Math.round((h - weight) * (1 - Math.max(0, Math.min(1, f))));
        for (let i = 0; i < v.length - 1; i++) {
            const xa = Math.round(x0 + i * step), xb = Math.round(x0 + (i + 1) * step);
            const ya = yOf(v[i]), yb = yOf(v[i + 1]);
            const n = Math.max(1, Math.abs(xb - xa), Math.abs(yb - ya));
            for (let k = 0; k <= n; k++)
                c.fillRect(Math.round(xa + (xb - xa) * k / n), Math.round(ya + (yb - ya) * k / n), weight, weight);
        }
    }
}
