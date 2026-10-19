import QtQuick
import qs
import qs.tokyo as T

// System, Frutiger Aero: two instrument dials on the sky glass, CPU and
// memory, and beside them the temperature with its warm bar and the load.
// Expanded, a top board: three dark graph cards (a reading and its green
// history), then the busiest processes in bubble dots (a click jumps to
// the process's window).
T.Face {
    id: root

    readonly property real cpu: ctx.cpu ?? 0
    readonly property real mem: ctx.mem ?? 0
    readonly property bool hasTemp: !!ctx.hasTemp
    readonly property var gauges: [
        { name: "CPU", text: Math.round(cpu * 100) + "%", hist: ctx.cpuHist ?? [] },
        { name: "MEM", text: (ctx.memGb ?? 0).toFixed(1) + "G", hist: ctx.memHist ?? [] },
        { name: "TEMP", text: hasTemp ? Math.round(ctx.temp) + "°" : "--", hist: ctx.tempHist ?? [] }
    ]
    function size(kb: real): string {
        return kb >= 1048576 ? (kb / 1048576).toFixed(1) + "G" : Math.round(kb / 1024) + "M";
    }

    Sky {
        anchors.fill: parent
        radius: root.big ? 28 : Math.min(32, height * 0.21)
        gloss: !root.big
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : dials
    }

    // ── Compact: the dials ──────────────────────────────────────────
    Component {
        id: dials
        Item {
            id: c
            readonly property real padX: 18
            readonly property real gap: 12
            readonly property real textW: Math.max(90, width * 0.26)
            readonly property real dialD: Math.min(height * 0.83, (width - padX * 2 - gap * 2 - textW) / 2)

            Row {
                id: pair
                x: c.padX
                anchors.verticalCenter: parent.verticalCenter
                spacing: c.gap
                Dial {
                    width: c.dialD
                    height: c.dialD
                    value: root.cpu
                    text: "CPU " + Math.round(root.cpu * 100) + "%"
                }
                Dial {
                    width: c.dialD
                    height: c.dialD
                    value: root.mem
                    text: "RAM " + Math.round(root.mem * 100) + "%"
                }
            }

            Column {
                x: pair.x + pair.width + c.gap
                width: parent.width - x - c.padX
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                Text {
                    width: parent.width
                    text: "CPU · Memory"
                    color: Ink.blue
                    elide: Text.ElideRight
                    font.family: Ink.family
                    font.pixelSize: 13
                }
                Text {
                    text: root.hasTemp ? Math.round(root.ctx.temp) + " °C" : (root.ctx.memGb ?? 0).toFixed(1) + " GB"
                    color: Ink.navy
                    font.family: Ink.family
                    font.pixelSize: 22
                }
                Rectangle {
                    width: parent.width
                    height: 10
                    radius: 5
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: Ink.track
                        }
                        GradientStop {
                            position: 1
                            color: "white"
                        }
                    }
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, root.hasTemp ? root.ctx.tempF ?? 0 : root.mem))
                        height: parent.height
                        radius: 5
                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: Ink.peach
                            }
                            GradientStop {
                                position: 1
                                color: Ink.orange
                            }
                        }
                    }
                }
                Text {
                    width: parent.width
                    text: "load " + Number(root.ctx.load ?? 0).toFixed(2)
                    color: Ink.blue
                    elide: Text.ElideRight
                    font.family: Ink.family
                    font.pixelSize: 12
                }
            }
        }
    }

    // ── Expanded: top ───────────────────────────────────────────────
    Component {
        id: board
        Item {
            id: b
            readonly property real pad: 18
            readonly property real gap: 10
            readonly property real cardW: (width - pad * 2 - gap * 2) / 3
            readonly property real cardH: Math.max(66, Math.round(height * 0.3))

            // The dark graph cards, crisp; their words and bars are dots.
            Repeater {
                model: root.gauges
                Rectangle {
                    required property int index
                    x: b.pad + index * (b.cardW + b.gap)
                    y: b.pad
                    width: b.cardW
                    height: b.cardH
                    radius: 14
                    border.width: 2
                    border.color: Ink.ice
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: Ink.slate
                        }
                        GradientStop {
                            position: 1
                            color: Ink.night
                        }
                    }
                }
            }

            Dots {
                id: ink
                anchors.fill: parent
                readonly property int p: pitch
                readonly property int x0: Math.ceil(b.pad / p)
                readonly property int w0: cols - x0 * 2
                readonly property int cardY: Math.ceil(b.pad / p)
                readonly property int cardH: Math.floor(b.cardH / p)
                readonly property int colCpu: 32
                readonly property int colMem: 31
                readonly property int colPid: 30

                // CPU  38%, then its history.
                Repeater {
                    model: root.gauges
                    Item {
                        required property var modelData
                        required property int index
                        x: Math.round((b.pad + index * (b.cardW + b.gap)) / ink.p) + 3
                        y: ink.cardY + 3
                        width: Math.floor(b.cardW / ink.p) - 6
                        height: ink.cardH - 6
                        MatrixText {
                            height: implicitHeight
                            font: "3x5"
                            text: modelData.name
                            color: Ink.pale
                        }
                        MatrixText {
                            anchors.right: parent.right
                            width: implicitWidth
                            height: implicitHeight
                            font: "3x5"
                            text: modelData.text
                            color: Ink.lime
                        }
                        Row {
                            id: bars
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            height: parent.height - 9
                            spacing: 1
                            readonly property int count: Math.max(1, Math.floor((parent.width + 1) / 3))
                            Repeater {
                                model: {
                                    const v = modelData.hist.slice(-bars.count);
                                    return Array(Math.max(0, bars.count - v.length)).fill(0).concat(v);
                                }
                                Rectangle {
                                    required property var modelData
                                    anchors.bottom: parent.bottom
                                    width: 2
                                    height: Math.max(1, Math.round(Math.max(0, Math.min(1, modelData)) * bars.height))
                                    gradient: Gradient {
                                        GradientStop {
                                            position: 0
                                            color: Ink.lime
                                        }
                                        GradientStop {
                                            position: 1
                                            color: Ink.green
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // PROCESS                    CPU    MEM    PID
                Item {
                    id: head
                    x: ink.x0
                    y: ink.cardY + ink.cardH + 4
                    width: ink.w0
                    height: 5
                    MatrixText {
                        height: implicitHeight
                        font: "3x5"
                        text: "PROCESS"
                        color: Ink.blue
                    }
                    Row {
                        anchors.right: parent.right
                        Repeater {
                            model: [["CPU", ink.colCpu], ["MEM", ink.colMem], ["PID", ink.colPid]]
                            MatrixText {
                                required property var modelData
                                width: modelData[1]
                                height: implicitHeight
                                font: "3x5"
                                align: "right"
                                text: modelData[0]
                                color: Ink.blue
                            }
                        }
                    }
                }
                Column {
                    id: procs
                    x: ink.x0
                    y: head.y + head.height + 3
                    width: ink.w0
                    spacing: 2
                    Repeater {
                        model: (root.ctx.top ?? []).slice(0, Math.max(1, Math.floor((ink.rows - procs.y - 10) / 9)))
                        Item {
                            id: proc
                            required property var modelData
                            required property int index
                            readonly property color tone: index === 0 ? Ink.green : Ink.navy
                            width: procs.width
                            height: 7
                            MatrixText {
                                width: parent.width - ink.colCpu - ink.colMem - ink.colPid - 2
                                height: 7
                                text: proc.modelData.name
                                color: proc.tone
                            }
                            Row {
                                anchors.right: parent.right
                                Repeater {
                                    model: [[Number(proc.modelData.cpu).toFixed(1) + "%", ink.colCpu, 1], [proc.modelData.rss !== undefined ? root.size(proc.modelData.rss) : proc.modelData.mem + "%", ink.colMem, 1], [proc.modelData.pid ?? "", ink.colPid, 0.4]]
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
                                anchors.topMargin: -1
                                anchors.bottomMargin: -1
                                action: "jump " + proc.modelData.name
                            }
                        }
                    }
                }

                MatrixText {
                    x: ink.x0
                    y: ink.rows - 5 - Math.ceil(b.pad / ink.p) + 2
                    width: ink.w0
                    height: implicitHeight
                    font: "3x5"
                    scroll: true
                    text: "CLICK A PROCESS TO SWITCH TO ITS WINDOW"
                    color: Ink.blue
                }
            }
        }
    }
}
