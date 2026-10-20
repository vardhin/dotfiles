import QtQuick
import qs
import qs.tokyo as T

// Todo, Night Vision: MISSION OBJECTIVES. Dim small print at the head with
// how many are complete, then a task a line: ✓ (dim, done) or ○ (lit), its
// words bright (dim once done), its day lit at the right, the next one
// boxed in white. A click checks a task; + ASSIGN OBJECTIVE at the foot
// adds one. Expanded, LISTS on the CRT: the lists down the left (the
// picked one lit solid), the add line boxed in white at the top, and the
// picked list's tasks with their priority.
T.Face {
    id: root

    readonly property var today: ctx.today ?? []
    readonly property var all: ctx.items ?? []
    readonly property var lists: ctx.lists ?? []
    readonly property int done: today.filter(t => t.done).length

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : page
    }

    // A task on its line, in dots: its mark, words, priority and day.
    component Task: Item {
        id: task
        property var t: ({})
        property bool showPrio: false
        property bool roomy: true
        readonly property int faceH: roomy ? 7 : 5
        readonly property string prio: ({ "!": "HIGH", ":": "MED", ".": "LOW" })[t.prio ?? ""] ?? ""
        readonly property int midY: Math.floor((height - faceH) / 2)
        MatrixText {
            x: 2
            y: task.midY
            width: implicitWidth
            height: task.faceH
            font: task.roomy ? "5x7" : "3x5"
            text: task.t.done ? "✓" : "○"
            color: task.t.done ? Ink.dim : Ink.lit
        }
        MatrixText {
            id: words
            x: task.roomy ? 12 : 9
            y: task.midY
            width: task.width - x - right.implicitWidth - 4
            height: task.faceH
            font: task.roomy ? "5x7" : "3x5"
            scroll: true
            text: task.t.text ?? ""
            color: task.t.done ? Ink.dim : Ink.bright
        }
        Row {
            id: right
            x: task.width - width - 2
            y: task.midY + (task.roomy ? 1 : 0)
            spacing: 4
            MatrixText {
                visible: task.showPrio && task.prio !== ""
                width: implicitWidth
                height: 5
                font: "3x5"
                text: task.prio
                color: Ink.bright
            }
            MatrixText {
                width: implicitWidth
                height: 5
                font: "3x5"
                text: String(task.t.due ?? "").toUpperCase()
                color: Ink.lit
            }
        }
    }

    // ── Compact: the objectives ─────────────────────────────────────
    Component {
        id: page
        Scope {
            id: s
            readonly property int l: dx((Math.max(18, rx * 0.5) + 8))
            readonly property int w: dx(width - (Math.max(18, rx * 0.5) + 8)) - l
            readonly property int t: (Math.max(2, Math.round(rows * 0.12)) + 2)
            readonly property bool roomy: w >= 150
            readonly property int rowH: roomy ? 11 : 8
            readonly property int listY: t + 8
            readonly property int rowsN: Math.max(0, Math.min(root.today.length, Math.floor((rows - t - listY - 8) / rowH)))

            MatrixText {
                x: s.l
                y: s.t
                width: s.w - done.implicitWidth - 4
                height: 5
                font: "3x5"
                text: root.words.title || "MISSION OBJECTIVES"
                color: Ink.dim
            }
            MatrixText {
                id: done
                x: s.l + s.w - width
                y: s.t
                width: implicitWidth
                height: 5
                font: "3x5"
                text: root.done + "/" + root.today.length + " COMPLETE"
                color: Ink.dim
            }
            Repeater {
                model: root.today.slice(0, s.rowsN)
                Task {
                    required property var modelData
                    required property int index
                    x: s.l
                    y: s.listY + index * s.rowH
                    width: s.w
                    height: s.rowH
                    roomy: s.roomy
                    t: modelData
                }
            }
            T.Field {
                x: s.l
                y: s.listY + s.rowsN * s.rowH + 2
                width: s.w
                height: 5
                hint: root.words.add || "+ ASSIGN OBJECTIVE"
                action: "todo add {value}"
                color: Ink.bright
                hintColor: Ink.dim
            }
            // The rows' clicks and the next one's white box.
            Repeater {
                parent: s.over
                model: root.today.slice(0, s.rowsN)
                Item {
                    required property var modelData
                    required property int index
                    x: s.px(s.l) - 3
                    y: s.py(s.listY + index * s.rowH)
                    width: s.w * Tokens.pitch + 6
                    height: s.rowH * Tokens.pitch
                    Box {
                        anchors.fill: parent
                        visible: !!parent.modelData.next
                        tone: "bright"
                    }
                    T.Hit {
                        anchors.fill: parent
                        action: "todo toggle " + parent.modelData.n
                    }
                }
            }
        }
    }

    // ── Expanded: lists ─────────────────────────────────────────────
    Component {
        id: board
        Scope {
            id: u
            crt: true
            property string list: ""
            readonly property var tabs: [{ name: root.words.title || "Today", key: "", count: root.ctx.left ?? 0 }].concat(root.lists.map(l => ({ name: String(l.name), key: l.name, count: l.count })))
            readonly property var shown: list === "" ? root.today : root.all.filter(t => (t.lists ?? []).includes(list))
            readonly property int p: Tokens.pitch
            readonly property real padX: (Math.max(16, rx * 0.36) + 10)
            readonly property real padY: (Math.max(12, ry * 0.6) + 8)
            readonly property real sideW: Math.round(width * 0.22)
            readonly property real mainX: padX + sideW + 14
            readonly property real mainW: width - mainX - padX
            readonly property bool roomy: mainW / p >= 150
            readonly property real rowH: (roomy ? 11 : 9) * p
            readonly property real fieldH: 9 * p
            readonly property real listY: padY + fieldH + 6
            readonly property real footY: height - padY - 5 * p
            readonly property int rowsN: Math.max(0, Math.min(shown.length, Math.floor((footY - 4 - listY) / rowH)))

            Item {
                x: u.dx(u.mainX + 6)
                y: u.dy(u.padY + u.fieldH / 2) - 3
                width: u.dx(u.mainX + u.mainW - 6) - x
                height: 7
                MatrixText {
                    y: 1
                    width: 5
                    height: 5
                    font: "3x5"
                    text: "+"
                    color: Ink.lit
                }
                T.Field {
                    x: 6
                    width: parent.width - 6
                    height: 7
                    hint: "ASSIGN: +LIST DUE:FRI !HIGH"
                    color: Ink.bright
                    hintColor: Ink.dim
                    action: "todo add {value}" + (u.list ? " +" + u.list : "")
                }
            }
            Repeater {
                model: u.shown.slice(0, u.rowsN)
                Task {
                    required property var modelData
                    required property int index
                    x: u.dx(u.mainX)
                    y: u.dy(u.listY + index * u.rowH)
                    width: u.dx(u.mainX + u.mainW) - x
                    height: Math.round(u.rowH / u.p)
                    roomy: u.roomy
                    showPrio: true
                    t: modelData
                }
            }
            MatrixText {
                visible: u.shown.length === 0
                x: u.dx(u.mainX) + 2
                y: u.dy(u.listY) + 2
                width: implicitWidth
                height: 7
                text: root.words.empty || "ALL OBJECTIVES MET"
                color: Ink.dim
            }
            MatrixText {
                x: u.dx(u.mainX)
                y: u.dy(u.footY)
                width: u.dx(u.mainX + u.mainW) - x
                height: 5
                font: "3x5"
                scroll: true
                text: u.shown.filter(t => !t.done).length + " OPEN OF " + u.shown.length + " · ASSIGN: +LIST DUE:FRI !HIGH · ENTER ADDS · CLICK CHECKS"
                color: Ink.dim
            }

            // The lists, the picked one lit solid.
            Column {
                parent: u.over
                x: u.padX
                y: u.padY
                width: u.sideW
                spacing: 4
                Repeater {
                    model: u.tabs
                    Item {
                        id: tab
                        required property var modelData
                        readonly property bool on: u.list === modelData.key
                        width: parent.width
                        height: 20
                        Rectangle {
                            anchors.fill: parent
                            color: tab.on ? Ink.lit : hit.containsMouse ? Ink.hover : "transparent"
                        }
                        Pen {
                            x: 6
                            width: parent.width - 30
                            height: parent.height
                            text: String(tab.modelData.name).toUpperCase()
                            size: 12
                            color: tab.on ? Ink.night : Ink.lit
                        }
                        Pen {
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            height: parent.height
                            text: tab.modelData.count
                            size: 12
                            color: tab.on ? Ink.night : Ink.lit
                        }
                        T.Hit {
                            id: hit
                            anchors.fill: parent
                            onTap: u.list = tab.modelData.key
                        }
                    }
                }
            }
            Box {
                parent: u.over
                x: u.mainX
                y: u.padY
                width: u.mainW
                height: u.fieldH
                tone: "bright"
            }
            Repeater {
                parent: u.over
                model: u.shown.slice(0, u.rowsN)
                Item {
                    required property var modelData
                    required property int index
                    x: u.mainX
                    y: u.py(u.dy(u.listY + index * u.rowH))
                    width: u.mainW
                    height: u.rowH
                    Box {
                        anchors.fill: parent
                        visible: !!parent.modelData.next
                        tone: "bright"
                    }
                    T.Hit {
                        anchors.fill: parent
                        action: "todo toggle " + parent.modelData.n
                    }
                }
            }
        }
    }
}
