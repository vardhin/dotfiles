import QtQuick
import Quickshell.Io
import qs
import qs.services
import qs.tokyo as T

// Battery, Split-Flap: the POWER board. BATTERY and the percent, the time
// left in yellow, and the state (ON BATTERY, CHARGING, FULL) on rows of
// flap tiles; low, the board goes red and says PLUG IN NOW. Expanded,
// POWER · 24 HOURS: the percent big in dots, the state and time in
// yellow, the last day as off-white dot columns on a dot screen (yellow
// where it charged, orange under 15 %, the alarms as orange rules), and
// RATE, HEALTH, CYCLES and PROFILE on dot screens (a click on PROFILE
// steps the power profile).
T.Face {
    id: root

    readonly property real frac: Math.max(0, Math.min(1, ctx.fraction ?? 0))
    readonly property bool charging: !!ctx.charging
    readonly property bool low: ctx.level === "bad"
    readonly property string pct: (ctx.pct ?? 0) + "%"
    readonly property string stateWord: low ? "LOW" : charging ? "CHARGING" : String(ctx.stateWord ?? "").toUpperCase()
    readonly property string remain: ctx.time ? ctx.time + (charging ? " TO FULL" : " LEFT") : ""
    readonly property string rate: (charging ? "+" : ctx.stateWord === "ON BATTERY" ? "-" : "") + (ctx.watts ?? 0).toFixed(1) + " W"

    Housing {
        id: box
        anchors.fill: parent
        label: root.big ? "POWER · 24 HOURS" : "POWER"
        status: root.big ? "LIVE" : root.stateWord
        statusInk: root.low ? Ink.red : root.charging ? Ink.yellow : Ink.label
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : rows
    }

    // ── Compact ─────────────────────────────────────────────────────
    Component {
        id: rows
        Item {
            Rows {
                x: 14
                y: box.bodyY + 2
                width: parent.width - 28
                height: parent.height - y - 10
                lines: root.low ? [
                    [["BATTERY ", Ink.red], [root.pct, Ink.red]],
                    [[root.remain, Ink.yellow]],
                    [["PLUG IN NOW", Ink.red]]
                ] : [
                    [["BATTERY ", Ink.white], [root.pct, Ink.white]],
                    [[root.remain || (root.charging ? "CHARGING" : "--:--"), Ink.yellow]],
                    [[root.stateWord, Ink.dim]]
                ]
            }
        }
    }

    // ── Expanded: the last day ──────────────────────────────────────
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
                { name: "PROFILE", text: Power.profileName(Power.profile).toUpperCase(), act: "power profile " + ((Power.profile + 1) % (Power.hasPerformance ? 3 : 2)) }
            ]
            readonly property int p: Tokens.pitch
            readonly property real padX: 14
            readonly property real bigY: box.bodyY + 4
            readonly property real bigH: Math.max(13 * p, Math.min(64, height * 0.14))
            // The state and time beside the percent: 5x7 when both rows fit.
            readonly property string sideFont: bigH / p >= 17 ? "5x7" : "3x5"
            readonly property real graphY: bigY + bigH + 10
            readonly property real footY: height - 12 - 5 * p
            readonly property real cardH: Math.max(16 * p, Math.min(60, height * 0.13))
            readonly property real cardY: footY - 10 - cardH
            readonly property real labY: cardY - 10 - 5 * p
            readonly property real graphH: labY - 6 - graphY
            readonly property real cardW: (width - padX * 2 - 30) / 4

            Glass {
                id: graph
                x: b.padX
                y: b.graphY
                width: b.width - b.padX * 2
                height: b.graphH
                Cols {
                    x: 1
                    y: 1
                    width: graph.cols - 2
                    height: graph.rows - 2
                    values: root.ctx.hist ?? []
                    up: Ink.yellow
                    low: Ink.orange
                    warn: 0.15
                }
                MatrixText {
                    visible: (root.ctx.hist ?? []).length < 2
                    anchors.centerIn: parent
                    width: implicitWidth
                    height: 5
                    font: "3x5"
                    text: "HISTORY FILLS IN EVERY 5 MIN"
                    color: Ink.dim
                }
            }
            // 15 / 10 / 5 % alarms, orange rules across the screen.
            Repeater {
                model: [0.15, 0.10, 0.05]
                Rectangle {
                    required property real modelData
                    x: graph.x
                    y: graph.y + graph.height - 2 - Math.round(modelData * (graph.height - 4))
                    width: graph.width
                    height: 1
                    color: Ink.orange
                    opacity: 0.8
                }
            }
            Repeater {
                model: b.cards
                Glass {
                    id: card
                    required property var modelData
                    required property int index
                    x: b.padX + index * (b.cardW + 10)
                    y: b.cardY
                    width: b.cardW
                    height: b.cardH
                    MatrixText {
                        x: 2
                        y: 2
                        height: 5
                        font: "3x5"
                        text: card.modelData.name
                        color: Ink.label
                    }
                    MatrixText {
                        x: 2
                        width: card.cols - 4
                        font: card.modelData.text.length * 6 <= width ? "5x7" : "3x5"
                        y: card.rows - (font === "5x7" ? 9 : 7)
                        height: font === "5x7" ? 7 : 5
                        scroll: true
                        text: card.modelData.text
                        color: Ink.white
                    }
                    Rectangle {
                        y: Math.floor(card.height / 2)
                        width: card.width
                        height: 1
                        color: Ink.seam
                    }
                    T.Hit {
                        anchors.fill: parent
                        visible: card.modelData.act !== ""
                        action: card.modelData.act
                    }
                }
            }

            Dots {
                id: ink
                anchors.fill: parent

                // 72%                                  ON BATTERY
                //                                       3:41 LEFT
                Say {
                    x: Math.ceil(b.padX / b.p)
                    y: Math.round(b.bigY / b.p)
                    height: Math.floor(b.bigH / b.p)
                    verticalAlignment: Text.AlignVCenter
                    text: root.pct
                    size: Math.floor(b.bigH / b.p * 1.25)
                    color: root.low ? Ink.red : Ink.white
                }
                Column {
                    x: ink.cols - Math.ceil(b.padX / b.p) - width
                    y: Math.round((b.bigY + b.bigH) / b.p) - height
                    spacing: 2
                    Repeater {
                        model: [root.low ? "LOW - PLUG IN" : root.stateWord, root.remain]
                        MatrixText {
                            required property string modelData
                            anchors.right: parent.right
                            width: implicitWidth
                            font: b.sideFont
                            height: font === "5x7" ? 7 : 5
                            text: modelData
                            color: root.low ? Ink.red : Ink.yellow
                        }
                    }
                }
                // -24 H              -12 H              NOW
                Repeater {
                    model: [["-24 H", "left"], ["-12 H", "center"], ["NOW", "right"]]
                    MatrixText {
                        required property var modelData
                        x: Math.ceil(b.padX / b.p)
                        y: Math.round(b.labY / b.p)
                        width: ink.cols - x * 2
                        height: 5
                        font: "3x5"
                        align: modelData[1]
                        text: modelData[0]
                        color: Ink.label
                    }
                }
                MatrixText {
                    x: Math.ceil(b.padX / b.p)
                    y: Math.floor(b.footY / b.p)
                    width: ink.cols - x * 2
                    height: 5
                    font: "3x5"
                    scroll: true
                    text: "WARNS AT 15 · 10 · 5% · PROFILE STEPS ON A CLICK"
                    color: Ink.label
                }
            }
        }
    }
}
