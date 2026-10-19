import QtQuick
import QtQuick.Effects

// The analog clock on the sky glass (the design's Clock): a white dial
// going sky blue at its rim, in a white ring, twelve navy ticks (the
// quarters heavy), a navy hour hand, a blue minute hand, a green second
// hand and hub, and the gloss over its top. Crisp.
//   Clockface { width: 118; height: 118; time: new Date() }
Item {
    id: dial

    property date time: new Date()
    readonly property real s: width / 132

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Ink.c("white", "#1f3d5f")
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Ink.shade(0.4)
            shadowBlur: 0.35
            blurMax: 12
            shadowVerticalOffset: 3
            shadowHorizontalOffset: 0
        }
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: 4 * dial.s
        radius: width / 2
        color: Ink.plate2
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: 5 * dial.s
        radius: width / 2
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Ink.c("white", "#1f3d5f")
            }
            GradientStop {
                position: 0.62
                color: Ink.pale
            }
            GradientStop {
                position: 1
                color: Ink.sky
            }
        }
    }

    Canvas {
        id: face
        anchors.fill: parent
        antialiasing: true
        onPaint: {
            const g = getContext("2d");
            const c = width / 2, k = dial.s;
            g.reset();
            g.lineCap = "round";
            g.strokeStyle = Ink.navy;
            for (let i = 0; i < 12; i++) {
                const a = i * Math.PI / 6, q = i % 3 === 0;
                g.lineWidth = (q ? 3 : 1.5) * k;
                g.beginPath();
                g.moveTo(c + Math.sin(a) * 56 * k, c - Math.cos(a) * 56 * k);
                g.lineTo(c + Math.sin(a) * (q ? 46 : 50) * k, c - Math.cos(a) * (q ? 46 : 50) * k);
                g.stroke();
            }
            const t = dial.time;
            const hand = (turn, len, w, col) => {
                const a = turn * Math.PI * 2;
                g.lineWidth = w * k;
                g.strokeStyle = col;
                g.beginPath();
                g.moveTo(c, c);
                g.lineTo(c + Math.sin(a) * len * k, c - Math.cos(a) * len * k);
                g.stroke();
            };
            hand((t.getHours() % 12 + t.getMinutes() / 60) / 12, 30, 5, Ink.navy);
            hand((t.getMinutes() + t.getSeconds() / 60) / 60, 44, 3.5, Ink.blue);
            hand(t.getSeconds() / 60, 48, 1.5, Ink.green);
            g.fillStyle = Ink.green;
            g.beginPath();
            g.arc(c, c, 5 * k, 0, Math.PI * 2);
            g.fill();
        }
        Connections {
            target: dial
            function onTimeChanged() {
                face.requestPaint();
            }
        }
    }

    // The gloss.
    Rectangle {
        x: 14 * dial.s
        y: 6 * dial.s
        width: parent.width - 28 * dial.s
        height: 54 * dial.s
        topLeftRadius: 60 * dial.s
        topRightRadius: 60 * dial.s
        bottomLeftRadius: 40 * dial.s
        bottomRightRadius: 40 * dial.s
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Ink.gloss(0.9)
            }
            GradientStop {
                position: 1
                color: Ink.gloss(0)
            }
        }
    }
}
