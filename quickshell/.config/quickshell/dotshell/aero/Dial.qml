import QtQuick
import QtQuick.Effects

// A round instrument dial on the sky glass (the design's System gauges):
// dark glass in an ice-white ring, eleven ticks round a 270 degree sweep
// (the last three hot), an orange needle, a pale hub, the reading in
// Varela Round under the hub, and the gloss across its top. Crisp.
//   Dial { width: 106; height: 106; value: 0.38; text: "CPU 38%" }
Item {
    id: dial

    property real value: 0
    property string text: ""

    readonly property real s: width / 124

    // Body: the dark glass, its shadow, and the white and sky rings.
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Ink.pale
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(11 / 255, 63 / 255, 128 / 255, 0.5)
            shadowBlur: 0.35
            blurMax: 12
            shadowVerticalOffset: 3
            shadowHorizontalOffset: 0
        }
    }
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Ink.ice
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: 4 * dial.s
        radius: width / 2
        color: Ink.plate2
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: 6 * dial.s
        radius: width / 2
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Ink.slate
            }
            GradientStop {
                position: 0.8
                color: Ink.night
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
            g.lineWidth = 2 * k;
            for (let i = 0; i <= 10; i++) {
                const a = (225 - i * 27) * Math.PI / 180;
                g.strokeStyle = i >= 8 ? Ink.red : Ink.pale;
                g.beginPath();
                g.moveTo(c + Math.cos(a) * 52 * k, c - Math.sin(a) * 52 * k);
                g.lineTo(c + Math.cos(a) * 44 * k, c - Math.sin(a) * 44 * k);
                g.stroke();
            }
            const a = (225 - Math.max(0, Math.min(1, dial.value)) * 270) * Math.PI / 180;
            g.lineWidth = 3 * k;
            g.lineCap = "round";
            g.strokeStyle = Ink.red;
            g.beginPath();
            g.moveTo(c, c);
            g.lineTo(c + Math.cos(a) * 42 * k, c - Math.sin(a) * 42 * k);
            g.stroke();
            g.fillStyle = Ink.pale;
            g.beginPath();
            g.arc(c, c, 6 * k, 0, Math.PI * 2);
            g.fill();
        }
        Connections {
            target: dial
            function onValueChanged() {
                face.requestPaint();
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height / 2 + 30 * dial.s - height * 0.75
        text: dial.text
        color: Ink.sky
        font.family: Ink.family
        font.pixelSize: Math.round(15 * dial.s)
    }

    // The gloss.
    Rectangle {
        x: 14 * dial.s
        y: 6 * dial.s
        width: parent.width - 28 * dial.s
        height: 48 * dial.s
        topLeftRadius: 60 * dial.s
        topRightRadius: 60 * dial.s
        bottomLeftRadius: 40 * dial.s
        bottomRightRadius: 40 * dial.s
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(1, 1, 1, 0.55)
            }
            GradientStop {
                position: 1
                color: Qt.rgba(1, 1, 1, 0)
            }
        }
    }
}
