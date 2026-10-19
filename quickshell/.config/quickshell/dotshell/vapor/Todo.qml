import QtQuick
import qs
import qs.tokyo as T

// Todo, Vaporwave: todo.txt — Notepad. Today's tasks in dots on the white
// page, each behind a little dotted box (✓ once done, the words faded and
// struck through), the next one on the sunset's violet-to-pink bar, its
// due day at the right; a click checks a task, and the line at the foot
// adds one. Expanded, the lists down the side (the picked one on the
// bar), the add line in its own box, and the picked list's tasks with
// their priority; the status line at the foot.
T.Face {
    id: root

    readonly property var today: ctx.today ?? []
    readonly property var all: ctx.items ?? []
    readonly property var lists: ctx.lists ?? []
    // A task's row, in dots.
    readonly property int rowH: big ? 10 : 9

    Win {
        id: win
        anchors.fill: parent
        icon: "✎"
        title: "todo.txt — Notepad"
        big: root.big
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : list
    }

    // The sunset bar behind the next task (or the picked list), crisp.
    component Glow: Rectangle {
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: Ink.violet
            }
            GradientStop {
                position: 1
                color: Ink.pink
            }
        }
    }

    // A task in dots: the box, the words, the priority and when it is due.
    component Task: Item {
        id: task
        property var t: ({})
        property bool showPrio: false
        readonly property string prio: ({ "!": "HIGH", ":": "MED", ".": "LOW" })[t.prio ?? ""] ?? ""
        readonly property color tone: t.done ? Ink.violet : t.next ? Ink.hi : Ink.ink
        height: root.rowH
        Rectangle {
            x: 1
            y: 1
            width: 7
            height: 7
            color: "transparent"
            border.width: 1
            border.color: task.t.next ? Ink.hi : Ink.pink
            MatrixText {
                visible: !!task.t.done
                x: 1
                y: 1
                width: 5
                height: 5
                font: "3x5"
                align: "center"
                text: "✓"
                color: Ink.ink
            }
        }
        MatrixText {
            id: words
            x: 11
            width: parent.width - x - right.implicitWidth - 6
            // 5x7 when the words fit, else the small face.
            font: String(task.t.text ?? "").length * 6 <= width ? "5x7" : "3x5"
            y: font === "5x7" ? 1 : 2
            height: font === "5x7" ? 7 : 5
            text: task.t.text ?? ""
            color: task.tone
        }
        // Done: struck through.
        Rectangle {
            visible: !!task.t.done
            x: words.x
            y: words.y + Math.floor(words.height / 2)
            width: Math.min(words.width, String(task.t.text ?? "").length * (words.font === "5x7" ? 6 : 4))
            height: 1
            color: Ink.violet
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
                color: task.t.next ? Ink.hi : Ink.pink
            }
            MatrixText {
                width: implicitWidth
                height: 5
                font: "3x5"
                text: String(task.t.due ?? "")
                color: task.t.next ? Ink.hi : Ink.violet
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
            readonly property real wellY: win.bodyY + 6
            readonly property real wellH: height - wellY - 8
            readonly property int x0: Math.ceil(18 / p)
            readonly property int w0: Math.floor((width - 36) / p)
            readonly property int listY: Math.ceil((wellY + 6) / p)
            readonly property int addY: Math.floor((wellY + wellH - 4) / p) - 8
            readonly property int rowsN: Math.max(0, Math.min(root.today.length, Math.floor((addY - listY - 1) / root.rowH)))

            Well {
                x: 8
                y: u.wellY
                width: parent.width - 16
                height: u.wellH
                paper: true
            }
            Repeater {
                model: root.today.slice(0, u.rowsN)
                Glow {
                    required property var modelData
                    required property int index
                    visible: !!modelData.next
                    x: (u.x0 - 1) * u.p
                    y: (u.listY + index * root.rowH) * u.p - 2
                    width: (u.w0 + 2) * u.p
                    height: root.rowH * u.p
                }
            }
            Dots {
                anchors.fill: parent
                Repeater {
                    model: root.today.slice(0, u.rowsN)
                    Task {
                        required property var modelData
                        required property int index
                        x: u.x0
                        y: u.listY + index * root.rowH
                        width: u.w0
                        t: modelData
                    }
                }
                MatrixText {
                    visible: root.today.length === 0
                    x: u.x0
                    y: u.listY + 1
                    width: implicitWidth
                    height: 7
                    text: root.words.empty || "ALL DONE"
                    color: Ink.violet
                }
                MatrixText {
                    x: u.x0 + 1
                    y: u.addY + 1
                    width: 3
                    height: 7
                    text: "|"
                    color: Ink.pink
                }
                T.Field {
                    x: u.x0 + 5
                    y: u.addY
                    width: u.w0 - 5
                    height: 8
                    hint: root.words.add || "+ ADD A TASK"
                    action: "todo add {value}"
                    color: Ink.ink
                    hintColor: Ink.violet
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
            readonly property real wellY: win.bodyY + 6
            readonly property real wellH: height - wellY - 8
            readonly property real sideW: Math.round(width * 0.24)
            readonly property real mainX: 8 + sideW + 14
            readonly property real mainW: width - mainX - 18
            readonly property int x0: Math.ceil(mainX / p)
            readonly property int w0: Math.floor(mainW / p)
            readonly property int fieldY: Math.ceil((wellY + 10) / p)
            readonly property int listY: fieldY + 13
            readonly property int footY: Math.floor((wellY + wellH - 6) / p) - 5
            readonly property int rowsN: Math.max(0, Math.min(shown.length, Math.floor((footY - listY - 2) / root.rowH)))

            Well {
                x: 8
                y: u.wellY
                width: parent.width - 16
                height: u.wellH
                paper: true
            }
            // The lists, crisp.
            Column {
                x: 14
                y: u.wellY + 8
                width: u.sideW - 6
                spacing: 2
                Repeater {
                    model: u.tabs
                    Item {
                        id: tab
                        required property var modelData
                        readonly property bool on: u.list === modelData.key
                        width: parent.width
                        height: 26
                        Glow {
                            anchors.fill: parent
                            visible: tab.on
                        }
                        Pen {
                            x: 8
                            width: parent.width - 36
                            height: parent.height
                            text: tab.modelData.name
                            size: 18
                            color: tab.on ? Ink.hi : Ink.ink
                        }
                        Pen {
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            height: parent.height
                            text: tab.modelData.count
                            size: 18
                            color: tab.on ? Ink.hi : Ink.ink
                        }
                        T.Hit {
                            anchors.fill: parent
                            onTap: u.list = tab.modelData.key
                        }
                    }
                }
            }
            // The add line's box, and the next task's bar.
            Rectangle {
                x: u.x0 * u.p - 4
                y: u.fieldY * u.p - 4
                width: u.w0 * u.p + 8
                height: 10 * u.p + 2
                color: "transparent"
                border.width: 1
                border.color: Ink.shade
            }
            Repeater {
                model: u.shown.slice(0, u.rowsN)
                Glow {
                    required property var modelData
                    required property int index
                    visible: !!modelData.next
                    x: u.x0 * u.p - 4
                    y: (u.listY + index * root.rowH) * u.p - 2
                    width: u.w0 * u.p + 8
                    height: root.rowH * u.p
                }
            }
            Dots {
                anchors.fill: parent
                // + match mp3 to yt video +dotfiles due:fri !high
                MatrixText {
                    x: u.x0
                    y: u.fieldY + 1
                    width: 5
                    height: 7
                    text: "+"
                    color: Ink.pink
                }
                T.Field {
                    x: u.x0 + 7
                    y: u.fieldY
                    width: u.w0 - 8
                    height: 8
                    hint: "ADD WITH +LIST DUE:FRI !HIGH"
                    color: Ink.ink
                    hintColor: Ink.violet
                    action: "todo add {value}" + (u.list ? " +" + u.list : "")
                }
                Repeater {
                    model: u.shown.slice(0, u.rowsN)
                    Task {
                        required property var modelData
                        required property int index
                        x: u.x0
                        y: u.listY + index * root.rowH
                        width: u.w0
                        showPrio: true
                        t: modelData
                    }
                }
                MatrixText {
                    visible: u.shown.length === 0
                    x: u.x0
                    y: u.listY + 1
                    width: implicitWidth
                    height: 7
                    text: root.words.empty || "ALL DONE"
                    color: Ink.violet
                }
                MatrixText {
                    x: u.x0
                    y: u.footY
                    width: u.w0
                    height: 5
                    font: "3x5"
                    scroll: true
                    text: "File Edit Search Help · " + u.shown.filter(t => !t.done).length + " left of " + u.shown.length
                    color: Ink.violet
                }
            }
        }
    }
}
