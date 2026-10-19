import QtQuick

// A level as a row (or a column) of segments, the ones that are off still
// showing (the design's flex row of cells): lit from the left, or from
// the bottom when `vertical`. In dots.
//   Bar { width: 60; height: 4; value: 0.38 }
Item {
    id: bar

    property real value: 0
    property color color: Ink.cyan
    property color off: Ink.ghost
    property bool vertical: false
    // One segment and the gap after it.
    property int cell: 2
    property int gap: 1

    readonly property int span: vertical ? height : width
    readonly property int count: Math.max(1, Math.floor((span + gap) / (cell + gap)))
    readonly property int lit: Math.round(Math.max(0, Math.min(1, value)) * count)

    Repeater {
        model: bar.count
        Rectangle {
            required property int index
            x: bar.vertical ? 0 : index * (bar.cell + bar.gap)
            y: bar.vertical ? bar.height - (index + 1) * (bar.cell + bar.gap) + bar.gap : 0
            width: bar.vertical ? bar.width : bar.cell
            height: bar.vertical ? bar.cell : bar.height
            color: index < bar.lit ? bar.color : bar.off
        }
    }
}
