import QtQuick
import qs
import qs.tokyo as T

// Todo, VFD: today's tasks on the head unit's display, each behind a round
// lamp (lit cyan once done, the text dimmed to teal), the next one outlined
// in amber, its due day in amber at the right; a line to add one. Expanded,
// the lists down the side (the picked one amber) and the picked list's
// tasks, with their priority.
T.Face {
    id: root

    readonly property var today: ctx.today ?? []
    readonly property var all: ctx.items ?? []
    readonly property var lists: ctx.lists ?? []
    readonly property int rowH: 8

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : list
    }

    // One task: lamp, text, priority, when it is due. In dots.
    component Task: Item {
        id: task
        property var t: ({})
        property bool showPrio: false
        readonly property string prio: ({ "!": "HIGH", ":": "MED", ".": "LOW" })[t.prio ?? ""] ?? ""
        height: root.rowH
        // The lamp: a dark disc in a teal ring; done, lit cyan.
        Rectangle {
            x: 1
            y: 1
            width: 6
            height: 6
            radius: 3
            color: task.t.done ? Ink.cyan : Ink.glass
            border.width: task.t.done ? 0 : 1
            border.color: Ink.teal
        }
        MatrixText {
            x: 10
            y: 2
            width: parent.width - x - right.implicitWidth - 4
            height: 5
            font: "3x5"
            text: task.t.text ?? ""
            color: task.t.done ? Ink.teal : Ink.cyan
        }
        MatrixText {
            id: right
            anchors.right: parent.right
            y: 2
            width: implicitWidth
            height: 5
            font: "3x5"
            text: [task.showPrio ? task.prio : "", String(task.t.due ?? "").toUpperCase()].filter(x => x).join(" ")
            color: Ink.amber
        }
        T.Hit {
            anchors.fill: parent
            action: "todo toggle " + task.t.n
        }
    }

    // ── Compact ─────────────────────────────────────────────────────
    Component {
        id: list
        Unit {
            id: u
            readonly property int padX: 4
            readonly property int listY: 10
            readonly property int rowsN: Math.max(0, Math.min(root.today.length, Math.floor((rows - listY - 13) / root.rowH)))
            readonly property int nextAt: root.today.slice(0, rowsN).findIndex(t => t.next)

            // TASK 2/5 · TODAY                         3 LEFT
            MatrixText {
                x: u.padX
                y: 3
                width: u.cols - u.padX * 2 - left.implicitWidth - 4
                height: 5
                font: "3x5"
                text: (u.nextAt >= 0 ? "TASK " + (u.nextAt + 1) + "/" + root.today.length + " · " : "") + (root.words.title || "TODAY")
                color: Ink.teal
            }
            MatrixText {
                id: left
                anchors.right: parent.right
                anchors.rightMargin: u.padX
                y: 3
                width: implicitWidth
                height: 5
                font: "3x5"
                text: (root.ctx.left ?? 0) + " " + (root.words.left || "LEFT")
                color: Ink.teal
            }
            Column {
                x: u.padX + 2
                y: u.listY
                width: u.cols - u.padX * 2 - 4
                Repeater {
                    model: root.today.slice(0, u.rowsN)
                    Task {
                        required property var modelData
                        width: parent.width
                        t: modelData
                    }
                }
            }
            MatrixText {
                visible: root.today.length === 0
                anchors.centerIn: parent
                width: implicitWidth
                height: implicitHeight
                text: root.words.empty || "ALL DONE"
                color: Ink.teal
            }
            T.Field {
                x: u.padX + 2
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 2
                width: u.cols - u.padX * 2 - 4
                height: 11
                hint: root.words.add || "+ ADD A TASK"
                action: "todo add {value}"
                hintColor: Ink.teal
            }

            over: Box {
                visible: u.nextAt >= 0
                dx: u.padX
                dy: u.listY + u.nextAt * root.rowH
                dw: u.cols - u.padX * 2
                dh: root.rowH
                border.color: Ink.amber
            }
        }
    }

    // ── Expanded: lists ─────────────────────────────────────────────
    Component {
        id: board
        Unit {
            id: u
            property string list: ""
            readonly property var tabs: [{ name: root.words.title || "TODAY", key: "", count: root.ctx.left ?? 0 }].concat(root.lists.map(l => ({ name: String(l.name).toUpperCase(), key: l.name, count: l.count })))
            readonly property var shown: list === "" ? root.today : root.all.filter(t => (t.lists ?? []).includes(list))
            readonly property int padX: 4
            readonly property int sideW: Math.round(cols * 0.22)
            readonly property int mainX: padX + sideW + 4
            readonly property int mainW: cols - mainX - padX
            readonly property int listY: 18
            readonly property int rowsN: Math.max(0, Math.min(shown.length, Math.floor((rows - listY - 9) / root.rowH)))
            readonly property int nextAt: shown.slice(0, rowsN).findIndex(t => t.next)

            // + match mp3 to yt video +dotfiles due:fri !high
            MatrixText {
                x: u.mainX + 3
                y: 6
                height: 5
                font: "3x5"
                text: "+"
                color: Ink.amber
            }
            T.Field {
                x: u.mainX + 9
                y: 3
                width: u.mainW - 12
                height: 11
                hint: "ADD A TASK  +LIST DUE:FRI !HIGH"
                hintColor: Ink.teal
                action: "todo add {value}" + (u.list ? " +" + u.list : "")
            }
            Column {
                x: u.mainX + 2
                y: u.listY
                width: u.mainW - 4
                Repeater {
                    model: u.shown.slice(0, u.rowsN)
                    Task {
                        required property var modelData
                        width: parent.width
                        showPrio: true
                        t: modelData
                    }
                }
            }
            MatrixText {
                visible: u.shown.length === 0
                x: u.mainX + 3
                y: u.listY + 2
                width: implicitWidth
                height: implicitHeight
                text: root.words.empty || "ALL DONE"
                color: Ink.teal
            }
            MatrixText {
                x: u.mainX
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3
                width: u.mainW
                height: 5
                font: "3x5"
                scroll: true
                text: "CLICK A LAMP TO CHECK IT · ENTER ADDS · +LIST DUE:FRI !HIGH"
                color: Ink.teal
            }

            // Crisp: the lists, the add line's rule, the next task.
            over: [
                Column {
                    x: u.px(u.padX)
                    y: u.px(3)
                    width: u.px(u.sideW)
                    spacing: 2
                    Repeater {
                        model: u.tabs
                        Item {
                            required property var modelData
                            readonly property color ink: u.list === modelData.key ? Ink.amber : Ink.teal
                            width: parent.width
                            height: 16
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 20
                                elide: Text.ElideRight
                                text: parent.modelData.name
                                color: parent.ink
                                font.family: Tokens.font
                                font.pixelSize: 11
                                font.letterSpacing: 1
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: parent.modelData.count
                                color: parent.ink
                                opacity: 0.7
                                font.family: Tokens.font
                                font.pixelSize: 11
                            }
                            T.Hit {
                                anchors.fill: parent
                                onTap: u.list = parent.modelData.key
                            }
                        }
                    }
                },
                Box {
                    dx: u.mainX
                    dy: 3
                    dw: u.mainW
                    dh: 11
                    border.color: Ink.cyan
                },
                Box {
                    visible: u.nextAt >= 0
                    dx: u.mainX
                    dy: u.listY + u.nextAt * root.rowH
                    dw: u.mainW
                    dh: root.rowH
                    border.color: Ink.amber
                }
            ]
        }
    }
}
