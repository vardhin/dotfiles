import QtQuick

// A history as dot columns (1 px = 1 dot): the newest at the right, each
// `bar` dots wide with a `gap`; those at or under `warn` take `low`, the
// ones where it rose take `up` when set (the battery's charge, paler).
//   Bars { width: 50; height: 20; values: ctx.cpuHist }
Canvas {
    id: bars

    property var values: []
    property color color: Ink.orange
    property color up: "transparent"
    property color low: color
    property real warn: -1
    property int bar: 2
    property int gap: 1
    readonly property int count: Math.max(1, Math.floor((width + gap) / (bar + gap)))
    readonly property var shown: {
        const v = values ?? [];
        if (v.length <= count)
            return v;
        const k = Math.ceil(v.length / count);
        return v.filter((_, i) => (v.length - 1 - i) % k === 0).slice(-count);
    }

    antialiasing: false
    renderTarget: Canvas.Image
    readonly property string sig: [width, height, shown.join(), color, up, low, warn, bar, gap].join("|")
    onSigChanged: requestPaint()
    onPaint: {
        const c = getContext("2d");
        c.reset();
        const h = Math.floor(height), s = shown;
        const x0 = Math.floor(width) - s.length * (bar + gap) + gap;
        for (let i = 0; i < s.length; i++) {
            const v = Math.max(0, Math.min(1, s[i]));
            const rising = up.a > 0 && i > 0 && s[i] > s[i - 1] + 0.001;
            c.fillStyle = String(rising ? up : v <= warn ? low : color);
            const lit = Math.max(1, Math.round(v * h));
            c.fillRect(x0 + i * (bar + gap), h - lit, bar, lit);
        }
    }
}
