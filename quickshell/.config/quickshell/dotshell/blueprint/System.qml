import QtQuick
import qs
import qs.tokyo as T

// System, Blueprint: FIG. 4, load against time. The last minute of CPU
// as a solid white line and memory as a dashed one on drawn axes, and a
// title block at the bottom right (CPU, MEM, TEMP and the key), all crisp
// on the drafting sheet. Expanded, SHEET 4: three framed graphs (a reading
// and its history as hollow dot columns), then the busiest processes as a
// schedule in dots (a click jumps to the process's window).
T.Face {
    id: root

    readonly property real cpu: ctx.cpu ?? 0
    readonly property real mem: ctx.mem ?? 0
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

    Paper {
        anchors.fill: parent
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : figure
    }

    // ── Compact: FIG. 4 ─────────────────────────────────────────────
    Component {
        id: figure
        Item {
            id: c
            readonly property real tableW: Math.min(120, width * 0.34)
            // The plot: axes from (ax, top) down to (ax, base), out to right.
            readonly property real ax: 14 + 20
            readonly property real plotTop: 34
            readonly property real base: height - 22
            readonly property real plotEnd: width - tableW - 10
            // The last minute, 24 points.
            function line(hist: var): string {
                const v = (hist ?? []).slice(-24);
                if (v.length < 2)
                    return "";
                const step = (plotEnd - ax - 4) / 23;
                const x0 = plotEnd - (v.length - 1) * step;
                return v.map((y, i) => (i ? "L " : "M ") + (x0 + i * step).toFixed(1) + " " + (base - 2 - Math.max(0, Math.min(1, y)) * (base - plotTop - 4)).toFixed(1)).join(" ");
            }

            Pen {
                x: 14
                y: 10
                width: parent.width - 28
                height: 14
                text: "FIG. 4 — LOAD vs TIME (60 s)"
            }
            Stroke {
                anchors.fill: parent
                path: `M ${c.ax} ${c.plotTop - 6} L ${c.ax} ${c.base} L ${c.plotEnd} ${c.base}`
                color: Ink.ink
            }
            Pen {
                x: 0
                width: c.ax - 6
                y: c.plotTop - 12
                height: 12
                horizontalAlignment: Text.AlignRight
                text: "100"
                size: 9
            }
            Pen {
                x: 0
                width: c.ax - 6
                y: c.base - 7
                height: 12
                horizontalAlignment: Text.AlignRight
                text: "0"
                size: 9
            }
            Pen {
                x: c.plotEnd - 60
                width: 60
                y: c.base + 2
                height: 14
                horizontalAlignment: Text.AlignRight
                text: "t (s)"
                size: 9
            }
            Stroke {
                anchors.fill: parent
                path: c.line(root.ctx.memHist)
                color: Ink.line
                line: 1.5
                dash: [4, 3]
            }
            Stroke {
                anchors.fill: parent
                path: c.line(root.ctx.cpuHist)
                color: Ink.white
                line: 1.5
            }
            Table {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: c.tableW
                labelW: 40
                rows: [["CPU", Math.round(root.cpu * 100) + "%"], ["MEM", root.memText], ["TEMP", root.tempText], ["KEY", "— CPU - - MEM"]]
            }
        }
    }

    // ── Expanded: SHEET 4 ───────────────────────────────────────────
    Component {
        id: board
        Item {
            id: b
            readonly property int p: Tokens.pitch
            readonly property int cols: Math.floor(width / p)
            readonly property int rows: Math.floor(height / p)
            readonly property int padX: Math.ceil(16 / p)
            readonly property int gap: 4
            readonly property int cardY: Math.ceil(32 / p)
            readonly property int cardW: Math.floor((cols - padX * 2 - gap * 2) / 3)
            readonly property int cardH: Math.max(20, Math.round(rows * 0.22))
            readonly property int headY: cardY + cardH + 5
            readonly property int rowH: 9
            readonly property int colCpu: 30
            readonly property int colMem: 28
            readonly property int colPid: 28

            Sheet {
                title: "SHEET 4 — LOAD SCHEDULE"
            }
            // The graphs' frames and the schedule's rule, crisp.
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    x: (b.padX + index * (b.cardW + b.gap)) * b.p
                    y: b.cardY * b.p
                    width: b.cardW * b.p
                    height: b.cardH * b.p
                    color: "transparent"
                    border.width: 1
                    border.color: Ink.line
                }
            }
            Rectangle {
                x: b.padX * b.p
                y: (b.headY + 8) * b.p
                width: (b.cols - b.padX * 2) * b.p
                height: 1
                color: Ink.line
            }

            Dots {
                id: ink
                anchors.fill: parent

                Repeater {
                    model: root.gauges
                    Item {
                        required property var modelData
                        required property int index
                        x: b.padX + index * (b.cardW + b.gap) + 3
                        y: b.cardY + 3
                        width: b.cardW - 6
                        height: b.cardH - 5
                        MatrixText {
                            height: 5
                            font: "3x5"
                            text: modelData.name
                            color: Ink.line
                        }
                        MatrixText {
                            anchors.right: parent.right
                            width: implicitWidth
                            height: 5
                            font: "3x5"
                            text: modelData.text
                            color: Ink.white
                        }
                        Bars {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: parent.height - 9
                            values: modelData.hist
                        }
                    }
                }

                // PROCESS                       CPU     MEM     PID
                Item {
                    x: b.padX
                    y: b.headY
                    width: b.cols - b.padX * 2
                    height: 7
                    MatrixText {
                        height: 7
                        text: "PROCESS"
                        color: Ink.line
                    }
                    Row {
                        anchors.right: parent.right
                        Repeater {
                            model: [["CPU", b.colCpu], ["MEM", b.colMem], ["PID", b.colPid]]
                            MatrixText {
                                required property var modelData
                                width: modelData[1]
                                height: 7
                                align: "right"
                                text: modelData[0]
                                color: Ink.line
                            }
                        }
                    }
                }
                Column {
                    id: procs
                    x: b.padX
                    y: b.headY + 11
                    width: b.cols - b.padX * 2
                    Repeater {
                        model: (root.ctx.top ?? []).slice(0, Math.max(1, Math.floor((b.rows - procs.y - 10) / b.rowH)))
                        Item {
                            id: proc
                            required property var modelData
                            required property int index
                            readonly property color tone: index === 0 ? Ink.white : Ink.ink
                            width: procs.width
                            height: b.rowH
                            MatrixText {
                                y: 0
                                width: parent.width - b.colCpu - b.colMem - b.colPid - 2
                                height: 7
                                text: proc.modelData.name
                                color: proc.tone
                            }
                            // The busiest one underlined, as picked.
                            Rectangle {
                                visible: proc.index === 0
                                y: 8
                                width: Math.min(proc.modelData.name.length * 6 - 1, parent.width - b.colCpu - b.colMem - b.colPid - 2)
                                height: 1
                                color: Ink.white
                            }
                            Row {
                                anchors.right: parent.right
                                y: 0
                                Repeater {
                                    model: [[Number(proc.modelData.cpu).toFixed(1) + "%", b.colCpu, 1], [proc.modelData.rss !== undefined ? root.size(proc.modelData.rss) : proc.modelData.mem + "%", b.colMem, 1], [proc.modelData.pid ?? "", b.colPid, 0.6]]
                                    MatrixText {
                                        required property var modelData
                                        width: modelData[1]
                                        height: 7
                                        align: "right"
                                        text: modelData[0]
                                        color: proc.tone
                                        opacity: modelData[2]
                                    }
                                }
                            }
                            T.Hit {
                                anchors.fill: parent
                                action: "jump " + proc.modelData.name
                            }
                        }
                    }
                }

                MatrixText {
                    x: b.padX
                    y: b.rows - 9
                    width: b.cols - b.padX * 2
                    height: 5
                    font: "3x5"
                    scroll: true
                    text: "NOTE: SELECT A ROW TO FOCUS THE PROCESS WINDOW."
                    color: Ink.line
                }
            }
        }
    }
}
