import QtQuick

// A title block, crisp: label | value rows ruled in pale blue (the design's
// STATE / EST / RATE tables), drawn from its top left; `edge` rules its top
// and left too. `rows` is [[label, value]]; a value can be a component
// instead (`cells`: { row index: Component }).
//   Table { width: 170; labelW: 54; rows: [["STATE", "ON BATTERY"], ["EST", "3H41"]] }
Item {
    id: table

    property var rows: []
    property real labelW: 40
    property real textPx: 10
    property real rowH: Math.round(textPx + 7)
    // Bigger value text per row index ({ 0: 13 }).
    property var sizes: ({})
    property var cells: ({})
    property bool edge: true
    // Rule under the last row.
    property bool foot: false

    implicitHeight: rows.length * rowH

    Rectangle {
        visible: table.edge
        width: parent.width
        height: 1
        color: Ink.line
    }
    Rectangle {
        visible: table.edge
        width: 1
        height: table.rows.length * table.rowH
        color: Ink.line
    }
    Rectangle {
        x: table.labelW
        width: 1
        height: table.rows.length * table.rowH
        color: Ink.line
    }
    Repeater {
        model: table.rows
        Item {
            id: row
            required property var modelData
            required property int index
            y: index * table.rowH
            width: table.width
            height: table.rowH
            Rectangle {
                visible: row.index < table.rows.length - 1 || table.foot
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Ink.line
            }
            Pen {
                x: 5
                width: table.labelW - 8
                height: parent.height
                text: row.modelData[0]
                size: table.textPx
                color: Ink.line
            }
            Pen {
                visible: !table.cells[row.index]
                x: table.labelW + 5
                width: parent.width - x - 4
                height: parent.height
                text: row.modelData[1] ?? ""
                size: table.sizes[row.index] ?? table.textPx
                color: Ink.ink
            }
            Loader {
                x: table.labelW + 1
                width: parent.width - x
                height: parent.height - 1
                active: !!table.cells[row.index]
                sourceComponent: table.cells[row.index] ?? null
            }
        }
    }
}
