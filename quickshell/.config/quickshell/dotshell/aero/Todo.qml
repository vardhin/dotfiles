import QtQuick
import qs
import qs.tokyo as T

// Todo, Frutiger Aero: today's tasks as white glass cards on the sky, each
// behind a little box of bubble dots (grass green with a tick once done,
// the words faded), the next one ringed in sky blue, its due day at the
// right; a line to add one. Expanded, the lists down the side (the picked
// one on a glossy pill), a field to add, and the picked list's tasks with
// their priority.
T.Face {
    id: root

    readonly property var today: ctx.today ?? []
    readonly property var all: ctx.items ?? []
    readonly property var lists: ctx.lists ?? []
    // A task card and the gap under it, in dots.
    readonly property int rowH: 8
    readonly property int rowGap: 2

    Sky {
        anchors.fill: parent
        radius: root.big ? 28 : Math.min(30, height * 0.16)
        gloss: false
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : list
    }

    // A task's words on its card, in dots: the box, the text, the
    // priority and when it is due.
    component Task: Item {
        id: task
        property var t: ({})
        property bool showPrio: false
        readonly property string prio: ({ "!": "!HIGH", ":": "!MED", ".": "!LOW" })[t.prio ?? ""] ?? ""
        height: root.rowH
        Rectangle {
            x: 3
            y: 0
            width: 7
            height: 7
            color: task.t.done ? Ink.green : Ink.track
            MatrixText {
                visible: !!task.t.done
                x: 1
                y: 0
                width: 5
                height: 7
                text: "✓"
                color: "white"
            }
        }
        MatrixText {
            x: 13
            width: parent.width - x - right.implicitWidth - 8
            // 5x7 when the words fit, else the small face.
            font: String(task.t.text ?? "").length * 6 <= width ? "5x7" : "3x5"
            y: font === "5x7" ? 0 : 1
            height: font === "5x7" ? 7 : 5
            text: task.t.text ?? ""
            color: task.t.done ? Ink.blue : Ink.navy
            opacity: task.t.done ? 0.45 : 1
        }
        Row {
            id: right
            anchors.right: parent.right
            anchors.rightMargin: 3
            y: 1
            spacing: 4
            MatrixText {
                visible: task.showPrio && task.prio !== ""
                width: implicitWidth
                height: 5
                font: "3x5"
                text: task.prio
                color: Ink.c("#c8323c", "#ff5a64")
            }
            MatrixText {
                width: implicitWidth
                height: 5
                font: "3x5"
                text: String(task.t.due ?? "")
                color: Ink.blue
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
            readonly property int padX: 6
            readonly property int listY: 13
            readonly property int rowsN: Math.max(0, Math.min(root.today.length, Math.floor((rows - listY - 10) / (root.rowH + root.rowGap))))

            // The cards, crisp.
            Repeater {
                model: root.today.slice(0, u.rowsN)
                Card {
                    required property var modelData
                    required property int index
                    x: u.padX * u.p
                    y: (u.listY + index * (root.rowH + root.rowGap)) * u.p
                    width: (u.cols - u.padX * 2) * u.p
                    height: root.rowH * u.p
                    radius: 12
                    ring: !!modelData.next
                }
            }

            Dots {
                anchors.fill: parent
                // Today                                  3 to go
                MatrixText {
                    x: u.padX
                    y: 4
                    width: u.cols - u.padX * 2 - left.implicitWidth - 4
                    height: 7
                    text: root.words.title || "Today"
                    color: Ink.navy
                }
                MatrixText {
                    id: left
                    anchors.right: parent.right
                    anchors.rightMargin: u.padX
                    y: 4
                    width: implicitWidth
                    height: 7
                    text: (root.ctx.left ?? 0) + " " + (root.words.left || "to go")
                    color: Ink.navy
                }
                Repeater {
                    model: root.today.slice(0, u.rowsN)
                    Task {
                        required property var modelData
                        required property int index
                        x: u.padX
                        y: u.listY + index * (root.rowH + root.rowGap)
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
                    text: root.words.empty || "All done"
                    color: Ink.green
                }
                T.Field {
                    x: u.padX
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    width: u.cols - u.padX * 2
                    height: 8
                    hint: root.words.add || "+ ADD A TASK"
                    action: "todo add {value}"
                    color: Ink.navy
                    hintColor: Ink.blue
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
            readonly property var tabs: [{ name: root.words.title || "Today", key: "", count: root.ctx.left ?? 0 }].concat(root.lists.map(l => ({ name: String(l.name).charAt(0).toUpperCase() + String(l.name).slice(1), key: l.name, count: l.count })))
            readonly property var shown: list === "" ? root.today : root.all.filter(t => (t.lists ?? []).includes(list))
            readonly property int p: Tokens.pitch
            readonly property int cols: Math.floor(width / p)
            readonly property int rows: Math.floor(height / p)
            readonly property int padX: 6
            readonly property int sideW: Math.round(cols * 0.24)
            readonly property int mainX: padX + sideW + 5
            readonly property int mainW: cols - mainX - padX
            readonly property int listY: 18
            readonly property int rowsN: Math.max(0, Math.min(shown.length, Math.floor((rows - listY - 10) / (root.rowH + root.rowGap))))

            // The lists, crisp.
            Column {
                x: u.padX * u.p
                y: 5 * u.p
                width: u.sideW * u.p
                spacing: 4
                Repeater {
                    model: u.tabs
                    Item {
                        id: tab
                        required property var modelData
                        readonly property bool on: u.list === modelData.key
                        width: parent.width
                        height: 26
                        Key {
                            anchors.fill: parent
                            visible: tab.on
                            radius: height / 2
                            look: "lit"
                        }
                        Text {
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 40
                            elide: Text.ElideRight
                            text: tab.modelData.name
                            color: tab.on ? Ink.navy : Ink.blue
                            font.family: Ink.family
                            font.pixelSize: 14
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: tab.modelData.count
                            color: Ink.blue
                            font.family: Ink.family
                            font.pixelSize: 14
                        }
                        T.Hit {
                            anchors.fill: parent
                            onTap: u.list = tab.modelData.key
                        }
                    }
                }
            }
            // The add field's pill and the task cards.
            Card {
                x: u.mainX * u.p
                y: 4 * u.p
                width: u.mainW * u.p
                height: 10 * u.p
                radius: height / 2
                ring: true
                ringColor: Ink.pale
            }
            Repeater {
                model: u.shown.slice(0, u.rowsN)
                Card {
                    required property var modelData
                    required property int index
                    x: u.mainX * u.p
                    y: (u.listY + index * (root.rowH + root.rowGap)) * u.p
                    width: u.mainW * u.p
                    height: root.rowH * u.p
                    radius: 12
                    ring: !!modelData.next
                }
            }

            Dots {
                anchors.fill: parent
                // + match mp3 to yt video +dotfiles due:fri !high
                MatrixText {
                    x: u.mainX + 4
                    y: 5
                    width: 5
                    height: 7
                    text: "+"
                    color: Ink.navy
                }
                T.Field {
                    x: u.mainX + 11
                    y: 5
                    width: u.mainW - 15
                    height: 8
                    hint: "ADD A TASK  +LIST DUE:FRI !HIGH"
                    color: Ink.navy
                    hintColor: Ink.blue
                    action: "todo add {value}" + (u.list ? " +" + u.list : "")
                }
                Repeater {
                    model: u.shown.slice(0, u.rowsN)
                    Task {
                        required property var modelData
                        required property int index
                        x: u.mainX
                        y: u.listY + index * (root.rowH + root.rowGap)
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
                    text: root.words.empty || "All done"
                    color: Ink.green
                }
                MatrixText {
                    x: u.mainX
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    width: u.mainW
                    height: 5
                    font: "3x5"
                    scroll: true
                    text: "TYPE +LIST, DUE:FRI OR !HIGH WHILE ADDING · CLICK A BOX TO CHECK IT"
                    color: Ink.blue
                }
            }
        }
    }
}
