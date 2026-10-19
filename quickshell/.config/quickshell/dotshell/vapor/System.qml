import QtQuick
import qs
import qs.tokyo as T

// System, Vaporwave: taskmgr.exe — Performance. "CPU Usage" over a dark
// dot screen with the load as a stack of yellow rows and its percent, and
// "CPU History · MEM · °C" over a screen ruled in faint cyan, the last
// minute of CPU as a yellow dotted line and memory as a pink one.
// Expanded, taskmgr.exe — Processes: three screens (CPU, MEM, TEMP, a
// reading and its history in yellow columns), then the busiest processes
// as a table in dots on the lilac, the picked one in hot pink; End Task,
// Switch To and New Task… under it.
T.Face {
    id: root

    readonly property real cpu: ctx.cpu ?? 0
    readonly property bool hasTemp: !!ctx.hasTemp
    readonly property string memText: (ctx.memGb ?? 0).toFixed(1) + "G"
    readonly property string tempText: hasTemp ? Math.round(ctx.temp) + "°" : "--"
    readonly property var gauges: [
        { name: "CPU", text: Math.round(cpu * 100) + "%", hist: ctx.cpuHist ?? [] },
        { name: "MEM", text: memText, hist: ctx.memHist ?? [] },
        { name: "TEMP", text: tempText, hist: ctx.tempHist ?? [] }
    ]
    function size(kb: real): string {
        return kb >= 1048576 ? (kb / 1048576).toFixed(1) + "G" : Math.round(kb / 1024) + "M";
    }

    Win {
        id: win
        anchors.fill: parent
        icon: "▤"
        title: root.big ? "taskmgr.exe — Processes" : "taskmgr.exe — Performance"
        big: root.big
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : perf
    }

    // ── Compact: Performance ────────────────────────────────────────
    Component {
        id: perf
        Item {
            id: c
            readonly property real topY: win.bodyY + 4
            readonly property real leftW: Math.min(82, width * 0.24)
            readonly property real screenY: topY + 18
            readonly property real screenH: height - screenY - 8

            Pen {
                x: 10
                y: c.topY
                width: c.leftW
                height: 16
                text: "CPU Usage"
            }
            Crt {
                id: usage
                x: 10
                y: c.screenY
                width: c.leftW
                height: c.screenH
                readonly property int n: Math.max(3, Math.min(10, Math.floor((rows - 10) / 2)))
                readonly property int barW: Math.min(cols - 4, 14)
                Repeater {
                    model: Math.round(root.cpu * usage.n)
                    Rectangle {
                        required property int index
                        x: Math.round((usage.cols - usage.barW) / 2)
                        y: usage.rows - 10 - index * 2
                        width: usage.barW
                        height: 1
                        color: Ink.yellow
                    }
                }
                MatrixText {
                    y: usage.rows - 8
                    width: usage.cols
                    height: 7
                    align: "center"
                    text: Math.round(root.cpu * 100) + " %"
                    color: Ink.yellow
                }
            }

            Pen {
                x: usage.x + usage.width + 8
                y: c.topY
                width: parent.width - x - 10
                height: 16
                text: "CPU History · MEM " + (root.ctx.memGb ?? 0).toFixed(1) + " GB" + (root.hasTemp ? " · " + Math.round(root.ctx.temp) + " °C" : "")
            }
            Crt {
                id: hist
                x: usage.x + usage.width + 8
                y: c.screenY
                width: parent.width - x - 10
                height: c.screenH
                grid: true
                Trace {
                    x: 1
                    y: 2
                    width: hist.cols - 2
                    height: hist.rows - 4
                    values: root.ctx.memHist ?? []
                    color: Ink.pink
                    points: Math.max(12, Math.floor(hist.cols / 2))
                }
                Trace {
                    x: 1
                    y: 2
                    width: hist.cols - 2
                    height: hist.rows - 4
                    values: root.ctx.cpuHist ?? []
                    color: Ink.yellow
                    points: Math.max(12, Math.floor(hist.cols / 2))
                }
            }
        }
    }

    // ── Expanded: Processes ─────────────────────────────────────────
    Component {
        id: board
        Item {
            id: b
            property int picked: 0
            readonly property var procs: root.ctx.top ?? []
            readonly property var cur: procs[Math.min(picked, procs.length - 1)] ?? null
            readonly property int p: Tokens.pitch
            readonly property real wellX: 10
            readonly property real wellY: win.bodyY + 8
            readonly property real wellW: width - 20
            readonly property real wellH: height - wellY - 10
            readonly property real cardY: wellY + 12
            readonly property real cardH: Math.max(60, Math.min(96, height * 0.25))
            readonly property real cardW: (wellW - 24 - 16) / 3
            // The table, in dots.
            readonly property int tx: Math.ceil((wellX + 12) / p)
            readonly property int tw: Math.floor((wellW - 24) / p)
            readonly property int ty: Math.ceil((cardY + cardH + 12) / p)
            readonly property int rowH: 9
            readonly property int colCpu: 32
            readonly property int colMem: 30
            readonly property int colPid: 26
            readonly property int footY: Math.floor((wellY + wellH - 12 - 22 - 6) / p)
            readonly property int fit: Math.max(1, Math.floor((footY - ty - rowH - 2) / rowH))

            Well {
                x: b.wellX
                y: b.wellY
                width: b.wellW
                height: b.wellH
            }

            Repeater {
                model: root.gauges
                Crt {
                    id: card
                    required property var modelData
                    required property int index
                    x: b.wellX + 12 + index * (b.cardW + 8)
                    y: b.cardY
                    width: b.cardW
                    height: b.cardH
                    grid: true
                    step: 12
                    // 5x7 when the name and the reading both fit, else 3x5.
                    readonly property string face: (card.modelData.name.length + card.modelData.text.length) * 6 + 4 <= cols - 4 ? "5x7" : "3x5"
                    MatrixText {
                        x: 2
                        y: 2
                        height: 7
                        font: card.face
                        text: card.modelData.name
                        color: Ink.cyan
                    }
                    MatrixText {
                        x: card.cols - width - 2
                        y: 2
                        width: implicitWidth
                        height: 7
                        font: card.face
                        text: card.modelData.text
                        color: Ink.yellow
                    }
                    Bars {
                        x: 2
                        y: 12
                        width: card.cols - 4
                        height: card.rows - 14
                        values: card.modelData.hist
                    }
                }
            }

            Dots {
                anchors.fill: parent

                // PROCESS                      CPU      MEM      PID
                Row {
                    x: b.tx
                    y: b.ty
                    spacing: 2
                    Repeater {
                        model: [["PROCESS", b.tw - b.colCpu - b.colMem - b.colPid - 6, "left"], ["CPU", b.colCpu, "right"], ["MEM", b.colMem, "right"], ["PID", b.colPid, "right"]]
                        Item {
                            id: head
                            required property var modelData
                            width: modelData[1]
                            height: 9
                            Rectangle {
                                anchors.fill: parent
                                color: Ink.pink
                                opacity: 0.3
                            }
                            MatrixText {
                                x: 1
                                y: 1
                                width: parent.width - 2
                                height: 7
                                align: head.modelData[2]
                                text: head.modelData[0]
                                color: Ink.ink
                            }
                        }
                    }
                }
                Column {
                    x: b.tx
                    y: b.ty + b.rowH + 2
                    width: b.tw
                    Repeater {
                        model: b.procs.slice(0, b.fit)
                        Item {
                            id: proc
                            required property var modelData
                            required property int index
                            readonly property bool on: index === b.picked
                            readonly property color tone: on ? Ink.hi : Ink.ink
                            width: b.tw
                            height: b.rowH
                            Rectangle {
                                visible: proc.on
                                width: parent.width - b.colPid - 2
                                height: parent.height
                                color: Ink.pink
                            }
                            MatrixText {
                                x: 1
                                y: 1
                                width: parent.width - b.colCpu - b.colMem - b.colPid - 8
                                height: 7
                                text: proc.modelData.name
                                color: proc.tone
                            }
                            Row {
                                anchors.right: parent.right
                                y: 1
                                spacing: 2
                                Repeater {
                                    model: [[Number(proc.modelData.cpu).toFixed(1) + "%", b.colCpu, proc.tone], [proc.modelData.rss !== undefined ? root.size(proc.modelData.rss) : proc.modelData.mem + "%", b.colMem, proc.tone], [proc.modelData.pid ?? "", b.colPid, Ink.label]]
                                    MatrixText {
                                        required property var modelData
                                        width: modelData[1]
                                        height: 7
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

            }

            // End Task, Switch To, New Task…: the picked process.
            Row {
                x: b.wellX + 12
                y: b.wellY + b.wellH - 12 - 22
                spacing: 6
                Repeater {
                    model: [["End Task", b.cur && b.cur.pid ? "run kill " + b.cur.pid : ""], ["Switch To", b.cur ? "jump " + b.cur.name : ""], ["New Task…", "launcher"]]
                    Key {
                        required property var modelData
                        width: 96
                        height: 22
                        text: modelData[0]
                        action: modelData[1]
                        enabled: modelData[1] !== ""
                    }
                }
            }
        }
    }
}
