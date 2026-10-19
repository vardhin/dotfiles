import QtQuick
import Quickshell.Io
import qs
import qs.services
import qs.tokyo as T

// Battery, Blueprint: FIG. 5, the cell in section A–A. Its outline and
// nub drawn on the sheet, the charge hatched in, a dashed line at the fill
// and a dimension line under it ("◂ FILL 72% ▸"), and a title block with
// the state, the time left and the rate, all crisp. Expanded, SHEET 5:
// the percent and the state in dots, the last 24 hours as hollow dot
// columns over dashed 15 / 10 / 5 % lines, and four framed readings.
T.Face {
    id: root

    readonly property real frac: Math.max(0, Math.min(1, ctx.fraction ?? 0))
    readonly property bool charging: !!ctx.charging
    readonly property bool low: ctx.level === "bad"
    readonly property string status: low ? "LOW · PLUG IN" : charging ? "CHARGING" : String(ctx.stateWord ?? "")
    readonly property string est: {
        const t = String(ctx.time ?? "").toUpperCase().replace(":", "H");
        return !t ? "--" : charging ? t + " FULL" : t;
    }
    readonly property string rate: (charging ? "+" : ctx.stateWord === "ON BATTERY" ? "-" : "") + (ctx.watts ?? 0).toFixed(1) + " W"

    Paper {
        anchors.fill: parent
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : section
    }

    // ── Compact: FIG. 5 ─────────────────────────────────────────────
    Component {
        id: section
        Item {
            id: c
            readonly property real tableW: Math.max(130, width * 0.5)
            readonly property real cellW: Math.min(130, width - tableW - 16 - 22)
            readonly property real cellH: Math.min(56, height - 34 - 40)

            Pen {
                x: 14
                y: 10
                width: parent.width - 28
                height: 14
                text: "FIG. 5 — CELL, SECTION A–A"
            }
            Item {
                id: cell
                x: 16
                y: 34
                width: c.cellW
                height: c.cellH
                Hatch {
                    x: 1.5
                    y: 1.5
                    width: (parent.width - 3) * root.frac
                    height: parent.height - 3
                    color: root.low ? Ink.warn : Ink.hatch
                }
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 1.5
                    border.color: Ink.ink
                }
                // The nub.
                Rectangle {
                    x: parent.width - 1.5
                    y: (parent.height - height) / 2
                    width: 9.5
                    height: Math.round(parent.height * 0.4)
                    color: "transparent"
                    border.width: 1.5
                    border.color: Ink.ink
                }
                Rectangle {
                    x: parent.width - 1.5
                    y: (parent.height - height) / 2 + 1.5
                    width: 1.5
                    height: Math.round(parent.height * 0.4) - 3
                    color: Ink.paper
                }
                // The fill line.
                Stroke {
                    anchors.fill: parent
                    readonly property real at: Math.round(cell.width * root.frac) + 0.5
                    path: `M ${at} -10 L ${at} ${cell.height + 8}`
                    color: Ink.white
                    dash: [3, 2]
                }
            }
            // ◂ FILL 72% ▸
            Rectangle {
                x: cell.x
                y: cell.y + cell.height + 8
                width: cell.width
                height: 1
                color: Ink.line
                Pen {
                    y: 2
                    width: parent.width
                    height: 12
                    horizontalAlignment: Text.AlignHCenter
                    text: "◂ FILL " + (root.ctx.pct ?? 0) + "% ▸" + (root.charging ? " +" : "")
                    size: 9
                }
            }
            Table {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: c.tableW
                labelW: Math.min(54, c.tableW * 0.32)
                rows: [["STATE", root.status], ["EST", root.est], ["RATE", root.rate]]
            }
        }
    }

    // ── Expanded: SHEET 5 ───────────────────────────────────────────
    Component {
        id: board
        Item {
            id: b
            property string cycles: "--"
            Process {
                running: true
                command: ["sh", "-c", "cat /sys/class/power_supply/BAT*/cycle_count 2>/dev/null | head -1"]
                stdout: StdioCollector {
                    onStreamFinished: b.cycles = text.trim() && text.trim() !== "0" ? text.trim() : "--"
                }
            }
            readonly property var cards: [
                { name: "RATE", text: root.rate, act: "" },
                { name: "HEALTH", text: root.ctx.health || "--", act: "" },
                { name: "CYCLES", text: b.cycles, act: "" },
                { name: "PROFILE", text: Power.profileName(Power.profile), act: "power profile " + ((Power.profile + 1) % (Power.hasPerformance ? 3 : 2)) }
            ]
            readonly property int p: Tokens.pitch
            readonly property int cols: Math.floor(width / p)
            readonly property int rows: Math.floor(height / p)
            readonly property int padX: Math.ceil(16 / p)
            readonly property int pageW: cols - padX * 2
            readonly property int topY: Math.ceil(30 / p)
            readonly property int bigPx: Math.max(12, Math.min(20, Math.floor(rows * 0.18)))
            readonly property int graphY: topY + bigPx + 3
            readonly property int cardH: 16
            readonly property int cardY: rows - 9 - cardH
            readonly property int graphH: cardY - 9 - graphY
            readonly property int cardW: Math.floor((pageW - 9) / 4)

            Sheet {
                title: "SHEET 5 — DISCHARGE CURVE"
            }
            // Crisp: the axes, the warning lines and their levels, the
            // readings' frames.
            Rectangle {
                x: b.padX * b.p
                y: b.graphY * b.p
                width: 1
                height: b.graphH * b.p
                color: Ink.ink
            }
            Rectangle {
                x: b.padX * b.p
                y: (b.graphY + b.graphH) * b.p
                width: b.pageW * b.p
                height: 1
                color: Ink.ink
            }
            Repeater {
                model: [0.15, 0.10, 0.05]
                Item {
                    required property real modelData
                    x: b.padX * b.p
                    y: (b.graphY + b.graphH) * b.p - Math.round(modelData * (b.graphH - 1) * b.p)
                    width: b.pageW * b.p
                    Stroke {
                        width: parent.width
                        height: 1
                        path: `M 0 0.5 L ${width} 0.5`
                        color: Ink.white
                        dash: [3, 3]
                    }
                    Pen {
                        anchors.right: parent.right
                        y: -11
                        height: 10
                        text: Math.round(modelData * 100)
                        size: 9
                    }
                }
            }
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    x: (b.padX + index * (b.cardW + 3)) * b.p
                    y: b.cardY * b.p
                    width: b.cardW * b.p
                    height: b.cardH * b.p
                    color: "transparent"
                    border.width: 1
                    border.color: Ink.line
                }
            }

            Dots {
                anchors.fill: parent

                // 72%                                      ON BATTERY
                //                                           3:41 LEFT
                Say {
                    x: b.padX
                    y: b.topY
                    text: (root.ctx.pct ?? 0) + "%"
                    size: b.bigPx
                    color: root.low ? Ink.warn : Ink.white
                }
                Column {
                    anchors.right: parent.right
                    anchors.rightMargin: b.padX
                    y: b.topY + b.bigPx - 13
                    spacing: 3
                    Repeater {
                        model: [root.status, root.ctx.time ? (root.ctx.time + (root.charging ? " TO FULL" : " LEFT")) : ""]
                        MatrixText {
                            required property string modelData
                            anchors.right: parent.right
                            width: implicitWidth
                            height: 5
                            font: "3x5"
                            text: modelData
                            color: Ink.line
                        }
                    }
                }

                // The day, oldest on the left: pale blue where it charged.
                Bars {
                    id: graph
                    x: b.padX + 2
                    y: b.graphY + 1
                    width: b.pageW - 3
                    height: b.graphH - 2
                    values: root.ctx.hist ?? []
                    color: Ink.ink
                    up: Ink.line
                    low: Ink.warn
                    warn: 0.15
                }
                MatrixText {
                    visible: (root.ctx.hist ?? []).length < 2
                    x: b.padX + Math.round((b.pageW - width) / 2)
                    y: b.graphY + Math.round((b.graphH - 5) / 2)
                    width: implicitWidth
                    height: 5
                    font: "3x5"
                    text: "HISTORY FILLS IN EVERY 5 MIN"
                    color: Ink.line
                }
                // -24 H              -12 H              NOW
                Repeater {
                    model: [["-24 H", "left"], ["-12 H", "center"], ["NOW", "right"]]
                    MatrixText {
                        required property var modelData
                        x: b.padX
                        y: b.graphY + b.graphH + 2
                        width: b.pageW
                        height: 5
                        font: "3x5"
                        align: modelData[1]
                        text: modelData[0]
                        color: Ink.line
                    }
                }
                // RATE   HEALTH   CYCLES   PROFILE
                Repeater {
                    model: b.cards
                    Item {
                        required property var modelData
                        required property int index
                        x: b.padX + index * (b.cardW + 3)
                        y: b.cardY
                        width: b.cardW
                        height: b.cardH
                        MatrixText {
                            x: 3
                            y: 2
                            height: 5
                            font: "3x5"
                            text: modelData.name
                            color: Ink.line
                        }
                        MatrixText {
                            x: 3
                            y: 8
                            width: parent.width - 5
                            height: 7
                            font: modelData.text.length * 6 <= parent.width - 5 ? "5x7" : "3x5"
                            scroll: true
                            text: modelData.text
                            color: Ink.white
                        }
                        T.Hit {
                            anchors.fill: parent
                            visible: modelData.act !== ""
                            action: modelData.act
                        }
                    }
                }
                MatrixText {
                    x: b.padX
                    y: b.rows - 7
                    width: b.pageW
                    height: 5
                    font: "3x5"
                    scroll: true
                    text: "NOTE: DASHED LINES MARK THE 15 / 10 / 5 % WARNING LEVELS."
                    color: Ink.line
                }
            }
        }
    }
}
