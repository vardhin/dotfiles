import QtQuick
import qs
import qs.tokyo as T

// System, Split-Flap: the SYSTEM STATUS board. A row of flap tiles per
// reading, CPU, MEM and TEMP in grey, the reading in yellow (orange when
// warm, red when hot) and its state word (OK, BUSY, WARM, HOT) after it;
// "● NOMINAL" lit in the corner, or what is wrong. Expanded, TOP: three
// cards with the reading and its history in off-white dot columns, then
// the busiest processes in dots (the picked one yellow: a click picks, a
// second click goes to its window), with KILL, FOCUS and NEW TASK keys.
T.Face {
    id: root

    readonly property real cpu: ctx.cpu ?? 0
    readonly property real mem: ctx.mem ?? 0
    readonly property bool hasTemp: !!ctx.hasTemp
    readonly property real temp: ctx.temp ?? 0
    readonly property string memText: (ctx.memGb ?? 0).toFixed(1) + "G"
    readonly property string tempText: hasTemp ? Math.round(temp) + "°" : "--"
    // 0 fine, 1 warm, 2 hot.
    readonly property int cpuState: cpu >= 0.9 ? 2 : cpu >= 0.7 ? 1 : 0
    readonly property int memState: mem >= 0.92 ? 2 : mem >= 0.8 ? 1 : 0
    readonly property int tempState: !hasTemp ? 0 : temp >= 85 ? 2 : temp >= 60 ? 1 : 0
    readonly property int worst: Math.max(cpuState, memState, tempState)
    readonly property var tones: [Ink.yellow, Ink.orange, Ink.red]
    readonly property var gauges: [
        { name: "CPU", text: Math.round(cpu * 100) + "%", state: cpuState, word: ["OK", "BUSY", "MAX"][cpuState], hist: ctx.cpuHist ?? [] },
        { name: "MEM", text: memText, state: memState, word: ["OK", "HIGH", "FULL"][memState], hist: ctx.memHist ?? [] },
        { name: "TEMP", text: tempText, state: tempState, word: ["OK", "WARM", "HOT"][tempState], hist: ctx.tempHist ?? [] }
    ]
    function size(kb: real): string {
        return kb >= 1048576 ? (kb / 1048576).toFixed(1) + "G" : Math.round(kb / 1024) + "M";
    }
    function pad(s: string, n: int): string {
        return String(s).slice(0, n).padEnd(n, " ");
    }

    Housing {
        id: box
        anchors.fill: parent
        label: "SYSTEM STATUS"
        status: ["NOMINAL", "BUSY", "HOT"][root.worst]
        statusInk: root.tones[root.worst]
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : rows
    }

    // ── Compact: a row of flaps per reading ─────────────────────────
    Component {
        id: rows
        Item {
            id: c
            readonly property int p: Tokens.pitch
            readonly property real topY: box.bodyY + 2
            readonly property real room: height - topY - 10
            readonly property real gap: 5
            // 5x7 tiles when all three rows fit, else 3x5.
            readonly property string font: 3 * 9 * p + 2 * gap <= room ? "5x7" : "3x5"
            readonly property int rowH: (font === "5x7" ? 9 : 7) * p
            readonly property int n: Math.max(1, Math.min(3, Math.floor((room + gap) / (rowH + gap))))
            readonly property int cells: Math.floor((width - 28) / ((font === "5x7" ? 7 : 5) * p))
            // Narrow rows drop the state word's gap first.
            readonly property int labW: cells >= 15 ? 5 : 4
            readonly property int valW: cells >= 15 ? 6 : 5

            Column {
                x: 14
                y: c.topY
                spacing: c.gap
                Repeater {
                    model: root.gauges.slice(0, c.n)
                    Flaps {
                        required property var modelData
                        width: c.width - 28
                        font: c.font
                        spans: [[root.pad(modelData.name, c.labW), Ink.dim], [root.pad(modelData.text, c.valW), root.tones[modelData.state]], [modelData.word, modelData.state ? root.tones[modelData.state] : Ink.white]]
                    }
                }
            }
        }
    }

    // ── Expanded: TOP ───────────────────────────────────────────────
    Component {
        id: board
        Item {
            id: b
            property int picked: 0
            readonly property var procs: root.ctx.top ?? []
            readonly property var cur: procs[Math.min(picked, procs.length - 1)] ?? null
            readonly property int p: Tokens.pitch
            readonly property real padX: 14
            readonly property real cardY: box.bodyY + 4
            readonly property real cardH: Math.max(60, Math.min(110, height * 0.27))
            readonly property real cardW: (width - padX * 2 - 20) / 3
            readonly property real keysY: height - 12 - 24
            // The table, in dots.
            readonly property int tx: Math.ceil(padX / p)
            readonly property int tw: Math.floor((width - padX * 2) / p)
            readonly property int ty: Math.ceil((cardY + cardH + 14) / p)
            // 5x7 rows when the table is wide enough, else 3x5.
            readonly property bool roomy: tw >= 150
            readonly property string face: roomy ? "5x7" : "3x5"
            readonly property int faceH: roomy ? 7 : 5
            readonly property int rowH: roomy ? 11 : 8
            readonly property int colCpu: roomy ? 32 : 22
            readonly property int colMem: roomy ? 30 : 20
            readonly property int colPid: roomy ? 26 : 18
            readonly property int footY: Math.floor((keysY - 6) / p) - 5
            readonly property int fit: Math.max(1, Math.floor((footY - 3 - ty - 8) / rowH))

            Repeater {
                model: root.gauges
                Card {
                    id: card
                    required property var modelData
                    required property int index
                    x: b.padX + index * (b.cardW + 10)
                    y: b.cardY
                    width: b.cardW
                    height: b.cardH
                    Dots {
                        id: ink
                        anchors.fill: parent
                        anchors.margins: 2
                        // Name and reading side by side in 5x7 when every card has room,
                        // else the reading under the name in 3x5.
                        readonly property bool roomy: (4 + 6) * 6 + 8 <= cols - 4
                        MatrixText {
                            x: 3
                            y: 3
                            height: ink.roomy ? 7 : 5
                            font: ink.roomy ? "5x7" : "3x5"
                            text: card.modelData.name
                            color: Ink.dim
                        }
                        MatrixText {
                            x: ink.roomy ? ink.cols - width - 3 : 3
                            y: ink.roomy ? 3 : 10
                            width: implicitWidth
                            height: ink.roomy ? 7 : 5
                            font: ink.roomy ? "5x7" : "3x5"
                            text: card.modelData.text
                            color: root.tones[card.modelData.state]
                        }
                        Cols {
                            x: 3
                            y: ink.roomy ? 13 : 18
                            width: ink.cols - 6
                            height: ink.rows - y - 3
                            values: card.modelData.hist
                            low: Ink.orange
                        }
                    }
                }
            }

            Dots {
                anchors.fill: parent

                // PROCESS                      CPU      MEM      PID
                Item {
                    x: b.tx
                    y: b.ty
                    width: b.tw
                    height: 5
                    MatrixText {
                        width: parent.width - b.colCpu - b.colMem - b.colPid - 8
                        height: 5
                        font: "3x5"
                        text: "PROCESS"
                        color: Ink.label
                    }
                    Row {
                        anchors.right: parent.right
                        spacing: 2
                        Repeater {
                            model: [["CPU", b.colCpu], ["MEM", b.colMem], ["PID", b.colPid]]
                            MatrixText {
                                required property var modelData
                                width: modelData[1]
                                height: 5
                                font: "3x5"
                                align: "right"
                                text: modelData[0]
                                color: Ink.label
                            }
                        }
                    }
                }
                Column {
                    x: b.tx
                    y: b.ty + 8
                    width: b.tw
                    Repeater {
                        model: b.procs.slice(0, b.fit)
                        Item {
                            id: proc
                            required property var modelData
                            required property int index
                            readonly property bool on: index === b.picked
                            readonly property color tone: on ? Ink.yellow : Ink.white
                            width: b.tw
                            height: b.rowH
                            MatrixText {
                                y: 2
                                width: parent.width - b.colCpu - b.colMem - b.colPid - 8
                                height: b.faceH
                                font: b.face
                                text: proc.modelData.name
                                color: proc.tone
                            }
                            Row {
                                anchors.right: parent.right
                                y: 2
                                spacing: 2
                                Repeater {
                                    model: [[Number(proc.modelData.cpu).toFixed(1) + "%", b.colCpu, proc.tone], [proc.modelData.rss !== undefined ? root.size(proc.modelData.rss) : proc.modelData.mem + "%", b.colMem, proc.tone], [proc.modelData.pid ?? "", b.colPid, Ink.dim]]
                                    MatrixText {
                                        required property var modelData
                                        width: modelData[1]
                                        height: b.faceH
                                        font: b.face
                                        align: "right"
                                        text: modelData[0]
                                        color: modelData[2]
                                    }
                                }
                            }
                            T.Hit {
                                anchors.fill: parent
                                onTap: b.picked === proc.index ? root.run("jump " + proc.modelData.name) : b.picked = proc.index
                            }
                        }
                    }
                }
                MatrixText {
                    x: b.tx
                    y: b.footY
                    width: b.tw
                    height: 5
                    font: "3x5"
                    scroll: true
                    text: "CLICK A PROCESS TO PICK IT · AGAIN TO GO TO ITS WINDOW"
                    color: Ink.label
                }
            }

            // KILL, FOCUS, NEW TASK: the picked process.
            Row {
                x: b.padX
                y: b.keysY
                spacing: 8
                Repeater {
                    model: [["KILL " + (b.cur?.name ?? "").toUpperCase().slice(0, 10), b.cur && b.cur.pid ? "run kill " + b.cur.pid : "", Ink.red], ["FOCUS", b.cur ? "jump " + b.cur.name : "", "transparent"], ["NEW TASK", "launcher", "transparent"]]
                    Key {
                        required property var modelData
                        width: (b.width - b.padX * 2 - 16) / 3
                        height: 24
                        text: modelData[0]
                        action: modelData[1]
                        tone: modelData[2]
                        enabled: modelData[1] !== ""
                    }
                }
            }
        }
    }
}
