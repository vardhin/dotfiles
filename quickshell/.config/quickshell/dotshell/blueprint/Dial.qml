import QtQuick

// FIG. 3, the clock as a drawing, crisp: the face's circle, a dashed
// circle inside it, twelve ticks, dashed centre lines across, and the
// hands (the hour hand the heavier).
//   Dial { width: 116; height: 116; time: new Date() }
Item {
    id: dial

    property date time: new Date()
    readonly property real cx: width / 2
    readonly property real cy: height / 2
    // The design's 132 px drawing: r 58, the dashed ring r 50.
    readonly property real k: Math.min(width, height) / 132
    function circle(r: real): string {
        return `M ${cx - r} ${cy} A ${r} ${r} 0 1 0 ${cx + r} ${cy} A ${r} ${r} 0 1 0 ${cx - r} ${cy} Z`;
    }
    function hand(turn: real, len: real): string {
        const a = turn * Math.PI * 2;
        return `M ${cx} ${cy} L ${(cx + Math.sin(a) * len).toFixed(1)} ${(cy - Math.cos(a) * len).toFixed(1)}`;
    }
    readonly property string ticks: {
        let s = "";
        for (let i = 0; i < 12; i++) {
            const a = i / 12 * Math.PI * 2, r0 = 46 * k, r1 = 56 * k;
            s += `M ${(cx + Math.sin(a) * r0).toFixed(1)} ${(cy - Math.cos(a) * r0).toFixed(1)} L ${(cx + Math.sin(a) * r1).toFixed(1)} ${(cy - Math.cos(a) * r1).toFixed(1)} `;
        }
        return s;
    }

    Stroke {
        anchors.fill: parent
        path: `M ${dial.cx} 0 L ${dial.cx} ${dial.height} M 0 ${dial.cy} L ${dial.width} ${dial.cy}`
        color: Ink.line
        line: 0.75
        dash: [6, 3]
    }
    Stroke {
        anchors.fill: parent
        path: dial.circle(58 * dial.k)
        color: Ink.ink
        line: 1.5
    }
    Stroke {
        anchors.fill: parent
        path: dial.circle(50 * dial.k)
        color: Ink.line
        dash: [3, 3]
    }
    Stroke {
        anchors.fill: parent
        path: dial.ticks
        color: Ink.ink
    }
    Stroke {
        anchors.fill: parent
        path: dial.hand(((dial.time.getHours() % 12) + dial.time.getMinutes() / 60) / 12, 30 * dial.k)
        color: Ink.white
        line: 2
    }
    Stroke {
        anchors.fill: parent
        path: dial.hand((dial.time.getMinutes() + dial.time.getSeconds() / 60) / 60, 44 * dial.k)
        color: Ink.white
        line: 1.5
    }
}
