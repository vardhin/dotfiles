import QtQuick
import Quickshell.Io
import qs
import qs.services
import qs.tokyo as T

// Battery, 90s Nights: a chrome can in the slanted sign, lit across with
// the charge (red when low, a yellow bolt over it while charging); beside
// it the percent big in sunset dots, the state spaced wide in electric
// blue and the time left in yellow. Expanded, HISTORY: the percent big,
// the state and time at the right, the last day as dot columns in a card
// ruled in the sunset (solid yellow where it charged, the alarms as dashed
// yellow rules), −24 H … NOW, and RATE, HEALTH, CYCLES and PROFILE cards
// (a click on PROFILE steps the power profile).
T.Face {
    id: root

    readonly property real frac: Math.max(0, Math.min(1, ctx.fraction ?? 0))
    readonly property bool charging: !!ctx.charging
    readonly property bool low: ctx.level === "bad"
    readonly property string pct: (ctx.pct ?? 0) + "%"
    readonly property string stateWord: low ? "LOW · PLUG IN" : charging ? "CHARGING" : String(ctx.stateWord ?? "").toUpperCase()
    readonly property string remain: ctx.time ? ctx.time + (charging ? " TO FULL" : " LEFT") : ""
    readonly property string rate: (charging ? "+" : ctx.stateWord === "ON BATTERY" ? "-" : "") + (ctx.watts ?? 0).toFixed(1) + " W"

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : can
    }

    // ── Compact: the can ────────────────────────────────────────────
    Component {
        id: can
        Item {
            id: c
            readonly property int p: Tokens.pitch
            readonly property real cellH: Math.round(Math.min(height * 0.48, 66))
            readonly property real cellW: Math.round(Math.min(width * 0.36, cellH * 1.95))
            // 5x7 scaled by whole dots: Audiowide this small blurs into the grid.
            readonly property int numDots: Math.max(7, Math.min(Math.floor(height * 0.3 / p / 7), 3) * 7)
            readonly property real midY: height / 2

            Plate {
                id: plate
                anchors.fill: parent
                Word {
                    x: Math.round((cell.x + cell.width + 14 - plate.rim) / c.p)
                    y: Math.round((c.midY - c.cellH / 2 - 2 - plate.rim) / c.p)
                    width: implicitWidth
                    height: c.numDots
                    dots: c.numDots
                    fontAt: 99
                    text: root.pct
                    stops: root.low ? [[0, Ink.yellow], [1, Ink.red]] : Ink.sunset
                }
            }
            Can {
                id: cell
                x: plate.leftAt(y) + 14
                y: Math.round(c.midY - c.cellH / 2)
                width: c.cellW
                height: c.cellH
                level: root.frac
                low: root.low
                charging: root.charging
            }
            Column {
                x: cell.x + cell.width + 14
                y: Math.round(c.midY - c.cellH / 2 + (c.numDots + 2) * c.p)
                width: plate.rightAt(y + 20) - x - 8
                spacing: 1
                Pen {
                    width: parent.width
                    text: root.stateWord
                    size: 11
                    spacing: 2
                }
                Pen {
                    width: parent.width
                    visible: text !== ""
                    text: root.remain
                    size: 11
                    color: Ink.yellow
                }
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
            // Px, over the whole face.
            readonly property real padX: 18
            readonly property real bigY: 18
            readonly property real bigH: Math.max(12 * p, Math.min(66, height * 0.15))
            readonly property real graphY: bigY + bigH + 12
            readonly property real footY: height - 16 - 5 * p
            readonly property real cardH: Math.max(16 * p, Math.min(54, height * 0.12))
            readonly property real cardY: footY - 10 - cardH
            readonly property real labY: cardY - 10 - 5 * p
            readonly property real graphH: labY - 6 - graphY
            readonly property real cardW: (width - padX * 2 - 24) / 4
            // px -> the glass's dots.
            function dx(px: real): int {
                return Math.round((px - plate.surface.x) / p);
            }
            function dy(px: real): int {
                return Math.round((px - plate.surface.y) / p);
            }

            Plate {
                id: plate
                anchors.fill: parent
                slant: false

                // 72%                                  ON BATTERY
                //                                       3:41 LEFT
                Word {
                    x: b.dx(b.padX)
                    y: b.dy(b.bigY)
                    width: implicitWidth
                    height: Math.floor(b.bigH / b.p)
                    dots: height
                    fontAt: 9
                    text: root.pct
                    stops: root.low ? [[0, Ink.yellow], [1, Ink.red]] : Ink.sunset
                }
                Column {
                    x: b.dx(b.width - b.padX) - width
                    y: b.dy(b.bigY + b.bigH) - height
                    spacing: 3
                    Repeater {
                        model: [root.stateWord, root.remain]
                        MatrixText {
                            required property string modelData
                            anchors.right: parent.right
                            width: implicitWidth
                            readonly property bool roomy: modelData.length * 6 <= (b.width - b.padX * 2) / b.p * 0.5
                            height: roomy ? 7 : 5
                            font: roomy ? "5x7" : "3x5"
                            text: modelData
                            color: root.low ? Ink.red : Ink.blue
                        }
                    }
                }
                // The last day, in the graph card.
                Cols {
                    x: b.dx(b.padX) + 2
                    y: b.dy(b.graphY) + 2
                    width: b.dx(b.width - b.padX) - x - 2
                    height: b.dy(b.graphY + b.graphH) - y - 1
                    values: root.ctx.hist ?? []
                    w: 2
                    gap: 1
                    up: Ink.yellow
                    low: Ink.red
                    warn: 0.15
                }
                MatrixText {
                    visible: (root.ctx.hist ?? []).length < 2
                    x: b.dx(b.padX) + 4
                    y: b.dy(b.graphY + b.graphH / 2) - 2
                    width: implicitWidth
                    height: 5
                    font: "3x5"
                    text: "HISTORY FILLS IN EVERY 5 MIN"
                    color: Ink.blue
                }
                // −24 H              −12 H              NOW
                Repeater {
                    model: [["-24 H", "left"], ["-12 H", "center"], ["NOW", "right"]]
                    MatrixText {
                        required property var modelData
                        x: b.dx(b.padX)
                        y: b.dy(b.labY)
                        width: b.dx(b.width - b.padX) - x
                        height: 5
                        font: "3x5"
                        align: modelData[1]
                        text: modelData[0]
                        color: Ink.blue
                    }
                }
                Repeater {
                    model: b.cards
                    Item {
                        id: cv
                        required property var modelData
                        required property int index
                        readonly property real px: b.padX + index * (b.cardW + 8)
                        x: b.dx(px) + 2
                        y: b.dy(b.cardY) + 2
                        width: b.dx(px + b.cardW) - x - 2
                        height: b.dy(b.cardY + b.cardH) - y - 1
                        MatrixText {
                            height: 5
                            font: "3x5"
                            text: cv.modelData.name
                            color: Ink.blue
                        }
                        MatrixText {
                            width: parent.width
                            font: cv.modelData.text.length * 6 <= width ? "5x7" : "3x5"
                            y: parent.height - height
                            height: font === "5x7" ? 7 : 5
                            scroll: true
                            text: cv.modelData.text
                            color: Ink.yellow
                        }
                    }
                }
                MatrixText {
                    x: b.dx(b.padX)
                    y: b.dy(b.footY)
                    width: b.dx(b.width - b.padX) - x
                    height: 5
                    font: "3x5"
                    scroll: true
                    text: "WARNS AT 15 · 10 · 5% · PROFILE STEPS ON A CLICK"
                    color: Ink.blue
                }
            }
            Rim {
                id: graph
                x: b.padX
                y: b.graphY
                width: b.width - b.padX * 2
                height: b.graphH
                thick: 2
            }
            // 15 / 10 / 5 % alarms, dashed yellow rules across the graph.
            Repeater {
                model: [0.15, 0.10, 0.05]
                Row {
                    required property real modelData
                    x: graph.x + 2
                    y: graph.y + graph.height - 1 * b.p - Math.round(modelData * (graph.height - 3 * b.p))
                    spacing: 3
                    Repeater {
                        model: Math.floor((graph.width - 4) / 7)
                        Rectangle {
                            width: 4
                            height: 1
                            color: Ink.yellow
                            opacity: 0.8
                        }
                    }
                }
            }
            Repeater {
                model: b.cards
                Stat {
                    required property var modelData
                    required property int index
                    x: b.padX + index * (b.cardW + 8)
                    y: b.cardY
                    width: b.cardW
                    height: b.cardH
                    action: modelData.act
                }
            }
        }
    }
}
