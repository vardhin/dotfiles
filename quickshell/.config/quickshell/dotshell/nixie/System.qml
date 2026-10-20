import QtQuick
import qs
import qs.tokyo as T

// System, Nixie: three glass level tubes in the walnut case, CPU, MEM and
// TEMP, each a glowing orange column at its reading with the number big in
// Nixie One dots beside it and its brass label under (amber when warm, red
// when hot). Expanded, TOP: the case's dot screen with a card per reading
// (its label, the number, its history in dot columns), then the busiest
// processes in dots (the picked one bright: a click picks, a second click
// goes to its window), and KILL, FOCUS and NEW TASK brass keys.
T.Face {
    id: root

    readonly property real cpu: ctx.cpu ?? 0
    readonly property real mem: ctx.mem ?? 0
    readonly property bool hasTemp: !!ctx.hasTemp
    readonly property real temp: ctx.temp ?? 0
    // 0 fine, 1 warm, 2 hot.
    readonly property int cpuState: cpu >= 0.9 ? 2 : cpu >= 0.7 ? 1 : 0
    readonly property int memState: mem >= 0.92 ? 2 : mem >= 0.8 ? 1 : 0
    readonly property int tempState: !hasTemp ? 0 : temp >= 85 ? 2 : temp >= 60 ? 1 : 0
    readonly property var tones: [Ink.digit, Ink.amber, Ink.red]
    readonly property var gauges: [
        { name: "CPU %", short: "CPU", big: String(Math.round(cpu * 100)), text: Math.round(cpu * 100) + "%", level: cpu, state: cpuState, hist: ctx.cpuHist ?? [] },
        { name: "MEM GB", short: "MEM", big: String(Math.round(ctx.memGb ?? 0)), text: (ctx.memGb ?? 0).toFixed(1) + "G", level: mem, state: memState, hist: ctx.memHist ?? [] },
        { name: "TEMP °C", short: "TEMP", big: hasTemp ? String(Math.round(temp)) : "--", text: hasTemp ? Math.round(temp) + "°" : "--", level: ctx.tempF ?? Math.min(1, temp / 100), state: tempState, hist: ctx.tempHist ?? [] }
    ]
    function size(kb: real): string {
        return kb >= 1048576 ? (kb / 1048576).toFixed(1) + "G" : Math.round(kb / 1024) + "M";
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : tubes
    }

    // A glass level tube: rounded glass, the orange column at `level`.
    component Level: Item {
        id: lv
        property real level: 0
        property color tint: Ink.orange
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Ink.c(Qt.rgba(1, 170 / 255, 110 / 255, 0.08), Qt.rgba(1, 1, 1, 0.4))
            border.width: 1
            border.color: Ink.c(Qt.rgba(1, 200 / 255, 150 / 255, 0.35), Qt.rgba(122 / 255, 70 / 255, 30 / 255, 0.4))
        }
        Glow {
            x: 4
            width: lv.width - 8
            height: Math.max(width, (lv.height - 8) * Math.max(0, Math.min(1, lv.level)))
            y: lv.height - 4 - height
            radius: width / 2
            color: lv.tint
            halo: 5
            Behavior on height {
                NumberAnimation {
                    duration: 400
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    // ── Compact: the three tubes ────────────────────────────────────
    Component {
        id: tubes
        Item {
            id: c
            readonly property int p: Tokens.pitch
            readonly property real tubeH: height - 34
            readonly property real tubeW: Math.max(10, Math.min(16, width / 26))
            readonly property real cellW: (width - 40) / 3
            // The number: as tall as the room beside the tube allows.
            readonly property int numDots: Math.max(7, Math.min(Math.floor(tubeH * 0.42 / p), Math.floor((cellW - tubeW - 10) / p / 1.3)))

            Wood {
                anchors.fill: parent
            }
            Repeater {
                model: root.gauges
                Item {
                    id: g
                    required property var modelData
                    required property int index
                    x: 20 + index * c.cellW
                    y: 17
                    width: c.cellW
                    height: c.tubeH
                    Row {
                        anchors.centerIn: parent
                        spacing: 10
                        Level {
                            width: c.tubeW
                            height: g.height
                            level: g.modelData.level
                            tint: g.modelData.state === 2 ? Ink.red : Ink.orange
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            Dots {
                                width: num.implicitWidth * c.p + 2 * c.p
                                height: (c.numDots + 2) * c.p
                                Word {
                                    id: num
                                    x: 1
                                    width: implicitWidth
                                    height: c.numDots + 2
                                    dots: c.numDots
                                    text: g.modelData.big
                                    color: root.tones[g.modelData.state]
                                }
                            }
                            Print {
                                text: g.modelData.name
                                size: 8
                            }
                        }
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
            // Inside the screen, px.
            readonly property real padX: 12 + 12
            readonly property real cardY: 12 + 12
            readonly property real cardH: Math.max(60, Math.min(110, height * 0.3))
            readonly property real cardW: (width - padX * 2 - 20) / 3
            readonly property real keysY: height - 12 - 12 - 22
            // The table, in the screen's dots.
            readonly property int tx: Math.ceil(12 / p)
            readonly property int tw: box.screen.cols - tx * 2
            readonly property int ty: Math.ceil((cardY + cardH + 12 - 12) / p)
            readonly property bool roomy: tw >= 150
            readonly property string face: roomy ? "5x7" : "3x5"
            readonly property int faceH: roomy ? 7 : 5
            readonly property int rowH: roomy ? 11 : 8
            readonly property int colCpu: roomy ? 32 : 22
            readonly property int colMem: roomy ? 30 : 20
            readonly property int colPid: roomy ? 26 : 18
            readonly property int footY: Math.floor((keysY - 12) / p) - 7
            readonly property int fit: Math.max(1, Math.floor((footY - 3 - ty - 8) / rowH))

            Case {
                id: box
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
                        color: Ink.brass
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
                                color: Ink.brass
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
                            readonly property color tone: on ? Ink.digit : Ink.orange
                            width: b.tw
                            height: b.rowH
                            MatrixText {
                                y: 2
                                width: parent.width - b.colCpu - b.colMem - b.colPid - 8
                                height: b.faceH
                                font: b.face
                                text: (proc.on ? "▸ " : "") + proc.modelData.name
                                color: proc.tone
                            }
                            Row {
                                anchors.right: parent.right
                                y: 2
                                spacing: 2
                                Repeater {
                                    model: [[Number(proc.modelData.cpu).toFixed(1) + "%", b.colCpu, proc.tone], [proc.modelData.rss !== undefined ? root.size(proc.modelData.rss) : proc.modelData.mem + "%", b.colMem, proc.tone], [proc.modelData.pid ?? "", b.colPid, Ink.deep]]
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
                    color: Ink.brass
                }
            }

            // The reading cards, over the screen.
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
                        anchors.margins: 4
                        readonly property bool roomy: (5 + 6) * 6 + 6 <= cols
                        MatrixText {
                            x: 2
                            y: 2
                            height: 5
                            font: "3x5"
                            text: card.modelData.short
                            color: Ink.brass
                        }
                        MatrixText {
                            x: ink.roomy ? ink.cols - width - 2 : 2
                            y: ink.roomy ? 1 : 9
                            width: implicitWidth
                            height: 7
                            text: card.modelData.text
                            color: root.tones[card.modelData.state]
                        }
                        Bars {
                            x: 2
                            y: ink.roomy ? 11 : 18
                            width: ink.cols - 4
                            height: ink.rows - y - 1
                            values: card.modelData.hist
                            color: card.modelData.state === 2 ? Ink.red : Ink.orange
                        }
                    }
                }
            }

            // KILL, FOCUS, NEW TASK: the picked process.
            Row {
                x: b.padX
                y: b.keysY
                spacing: 8
                Repeater {
                    model: [["KILL " + (b.cur?.name ?? "").toUpperCase().slice(0, 10), b.cur && b.cur.pid ? "run kill " + b.cur.pid : "", "hot"], ["FOCUS", b.cur ? "jump " + b.cur.name : "", ""], ["NEW TASK", "launcher", ""]]
                    Key {
                        required property var modelData
                        width: (b.width - b.padX * 2 - 16) / 3
                        height: 20
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
