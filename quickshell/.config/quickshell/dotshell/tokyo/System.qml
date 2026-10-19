import QtQuick
import qs

// System, Tokyo Night: three neon gauges (CPU cyan, memory violet,
// temperature pink), the reading in dots inside each ring. Expanded, a
// top board: the three histories as bar cards, then the busiest processes
// (a click jumps to the process's window).
Face {
    id: root

    readonly property real cpu: ctx.cpu ?? 0
    readonly property real mem: ctx.mem ?? 0
    readonly property bool hasTemp: !!ctx.hasTemp
    readonly property var gauges: [
        { name: "CPU", value: cpu, text: Math.round(cpu * 100) + "%", tint: Ink.cyan, hist: ctx.cpuHist ?? [] },
        { name: "MEM", value: mem, text: (ctx.memGb ?? 0).toFixed(1) + "G", tint: Ink.violet, hist: ctx.memHist ?? [] },
        { name: "TEMP", value: ctx.tempF ?? 0, text: hasTemp ? Math.round(ctx.temp) + "°" : "--", tint: Ink.pink, hist: ctx.tempHist ?? [] }
    ]
    function size(kb: real): string {
        return kb >= 1048576 ? (kb / 1048576).toFixed(1) + "G" : Math.round(kb / 1024) + "M";
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : sign
    }

    // ── Compact: the gauges ─────────────────────────────────────────
    Component {
        id: sign
        Item {
            id: s
            readonly property real dia: Math.min(height * 0.5, (width - 56) / 3.4)
            readonly property real ringY: Math.round((height - dia - 4 - Tokens.fontPx * root.pitch) / 2)
            function cx(i: int): real {
                return width / 2 + (i - 1) * (width - 56) / 3;
            }

            Glass {
                id: glass
                radius: Ink.curve

                Repeater {
                    model: root.gauges
                    Item {
                        required property var modelData
                        required property int index
                        // The reading, inside the ring.
                        Words {
                            readonly property int inner: Math.floor(s.dia * 0.78 / root.pitch)
                            x: Math.round(root.d(s.cx(index)) - inner / 2)
                            y: Math.round(root.d(s.ringY + s.dia / 2) - height / 2)
                            width: inner
                            room: inner - 2
                            height: implicitHeight
                            align: "center"
                            text: modelData.text
                            color: modelData.tint
                        }
                        // The name, under it.
                        DotText {
                            x: Math.round(root.d(s.cx(index)) - implicitWidth / 2)
                            y: root.d(s.ringY + s.dia + 4)
                            height: Tokens.fontPx
                            text: modelData.name
                            color: Ink.violet
                        }
                    }
                }
            }
            Repeater {
                model: root.gauges
                Ring {
                    required property var modelData
                    required property int index
                    x: s.cx(index) - width / 2
                    y: s.ringY
                    width: s.dia
                    height: s.dia
                    value: modelData.value
                    tint: modelData.tint
                }
            }
            Sign {
                radius: Ink.curve
                inner: true
            }
        }
    }

    // ── Expanded: top ───────────────────────────────────────────────
    Component {
        id: board
        Item {
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
                        readonly property int gap: 3
                        readonly property int cardW: Math.floor((width - gap * 2) / 3)
                        readonly property int cardH: Math.max(24, Math.round(height * 0.4))
                        readonly property int colCpu: 26
                        readonly property int colMem: 22
                        readonly property int colPid: 22

                        // CPU 38%   MEM 11.2G   TEMP 61°: name, reading, history.
                        Repeater {
                            model: root.gauges
                            Item {
                                required property var modelData
                                required property int index
                                x: index * (page.cardW + page.gap)
                                width: page.cardW
                                height: page.cardH
                                Words {
                                    x: 4
                                    y: 3
                                    small: true
                                    text: modelData.name
                                    color: Ink.violet
                                }
                                Words {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 4
                                    y: 3
                                    small: true
                                    text: modelData.text
                                    color: modelData.tint
                                }
                                Bars {
                                    x: 4
                                    width: parent.width - 8
                                    y: 15
                                    height: parent.height - y - 3
                                    values: modelData.hist
                                    color: Ink.cyan
                                    barW: 1
                                }
                            }
                        }

                        // PROCESS                CPU    MEM    PID
                        Item {
                            id: head
                            y: page.cardH + 4
                            width: page.width
                            height: 7
                            MatrixText {
                                height: implicitHeight
                                font: "3x5"
                                text: "PROCESS"
                                color: Ink.violet
                            }
                            Row {
                                anchors.right: parent.right
                                Repeater {
                                    model: [["CPU", page.colCpu], ["MEM", page.colMem], ["PID", page.colPid]]
                                    MatrixText {
                                        required property var modelData
                                        width: modelData[1]
                                        height: implicitHeight
                                        font: "3x5"
                                        align: "right"
                                        text: modelData[0]
                                        color: Ink.violet
                                    }
                                }
                            }
                        }
                        Column {
                            id: procs
                            y: head.y + head.height + 1
                            width: page.width
                            spacing: 2
                            Repeater {
                                model: (root.ctx.top ?? []).slice(0, Math.max(1, Math.floor((page.height - procs.y - 8) / 7)))
                                Item {
                                    id: proc
                                    required property var modelData
                                    required property int index
                                    readonly property color ink: index === 0 ? Ink.cyan : Ink.pink
                                    width: procs.width
                                    height: 5
                                    MatrixText {
                                        width: parent.width - page.colCpu - page.colMem - page.colPid - 2
                                        height: 5
                                        font: "3x5"
                                        text: proc.modelData.name
                                        color: proc.ink
                                    }
                                    Row {
                                        anchors.right: parent.right
                                        Repeater {
                                            model: [[Number(proc.modelData.cpu).toFixed(1) + "%", page.colCpu, 1], [proc.modelData.rss !== undefined ? root.size(proc.modelData.rss) : proc.modelData.mem + "%", page.colMem, 1], [proc.modelData.pid ?? "", page.colPid, 0.6]]
                                            MatrixText {
                                                required property var modelData
                                                width: modelData[1]
                                                height: 5
                                                font: "3x5"
                                                align: "right"
                                                text: modelData[0]
                                                color: proc.ink
                                                opacity: modelData[2]
                                            }
                                        }
                                    }
                                    Hit {
                                        anchors.fill: parent
                                        anchors.topMargin: -1
                                        anchors.bottomMargin: -1
                                        action: "jump " + proc.modelData.name
                                    }
                                }
                            }
                        }

                        MatrixText {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: implicitHeight
                            font: "3x5"
                            scroll: true
                            text: "CLICK A PROCESS TO FOCUS ITS WINDOW"
                            color: Ink.violet
                        }
                    }
                }

                // The cards' rims, crisp.
                Repeater {
                    model: 3
                    Tube {
                        required property int index
                        x: glass.x + (page.x + index * (page.cardW + page.gap)) * root.pitch
                        y: glass.y + page.y * root.pitch
                        width: page.cardW * root.pitch
                        height: page.cardH * root.pitch
                        radius: 12
                        line: 1.5
                        tint: Ink.deep
                        glow: 0
                    }
                }
            }
            Sign {
                radius: 30
                inner: true
                innerInset: 12
            }
        }
    }
}
