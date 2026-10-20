import QtQuick

// A row of tubes, one per character of `text` (a ":" is the two glowing
// colon dots between them). Tubes are `tubeW` × `height`, `gap` apart.
//   Tubes { height: 86; tubeW: 46; text: "21:47" }
Row {
    id: row

    property string text: ""
    property real tubeW: height * 0.54
    property bool lit: true
    property color ink: Ink.digit
    property bool mesh: true
    property real gap: 5

    spacing: gap
    Repeater {
        model: row.text.split("")
        Item {
            id: cell
            required property string modelData
            readonly property bool colon: modelData === ":"
            width: colon ? Math.max(7, row.tubeW * 0.18) : row.tubeW
            height: row.height
            Tube {
                visible: !cell.colon
                anchors.fill: parent
                text: cell.modelData
                lit: row.lit
                ink: row.ink
                mesh: row.mesh
            }
            Column {
                visible: cell.colon
                anchors.centerIn: parent
                spacing: row.height * 0.2
                Repeater {
                    model: 2
                    Glow {
                        width: Math.max(4, Math.round(row.tubeW * 0.15))
                        height: width
                        radius: width / 2
                        color: row.lit ? Ink.orange : Ink.off
                        halo: row.lit ? width : 0
                    }
                }
            }
        }
    }
}
