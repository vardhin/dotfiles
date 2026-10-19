import QtQuick
import Quickshell.Io
import qs
import qs.services
import qs.tokyo as T

// Battery, Vaporwave: power_meter.exe. The cell as a dark dot screen with
// a cap, filled from the bottom in yellow (pink when low, cyan while it
// charges), "Power status: …", the Windows progress bar in violet and
// cyan blocks and "72% remaining · 3H41". Expanded, power_meter.exe —
// Details: the percent big in dots and the state beside it, the last day
// as yellow dot columns on a ruled screen (cyan where it charged, pink
// under 15 %), and four pink-dotted readings (RATE, HEALTH, CYCLES,
// PROFILE: a click steps the power profile); the alarms at the foot.
T.Face {
    id: root

    readonly property real frac: Math.max(0, Math.min(1, ctx.fraction ?? 0))
    readonly property bool charging: !!ctx.charging
    readonly property bool low: ctx.level === "bad"
    readonly property color tone: low ? Ink.red : charging ? Ink.cyan : Ink.yellow
    readonly property string status: low ? "Low - plug in" : charging ? "Charging" : ctx.stateWord === "ON BATTERY" ? "On battery" : String(ctx.stateWord ?? "").toLowerCase().replace(/^./, ch => ch.toUpperCase())
    readonly property string est: {
        const t = String(ctx.time ?? "").toUpperCase().replace(":", "H");
        return !t ? "" : charging ? t + " to full" : t;
    }
    readonly property string rate: (charging ? "+" : ctx.stateWord === "ON BATTERY" ? "-" : "") + (ctx.watts ?? 0).toFixed(1) + " W"

    Win {
        id: win
        anchors.fill: parent
        icon: "⌁"
        title: root.big ? "power_meter.exe — Details" : "power_meter.exe"
        controls: root.big ? "max" : "help"
        big: root.big
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : meter
    }

    // ── Compact ─────────────────────────────────────────────────────
    Component {
        id: meter
        Item {
            id: c
            readonly property real topY: win.bodyY + 8
            readonly property real cellH: height - topY - 10
            readonly property real cellW: Math.round(cellH * 0.62)

            // The cell: its cap, then the dot screen.
            Rectangle {
                x: 16 + c.cellW * 0.3
                y: c.topY
                width: c.cellW * 0.4
                height: 6
                color: Ink.shade
            }
            Crt {
                id: cell
                x: 16
                y: c.topY + 6
                width: c.cellW
                height: c.cellH - 6
                Rectangle {
                    x: 1
                    y: cell.rows - height - 1
                    width: cell.cols - 2
                    height: Math.max(1, Math.round((cell.rows - 2) * root.frac))
                    color: root.tone
                }
            }

            Column {
                x: cell.x + cell.width + 16
                y: c.topY + 4
                width: parent.width - x - 14
                spacing: 6
                Pen {
                    width: parent.width
                    height: 22
                    text: "Power status: " + root.status
                    size: 18
                }
                Meter {
                    width: parent.width
                    height: 18
                    value: root.frac
                    tones: root.low ? [Ink.red] : [Ink.violet, Ink.cyan]
                }
                Pen {
                    width: parent.width
                    height: 22
                    text: (root.ctx.pct ?? 0) + "% remaining" + (root.est ? " · " + root.est : "")
                    size: 17
                }
            }
        }
    }

    // ── Expanded: Details ───────────────────────────────────────────
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
            readonly property real wellY: win.bodyY + 8
            readonly property real wellH: height - wellY - 10
            // In dots, inside the well.
            readonly property int x0: Math.ceil(22 / p)
            readonly property int w0: Math.floor((width - 44) / p)
            readonly property int y0: Math.ceil((wellY + 10) / p)
            readonly property int y1: Math.floor((wellY + wellH - 8) / p)
            readonly property int bigSize: 2
            readonly property int graphY: y0 + 7 * bigSize + 3
            readonly property int cardH: 15
            readonly property int footY: y1 - 5
            readonly property int cardY: footY - 3 - cardH
            readonly property int labY: cardY - 3 - 5
            readonly property int graphH: labY - 2 - graphY
            readonly property int cardW: Math.floor((w0 - 9) / 4)

            Well {
                x: 10
                y: b.wellY
                width: parent.width - 20
                height: b.wellH
            }
            Crt {
                id: graph
                x: b.x0 * b.p
                y: b.graphY * b.p
                width: b.w0 * b.p
                height: b.graphH * b.p
                grid: true
                step: 12
                // 15 / 10 / 5 % alarms, faint pink rules.
                Repeater {
                    model: [0.15, 0.10, 0.05]
                    Rectangle {
                        required property real modelData
                        y: graph.rows - 1 - Math.round(modelData * (graph.rows - 2))
                        width: graph.cols
                        height: 1
                        color: Ink.pink
                        opacity: 0.45
                    }
                }
                Bars {
                    x: 1
                    y: 1
                    width: graph.cols - 2
                    height: graph.rows - 2
                    values: root.ctx.hist ?? []
                    up: Ink.cyan
                    low: Ink.red
                    warn: 0.15
                }
                MatrixText {
                    visible: (root.ctx.hist ?? []).length < 2
                    anchors.centerIn: parent
                    width: implicitWidth
                    height: 5
                    font: "3x5"
                    text: "HISTORY FILLS IN EVERY 5 MIN"
                    color: Ink.cyan
                }
            }

            Dots {
                anchors.fill: parent

                // 72%                                  ON BATTERY
                //                                       3:41 LEFT
                MatrixText {
                    x: b.x0
                    y: b.y0
                    width: implicitWidth
                    height: 7 * b.bigSize
                    size: b.bigSize
                    dot: b.bigSize - 1
                    text: (root.ctx.pct ?? 0) + "%"
                    color: root.low ? Ink.red : Ink.ink
                }
                Column {
                    x: b.x0 + b.w0 - width
                    y: b.y0 + 2
                    spacing: 3
                    Repeater {
                        model: [root.low ? "LOW - PLUG IN" : root.charging ? "CHARGING" : String(root.ctx.stateWord ?? ""), root.ctx.time ? root.ctx.time + (root.charging ? " TO FULL" : " LEFT") : ""]
                        MatrixText {
                            required property string modelData
                            anchors.right: parent.right
                            width: implicitWidth
                            height: 5
                            font: "3x5"
                            text: modelData
                            color: Ink.label
                        }
                    }
                }
                // -24 H              -12 H              NOW
                Repeater {
                    model: [["-24 H", "left"], ["-12 H", "center"], ["NOW", "right"]]
                    MatrixText {
                        required property var modelData
                        x: b.x0
                        y: b.labY
                        width: b.w0
                        height: 5
                        font: "3x5"
                        align: modelData[1]
                        text: modelData[0]
                        color: Ink.label
                    }
                }
                // RATE   HEALTH   CYCLES   PROFILE
                Repeater {
                    model: b.cards
                    Item {
                        required property var modelData
                        required property int index
                        x: b.x0 + index * (b.cardW + 3)
                        y: b.cardY
                        width: b.cardW
                        height: b.cardH
                        Rectangle {
                            anchors.fill: parent
                            color: Ink.pink
                            opacity: 0.3
                        }
                        MatrixText {
                            x: 3
                            y: 2
                            height: 5
                            font: "3x5"
                            text: modelData.name
                            color: Ink.label
                        }
                        MatrixText {
                            x: 3
                            width: parent.width - 5
                            height: 7
                            font: modelData.text.length * 6 <= parent.width - 5 ? "5x7" : "3x5"
                            y: font === "5x7" ? 7 : 8
                            scroll: true
                            text: modelData.text
                            color: Ink.ink
                        }
                        T.Hit {
                            anchors.fill: parent
                            visible: modelData.act !== ""
                            action: modelData.act
                        }
                    }
                }
                MatrixText {
                    x: b.x0
                    y: b.footY
                    width: b.w0
                    height: 5
                    font: "3x5"
                    scroll: true
                    text: "Alarms: 15% · 10% · 5% (critical)"
                    color: Ink.label
                }
            }
        }
    }
}
