pragma Singleton
import QtQuick
QtObject {
    signal flipStarting
    property string era: "vfd"
    property int pitch: 3
    property real dotSize: 1
    property var current: ({ slots: ["#6fffe9", "#ff9f1c", "#9dffb0"], unlit: "#0e201c", glass: "#030706", ramp: ["#0a3c37", "#289682", "#6fffe9", "#ff9f1c"], glow: 0.65, shape: "round" })
    property var previous: current
    property real flip: 1
    property color slot0: "#6fffe9"
    property color slot1: "#ff9f1c"
    property color slot2: "#9dffb0"
    property color unlit: "#0e201c"
    property color glass: "#030706"
    property int depthBits: 16
    property string font: "DepartureMono Nerd Font"
    property int fontPx: 11
    property int charDots: 7
    property int lineDots: 13
    property int railDots: 16
    property int home: 1
}
