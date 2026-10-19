import QtQuick
import qs
import qs.tokyo as T

// The board's lines, stacked: one Flaps row per entry of `lines` (each a
// list of [text, color] runs, or { spans, action, lit, dim }), 5x7 tiles
// when every line fits the height, else 3x5, as many lines as fit. A line
// with an `action` runs it on a click; `dim` fades it.
//   Rows { width: 300; height: 90; lines: [[["CPU  ", Ink.dim], ["38%", Ink.yellow]]] }
Item {
    id: rows

    property var lines: []
    property real gap: 5
    property int cells: 0
    // 5x7 tiles when this many lines fit (all of them by default), else 3x5.
    property int least: entries.length
    readonly property int pitch: Tokens.pitch
    readonly property var entries: lines.map(l => Array.isArray(l) ? { spans: l } : l)
    readonly property int want: Math.max(1, Math.min(least, entries.length))
    readonly property string font: want * 9 * pitch + (want - 1) * gap <= height ? "5x7" : "3x5"
    readonly property int rowH: (font === "5x7" ? 9 : 7) * pitch
    readonly property int fit: Math.max(1, Math.floor((height + gap) / (rowH + gap)))
    readonly property int tiles: cells > 0 ? cells : Math.floor(width / ((font === "5x7" ? 7 : 5) * pitch))

    Column {
        spacing: rows.gap
        Repeater {
            model: rows.entries.slice(0, rows.fit)
            Flaps {
                required property var modelData
                width: rows.width
                cells: rows.tiles
                font: rows.font
                spans: modelData.spans
                lit: modelData.lit ?? []
                page: !!modelData.page
                opacity: modelData.dim ? 0.45 : 1
                T.Hit {
                    anchors.fill: parent
                    visible: !!parent.modelData.action
                    action: parent.modelData.action ?? ""
                }
            }
        }
    }
}
