import QtQuick
import qs
import qs.tokyo as T

// Todo, Blueprint: today's punch list. "PUNCH LIST — TODAY" and what is
// left (crisp), then each task in dots behind a drawn box (crossed once
// done, the words faded), the next one marked by a white bar at its left,
// its due day at the right, each on a faint rule; a line to add one.
// Expanded, the lists down the side (the picked one boxed in white), a
// framed field to add, and the picked list's tasks with their priority.
T.Face {
    id: root

    readonly property var today: ctx.today ?? []
    readonly property var all: ctx.items ?? []
    readonly property var lists: ctx.lists ?? []
    // A task's row, in dots.
    readonly property int rowH: 10

    Paper {
        anchors.fill: parent
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : list
    }

    // The faint rule under a row and the next one's white bar, crisp.
    component Rule: Item {
        id: rule
        property bool next: false
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Ink.faint
        }
        Rectangle {
            visible: rule.next
            y: 2
            width: 2
            height: parent.height - 4
            color: Ink.white
        }
    }

    // A task in dots: the box, the words, the priority and when it is due.
    component Task: Item {
        id: task
        property var t: ({})
        property bool showPrio: false
        readonly property string prio: ({ "!": "HIGH", ":": "MED", ".": "LOW" })[t.prio ?? ""] ?? ""
        readonly property int lead: t.next ? 3 : 0
        height: root.rowH
        Rectangle {
            x: task.lead
            y: 1
            width: 7
            height: 7
            color: "transparent"
            border.width: 1
            border.color: Ink.ink
            MatrixText {
                visible: !!task.t.done
                x: 2
                y: 1
                width: 3
                height: 5
                font: "3x5"
                text: "×"
                color: Ink.white
            }
        }
        MatrixText {
            x: task.lead + 10
            width: parent.width - x - right.implicitWidth - 6
            // 5x7 when the words fit, else the small face.
            font: String(task.t.text ?? "").length * 6 <= width ? "5x7" : "3x5"
            y: font === "5x7" ? 1 : 2
            height: font === "5x7" ? 7 : 5
            text: task.t.text ?? ""
            color: task.t.done ? Ink.done : Ink.ink
        }
        Row {
            id: right
            anchors.right: parent.right
            y: 2
            spacing: 4
            MatrixText {
                visible: task.showPrio && task.prio !== ""
                width: implicitWidth
                height: 5
                font: "3x5"
                text: task.prio
                color: Ink.white
            }
            MatrixText {
                width: implicitWidth
                height: 5
                font: "3x5"
                text: String(task.t.due ?? "")
                color: Ink.line
            }
        }
        T.Hit {
            anchors.fill: parent
            action: "todo toggle " + task.t.n
        }
    }

    // ── Compact ─────────────────────────────────────────────────────
    Component {
        id: list
        Item {
            id: u
            readonly property int p: Tokens.pitch
            readonly property int cols: Math.floor(width / p)
            readonly property int rows: Math.floor(height / p)
            readonly property int padX: Math.ceil(14 / p)
            readonly property int listY: Math.ceil(28 / p)
            readonly property int rowsN: Math.max(0, Math.min(root.today.length, Math.floor((rows - listY - 10) / root.rowH)))

            Item {
                x: 14
                y: 8
                width: parent.width - 28
                height: 14
                Pen {
                    width: parent.width - left.implicitWidth - 8
                    height: parent.height
                    text: "PUNCH LIST — " + (root.words.title || "TODAY").toUpperCase()
                }
                Pen {
                    id: left
                    anchors.right: parent.right
                    height: parent.height
                    text: (root.ctx.left ?? 0) + " " + (root.words.left || "LEFT").toUpperCase()
                }
            }
            Repeater {
                model: root.today.slice(0, u.rowsN)
                Rule {
                    required property var modelData
                    required property int index
                    x: u.padX * u.p - (next ? 6 : 0)
                    y: (u.listY + index * root.rowH) * u.p
                    width: (u.cols - u.padX * 2) * u.p + (next ? 6 : 0)
                    height: root.rowH * u.p
                    next: !!modelData.next
                }
            }

            Dots {
                anchors.fill: parent
                Repeater {
                    model: root.today.slice(0, u.rowsN)
                    Task {
                        required property var modelData
                        required property int index
                        x: u.padX
                        y: u.listY + index * root.rowH
                        width: u.cols - u.padX * 2
                        t: modelData
                    }
                }
                MatrixText {
                    visible: root.today.length === 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: u.listY + Math.max(0, Math.floor((u.rows - u.listY - 12 - 7) / 2))
                    width: implicitWidth
                    height: 7
                    text: root.words.empty || "ALL DONE"
                    color: Ink.white
                }
                T.Field {
                    x: u.padX
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    width: u.cols - u.padX * 2
                    height: 8
                    hint: root.words.add || "+ ADD ITEM"
                    action: "todo add {value}"
                    color: Ink.ink
                    hintColor: Ink.line
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
            readonly property var tabs: [{ name: root.words.title || "Today", key: "", count: root.ctx.left ?? 0 }].concat(root.lists.map(l => ({ name: String(l.name), key: l.name, count: l.count })))
            readonly property var shown: list === "" ? root.today : root.all.filter(t => (t.lists ?? []).includes(list))
            readonly property int p: Tokens.pitch
            readonly property int cols: Math.floor(width / p)
            readonly property int rows: Math.floor(height / p)
            readonly property int padX: Math.ceil(16 / p)
            readonly property int topY: Math.ceil(30 / p)
            readonly property int sideW: Math.round(cols * 0.24)
            readonly property int mainX: padX + sideW + 5
            readonly property int mainW: cols - mainX - padX
            readonly property int listY: topY + 13
            readonly property int rowsN: Math.max(0, Math.min(shown.length, Math.floor((rows - listY - 9) / root.rowH)))

            Sheet {
                title: "PUNCH LIST — " + (u.tabs.find(t => t.key === u.list)?.name ?? "TODAY").toUpperCase()
                rev: "SHT 13"
            }
            // The lists, crisp.
            Column {
                x: u.padX * u.p
                y: u.topY * u.p
                width: u.sideW * u.p
                spacing: 2
                Repeater {
                    model: u.tabs
                    Item {
                        id: tab
                        required property var modelData
                        readonly property bool on: u.list === modelData.key
                        width: parent.width
                        height: 24
                        Rectangle {
                            anchors.fill: parent
                            visible: tab.on
                            color: "transparent"
                            border.width: 1.5
                            border.color: Ink.white
                        }
                        Pen {
                            x: 10
                            width: parent.width - 36
                            height: parent.height
                            text: String(tab.modelData.name).toUpperCase()
                            size: 12
                            color: tab.on ? Ink.white : Ink.line
                        }
                        Pen {
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            height: parent.height
                            text: tab.modelData.count
                            size: 12
                            color: tab.on ? Ink.white : Ink.line
                            opacity: 0.7
                        }
                        T.Hit {
                            anchors.fill: parent
                            onTap: u.list = tab.modelData.key
                        }
                    }
                }
            }
            // The add field's frame and the rows' rules.
            Rectangle {
                x: u.mainX * u.p
                y: u.topY * u.p
                width: u.mainW * u.p
                height: 10 * u.p
                color: "transparent"
                border.width: 1
                border.color: Ink.white
            }
            Repeater {
                model: u.shown.slice(0, u.rowsN)
                Rule {
                    required property var modelData
                    required property int index
                    x: u.mainX * u.p - (next ? 6 : 0)
                    y: (u.listY + index * root.rowH) * u.p
                    width: u.mainW * u.p + (next ? 6 : 0)
                    height: root.rowH * u.p
                    next: !!modelData.next
                }
            }

            Dots {
                anchors.fill: parent
                // + match mp3 to yt video +dotfiles due:fri !high
                MatrixText {
                    x: u.mainX + 3
                    y: u.topY + 3
                    width: 3
                    height: 5
                    font: "3x5"
                    text: "+"
                    color: Ink.line
                }
                T.Field {
                    x: u.mainX + 9
                    y: u.topY + 1
                    width: u.mainW - 12
                    height: 8
                    hint: "ADD WITH +LIST DUE:FRI !HIGH"
                    color: Ink.ink
                    hintColor: Ink.line
                    action: "todo add {value}" + (u.list ? " +" + u.list : "")
                }
                Repeater {
                    model: u.shown.slice(0, u.rowsN)
                    Task {
                        required property var modelData
                        required property int index
                        x: u.mainX
                        y: u.listY + index * root.rowH
                        width: u.mainW
                        showPrio: true
                        t: modelData
                    }
                }
                MatrixText {
                    visible: u.shown.length === 0
                    x: u.mainX + 3
                    y: u.listY + 2
                    width: implicitWidth
                    height: 7
                    text: root.words.empty || "ALL DONE"
                    color: Ink.white
                }
                MatrixText {
                    x: u.mainX
                    y: u.rows - 7
                    width: u.mainW
                    height: 5
                    font: "3x5"
                    scroll: true
                    text: "NOTE: ADD WITH +LIST DUE:FRI !HIGH · CLICK A BOX TO CHECK IT."
                    color: Ink.line
                }
            }
        }
    }
}
