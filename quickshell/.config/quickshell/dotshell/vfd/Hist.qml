import QtQuick

// A history as columns of stacked dot cells (the design's striped bars,
// lit `cell` dots, then a dark one): the last values that fit, newest on
// the right. In dots.
//   Hist { width: 50; height: 14; values: ctx.cpuHist }
Canvas {
    id: hist

    property var values: []
    property color color: Ink.cyan
    property int barW: 2
    property int gap: 1
    property int cell: 2

    readonly property int count: Math.max(1, Math.floor((width + gap) / (barW + gap)))
    readonly property var shown: {
        const v = values ?? [];
        const s = v.slice(-count);
        return Array(Math.max(0, count - s.length)).fill(0).concat(s);
    }

    antialiasing: false
    renderTarget: Canvas.Image
    onShownChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const c = getContext("2d");
        c.reset();
        c.fillStyle = String(color);
        const h = Math.floor(height);
        for (let i = 0; i < shown.length; i++) {
            const lit = Math.max(1, Math.round(Math.max(0, Math.min(1, shown[i])) * h));
            const x = i * (barW + gap);
            for (let k = 0; k < lit; k++) {
                if ((k + 1) % (cell + 1) === 0)
                    continue;
                c.fillRect(x, h - 1 - k, barW, 1);
            }
        }
    }
}
