import QtQuick

// The honeycomb mesh behind a tube's digit: thin lines at ±60°, `step` px
// apart, in a faint warm tint. Crisp.
Canvas {
    id: mesh

    property real step: 5
    property color tint: Ink.mesh

    antialiasing: true
    readonly property string sig: [width, height, step, tint].join("|")
    onSigChanged: requestPaint()
    onPaint: {
        const g = getContext("2d");
        g.reset();
        g.strokeStyle = String(tint);
        g.lineWidth = 1;
        const w = width, h = height, k = Math.tan(Math.PI / 3), s = step / Math.sin(Math.PI / 3);
        g.beginPath();
        for (let x = -h / k; x < w + h / k; x += s) {
            g.moveTo(x, h);
            g.lineTo(x + h / k, 0);
            g.moveTo(x, 0);
            g.lineTo(x + h / k, h);
        }
        g.stroke();
    }
}
