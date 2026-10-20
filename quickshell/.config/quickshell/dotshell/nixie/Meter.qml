import QtQuick

// A moving-coil meter, crisp: an ivory face in a brass bezel with a shade
// falling in from the top, the scale's arc and ticks in dark brown, the red
// zone at its low end, `label` under the arc, 0 and 100 at its ends, and a
// needle at `value` (0..1) on its pivot. From the battery board's dial
// (170 × 110 in the design; scales to its box).
//   Meter { width: 170; height: 110; value: 0.72; label: "% CHARGE" }
Item {
    id: meter

    property real value: 0
    property string label: "% CHARGE"
    property real zone: 0.15
    Behavior on value {
        NumberAnimation {
            duration: 600
            easing.type: Easing.OutBack
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 6
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Ink.paperHi
            }
            GradientStop {
                position: 1
                color: Ink.paperLo
            }
        }
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: 3
        radius: 4
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Ink.c(Qt.rgba(0, 0, 0, 0.22), Qt.rgba(90 / 255, 50 / 255, 20 / 255, 0.1))
            }
            GradientStop {
                position: 0.14
                color: "transparent"
            }
        }
    }
    Canvas {
        id: dial
        anchors.fill: parent
        readonly property string sig: [width, height, meter.value, meter.zone, Ink.paperInk, Ink.deep].join("|")
        onSigChanged: requestPaint()
        onPaint: {
            const g = getContext("2d");
            g.reset();
            const s = Math.min(width / 170, height / 110);
            g.translate((width - 170 * s) / 2, (height - 110 * s) / 2);
            g.scale(s, s);
            // The scale line (a wide arc over the face), the red zone on it,
            // and ticks radial from the pivot at (85, 96), 210° to 330°.
            g.lineCap = "butt";
            g.strokeStyle = String(Ink.paperInk);
            g.lineWidth = 1.5;
            const sa = Math.atan2(92 - 128, 25 - 85), se = Math.atan2(92 - 128, 145 - 85);
            g.beginPath();
            g.arc(85, 128, 70, sa, se, false);
            g.stroke();
            g.strokeStyle = String(Ink.deep);
            g.lineWidth = 5;
            g.beginPath();
            g.arc(85, 128, 70, sa, sa + (se - sa) * meter.zone * 1.6, false);
            g.stroke();
            const cx = 85, cy = 96, a = v => (210 + v * 120) * Math.PI / 180;
            g.strokeStyle = String(Ink.paperInk);
            for (let i = 0; i <= 10; i++) {
                const t = a(i / 10), major = i === 0 || i === 5 || i === 10;
                const r1 = major ? 60 : 64, r2 = 70;
                g.lineWidth = major ? 2 : 1;
                g.beginPath();
                g.moveTo(cx + Math.cos(t) * r1, cy + Math.sin(t) * r1);
                g.lineTo(cx + Math.cos(t) * r2, cy + Math.sin(t) * r2);
                g.stroke();
            }
            // The needle and its pivot.
            const t = a(Math.max(0, Math.min(1, meter.value)));
            g.strokeStyle = String(Ink.c("#1a0d06", "#1a0d06"));
            g.lineWidth = 2;
            g.beginPath();
            g.moveTo(cx, cy);
            g.lineTo(cx + Math.cos(t) * 66, cy + Math.sin(t) * 66);
            g.stroke();
            g.fillStyle = String(Ink.paperInk);
            g.beginPath();
            g.arc(cx, cy, 5, 0, Math.PI * 2);
            g.fill();
        }
    }
    // The words, crisp.
    readonly property real k: Math.min(width / 170, height / 110)
    Print {
        x: meter.width / 2 - width / 2
        y: (meter.height - 110 * meter.k) / 2 + 70 * meter.k
        width: implicitWidth
        height: 10 * meter.k
        text: meter.label
        size: Math.max(5, 6 * meter.k)
        spacing: 1
        color: Ink.paperInk
        font.bold: true
    }
    Text {
        x: (meter.width - 170 * meter.k) / 2 + 20 * meter.k
        y: (meter.height - 110 * meter.k) / 2 + 92 * meter.k
        text: "0"
        color: Ink.paperInk
        font.family: Ink.family
        font.pixelSize: Math.max(7, 11 * meter.k)
    }
    Text {
        x: (meter.width + 170 * meter.k) / 2 - 28 * meter.k
        y: (meter.height - 110 * meter.k) / 2 + 92 * meter.k
        text: "100"
        color: Ink.paperInk
        font.family: Ink.family
        font.pixelSize: Math.max(7, 11 * meter.k)
    }
    // The brass bezel over all of it.
    Rectangle {
        anchors.fill: parent
        radius: 6
        color: "transparent"
        border.width: 3
        border.color: Ink.brass
    }
}
