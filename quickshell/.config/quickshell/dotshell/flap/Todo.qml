import QtQuick
import qs
import qs.tokyo as T

// Todo, Split-Flap: TODAY'S RUNS. Each task a long flap row (the hinge
// across it): DUE in yellow or DONE in grey, its words in off-white dots
// (faded once done), its day in orange at the right; the next one ruled
// yellow. A click checks a task; the line at the foot adds one. Expanded,
// the lists down the side as flap rows (the picked one yellow), the add
// line ruled yellow, and the picked list's tasks with their priority.
T.Face {
    id: root

    readonly property var today: ctx.today ?? []
    readonly property var all: ctx.items ?? []
    readonly property var lists: ctx.lists ?? []
    readonly property int due: today.filter(t => !t.done).length

    Housing {
        id: box
        anchors.fill: parent
        label: "TODAY'S RUNS"
        status: root.due + " DUE"
        statusInk: Ink.label
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : list
    }

    // A task: its row (crisp), and in dots the mark, the words, the
    // priority and the day.
    component Run: Item {
        id: run
        property var t: ({})
        property bool showPrio: false
        readonly property int p: Tokens.pitch
        readonly property string prio: ({ "!": "HIGH", ":": "MED", ".": "LOW" })[t.prio ?? ""] ?? ""
        Rectangle {
            anchors.fill: parent
            radius: 2
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Ink.upper
                }
                GradientStop {
                    position: 0.5
                    color: Ink.upper
                }
                GradientStop {
                    position: 0.5
                    color: Ink.lower
                }
                GradientStop {
                    position: 1
                    color: Ink.lower
                }
            }
            border.width: run.t.next ? 2 : 0
            border.color: Ink.yellow
        }
        Dots {
            id: ink
            anchors.fill: parent
            readonly property int midY: Math.floor((rows - 7) / 2)
            MatrixText {
                x: 3
                y: ink.midY + 1
                width: 16
                height: 5
                font: "3x5"
                align: "center"
                text: run.t.done ? "DONE" : "DUE"
                color: run.t.done ? Ink.label : Ink.yellow
            }
            MatrixText {
                id: words
                x: 23
                y: ink.midY
                width: ink.cols - x - right.implicitWidth - 6
                height: 7
                scroll: true
                text: run.t.text ?? ""
                color: run.t.done ? Ink.label : Ink.white
            }
            Row {
                id: right
                x: ink.cols - width - 3
                y: ink.midY + 1
                spacing: 4
                MatrixText {
                    visible: run.showPrio && run.prio !== ""
                    width: implicitWidth
                    height: 5
                    font: "3x5"
                    text: run.prio
                    color: Ink.orange
                }
                MatrixText {
                    width: implicitWidth
                    height: 5
                    font: "3x5"
                    text: String(run.t.due ?? "").toUpperCase()
                    color: Ink.orange
                }
            }
        }
        Rectangle {
            x: 2
            y: Math.floor(parent.height / 2)
            width: parent.width - 4
            height: 1
            color: Ink.seam
            opacity: 0.85
        }
        T.Hit {
            anchors.fill: parent
            action: "todo toggle " + run.t.n
        }
    }

    // ── Compact ─────────────────────────────────────────────────────
    Component {
        id: list
        Item {
            id: u
            readonly property int p: Tokens.pitch
            readonly property real rowH: 11 * p
            readonly property real gap: 4
            readonly property real addH: 7 * p
            readonly property real listY: box.bodyY + 2
            readonly property int rowsN: Math.max(0, Math.min(root.today.length, Math.floor((height - listY - addH - 16 + gap) / (rowH + gap))))

            Column {
                x: 12
                y: u.listY
                spacing: u.gap
                Repeater {
                    model: root.today.slice(0, u.rowsN)
                    Run {
                        required property var modelData
                        width: u.width - 24
                        height: u.rowH
                        t: modelData
                    }
                }
            }
            Dots {
                anchors.fill: parent
                MatrixText {
                    visible: root.today.length === 0
                    x: Math.ceil(14 / u.p)
                    y: Math.ceil(u.listY / u.p) + 2
                    width: implicitWidth
                    height: 7
                    text: root.words.empty || "ALL DONE"
                    color: Ink.dim
                }
                MatrixText {
                    x: Math.ceil(14 / u.p)
                    y: Math.floor((u.height - 10) / u.p) - 6
                    width: 3
                    height: 5
                    font: "3x5"
                    text: "+"
                    color: Ink.label
                }
                T.Field {
                    x: Math.ceil(14 / u.p) + 5
                    y: Math.floor((u.height - 10) / u.p) - 7
                    width: Math.floor((u.width - 28) / u.p) - 5
                    height: 7
                    hint: root.words.add || "ADD A RUN"
                    action: "todo add {value}"
                    color: Ink.white
                    hintColor: Ink.label
                }
            }
        }
    }

    // ── Expanded: lists ─────────────────────────────────────────────
    Component {
        id: board
        Item {
            id: u
            property string list: ""
            readonly property var tabs: [{ name: root.words.title || "TODAY", key: "", count: root.ctx.left ?? 0 }].concat(root.lists.map(l => ({ name: String(l.name), key: l.name, count: l.count })))
            readonly property var shown: list === "" ? root.today : root.all.filter(t => (t.lists ?? []).includes(list))
            readonly property int p: Tokens.pitch
            readonly property real sideW: Math.round(width * 0.24)
            readonly property real mainX: 14 + sideW + 12
            readonly property real mainW: width - mainX - 14
            readonly property real fieldY: box.bodyY + 2
            readonly property real fieldH: 11 * p
            readonly property real rowH: 11 * p
            readonly property real gap: 4
            readonly property real listY: fieldY + fieldH + 8
            readonly property real footY: height - 10 - 5 * p
            readonly property int rowsN: Math.max(0, Math.min(shown.length, Math.floor((footY - 6 - listY + gap) / (rowH + gap))))

            // The lists, as flap rows.
            Column {
                x: 14
                y: u.fieldY
                width: u.sideW
                spacing: 4
                Repeater {
                    model: u.tabs
                    Item {
                        id: tab
                        required property var modelData
                        readonly property bool on: u.list === modelData.key
                        width: parent.width
                        height: 9 * u.p
                        Tile {
                            anchors.fill: parent
                            lit: tab.on
                        }
                        Dots {
                            id: tink
                            anchors.fill: parent
                            MatrixText {
                                x: 2
                                y: 1
                                width: tink.cols - count.implicitWidth - 6
                                height: 7
                                text: tab.modelData.name
                                color: tab.on ? Ink.housing : Ink.dim
                            }
                            MatrixText {
                                id: count
                                x: tink.cols - width - 2
                                y: 1
                                width: implicitWidth
                                height: 7
                                text: tab.modelData.count
                                color: tab.on ? Ink.housing : Ink.dim
                            }
                        }
                        Rectangle {
                            y: Math.floor(parent.height / 2)
                            width: parent.width
                            height: 1
                            color: Ink.seam
                            opacity: 0.85
                        }
                        T.Hit {
                            anchors.fill: parent
                            onTap: u.list = tab.modelData.key
                        }
                    }
                }
            }
            // The add line, ruled yellow.
            Rectangle {
                x: u.mainX
                y: u.fieldY
                width: u.mainW
                height: u.fieldH
                radius: 2
                color: Ink.lower
                border.width: 2
                border.color: Ink.yellow
            }
            Dots {
                x: u.mainX + 6
                y: u.fieldY + Math.round((u.fieldH - 7 * u.p) / 2)
                width: u.mainW - 12
                height: 7 * u.p
                MatrixText {
                    y: 1
                    width: 5
                    height: 5
                    font: "3x5"
                    text: "+"
                    color: Ink.yellow
                }
                T.Field {
                    x: 6
                    width: Math.floor((u.mainW - 12) / u.p) - 6
                    height: 7
                    hint: "ADD WITH +LIST DUE:FRI !HIGH"
                    color: Ink.white
                    hintColor: Ink.label
                    action: "todo add {value}" + (u.list ? " +" + u.list : "")
                }
            }
            Column {
                x: u.mainX
                y: u.listY
                spacing: u.gap
                Repeater {
                    model: u.shown.slice(0, u.rowsN)
                    Run {
                        required property var modelData
                        width: u.mainW
                        height: u.rowH
                        showPrio: true
                        t: modelData
                    }
                }
            }
            Dots {
                anchors.fill: parent
                MatrixText {
                    visible: u.shown.length === 0
                    x: Math.ceil(u.mainX / u.p)
                    y: Math.ceil(u.listY / u.p) + 2
                    width: implicitWidth
                    height: 7
                    text: root.words.empty || "ALL DONE"
                    color: Ink.dim
                }
                MatrixText {
                    x: Math.ceil(u.mainX / u.p)
                    y: Math.floor(u.footY / u.p)
                    width: Math.floor(u.mainW / u.p)
                    height: 5
                    font: "3x5"
                    scroll: true
                    text: u.shown.filter(t => !t.done).length + " LEFT OF " + u.shown.length + " · ENTER ADDS · CLICK CHECKS"
                    color: Ink.label
                }
            }
        }
    }
}
