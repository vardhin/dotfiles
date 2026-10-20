import QtQuick
import qs

// A nixie tube, crisp glass round a digit in dots: a rounded dome, warm
// glass shading, the honeycomb mesh, the unlit "8" behind, and `text` (one
// character) glowing in Nixie One dots over it. `lit` false draws the
// digit as a cold cathode (switched off); `ink` recolours it (red when
// low). `mesh` false for the strip's small tubes.
//   Tube { width: 46; height: 86; text: "2" }
Item {
    id: tube

    property string text: ""
    property bool lit: true
    property color ink: Ink.digit
    property bool mesh: true
    property bool ghost: true
    // The dome's radius; small tubes in a strip take a flatter one.
    property real dome: width / 2

    Rectangle {
        id: glass
        anchors.fill: parent
        topLeftRadius: tube.dome
        topRightRadius: tube.dome
        bottomLeftRadius: Math.max(2, tube.width * 0.09)
        bottomRightRadius: Math.max(2, tube.width * 0.09)
        border.width: 1
        border.color: Ink.tubeRim
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: Ink.tubeHi
            }
            GradientStop {
                position: 0.45
                color: Ink.tubeLo
            }
            GradientStop {
                position: 1
                color: Ink.tubeMid
            }
        }
    }
    Mesh {
        visible: tube.mesh
        x: Math.round(tube.width * 0.11)
        y: Math.round(Math.min(tube.dome * 0.4, tube.height * 0.1)) + 6
        width: tube.width - x * 2
        height: tube.height - y - 8
    }
    // The digit's height: most of the tube, like the design's 62 px in 86.
    readonly property real glyphPx: Math.min(tube.height * 0.72, tube.width * 1.35)
    Text {
        visible: tube.ghost
        anchors.centerIn: parent
        anchors.verticalCenterOffset: tube.height * 0.04
        text: "8"
        color: Ink.ghost
        font.family: Ink.family
        font.pixelSize: tube.glyphPx
    }
    Dots {
        anchors.fill: parent
        glow: tube.lit
        Word {
            readonly property int p: Tokens.pitch
            width: parent.width
            height: parent.height
            y: Math.round(tube.height * 0.04 / p)
            align: "center"
            text: tube.text
            readonly property int gd: Math.round(tube.glyphPx / p)
            dots: gd >= 13 ? gd : Math.round(gd * 0.8)
            color: tube.lit ? tube.ink : Ink.off
        }
    }
}
