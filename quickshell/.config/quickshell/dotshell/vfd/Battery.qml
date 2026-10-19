import QtQuick
import Quickshell.Io
import qs
import qs.services
import qs.tokyo as T

// Battery, VFD: the stereo's fuel gauge. BAT CHG LOW ECO annunciators, an
// E ... F segment gauge stepping up to the right, the percent in big dots
// and the time left in amber. Charging, the gauge goes amber; low, the
// gauge and the percent go red. Expanded, the last 24 hours as dot columns
// (amber where it was charging) in a ruled frame with the warning lines,
// and four readings in ruled cards.
T.Face {
    id: root

    readonly property real frac: ctx.fraction ?? 0
    readonly property bool charging: !!ctx.charging
    readonly property bool low: ctx.level === "bad"
    readonly property bool eco: Power.profile === 0
    readonly property color ink: low ? Ink.red : charging ? Ink.amber : Ink.cyan
    readonly property color off: low ? Ink.c("#3a1a12", "#dcc0b6") : Ink.ghost
    readonly property string remain: {
        const t = String(ctx.time ?? "");
        return !t ? String(ctx.stateWord ?? "") : charging ? t + " TO FULL" : t + " LEFT";
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : gauge
    }

    // ── Compact: the gauge ──────────────────────────────────────────
    Component {
        id: gauge
        Unit {
            id: u
            readonly property int padX: 5
            readonly property int size: rows >= 38 ? 2 : 1
            readonly property int barH: Math.max(3, Math.min(8, rows - 9 - 7 * size - 8))

            // BAT CHG LOW ECO
            Row {
                x: u.padX
                y: 3
                spacing: 5
                Repeater {
                    model: [["BAT", true, Ink.cyan], ["CHG", root.charging, Ink.amber], ["LOW", root.low, Ink.red], ["ECO", root.eco, Ink.green]]
                    MatrixText {
                        required property var modelData
                        height: 5
                        font: "3x5"
                        text: modelData[0]
                        color: modelData[1] ? modelData[2] : Ink.ghost
                    }
                }
            }
            // E ▮▮▮▮▮▮▮▯▯▯ F
            Item {
                x: u.padX
                y: 11
                width: u.cols - u.padX * 2
                height: u.barH
                MatrixText {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 5
                    font: "3x5"
                    text: "E"
                    color: root.low ? Ink.red : Ink.cyan
                }
                Item {
                    id: track
                    x: 6
                    width: parent.width - 12
                    height: parent.height
                    readonly property int count: Math.max(4, Math.floor((width + 1) / 4))
                    readonly property int lit: Math.round(Math.max(0, Math.min(1, root.frac)) * count)
                    Repeater {
                        model: track.count
                        Rectangle {
                            required property int index
                            x: index * 4
                            width: 3
                            // Stepping up to the right, like a fuel gauge.
                            height: Math.max(2, Math.round(track.height * (0.55 + 0.45 * index / Math.max(1, track.count - 1))))
                            anchors.bottom: parent.bottom
                            color: index < Math.max(root.frac > 0 ? 1 : 0, track.lit) ? root.ink : root.off
                        }
                    }
                }
                MatrixText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: implicitWidth
                    height: 5
                    font: "3x5"
                    text: "F"
                    color: root.low ? Ink.red : Ink.cyan
                }
            }
            // 72%                            3:41 LEFT
            Digits {
                x: u.padX
                y: u.rows - 3 - height
                width: implicitWidth
                height: implicitHeight
                size: u.size
                ghosts: false
                text: (root.ctx.pct ?? 0) + "%"
                color: root.low ? Ink.red : Ink.cyan
            }
            MatrixText {
                anchors.right: parent.right
                anchors.rightMargin: u.padX
                y: u.rows - 8
                width: implicitWidth
                height: 5
                font: "3x5"
                text: root.remain
                color: root.low ? Ink.red : Ink.amber
            }
        }
    }

    // ── Expanded: 24 hours ──────────────────────────────────────────
    Component {
        id: board
        Unit {
            id: u
            property string cycles: "--"
            Process {
                running: true
                command: ["sh", "-c", "cat /sys/class/power_supply/BAT*/cycle_count 2>/dev/null | head -1"]
                stdout: StdioCollector {
                    onStreamFinished: u.cycles = text.trim() && text.trim() !== "0" ? text.trim() : "--"
                }
            }
            readonly property var cards: [
                { name: "RATE", text: ((root.charging ? "+" : root.ctx.stateWord === "ON BATTERY" ? "-" : "") + (root.ctx.watts ?? 0).toFixed(1) + " W"), act: "" },
                { name: "HEALTH", text: root.ctx.health || "--", act: "" },
                { name: "CYCLES", text: u.cycles, act: "" },
                { name: "PROFILE", text: Power.profileName(Power.profile), act: "power profile " + ((Power.profile + 1) % (Power.hasPerformance ? 3 : 2)) }
            ]
            readonly property int padX: 4
            readonly property int pageW: cols - padX * 2
            readonly property int size: Math.max(2, Math.min(3, Math.floor(rows / 30)))
            readonly property int graphY: 4 + size * 7 + 4
            readonly property int cardH: 18
            readonly property int cardY: rows - 9 - cardH - 2
            readonly property int graphH: cardY - 10 - graphY
            readonly property int cardW: Math.floor((pageW - 9) / 4)

            // 72%                                      ON BATTERY
            //                                           3:41 LEFT
            Digits {
                x: u.padX
                y: 4
                width: implicitWidth
                height: implicitHeight
                size: u.size
                ghosts: false
                text: (root.ctx.pct ?? 0) + "%"
                color: root.low ? Ink.red : Ink.cyan
            }
            Column {
                anchors.right: parent.right
                anchors.rightMargin: u.padX
                y: 4 + u.size * 7 - 12
                spacing: 2
                Repeater {
                    model: [String(root.ctx.stateWord ?? ""), root.remain]
                    MatrixText {
                        required property string modelData
                        anchors.right: parent.right
                        width: implicitWidth
                        height: 5
                        font: "3x5"
                        text: modelData
                        color: Ink.amber
                    }
                }
            }

            // The day, oldest on the left: amber where it was charging.
            Canvas {
                id: graph
                x: u.padX + 2
                y: u.graphY + 2
                width: u.pageW - 4
                height: u.graphH - 4
                readonly property var hist: root.ctx.hist ?? []
                readonly property int n: Math.max(1, Math.floor((width + 1) / 3))
                readonly property var shown: hist.length > n ? hist.filter((v, i) => i % Math.ceil(hist.length / n) === 0) : hist
                antialiasing: false
                renderTarget: Canvas.Image
                onShownChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const c = getContext("2d");
                    c.reset();
                    const h = Math.floor(height), s = shown;
                    for (let i = 0; i < s.length; i++) {
                        const up = i > 0 && s[i] > s[i - 1] + 0.001;
                        c.fillStyle = String(up ? Ink.amber : s[i] <= 0.15 ? Ink.red : Ink.cyan);
                        const lit = Math.max(1, Math.round(Math.max(0, Math.min(1, s[i])) * h));
                        for (let k = 0; k < lit; k++)
                            if (k % 3 !== 2)
                                c.fillRect(i * 3, h - 1 - k, 2, 1);
                    }
                }
            }
            MatrixText {
                visible: graph.shown.length < 2
                x: u.padX + Math.round((u.pageW - width) / 2)
                y: u.graphY + Math.round((u.graphH - 5) / 2)
                width: implicitWidth
                height: 5
                font: "3x5"
                text: "HISTORY FILLS IN EVERY 5 MIN"
                color: Ink.teal
            }
            // -24 H              -12 H              NOW
            Repeater {
                model: [["-24 H", "left"], ["-12 H", "center"], ["NOW", "right"]]
                MatrixText {
                    required property var modelData
                    x: u.padX
                    y: u.graphY + u.graphH + 3
                    width: u.pageW
                    height: 5
                    font: "3x5"
                    align: modelData[1]
                    text: modelData[0]
                    color: Ink.teal
                }
            }
            // RATE   HEALTH   CYCLES   PROFILE
            Repeater {
                model: u.cards
                Item {
                    required property var modelData
                    required property int index
                    x: u.padX + index * (u.cardW + 3)
                    y: u.cardY
                    width: u.cardW
                    height: u.cardH
                    MatrixText {
                        x: 3
                        y: 3
                        height: 5
                        font: "3x5"
                        text: modelData.name
                        color: Ink.teal
                    }
                    MatrixText {
                        x: 3
                        y: 10
                        width: parent.width - 5
                        height: 7
                        font: modelData.text.length * 6 <= parent.width - 5 ? "5x7" : "3x5"
                        scroll: true
                        text: modelData.text
                        color: Ink.cyan
                    }
                    T.Hit {
                        anchors.fill: parent
                        visible: modelData.act !== ""
                        action: modelData.act
                    }
                }
            }
            MatrixText {
                x: u.padX
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3
                width: u.pageW
                height: 5
                font: "3x5"
                scroll: true
                text: "WARNS AT 15 · 10 · 5% · SHUTS DOWN 60 S AFTER 5% UNLESS PLUGGED IN"
                color: Ink.teal
            }

            // Crisp: the graph's frame and warning lines, the cards' rules.
            over: [
                Box {
                    dx: u.padX
                    dy: u.graphY
                    dw: u.pageW
                    dh: u.graphH
                },
                Repeater {
                    model: [0.15, 0.10, 0.05]
                    Row {
                        required property real modelData
                        x: u.px(u.padX) + 3
                        y: u.px(graph.y + graph.height - modelData * graph.height)
                        spacing: 3
                        Repeater {
                            model: Math.max(0, Math.floor((u.px(u.pageW) - 6) / 7))
                            Rectangle {
                                width: 4
                                height: 1
                                color: Ink.amber
                                opacity: 0.8
                            }
                        }
                    }
                },
                Repeater {
                    model: 4
                    Box {
                        required property int index
                        dx: u.padX + index * (u.cardW + 3)
                        dy: u.cardY
                        dw: u.cardW
                        dh: u.cardH
                    }
                }
            ]
        }
    }
}
