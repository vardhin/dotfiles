import QtQuick
import qs.tokyo as T

// A board key, crisp: a flap-dark block (lighter top half, darker bottom
// one, a black lip under it), its word in Silkscreen. `on` is yellow,
// `tone` another fill (the red REC/STOP, the orange VID VIS LYR); held
// down it sinks onto its lip. `glyph` draws a transport icon instead
// (prev, next, play, pause). A click runs `action` and fires tap().
//   Key { width: 70; height: 22; text: "1 H"; on: true; action: "caffeine for 60" }
Item {
    id: key

    property string text: ""
    property string glyph: ""
    property bool on: false
    property color tone: "transparent"
    property string action: ""
    property real textPx: 8
    readonly property bool toned: tone.a > 0
    readonly property color face: on ? Ink.yellow : toned ? tone : Ink.upper
    readonly property color low: on ? Ink.yellowDeep : toned ? Qt.darker(tone, 1.12) : Ink.lower
    readonly property color ink: on || toned ? Ink.housing : Ink.dim
    signal tap

    opacity: enabled ? 1 : 0.45

    Rectangle {
        anchors.fill: parent
        color: Ink.seam
        radius: 2
    }
    Item {
        anchors.fill: parent
        anchors.bottomMargin: hit.pressed ? 0 : 2
        anchors.topMargin: hit.pressed ? 2 : 0
        Rectangle {
            anchors.fill: parent
            radius: 2
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: key.face
                }
                GradientStop {
                    position: 0.5
                    color: key.face
                }
                GradientStop {
                    position: 0.5
                    color: key.low
                }
                GradientStop {
                    position: 1
                    color: key.low
                }
            }
        }
        Rectangle {
            visible: hit.containsMouse
            anchors.fill: parent
            radius: 2
            color: Qt.rgba(1, 1, 1, 0.06)
        }
        Print {
            visible: key.glyph === ""
            anchors.fill: parent
            anchors.leftMargin: 3
            anchors.rightMargin: 3
            horizontalAlignment: Text.AlignHCenter
            text: key.text
            size: key.textPx
            spacing: 1
            color: key.ink
        }
        // Transport icons, crisp.
        Item {
            visible: key.glyph !== ""
            anchors.centerIn: parent
            width: 12
            height: 12
            readonly property color ink: key.on || key.toned ? Ink.housing : Ink.white
            Rectangle {
                visible: key.glyph === "pause"
                x: 2
                width: 3
                height: 12
                color: parent.ink
            }
            Rectangle {
                visible: key.glyph === "pause"
                x: 7
                width: 3
                height: 12
                color: parent.ink
            }
            Rectangle {
                visible: key.glyph === "prev"
                x: 1
                y: 1
                width: 2
                height: 10
                color: parent.ink
            }
            Rectangle {
                visible: key.glyph === "next"
                x: 9
                y: 1
                width: 2
                height: 10
                color: parent.ink
            }
            Canvas {
                visible: key.glyph === "play" || key.glyph === "prev" || key.glyph === "next"
                anchors.fill: parent
                readonly property string sig: key.glyph + parent.ink
                onSigChanged: requestPaint()
                onPaint: {
                    const g = getContext("2d");
                    g.reset();
                    g.fillStyle = String(parent.ink);
                    g.beginPath();
                    if (key.glyph === "play") {
                        g.moveTo(2, 0); g.lineTo(11, 6); g.lineTo(2, 12);
                    } else if (key.glyph === "prev") {
                        g.moveTo(11, 1); g.lineTo(3, 6); g.lineTo(11, 11);
                    } else {
                        g.moveTo(1, 1); g.lineTo(9, 6); g.lineTo(1, 11);
                    }
                    g.closePath();
                    g.fill();
                }
            }
        }
    }
    T.Hit {
        id: hit
        anchors.fill: parent
        action: key.action
        onTap: key.tap()
    }
}
