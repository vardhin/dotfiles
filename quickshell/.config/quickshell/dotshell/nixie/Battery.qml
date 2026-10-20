import QtQuick
import Quickshell.Io
import qs
import qs.services
import qs.tokyo as T

// Battery, Nixie: a moving-coil meter in the walnut case, its needle at the
// charge over an ivory face with the red zone at its low end; beside it the
// percent big in amber Nixie One dots, the state in brass small print and
// the time left in orange. Low, the number goes red and says PLUG IN.
// Expanded, HISTORY: the case's dot screen with the percent big, the state
// and time at the right, the last day as orange dot columns in a glass
// card (paler where it charged, red under 15 %, the alarms as rules), and
// RATE, HEALTH, CYCLES and PROFILE cards (a click on PROFILE steps the
// power profile).
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
        sourceComponent: root.big ? board : meter
    }

    // ── Compact: the meter ──────────────────────────────────────────
    Component {
        id: meter
        Item {
            id: c
            readonly property int p: Tokens.pitch
            readonly property real dialH: height - 30
            readonly property real dialW: Math.min(width * 0.5, dialH * 1.55)
            readonly property int numDots: Math.max(8, Math.min(Math.floor(dialH * 0.36 / p), 16))

            Wood {
                anchors.fill: parent
            }
            Meter {
                id: dial
                x: 16
                y: 15
                width: c.dialW
                height: c.dialH
                value: root.frac
            }
            Column {
                x: dial.x + dial.width + 14
                anchors.verticalCenter: dial.verticalCenter
                width: c.width - x - 14
                spacing: 3
                Dots {
                    width: parent.width
                    height: (c.numDots + 2) * c.p
                    Word {
                        x: 1
                        width: parent.width
                        height: c.numDots + 2
                        dots: c.numDots
                        text: String(root.ctx.pct ?? 0)
                        color: root.low ? Ink.red : Ink.amber
                    }
                }
                Print {
                    width: parent.width
                    text: root.stateWord
                    size: 8
                }
                Pen {
                    width: parent.width
                    text: root.remain || (root.charging ? "charging" : root.pct)
                    size: 13
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
            readonly property real padX: 24
            readonly property real bigY: 22
            readonly property real bigH: Math.max(13 * p, Math.min(80, height * 0.17))
            readonly property real graphY: bigY + bigH + 10
            readonly property real footY: height - 22 - 5 * p
            readonly property real cardH: Math.max(16 * p, Math.min(60, height * 0.13))
            readonly property real cardY: footY - 10 - cardH
            readonly property real labY: cardY - 8 - 5 * p
            readonly property real graphH: labY - 6 - graphY
            readonly property real cardW: (width - padX * 2 - 30) / 4
            // px -> the screen's dots.
            function dx(px: real): int {
                return Math.round((px - box.sx - box.screen.surface.x) / p);
            }
            function dy(px: real): int {
                return Math.round((px - box.sy - box.screen.surface.y) / p);
            }

            Case {
                id: box
                anchors.fill: parent

                // 72%                                  ON BATTERY
                //                                       3:41 LEFT
                Word {
                    x: b.dx(b.padX)
                    y: b.dy(b.bigY)
                    width: implicitWidth
                    height: Math.floor(b.bigH / b.p)
                    dots: height
                    text: root.pct
                    color: root.low ? Ink.red : Ink.digit
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
                            height: 5
                            font: "3x5"
                            text: modelData
                            color: root.low ? Ink.red : Ink.amber
                        }
                    }
                }
                // The last day, in the graph card.
                Bars {
                    x: b.dx(b.padX) + 2
                    y: b.dy(b.graphY) + 2
                    width: b.dx(b.width - b.padX) - x - 2
                    height: b.dy(b.graphY + b.graphH) - y - 2
                    values: root.ctx.hist ?? []
                    bar: 2
                    gap: 1
                    up: Ink.digit
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
                    color: Ink.brass
                }
                // -24 H              -12 H              NOW
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
                        color: Ink.brass
                    }
                }
                Repeater {
                    model: b.cards
                    Item {
                        id: cv
                        required property var modelData
                        required property int index
                        readonly property real px: b.padX + index * (b.cardW + 10)
                        x: b.dx(px) + 2
                        y: b.dy(b.cardY) + 2
                        width: b.dx(px + b.cardW) - x - 2
                        height: b.dy(b.cardY + b.cardH) - y - 1
                        MatrixText {
                            height: 5
                            font: "3x5"
                            text: cv.modelData.name
                            color: Ink.brass
                        }
                        MatrixText {
                            width: parent.width
                            font: cv.modelData.text.length * 6 <= width ? "5x7" : "3x5"
                            y: parent.height - height
                            height: font === "5x7" ? 7 : 5
                            scroll: true
                            text: cv.modelData.text
                            color: Ink.digit
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
                    color: Ink.brass
                }
            }
            Card {
                id: graph
                x: b.padX
                y: b.graphY
                width: b.width - b.padX * 2
                height: b.graphH
            }
            // 15 / 10 / 5 % alarms, rules across the graph.
            Repeater {
                model: [0.15, 0.10, 0.05]
                Rectangle {
                    required property real modelData
                    x: graph.x + 2
                    y: graph.y + graph.height - 2 * b.p - Math.round(modelData * (graph.height - 4 * b.p))
                    width: graph.width - 4
                    height: 1
                    color: Ink.deep
                    opacity: 0.7
                }
            }
            Repeater {
                model: b.cards
                Card {
                    required property var modelData
                    required property int index
                    x: b.padX + index * (b.cardW + 10)
                    y: b.cardY
                    width: b.cardW
                    height: b.cardH
                    T.Hit {
                        anchors.fill: parent
                        visible: parent.modelData.act !== ""
                        action: parent.modelData.act
                    }
                }
            }
        }
    }
}
