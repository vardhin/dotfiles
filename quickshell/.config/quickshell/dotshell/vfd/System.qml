import QtQuick
import qs
import qs.tokyo as T

// System, VFD: the head unit's level meters. CPU, memory and temperature
// as segment bars, each with its reading in big dots at the right (the
// temperature in amber). Expanded, a top board: three outlined cards, each
// a reading and its history, then the busiest processes (a click jumps to
// the process's window).
T.Face {
    id: root

    readonly property real cpu: ctx.cpu ?? 0
    readonly property real mem: ctx.mem ?? 0
    readonly property bool hasTemp: !!ctx.hasTemp
    readonly property var gauges: [
        { name: "CPU", value: cpu, text: Math.round(cpu * 100) + "%", tint: Ink.cyan, hist: ctx.cpuHist ?? [] },
        { name: "MEM", value: mem, text: (ctx.memGb ?? 0).toFixed(1) + "G", tint: Ink.cyan, hist: ctx.memHist ?? [] },
        { name: "TEMP", value: ctx.tempF ?? 0, text: hasTemp ? Math.round(ctx.temp) + "°" : "--", tint: Ink.amber, hist: ctx.tempHist ?? [] }
    ]
    function size(kb: real): string {
        return kb >= 1048576 ? (kb / 1048576).toFixed(1) + "G" : Math.round(kb / 1024) + "M";
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : meters
    }

    // ── Compact: the meters ─────────────────────────────────────────
    Component {
        id: meters
        Unit {
            id: u
            readonly property int padX: 5
            readonly property int padY: 3
            readonly property int rowH: Math.floor((rows - padY * 2) / 3)
            readonly property int valW: 32
            readonly property int labW: 18

            Repeater {
                model: root.gauges
                Item {
                    required property var modelData
                    required property int index
                    x: u.padX
                    y: u.padY + index * u.rowH
                    width: u.cols - u.padX * 2
                    height: u.rowH

                    MatrixText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: u.labW
                        height: implicitHeight
                        font: "3x5"
                        text: modelData.name
                        color: Ink.cyan
                    }
                    Bar {
                        x: u.labW
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - u.labW - u.valW - 3
                        height: Math.max(3, Math.min(5, u.rowH - 4))
                        value: modelData.value
                    }
                    MatrixText {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: u.valW
                        height: implicitHeight
                        align: "right"
                        text: modelData.text
                        color: modelData.tint
                    }
                }
            }
        }
    }

    // ── Expanded: top ───────────────────────────────────────────────
    Component {
        id: board
        Unit {
            id: u
            Item {
                id: page
                x: 4
                y: 4
                width: u.cols - 8
                height: u.rows - 8
                readonly property int gap: 3
                readonly property int cardW: Math.floor((width - gap * 2) / 3)
                readonly property int cardH: Math.max(22, Math.round(height * 0.36))
                readonly property int colCpu: 34
                readonly property int colMem: 31
                readonly property int colPid: 29

                // CPU  38%: name, reading, history, in a ruled card.
                Repeater {
                    model: root.gauges
                    Item {
                        required property var modelData
                        required property int index
                        x: index * (page.cardW + page.gap)
                        width: page.cardW
                        height: page.cardH
                        MatrixText {
                            x: 3
                            y: 4
                            height: implicitHeight
                            font: "3x5"
                            text: modelData.name
                            color: Ink.teal
                        }
                        MatrixText {
                            anchors.right: parent.right
                            anchors.rightMargin: 3
                            y: 3
                            width: implicitWidth
                            height: implicitHeight
                            text: modelData.text
                            color: Ink.amber
                        }
                        Hist {
                            x: 3
                            y: 13
                            width: parent.width - 6
                            height: parent.height - y - 3
                            values: modelData.hist
                        }
                    }
                }

                // PROCESS                    CPU    MEM    PID
                Item {
                    id: head
                    y: page.cardH + 5
                    width: page.width
                    height: 5
                    MatrixText {
                        height: implicitHeight
                        font: "3x5"
                        text: "PROCESS"
                        color: Ink.teal
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
                                color: Ink.teal
                            }
                        }
                    }
                }
                Column {
                    id: procs
                    y: head.y + head.height + 3
                    width: page.width
                    spacing: 2
                    Repeater {
                        model: (root.ctx.top ?? []).slice(0, Math.max(1, Math.floor((page.height - procs.y - 7) / 9)))
                        Item {
                            id: proc
                            required property var modelData
                            required property int index
                            readonly property color ink: index === 0 ? Ink.amber : Ink.cyan
                            width: procs.width
                            height: 7
                            MatrixText {
                                width: parent.width - page.colCpu - page.colMem - page.colPid - 2
                                height: 7
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
                                        height: 7
                                        align: "right"
                                        text: modelData[0]
                                        color: proc.ink
                                        opacity: modelData[2]
                                    }
                                }
                            }
                            T.Hit {
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
                    color: Ink.teal
                }
            }

            over: Repeater {
                model: 3
                Box {
                    required property int index
                    dx: page.x + index * (page.cardW + page.gap)
                    dy: page.y
                    dw: page.cardW
                    dh: page.cardH
                }
            }
        }
    }
}
