import QtQuick
import qs

// The scope's framing corners: four bright L marks at the box's corners
// (the clock's and the bodycam's reticle frame).
//   Brackets { x: 40; y: 20; width: 240; height: 80 }
Item {
    id: br

    property real len: Math.max(8, Math.min(16, Math.min(width, height) * 0.16))
    property real thick: 1.5
    property color color: Ink.bright

    Repeater {
        model: 4
        Item {
            required property int index
            readonly property bool r: index % 2 === 1
            readonly property bool b: index >= 2
            x: r ? br.width - br.len : 0
            y: b ? br.height - br.len : 0
            width: br.len
            height: br.len
            Rectangle {
                y: parent.b ? br.len - br.thick : 0
                width: br.len
                height: br.thick
                color: br.color
            }
            Rectangle {
                x: parent.r ? br.len - br.thick : 0
                width: br.thick
                height: br.len
                color: br.color
            }
        }
    }
}
