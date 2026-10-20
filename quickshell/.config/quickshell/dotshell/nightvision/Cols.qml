import QtQuick

// A history as dot columns (1 px = 1 dot), the newest at the right, each
// `w` dots wide with a `gap`, lit green (the expanded boards' CPU/MEM/TEMP
// and battery charts); `up` paints the ones where it rose (the battery's
// charging, dimmer), `low` those at or under `warn`.
//   Cols { width: 60; height: 18; values: ctx.cpuHist }
Canvas {
    id: cols

    property var values: []
    property int w: 1
    property int gap: 1
    property color tone: Ink.lit
    property var up: null
    property var low: null
    property real warn: -1
    readonly property int count: Math.max(1, Math.floor((width + gap) / (w + gap)))
    readonly property var shown: {
        const v = values ?? [];
        if (v.length <= count)
            return v;
        const k = Math.ceil(v.length / count);
        return v.filter((_, i) => (v.length - 1 - i) % k === 0).slice(-count);
    }

    antialiasing: false
    renderTarget: Canvas.Image
    readonly property string sig: [width, height, shown.join(), tone, up, low, warn, w, gap].join("|")
    onSigChanged: requestPaint()
    onPaint: {
        const c = getContext("2d");
        c.reset();
        const h = Math.floor(height), s = shown;
        const x0 = Math.floor(width) - s.length * (w + gap) + gap;
        for (let i = 0; i < s.length; i++) {
            const v = Math.max(0, Math.min(1, Number(s[i]) || 0));
            const lit = Math.max(1, Math.round(v * h));
            const rising = up !== null && i > 0 && s[i] > s[i - 1] + 0.001;
            c.fillStyle = String(rising ? up : low !== null && v <= warn ? low : tone);
            c.fillRect(x0 + i * (w + gap), h - lit, w, lit);
        }
    }
}
