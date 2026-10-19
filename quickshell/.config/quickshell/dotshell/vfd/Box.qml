import QtQuick
import qs

// A crisp rule round a rect of dots, on a Unit's `over` layer (the design's
// inset box-shadow lines on the glass): card outlines in deep teal, the
// picked row in amber, a field in cyan. Given in dots, drawn in px.
//   Box { dx: 2; dy: 10; dw: 80; dh: 9; color: Ink.amber }
Rectangle {
    property real dx: 0
    property real dy: 0
    property real dw: 0
    property real dh: 0
    property real line: 1

    readonly property int pitch: Tokens.pitch

    x: Math.round(dx * pitch)
    y: Math.round(dy * pitch)
    width: Math.round(dw * pitch)
    height: Math.round(dh * pitch)
    color: "transparent"
    border.width: line
    border.color: Ink.deep
}
