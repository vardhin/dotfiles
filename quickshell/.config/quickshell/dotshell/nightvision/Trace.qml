import QtQuick

// The vitals monitor's trace, in dots (1 px = 1 dot): a flat line with a
// heartbeat blip every `beat` dots, its spike as tall as `level` (0 .. 1)
// allows, sweeping left while `running` (the System panel's VITALS · HOST).
//   Trace { width: 100; height: 20; level: ctx.cpu }
Canvas {
    id: tr

    property real level: 0.5
    property int beat: 40
    property color color: Ink.lit
    property bool running: true
    property int phase: 0

    antialiasing: false
    renderTarget: Canvas.Image
    readonly property string sig: [width, height, Math.round(level * 20), beat, color, phase].join("|")
    onSigChanged: requestPaint()

    Timer {
        interval: 120
        repeat: true
        running: tr.running && tr.visible
        onTriggered: tr.phase = (tr.phase + 1) % Math.max(1, tr.beat)
    }

    onPaint: {
        const c = getContext("2d");
        c.reset();
        const w = Math.floor(width), h = Math.floor(height);
        if (w < 4 || h < 4)
            return;
        const mid = Math.floor(h / 2);
        const amp = Math.max(3, Math.round((h / 2 - 1) * (0.45 + 0.55 * Math.max(0, Math.min(1, level)))));
        // y offsets of one blip, dot by dot: a small bump, the spike up,
        // down past the line, back.
        const blip = [0, -1, 0, 0, -amp, Math.round(amp * 0.7), 0, -1, 0];
        const ys = new Array(w).fill(0);
        for (let s = -tr.beat + (tr.beat - tr.phase) % tr.beat; s < w; s += tr.beat) {
            const at = s + Math.round(tr.beat * 0.6);
            for (let i = 0; i < blip.length; i++) {
                const x = at + i;
                if (x >= 0 && x < w)
                    ys[x] = blip[i];
            }
        }
        c.fillStyle = String(tr.color);
        for (let x = 0; x < w; x++) {
            const y0 = mid + ys[x], y1 = x > 0 ? mid + ys[x - 1] : y0;
            const top = Math.min(y0, y1), bot = Math.max(y0, y1);
            c.fillRect(x, Math.max(0, top), 1, Math.max(1, Math.min(h - 1, bot) - Math.max(0, top) + 1));
        }
    }
}
