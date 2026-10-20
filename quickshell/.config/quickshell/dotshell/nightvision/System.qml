import QtQuick
import qs
import qs.services
import qs.tokyo as T

// System, Night Vision: a vitals monitor in the eyepiece. VITALS · HOST in
// dim small print with STABLE (STRAINED when anything runs hot) across
// from it, a heartbeat trace sweeping the glass, its spikes as tall as the
// CPU load, then CPU, MEM and TEMP, each dim label and bright reading. A
// click expands it. Expanded, TOP on the CRT: three cards ruled in green
// with each reading and its history in lit dot columns, then the busiest
// processes (the picked one boxed in white: a click picks, a second click
// goes to its window), and KILL, FOCUS, NEW TASK keys.
T.Face {
    id: root

    readonly property real cpu: ctx.cpu ?? 0
    readonly property real mem: ctx.mem ?? 0
    readonly property bool hasTemp: !!ctx.hasTemp
    readonly property real temp: ctx.temp ?? 0
    readonly property bool hot: cpu >= 0.9 || mem >= 0.92 || (hasTemp && temp >= 85)
    readonly property var gauges: [
        { name: "CPU", text: Math.round(cpu * 100) + "%", hot: cpu >= 0.9, hist: ctx.cpuHist ?? [] },
        { name: "MEM", text: (ctx.memGb ?? 0).toFixed(1) + "G", hot: mem >= 0.92, hist: ctx.memHist ?? [] },
        { name: "TEMP", text: hasTemp ? Math.round(temp) + "°" : "--", hot: hasTemp && temp >= 85, hist: ctx.tempHist ?? [] }
    ]
    function size(kb: real): string {
        return kb >= 1048576 ? (kb / 1048576).toFixed(1) + "G" : Math.round(kb / 1024) + "M";
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : vitals
    }

    // ── Compact: the vitals monitor ─────────────────────────────────
    Component {
        id: vitals
        Scope {
            id: s
            readonly property int l: Math.round(cols * 0.1) + 3
            readonly property int w: cols - l * 2
            readonly property int t: (Math.max(2, Math.round(rows * 0.14)) + 2)
            readonly property bool roomy: w >= 3 * 6 * 11
            readonly property int faceH: roomy ? 7 : 5

            MatrixText {
                x: s.l
                y: s.t
                width: s.w - 40
                height: 5
                font: "3x5"
                text: "VITALS · HOST"
                color: Ink.dim
            }
            MatrixText {
                x: s.l + s.w - width
                y: s.t
                width: implicitWidth
                height: 5
                font: "3x5"
                text: root.hot ? "STRAINED" : "STABLE"
                color: root.hot ? Ink.bright : Ink.dim
            }
            Trace {
                x: s.l
                y: s.t + 8
                width: s.w
                height: Math.max(8, s.rows - s.t * 2 - 8 - s.faceH - 4)
                level: root.cpu
                beat: Math.max(24, Math.round(s.w / 4))
            }
            Item {
                x: s.l
                y: s.rows - s.t - s.faceH
                width: s.w
                height: s.faceH
                Repeater {
                    model: root.gauges
                    Row {
                        required property var modelData
                        required property int index
                        x: index === 0 ? 0 : index === 1 ? Math.round((s.w - width) / 2) : s.w - width
                        spacing: s.roomy ? 4 : 3
                        MatrixText {
                            width: implicitWidth
                            height: s.faceH
                            font: s.roomy ? "5x7" : "3x5"
                            text: modelData.name
                            color: Ink.dim
                        }
                        MatrixText {
                            width: implicitWidth
                            height: s.faceH
                            font: s.roomy ? "5x7" : "3x5"
                            text: modelData.text
                            color: Ink.bright
                        }
                    }
                }
            }
            T.Hit {
                parent: s.over
                anchors.fill: parent
                action: "panel expand"
            }
        }
    }

    // ── Expanded: TOP ───────────────────────────────────────────────
    Component {
        id: board
        Scope {
            id: b
            crt: true
            property int picked: 0
            readonly property var procs: root.ctx.top ?? []
            readonly property var cur: procs[Math.min(picked, procs.length - 1)] ?? null
            readonly property int p: Tokens.pitch
            readonly property real padX: (Math.max(16, rx * 0.36) + 10)
            readonly property real padY: (Math.max(12, ry * 0.75) + 8)
            readonly property real cardH: Math.max(50, Math.min(100, height * 0.26))
            readonly property real cardW: (width - padX * 2 - 24) / 3
            readonly property real keysY: height - padY - 20
            // The table, in dots.
            readonly property int tx: dx(padX)
            readonly property int tw: dx(width - padX) - tx
            readonly property int ty: dy(padY + cardH + 12)
            readonly property bool roomy: tw >= 150
            readonly property string face: roomy ? "5x7" : "3x5"
            readonly property int faceH: roomy ? 7 : 5
            readonly property int rowH: roomy ? 12 : 8
            readonly property int colCpu: roomy ? 34 : 22
            readonly property int colMem: roomy ? 34 : 22
            readonly property int colPid: roomy ? 30 : 20
            readonly property int footY: dy(keysY - 8) - 5
            readonly property int fit: Math.max(1, Math.floor((footY - 3 - ty - 9) / rowH))

            // The cards' words and columns.
            Repeater {
                model: root.gauges
                Item {
                    id: card
                    required property var modelData
                    required property int index
                    x: b.dx(b.padX + index * (b.cardW + 12) + 8)
                    y: b.dy(b.padY + 8)
                    width: Math.floor((b.cardW - 16) / b.p)
                    height: Math.floor((b.cardH - 14) / b.p)
                    readonly property bool roomy: (card.modelData.name.length + card.modelData.text.length + 1) * 6 <= width
                    MatrixText {
                        height: card.roomy ? 7 : 5
                        font: card.roomy ? "5x7" : "3x5"
                        text: card.modelData.name
                        color: Ink.dim
                    }
                    MatrixText {
                        x: parent.width - width
                        width: implicitWidth
                        height: card.roomy ? 7 : 5
                        font: card.roomy ? "5x7" : "3x5"
                        text: card.modelData.text
                        color: Ink.bright
                    }
                    Cols {
                        y: 11
                        width: parent.width
                        height: parent.height - 11
                        values: card.modelData.hist
                        tone: card.modelData.hot ? Ink.bright : Ink.lit
                    }
                }
            }

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
                    color: Ink.dim
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
                            color: Ink.dim
                        }
                    }
                }
            }
            Column {
                x: b.tx
                y: b.ty + 9
                width: b.tw
                Repeater {
                    model: b.procs.slice(0, b.fit)
                    Item {
                        id: proc
                        required property var modelData
                        required property int index
                        readonly property bool on: index === b.picked
                        width: b.tw
                        height: b.rowH
                        MatrixText {
                            x: 2
                            y: Math.floor((b.rowH - b.faceH) / 2)
                            width: parent.width - b.colCpu - b.colMem - b.colPid - 10
                            height: b.faceH
                            font: b.face
                            text: proc.modelData.name
                            color: Ink.bright
                        }
                        Row {
                            anchors.right: parent.right
                            anchors.rightMargin: 2
                            y: Math.floor((b.rowH - b.faceH) / 2)
                            spacing: 2
                            Repeater {
                                model: [[Number(proc.modelData.cpu).toFixed(1) + "%", b.colCpu, Ink.lit], [proc.modelData.rss !== undefined ? root.size(proc.modelData.rss) : proc.modelData.mem + "%", b.colMem, Ink.lit], [proc.modelData.pid ?? "", b.colPid, Ink.dim]]
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
                text: "SELECT CONTACT TO FOCUS · AGAIN TO JUMP · KILL TO NEUTRALIZE"
                color: Ink.dim
            }

            // The cards' rules, the picked row's white box, the keys.
            Repeater {
                parent: b.over
                model: 3
                Box {
                    required property int index
                    x: b.padX + index * (b.cardW + 12)
                    y: b.padY
                    width: b.cardW
                    height: b.cardH
                }
            }
            Box {
                parent: b.over
                visible: b.procs.length > 0 && b.picked < b.fit
                tone: "bright"
                x: b.px(b.tx) - 2
                y: b.py(b.ty + 9 + b.picked * b.rowH) - 1
                width: b.tw * b.p + 4
                height: b.rowH * b.p + 1
            }
            Row {
                parent: b.over
                x: b.padX
                y: b.keysY
                spacing: 10
                Repeater {
                    model: [["KILL " + (b.cur?.name ?? "").toUpperCase().slice(0, 10), b.cur && b.cur.pid ? "run kill " + b.cur.pid : "", "bright"], ["FOCUS", b.cur ? "jump " + b.cur.name : "", ""], ["NEW TASK", "launcher", ""]]
                    Key {
                        required property var modelData
                        width: (b.width - b.padX * 2 - 20) / 3
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
