import QtQuick
import Quickshell.Io
import qs
import qs.services
import qs.tokyo as T

// Battery, Night Vision: the scope's power cell. PWR · CELL 1 in dim small
// print with its state across from it (NOMINAL, !! LOW POWER, EXT PWR), a
// row of cells between two bright end rules, lit to the charge (bright and
// few when low), the percent bright under it and EST 3H41 lit at the right.
// Expanded, HISTORY on the CRT: the percent big, the state and time left
// at the right, the last day as lit dot columns in a card ruled in green
// (dimmer where it charged, the alarms as dashed bright rules), −24 H …
// NOW, and RATE, HEALTH, CYCLES and PROFILE in dashed cards (a click on
// PROFILE steps the power profile).
T.Face {
    id: root

    readonly property real frac: Math.max(0, Math.min(1, ctx.fraction ?? 0))
    readonly property bool charging: !!ctx.charging
    readonly property bool low: ctx.level === "bad"
    readonly property string pct: (ctx.pct ?? 0) + "%"
    readonly property string stateWord: low ? "!! LOW POWER" : charging ? "EXT PWR" : ctx.stateWord === "ON BATTERY" ? "NOMINAL" : String(ctx.stateWord ?? "").toUpperCase()
    readonly property string est: ctx.time ? "EST " + String(ctx.time).replace(":", "H") + (charging ? " FULL" : "") : ""
    readonly property string rate: (charging ? "+" : ctx.stateWord === "ON BATTERY" ? "-" : "") + (ctx.watts ?? 0).toFixed(1) + " W"

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : cell
    }

    // ── Compact: the cell ───────────────────────────────────────────
    Component {
        id: cell
        Scope {
            id: s
            readonly property int l: dx((Math.max(18, rx * 0.5) + 8))
            readonly property int w: dx(width - (Math.max(18, rx * 0.5) + 8)) - l
            readonly property int t: (Math.max(2, Math.round(rows * 0.14)) + 2)
            readonly property int barY: t + 9
            readonly property int barH: Math.max(5, Math.min(12, rows - t * 2 - 9 - 7 - 6))
            // Cells 3 dots wide with a 2 dot gap, between the end rules.
            readonly property int n: Math.max(4, Math.floor((w - 4 + 2) / 5))
            readonly property int on: Math.round(root.frac * n)
            readonly property bool roomy: w >= 110

            MatrixText {
                x: s.l
                y: s.t
                width: s.w - stateTag.width - 4
                height: 5
                font: "3x5"
                text: "PWR · CELL 1"
                color: Ink.dim
            }
            MatrixText {
                id: stateTag
                x: s.l + s.w - width
                y: s.t
                width: implicitWidth
                height: 5
                font: "3x5"
                text: root.stateWord
                color: root.low ? Ink.bright : Ink.dim
            }
            Row {
                x: s.l + 2 + Math.floor((s.w - 4 - (s.n * 5 - 2)) / 2)
                y: s.barY
                spacing: 2
                Repeater {
                    model: s.n
                    Rectangle {
                        required property int index
                        width: 3
                        height: s.barH
                        color: index < s.on ? (root.low ? Ink.bright : Ink.lit) : Ink.deep
                    }
                }
            }
            MatrixText {
                x: s.l
                y: s.barY + s.barH + 4
                width: implicitWidth
                height: s.roomy ? 7 : 5
                font: s.roomy ? "5x7" : "3x5"
                text: root.pct
                color: Ink.bright
            }
            MatrixText {
                x: s.l + s.w - width
                y: s.barY + s.barH + 4
                width: implicitWidth
                height: s.roomy ? 7 : 5
                font: s.roomy ? "5x7" : "3x5"
                text: root.est
                color: Ink.lit
            }
            // The cell's bright end rules.
            Repeater {
                parent: s.over
                model: 2
                Rectangle {
                    required property int index
                    x: index === 0 ? s.px(s.l) : s.px(s.l + s.w) - 1.5
                    y: s.py(s.barY) - 4
                    width: 1.5
                    height: s.barH * Tokens.pitch + 8
                    color: Ink.bright
                }
            }
        }
    }

    // ── Expanded: the last day ──────────────────────────────────────
    Component {
        id: board
        Scope {
            id: b
            crt: true
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
            readonly property real padX: (Math.max(16, rx * 0.36) + 10)
            readonly property real bigY: (Math.max(12, ry * 0.7) + 8)
            readonly property real bigH: Math.max(12 * p, Math.min(66, height * 0.15))
            readonly property real graphY: bigY + bigH + 12
            readonly property real footY: height - (Math.max(12, ry * 0.7) + 8) - 5 * p
            readonly property real cardH: Math.max(16 * p, Math.min(54, height * 0.12))
            readonly property real cardY: footY - 10 - cardH
            readonly property real labY: cardY - 10 - 5 * p
            readonly property real graphH: labY - 6 - graphY
            readonly property real cardW: (width - padX * 2 - 30) / 4

            // 72%                                  ON BATTERY
            //                                       3:41 LEFT
            Say {
                x: b.dx(b.padX)
                y: b.dy(b.bigY) - Math.round(b.bigH / b.p * 0.15)
                width: Math.ceil(implicitWidth) + 2
                height: Math.round(b.bigH / b.p * 1.3)
                verticalAlignment: Text.AlignVCenter
                size: Math.round(b.bigH / b.p * 1.32)
                text: root.pct
                elide: Text.ElideNone
            }
            Column {
                x: b.dx(b.width - b.padX) - width
                y: b.dy(b.bigY + b.bigH) - height
                spacing: 3
                Repeater {
                    model: [root.low ? "!! LOW POWER" : root.charging ? "CHARGING" : String(root.ctx.stateWord ?? "").toUpperCase(), root.ctx.time ? root.ctx.time + (root.charging ? " TO FULL" : " LEFT") : ""]
                    MatrixText {
                        required property string modelData
                        required property int index
                        anchors.right: parent.right
                        width: implicitWidth
                        readonly property bool roomy: modelData.length * 6 <= (b.width - b.padX * 2) / b.p * 0.5
                        height: roomy ? 7 : 5
                        font: roomy ? "5x7" : "3x5"
                        text: modelData
                        color: index === 0 ? Ink.lit : Ink.bright
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
                up: Ink.dim
                low: Ink.bright
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
                color: Ink.dim
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
                    color: Ink.dim
                }
            }
            Repeater {
                model: b.cards
                Item {
                    id: cv
                    required property var modelData
                    required property int index
                    readonly property real px: b.padX + index * (b.cardW + 10)
                    x: b.dx(px) + 3
                    y: b.dy(b.cardY) + 2
                    width: b.dx(px + b.cardW) - x - 2
                    height: b.dy(b.cardY + b.cardH) - y - 2
                    MatrixText {
                        height: 5
                        font: "3x5"
                        text: cv.modelData.name
                        color: Ink.dim
                    }
                    MatrixText {
                        width: parent.width
                        font: cv.modelData.text.length * 6 <= width ? "5x7" : "3x5"
                        y: parent.height - height - 1
                        height: font === "5x7" ? 7 : 5
                        scroll: true
                        text: cv.modelData.text
                        color: Ink.bright
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
                text: "ALERTS @ 15 / 10 / 5 · PROFILE STEPS ON A CLICK"
                color: Ink.dim
            }

            Box {
                id: graph
                parent: b.over
                x: b.padX
                y: b.graphY
                width: b.width - b.padX * 2
                height: b.graphH
            }
            // 15 / 10 / 5 % alarms, dashed bright rules across the graph.
            Repeater {
                parent: b.over
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
                            color: Ink.bright
                            opacity: 0.8
                        }
                    }
                }
            }
            Repeater {
                parent: b.over
                model: b.cards
                Item {
                    required property var modelData
                    required property int index
                    x: b.padX + index * (b.cardW + 10)
                    y: b.cardY
                    width: b.cardW
                    height: b.cardH
                    Box {
                        anchors.fill: parent
                        dashed: true
                        tone: parent.modelData.act !== "" && hit.containsMouse ? "lit" : ""
                    }
                    T.Hit {
                        id: hit
                        visible: parent.modelData.act !== ""
                        anchors.fill: parent
                        action: parent.modelData.act
                    }
                }
            }
        }
    }
}
