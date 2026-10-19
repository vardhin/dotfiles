import QtQuick

// The Windows progress bar (the design's power meter and seek bar): a
// white sunken trough and square blocks across it, violet and cyan in
// turn, as many as `value` (0 .. 1) fills. A click seeks when `seek` is
// set (fires seeked(f)). Crisp.
//   Meter { width: 300; height: 16; value: 0.72 }
Item {
    id: meter

    property real value: 0
    property bool seek: false
    property color fill: Ink.hi
    property var tones: [Ink.violet, Ink.cyan]
    signal seeked(real f)

    readonly property real block: Math.max(6, height - 4)
    readonly property int count: Math.max(1, Math.floor((width - 3) / (block + 2)))
    readonly property int lit: Math.round(Math.max(0, Math.min(1, value)) * count)

    Rectangle {
        anchors.fill: parent
        color: meter.fill
    }
    Rectangle {
        width: parent.width
        height: 1
        color: Ink.shade
    }
    Rectangle {
        width: 1
        height: parent.height
        color: Ink.shade
    }
    Row {
        x: 2
        y: 2
        spacing: 2
        Repeater {
            model: meter.lit
            Rectangle {
                required property int index
                width: meter.block
                height: meter.height - 4
                color: meter.tones[index % meter.tones.length]
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        enabled: meter.seek
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => meter.seeked(Math.max(0, Math.min(1, mouse.x / meter.width)))
    }
}
