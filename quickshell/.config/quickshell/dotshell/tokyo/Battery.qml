import QtQuick
import Quickshell.Io
import qs
import qs.services

// Battery, Tokyo Night: a neon cell (five bars, lit to the charge) beside
// the percent; the sign's tube goes red when it is low. Expanded, the last
// 24 hours as bars with the warning lines, and four readings.
Face {
    id: root

    readonly property real frac: ctx.fraction ?? 0
    readonly property bool charging: !!ctx.charging
    readonly property bool low: ctx.level === "bad"
    readonly property string word: low ? "残量わずか · CHARGE" : charging ? "充電中 · CHARGING" : ctx.stateWord === "FULL" ? "満 · FULL" : "残 · REMAINING"
    readonly property color ink: low ? Ink.red : Ink.cyan

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : sign
    }

    // ── Compact: the cell and the percent ───────────────────────────
    Component {
        id: sign
        Item {
            id: s
            readonly property real padX: Math.round(height * 0.16)
            readonly property real cellH: Math.round(height * 0.47)
            readonly property real cellW: Math.round(Math.min(cellH * 2.12, width * 0.36))

            Glass {
                id: glass
                radius: 28
                Column {
                    x: root.d(s.padX + s.cellW + s.padX * 0.9)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Neon {
                        text: (root.ctx.pct ?? 0) + "%"
                        size: Math.round(glass.rows * 0.4)
                        height: Math.round(size * 0.85)
                        color: root.ink
                        halo: true
                    }
                    Words {
                        text: root.word
                        room: glass.cols - parent.x - 3
                        color: Ink.pink
                    }
                    Words {
                        text: root.ctx.time ?? ""
                        room: glass.cols - parent.x - 3
                        color: Ink.violet
                    }
                }
            }
            Cell {
                x: s.padX
                y: (s.height - height) / 2
                width: s.cellW
                height: s.cellH
                value: root.frac
                lit: !root.low
            }
            Sign {
                radius: 28
                tone: root.low ? "red" : "pink"
            }
        }
    }

    // A neon battery: a cyan outline, five bars, a nub.
    component Cell: Item {
        id: cell
        property real value: 0
        property bool lit: true
        readonly property real line: Math.max(2, Math.round(height * 0.05))
        readonly property real gap: Math.max(2, Math.round(height * 0.08))
        Tube {
            id: can
            width: parent.width - nub.width - 1
            height: parent.height
            radius: Math.round(height * 0.18)
            line: cell.line
            tint: Ink.cyan
            glow: 0.8
        }
        Row {
            x: cell.line + cell.gap
            y: cell.line + cell.gap
            spacing: cell.gap
            Repeater {
                model: 5
                Tube {
                    required property int index
                    readonly property bool on: cell.lit && cell.value > index / 5 + 0.04
                    width: (can.width - (cell.line + cell.gap) * 2 - cell.gap * 4) / 5
                    height: can.height - (cell.line + cell.gap) * 2
                    radius: 4
                    line: 0
                    fill: on ? Ink.cyan : Ink.unlit
                    tint: Ink.cyan
                    glow: on ? 0.6 : 0
                }
            }
        }
        Tube {
            id: nub
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(4, Math.round(cell.height * 0.12))
            height: Math.round(cell.height * 0.4)
            radius: 3
            line: 0
            fill: Ink.cyan
            tint: Ink.cyan
            glow: 0.6
        }
    }

    // ── Expanded: 24 hours ──────────────────────────────────────────
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
                { name: "RATE", text: ((root.charging ? "+" : root.ctx.stateWord === "ON BATTERY" ? "−" : "") + (root.ctx.watts ?? 0).toFixed(1) + " W"), act: "" },
                { name: "HEALTH", text: root.ctx.health || "--", act: "" },
                { name: "CYCLES", text: b.cycles, act: "" },
                { name: "PROFILE", text: Power.profileName(Power.profile), act: "power profile " + ((Power.profile + 1) % (Power.hasPerformance ? 3 : 2)) }
            ]

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: 30
                color: Ink.glass
            }
            Item {
                anchors.fill: parent
                anchors.margins: 12

                Glass {
                    id: glass
                    radius: 20
                    Item {
                        id: page
                        x: 5
                        y: 5
                        width: glass.cols - 10
                        height: glass.rows - 10
                        readonly property int cardH: 17
                        readonly property int graphY: pctText.height + 3
                        readonly property int graphH: height - graphY - 8 - 3 - cardH - 3 - 8

                        Neon {
                            id: pctText
                            text: (root.ctx.pct ?? 0) + "%"
                            size: Math.round(Math.min(page.height * 0.2, 24))
                            height: Math.round(size * 0.85)
                            color: root.ink
                            halo: true
                        }
                        Column {
                            anchors.right: parent.right
                            anchors.verticalCenter: pctText.verticalCenter
                            Words {
                                anchors.right: parent.right
                                small: true
                                text: root.ctx.stateWord ?? ""
                                color: Ink.pink
                            }
                            Words {
                                anchors.right: parent.right
                                small: true
                                text: root.ctx.time ?? ""
                                color: Ink.pink
                            }
                        }

                        // The day, oldest on the left: violet under the
                        // warning line, cyan over it.
                        Item {
                            id: graph
                            y: page.graphY
                            width: page.width
                            height: page.graphH
                            Row {
                                id: barsRow
                                x: 2
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 1
                                readonly property var hist: root.ctx.hist ?? []
                                readonly property int n: Math.max(1, Math.floor((graph.width - 4) / 2))
                                readonly property var shown: hist.length > n ? hist.filter((v, i) => i % Math.ceil(hist.length / n) === 0) : hist
                                spacing: 1
                                Repeater {
                                    model: barsRow.shown
                                    Rectangle {
                                        required property var modelData
                                        anchors.bottom: parent.bottom
                                        width: Math.max(1, Math.floor((graph.width - 4) / Math.max(barsRow.shown.length, 1)) - 1)
                                        height: Math.max(1, Math.round(modelData * (graph.height - 2)))
                                        color: modelData <= 0.15 ? Ink.violet : Ink.cyan
                                    }
                                }
                            }
                            MatrixText {
                                visible: barsRow.shown.length < 2
                                anchors.centerIn: parent
                                height: implicitHeight
                                font: "3x5"
                                text: "HISTORY FILLS IN EVERY 5 MIN"
                                color: Ink.deep
                            }
                        }
                        Row {
                            y: graph.y + graph.height + 2
                            width: page.width
                            MatrixText {
                                width: page.width / 3
                                height: 5
                                font: "3x5"
                                text: "−24 H"
                                color: Ink.violet
                            }
                            MatrixText {
                                width: page.width / 3
                                height: 5
                                font: "3x5"
                                align: "center"
                                text: "−12 H"
                                color: Ink.violet
                            }
                            MatrixText {
                                width: page.width / 3
                                height: 5
                                font: "3x5"
                                align: "right"
                                text: "NOW"
                                color: Ink.violet
                            }
                        }

                        // RATE   HEALTH   CYCLES   PROFILE
                        Row {
                            id: cardRow
                            y: graph.y + graph.height + 10
                            spacing: 3
                            readonly property int cardW: Math.floor((page.width - 9) / 4)
                            Repeater {
                                model: b.cards
                                Item {
                                    required property var modelData
                                    width: cardRow.cardW
                                    height: page.cardH
                                    MatrixText {
                                        x: 3
                                        y: 3
                                        height: 5
                                        font: "3x5"
                                        text: modelData.name
                                        color: Ink.violet
                                    }
                                    Words {
                                        x: 3
                                        y: 9
                                        room: parent.width - 5
                                        width: parent.width - 5
                                        scroll: true
                                        text: modelData.text
                                        color: Ink.cyan
                                    }
                                    Hit {
                                        anchors.fill: parent
                                        visible: modelData.act !== ""
                                        action: modelData.act
                                    }
                                }
                            }
                        }

                        MatrixText {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 5
                            font: "3x5"
                            scroll: true
                            text: "WARNS AT 15 · 10 · 5% · SHUTS DOWN 60 S AFTER 5% UNLESS PLUGGED IN"
                            color: Ink.violet
                        }
                    }
                }

                // Crisp: the graph's frame and warning lines, the cards' rims.
                Item {
                    x: glass.x + page.x * root.pitch
                    y: glass.y + page.y * root.pitch
                    Tube {
                        y: graph.y * root.pitch
                        width: graph.width * root.pitch
                        height: graph.height * root.pitch
                        radius: 12
                        line: 1.5
                        tint: Ink.deep
                        glow: 0
                    }
                    Repeater {
                        model: [0.15, 0.10, 0.05]
                        Item {
                            required property real modelData
                            x: 4
                            y: (graph.y + graph.height - 1 - modelData * (graph.height - 2)) * root.pitch
                            width: graph.width * root.pitch - 8
                            height: 1
                            Row {
                                spacing: 3
                                Repeater {
                                    model: Math.max(0, Math.floor(parent.parent.width / 7))
                                    Rectangle {
                                        width: 4
                                        height: 1
                                        color: Ink.pink
                                        opacity: 0.8
                                    }
                                }
                            }
                        }
                    }
                    Repeater {
                        model: 4
                        Tube {
                            required property int index
                            x: index * (cardRow.cardW + 3) * root.pitch
                            y: cardRow.y * root.pitch
                            width: cardRow.cardW * root.pitch
                            height: page.cardH * root.pitch
                            radius: 10
                            line: 1.5
                            tint: Ink.deep
                            glow: 0
                        }
                    }
                }
            }
            Sign {
                radius: 30
                inner: true
                innerInset: 12
                tone: root.low ? "red" : "pink"
            }
        }
    }
}
