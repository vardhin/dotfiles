import QtQuick
import qs

// Todo, Tokyo Night: today's tasks, each behind a neon ring (lit cyan once
// done, the text struck), the next one glowing; a line to add one.
// Expanded, the lists down the side and the picked list's tasks.
Face {
    id: root

    readonly property var today: ctx.today ?? []
    readonly property var all: ctx.items ?? []
    readonly property var lists: ctx.lists ?? []

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : sign
    }

    // One task: ring, text, when it is due. In dots.
    component Task: Item {
        id: task
        property var t: ({})
        property int textW: width - 10
        height: 7
        // The ring: a pink circle; done, a lit cyan disc.
        Rectangle {
            width: 7
            height: 7
            radius: 3.5
            color: task.t.done ? Ink.cyan : "transparent"
            border.width: 1
            border.color: task.t.done ? Ink.cyan : Ink.pink
        }
        MatrixText {
            id: label
            x: 10
            y: 1
            width: Math.min(implicitWidth, task.textW - due.implicitWidth - 3)
            height: 5
            font: "3x5"
            text: task.t.text ?? ""
            color: Ink.pink
            opacity: task.t.done ? 0.45 : 1
        }
        Rectangle {
            visible: !!task.t.done
            x: label.x
            y: 3
            width: label.width
            height: 1
            color: Ink.pink
            opacity: 0.6
        }
        MatrixText {
            id: due
            anchors.right: parent.right
            y: 1
            height: 5
            font: "3x5"
            text: String(task.t.due ?? "").toLowerCase()
            color: Ink.violet
        }
        Hit {
            anchors.fill: parent
            action: "todo toggle " + task.t.n
        }
    }

    // ── Compact ─────────────────────────────────────────────────────
    Component {
        id: sign
        Item {
            id: s
            readonly property int rowsN: Math.max(0, Math.min(root.today.length, Math.floor((glass.rows - 4 - 9 - 13) / 9)))
            // Dot glass across the whole sign, as on the media sign.
            Glass {
                radius: Ink.curve
            }
            Item {
                anchors.fill: parent
                anchors.leftMargin: 48
                anchors.rightMargin: 48
                anchors.topMargin: 22
                anchors.bottomMargin: 22
                Glass {
                    id: glass
                    radius: 4
                    Words {
                        x: 1
                        y: 1
                        small: true
                        room: glass.cols - 2 - leftWord.implicitWidth - 4
                        text: "今日 · " + (root.words.title || "TODAY")
                        color: Ink.violet
                    }
                    Words {
                        id: leftWord
                        anchors.right: parent.right
                        anchors.rightMargin: 1
                        y: 1
                        small: true
                        text: (root.ctx.left ?? 0) + " " + (root.words.left || "LEFT")
                        color: Ink.violet
                    }
                    Column {
                        x: 1
                        y: 11
                        width: glass.cols - 2
                        spacing: 2
                        Repeater {
                            model: root.today.slice(0, s.rowsN)
                            Task {
                                required property var modelData
                                width: parent.width
                                t: modelData
                                // The next one glows.
                                opacity: 1
                            }
                        }
                    }
                    Words {
                        visible: root.today.length === 0
                        anchors.centerIn: parent
                        text: root.words.empty || "ALL DONE"
                        color: Ink.deep
                    }
                    Field {
                        x: 1
                        anchors.bottom: parent.bottom
                        width: glass.cols - 2
                        height: Tokens.lineDots
                        hint: (root.words.add || "+ ADD A TASK").toLowerCase()
                        action: "todo add {value}"
                        color: Ink.pink
                        hintColor: Ink.cyan
                    }
                }
                // The next task glows cyan behind its ring.
                Repeater {
                    model: root.today.slice(0, s.rowsN)
                    Tube {
                        required property var modelData
                        required property int index
                        visible: !!modelData.next
                        x: glass.x + 1 * root.pitch - 2
                        y: glass.y + (11 + index * 9) * root.pitch - 2
                        width: 7 * root.pitch + 4
                        height: width
                        radius: width / 2
                        line: 1
                        tint: Ink.cyan
                        glow: 1
                        opacity: 0.8
                    }
                }
            }
            Sign {
                radius: Ink.curve
                inner: true
            }
        }
    }

    // ── Expanded: lists ─────────────────────────────────────────────
    Component {
        id: board
        Item {
            id: b
            property string list: ""
            readonly property var tabs: [{ name: root.words.title || "TODAY", key: "", count: root.ctx.left ?? 0 }].concat(root.lists.map(l => ({ name: String(l.name).toUpperCase(), key: l.name, count: l.count })))
            readonly property var shown: list === "" ? root.today : root.all.filter(t => (t.lists ?? []).includes(list))
            readonly property int sideW: Math.round(glass.cols * 0.27)
            readonly property int rowsN: Math.max(0, Math.min(shown.length, Math.floor((glass.rows - 4 - 17 - 9) / 9)))

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: 28
                color: Ink.glass
            }
            Item {
                anchors.fill: parent
                anchors.margins: 14
                Glass {
                    id: glass
                    radius: 6
                    // The tabs' counts and names (pink), the picked one lit.
                    Repeater {
                        model: b.tabs.slice(0, Math.floor((glass.rows - 4) / 12))
                        Item {
                            required property var modelData
                            required property int index
                            readonly property bool on: b.list === modelData.key
                            x: 2
                            y: 2 + index * 12
                            width: b.sideW - 4
                            height: 9
                            visible: !on
                            MatrixText {
                                x: 4
                                y: 2
                                width: parent.width - 16
                                height: 5
                                font: "3x5"
                                text: modelData.name
                                color: Ink.pink
                            }
                            MatrixText {
                                anchors.right: parent.right
                                anchors.rightMargin: 4
                                y: 2
                                height: 5
                                font: "3x5"
                                text: modelData.count
                                color: Ink.pink
                            }
                        }
                    }
                    Item {
                        x: b.sideW + 3
                        y: 2
                        width: glass.cols - b.sideW - 6
                        height: glass.rows - 4
                        Field {
                            x: 3
                            y: 1
                            width: parent.width - 6
                            height: Tokens.lineDots
                            hint: (root.words.add || "+ ADD A TASK").toLowerCase()
                            action: "todo add {value}" + (b.list ? " +" + b.list : "")
                            color: Ink.pink
                            hintColor: Ink.pink
                        }
                        Column {
                            x: 3
                            y: 18
                            width: parent.width - 6
                            spacing: 2
                            Repeater {
                                model: b.shown.slice(0, b.rowsN)
                                Task {
                                    required property var modelData
                                    width: parent.width
                                    t: Object.assign({}, modelData, { due: [(modelData.lists ?? []).filter(l => l !== b.list).map(l => "+" + l).join(" "), modelData.due].filter(x => x).join("  ") })
                                }
                            }
                        }
                        Words {
                            visible: b.shown.length === 0
                            anchors.centerIn: parent
                            text: root.words.empty || "ALL DONE"
                            color: Ink.deep
                        }
                        MatrixText {
                            x: 3
                            anchors.bottom: parent.bottom
                            width: parent.width - 6
                            height: 5
                            font: "3x5"
                            scroll: true
                            text: "QUICK-ADD: +LIST DUE:FRI !HIGH · ENTER ADDS · CLICK A RING TO CHECK IT"
                            color: Ink.violet
                        }
                    }
                }
                // Crisp: the picked tab's fill, the add line's rim.
                Repeater {
                    model: b.tabs.slice(0, Math.floor((glass.rows - 4) / 12))
                    Item {
                        required property var modelData
                        required property int index
                        x: glass.x + 2 * root.pitch
                        y: glass.y + (2 + index * 12) * root.pitch
                        width: (b.sideW - 4) * root.pitch
                        height: 9 * root.pitch
                        Tube {
                            anchors.fill: parent
                            visible: b.list === parent.modelData.key
                            radius: height / 2
                            line: 0
                            fill: Ink.cyan
                            tint: Ink.cyan
                            glow: 0.6
                            Text {
                                x: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: parent.parent.modelData.name
                                color: Ink.glass
                                font.family: Ink.family
                                font.pixelSize: 12
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: parent.parent.modelData.count
                                color: Ink.glass
                                font.family: Ink.family
                                font.pixelSize: 12
                            }
                        }
                        Hit {
                            anchors.fill: parent
                            onTap: b.list = parent.modelData.key
                        }
                    }
                }
                Tube {
                    x: glass.x + (b.sideW + 4) * root.pitch
                    y: glass.y + 2 * root.pitch
                    width: (glass.cols - b.sideW - 6 - 2) * root.pitch
                    height: 15 * root.pitch
                    radius: height / 2
                    line: 2
                    tint: Ink.cyan
                    glow: 0.8
                }
            }
            Sign {
                radius: 28
                inner: true
            }
        }
    }
}
