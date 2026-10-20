import QtQuick
import qs
import qs.services
import qs.tokyo as T

// System, 90s Nights: a mixing desk in the slanted neon sign. SYSTEM in
// sunset dots, the TURBO slab (lit hot pink when the power profile is
// performance; a click switches it), the task count, and three faders,
// CPU, MEM and TEMP, each lit from the foot to its reading under a chrome
// cap, the number yellow under it (red when hot) and its label blue.
// Expanded, TOP: three cards ruled in the sunset with each reading and its
// history in dot columns, then the busiest processes in dots (the picked
// one yellow: a click picks, a second click goes to its window), and KILL,
// FOCUS, NEW TASK, TURBO keys.
T.Face {
    id: root

    readonly property real cpu: ctx.cpu ?? 0
    readonly property real mem: ctx.mem ?? 0
    readonly property bool hasTemp: !!ctx.hasTemp
    readonly property real temp: ctx.temp ?? 0
    readonly property bool cpuHot: cpu >= 0.9
    readonly property bool memHot: mem >= 0.92
    readonly property bool tempHot: hasTemp && temp >= 85
    readonly property bool turbo: Power.profile === 2
    readonly property string turboAct: Power.hasPerformance ? "power profile " + (turbo ? 1 : 2) : ""
    readonly property var gauges: [
        { name: "CPU", text: Math.round(cpu * 100) + "%", level: cpu, hot: cpuHot, hist: ctx.cpuHist ?? [] },
        { name: "MEM", text: (ctx.memGb ?? 0).toFixed(1) + "G", level: mem, hot: memHot, hist: ctx.memHist ?? [] },
        { name: "TEMP", text: hasTemp ? Math.round(temp) + "°" : "--", level: ctx.tempF ?? Math.min(1, temp / 100), hot: tempHot, hist: ctx.tempHist ?? [] }
    ]
    function size(kb: real): string {
        return kb >= 1048576 ? (kb / 1048576).toFixed(1) + "G" : Math.round(kb / 1024) + "M";
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : desk
    }

    // ── Compact: the desk ───────────────────────────────────────────
    Component {
        id: desk
        Item {
            id: c
            readonly property int p: Tokens.pitch
            // The left column's width, the faders' room right of it.
            readonly property real colW: Math.max(84, width * 0.25)
            readonly property real padY: Math.max(10, height * 0.09)
            // x of a crisp part at height y, so it leans with the sign.
            function at(y: real): real {
                return plate.leftAt(y) + 14;
            }

            Plate {
                id: plate
                anchors.fill: parent

                // SYSTEM in sunset dots, as big as the column allows.
                Word {
                    readonly property int k: Math.max(1, Math.min(3, Math.floor((c.colW / c.p) / 36)))
                    x: Math.round((c.at(c.padY + 10) - plate.rim) / c.p)
                    y: Math.round((c.padY - plate.rim) / c.p)
                    width: implicitWidth
                    height: 7 * k
                    dots: 7 * k
                    fontAt: 99
                    text: "SYSTEM"
                    stops: Ink.sunset
                }
            }

            // TURBO: the profile's slab.
            Key {
                x: c.at(c.height / 2) + 4
                y: Math.round(c.height / 2 - height / 2)
                width: c.colW - 8
                height: Math.max(18, Math.min(22, c.height * 0.17))
                text: root.turbo ? "TURBO ●" : "TURBO ○"
                tone: root.turbo ? "pink" : "dim"
                lean: false
                slanted: false
                action: root.turboAct
                enabled: Power.hasPerformance
            }
            Pen {
                x: c.at(c.height - c.padY - 8)
                y: c.height - c.padY - 14
                height: 14
                width: c.colW
                text: (root.ctx.tasks ?? 0) + " TASKS"
                size: 10
            }

            // The faders.
            Repeater {
                model: root.gauges
                Item {
                    id: g
                    required property var modelData
                    required property int index
                    readonly property real x0: plate.leftAt(c.height / 2) + 14 + c.colW + 10
                    readonly property real cellW: (plate.rightAt(c.height / 2) - 14 - x0) / 3
                    x: x0 + index * cellW
                    y: c.padY + 2
                    width: cellW
                    height: c.height - c.padY * 2 - 4
                    Fader {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 16
                        y: 4
                        height: g.height - 34
                        level: g.modelData.level
                        hot: g.modelData.hot
                    }
                    Pen {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: g.height - 28
                        height: 14
                        text: g.modelData.text
                        size: 11
                        color: g.modelData.hot ? Ink.red : Ink.yellow
                    }
                    Pen {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: g.height - 13
                        height: 12
                        text: g.modelData.name
                        size: 9
                    }
                    T.Hit {
                        anchors.fill: parent
                        action: "panel expand"
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
            readonly property real pad: 16
            readonly property real cardY: pad
            readonly property real cardH: Math.max(56, Math.min(100, height * 0.26))
            readonly property real cardW: (width - pad * 2 - 20) / 3
            readonly property real keysY: height - pad - 20
            // The table, in the glass's dots.
            readonly property int tx: Math.ceil((pad - 3) / p)
            readonly property int tw: plate.cols - tx * 2
            readonly property int ty: Math.ceil((cardY + cardH + 12 - 3) / p)
            readonly property bool roomy: tw >= 150
            readonly property string face: roomy ? "5x7" : "3x5"
            readonly property int faceH: roomy ? 7 : 5
            readonly property int rowH: roomy ? 11 : 8
            readonly property int colCpu: roomy ? 32 : 22
            readonly property int colMem: roomy ? 30 : 20
            readonly property int colPid: roomy ? 26 : 18
            readonly property int footY: Math.floor((keysY - 8 - 3) / p) - 5
            readonly property int fit: Math.max(1, Math.floor((footY - 3 - ty - 8) / rowH))

            Plate {
                id: plate
                anchors.fill: parent
                slant: false

                // The cards' words and columns, in dots.
                Repeater {
                    model: root.gauges
                    Item {
                        id: card
                        required property var modelData
                        required property int index
                        x: Math.round((b.pad + index * (b.cardW + 10) + 8 - 3) / b.p)
                        y: Math.round((b.cardY + 6 - 3) / b.p)
                        width: Math.floor((b.cardW - 16) / b.p)
                        height: Math.floor((b.cardH - 12) / b.p)
                        // 5x7 when the label and the reading fit side by side.
                        readonly property bool roomy: (card.modelData.name.length + card.modelData.text.length + 1) * 6 <= width
                        MatrixText {
                            height: card.roomy ? 7 : 5
                            font: card.roomy ? "5x7" : "3x5"
                            text: card.modelData.name
                            color: Ink.blue
                        }
                        MatrixText {
                            x: parent.width - width
                            width: implicitWidth
                            height: card.roomy ? 7 : 5
                            font: card.roomy ? "5x7" : "3x5"
                            text: card.modelData.text
                            color: card.modelData.hot ? Ink.red : Ink.yellow
                        }
                        Cols {
                            y: 10
                            width: parent.width
                            height: parent.height - 10
                            w: b.p >= 5 ? 1 : 2
                            values: card.modelData.hist
                            tone: card.modelData.hot ? Ink.red : null
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
                        color: Ink.yellow
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
                                color: Ink.yellow
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
                            readonly property color tone: on ? Ink.yellow : Ink.pink
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
                                    model: [[Number(proc.modelData.cpu).toFixed(1) + "%", b.colCpu, proc.tone], [proc.modelData.rss !== undefined ? root.size(proc.modelData.rss) : proc.modelData.mem + "%", b.colMem, proc.tone], [proc.modelData.pid ?? "", b.colPid, Ink.magenta]]
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
                    text: (root.turbo ? "TURBO ON" : "TURBO OFF") + " · CLICK TO PICK · AGAIN TO FOCUS"
                    color: Ink.blue
                }
            }

            // The cards' sunset rules.
            Repeater {
                model: 3
                Rim {
                    required property int index
                    x: b.pad + index * (b.cardW + 10)
                    y: b.cardY
                    width: b.cardW
                    height: b.cardH
                    thick: 2
                }
            }

            // KILL, FOCUS, NEW TASK: the picked process. TURBO: the profile.
            Row {
                x: b.pad + 4
                y: b.keysY
                spacing: 10
                Repeater {
                    model: [["KILL " + (b.cur?.name ?? "").toUpperCase().slice(0, 10), b.cur && b.cur.pid ? "run kill " + b.cur.pid : "", "red", false], ["FOCUS", b.cur ? "jump " + b.cur.name : "", "", false], ["NEW TASK", "launcher", "", false], [root.turbo ? "TURBO ●" : "TURBO ○", root.turboAct, root.turbo ? "pink" : "", false]]
                    Key {
                        required property var modelData
                        width: (b.width - b.pad * 2 - 8 - 30) / 4
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
