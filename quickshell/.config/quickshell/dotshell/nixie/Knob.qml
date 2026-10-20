import QtQuick
import qs.tokyo as T

// A round brass transport button, crisp: polished brass lit from the top
// left, its icon (prev, next, play, pause) in dark brown. A click fires
// tap() (and runs `action`).
//   Knob { width: 30; height: 30; glyph: "pause"; onTap: Media.toggle() }
Item {
    id: knob

    property string glyph: "play"
    property string action: ""
    signal tap

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 2
        radius: width / 2
        color: Ink.c(Qt.rgba(0, 0, 0, 0.45), Qt.rgba(90 / 255, 50 / 255, 20 / 255, 0.2))
    }
    Rectangle {
        id: disc
        width: parent.width
        height: parent.height
        y: hit.pressed ? 1 : 0
        radius: width / 2
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Ink.brassHi
            }
            GradientStop {
                position: 0.55
                color: Ink.c("#c99a52", "#c99a52")
            }
            GradientStop {
                position: 1
                color: Ink.brassLo
            }
        }
        Rectangle {
            x: parent.width * 0.18
            y: parent.height * 0.1
            width: parent.width * 0.44
            height: parent.height * 0.3
            radius: height / 2
            color: Qt.rgba(1, 1, 1, hit.containsMouse ? 0.32 : 0.2)
        }
        Canvas {
            id: icon
            anchors.centerIn: parent
            width: Math.round(knob.width * 0.36)
            height: width
            readonly property string sig: knob.glyph + width
            onSigChanged: requestPaint()
            onPaint: {
                const g = getContext("2d");
                g.reset();
                g.fillStyle = String(Ink.c("#3a1d0e", "#3a1d0e"));
                const s = width / 16;
                g.scale(s, s);
                g.beginPath();
                if (knob.glyph === "pause") {
                    g.rect(2, 0, 4, 16);
                    g.rect(10, 0, 4, 16);
                } else if (knob.glyph === "prev") {
                    g.rect(0, 2, 3, 12);
                    g.moveTo(15, 2); g.lineTo(4, 8); g.lineTo(15, 14);
                } else if (knob.glyph === "next") {
                    g.moveTo(1, 2); g.lineTo(12, 8); g.lineTo(1, 14);
                    g.rect(13, 2, 3, 12);
                } else {
                    g.moveTo(3, 0); g.lineTo(15, 8); g.lineTo(3, 16);
                }
                g.closePath();
                g.fill();
            }
        }
    }
    T.Hit {
        id: hit
        anchors.fill: parent
        action: knob.action
        onTap: knob.tap()
    }
}
