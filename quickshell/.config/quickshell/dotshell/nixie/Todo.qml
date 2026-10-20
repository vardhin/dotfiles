import QtQuick
import qs
import qs.tokyo as T

// Todo, Nixie: an ivory pad in the walnut case. "Today" and what is left
// glowing at its head, then each task in dark dots: its box (a red ✕ once
// done, the words faded), its day at the right, ruled lines between, the
// next one washed orange. A click checks a task; the line at the foot adds
// one. Expanded, LISTS: the pad across the case, the lists down the side in
// Nixie One (the picked one on a polished brass tab), the add line boxed at
// the top, and the picked list's tasks with their priority.
T.Face {
    id: root

    readonly property var today: ctx.today ?? []
    readonly property var all: ctx.items ?? []
    readonly property var lists: ctx.lists ?? []
    readonly property int due: today.filter(t => !t.done).length

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : list
    }

    // A task: the wash and the rule (crisp), and in dots its box, its words,
    // its priority and its day.
    component Line: Item {
        id: line
        property var t: ({})
        property bool showPrio: false
        readonly property int p: Tokens.pitch
        readonly property string prio: ({ "!": "!HIGH", ":": "!MED", ".": "!LOW" })[t.prio ?? ""] ?? ""
        Rectangle {
            anchors.fill: parent
            visible: !!line.t.next
            color: Ink.paperPick
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Ink.paperLo
        }
        Dots {
            id: ink
            anchors.fill: parent
            soft: true
            readonly property int midY: Math.floor((rows - 7) / 2)
            Rectangle {
                x: 1
                y: ink.midY - 1
                width: 9
                height: 9
                color: "transparent"
                border.width: 1
                border.color: Ink.woodB
            }
            MatrixText {
                visible: !!line.t.done
                x: 3
                y: ink.midY
                width: 5
                height: 7
                text: "×"
                color: Ink.deep
            }
            MatrixText {
                x: 14
                y: ink.midY
                width: ink.cols - x - right.implicitWidth - 4
                height: 7
                scroll: true
                text: line.t.text ?? ""
                color: line.t.done ? Ink.paperDone : Ink.paperInk
            }
            Row {
                id: right
                x: ink.cols - width - 1
                y: ink.midY + 1
                spacing: 4
                MatrixText {
                    visible: line.showPrio && line.prio !== ""
                    width: implicitWidth
                    height: 5
                    font: "3x5"
                    text: line.prio
                    color: Ink.deep
                }
                MatrixText {
                    width: implicitWidth
                    height: 5
                    font: "3x5"
                    text: String(line.t.due ?? "")
                    color: Ink.paperSoft
                }
            }
        }
        T.Hit {
            anchors.fill: parent
            action: "todo toggle " + line.t.n
        }
    }

    // ── Compact: the pad ────────────────────────────────────────────
    Component {
        id: list
        Item {
            id: u
            readonly property int p: Tokens.pitch
            readonly property real headH: Math.max(9 * p, Math.min(24, height * 0.16))
            readonly property real rowH: 11 * p
            readonly property real addH: 9 * p
            readonly property real listY: 10 + headH + 4
            readonly property int rowsN: Math.max(0, Math.min(root.today.length, Math.floor((pad.height - listY - addH - 6) / rowH)))

            Wood {
                anchors.fill: parent
            }
            Paper {
                id: pad
                x: 12
                y: 12
                width: parent.width - 24
                height: parent.height - 24
                Dots {
                    x: 12
                    y: 8
                    width: parent.width - 24
                    height: u.headH
                    soft: true
                    Word {
                        width: implicitWidth
                        height: parent.height
                        dots: height
                        text: root.words.title || "Today"
                        color: Ink.woodB
                    }
                    Word {
                        x: parent.width - width
                        width: implicitWidth
                        height: parent.height
                        dots: height
                        text: root.due + " left"
                        color: Ink.woodB
                    }
                }
                Column {
                    x: 12
                    y: u.listY
                    width: parent.width - 24
                    Repeater {
                        model: root.today.slice(0, u.rowsN)
                        Line {
                            required property var modelData
                            width: parent.width
                            height: u.rowH
                            t: modelData
                        }
                    }
                }
                Dots {
                    x: 12
                    y: u.listY + u.rowsN * u.rowH + 3
                    width: parent.width - 24
                    height: u.addH
                    soft: true
                    MatrixText {
                        visible: root.today.length === 0
                        y: -9
                        width: implicitWidth
                        height: 7
                        text: root.words.empty || "ALL DONE"
                        color: Ink.paperSoft
                    }
                    MatrixText {
                        y: 2
                        width: 5
                        height: 5
                        font: "3x5"
                        text: "+"
                        color: Ink.paperSoft
                    }
                    T.Field {
                        x: 6
                        y: 1
                        width: parent.cols - 6
                        height: 7
                        hint: root.words.add || "TYPE A NEW LINE…"
                        action: "todo add {value}"
                        color: Ink.paperInk
                        hintColor: Ink.paperSoft
                    }
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
            readonly property real sideW: Math.round(pad.width * 0.26)
            readonly property real mainX: 12 + sideW + 14
            readonly property real mainW: pad.width - mainX - 12
            readonly property real fieldH: 11 * p
            readonly property real rowH: 11 * p
            readonly property real listY: 12 + fieldH + 6
            readonly property real footY: pad.height - 8 - 5 * p
            readonly property int rowsN: Math.max(0, Math.min(shown.length, Math.floor((footY - 4 - listY) / rowH)))

            Wood {
                anchors.fill: parent
            }
            Paper {
                id: pad
                x: 12
                y: 12
                width: parent.width - 24
                height: parent.height - 24

                // The lists, Nixie One on the paper; the picked one on brass.
                Column {
                    x: 10
                    y: 12
                    width: u.sideW
                    spacing: 4
                    Repeater {
                        model: u.tabs
                        Item {
                            id: tab
                            required property var modelData
                            readonly property bool on: u.list === modelData.key
                            width: parent.width
                            height: 24
                            Key {
                                anchors.fill: parent
                                visible: tab.on
                                on: true
                            }
                            Text {
                                x: 12
                                width: parent.width - 40
                                height: parent.height
                                verticalAlignment: Text.AlignVCenter
                                text: tab.modelData.name
                                color: tab.on ? Ink.paperInk : Ink.woodB
                                font.family: Ink.family
                                font.pixelSize: 16
                                elide: Text.ElideRight
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                height: parent.height
                                verticalAlignment: Text.AlignVCenter
                                text: tab.modelData.count
                                color: tab.on ? Ink.paperInk : Ink.woodB
                                font.family: Ink.family
                                font.pixelSize: 16
                            }
                            T.Hit {
                                anchors.fill: parent
                                onTap: u.list = tab.modelData.key
                            }
                        }
                    }
                }
                // The add line, boxed.
                Rectangle {
                    x: u.mainX
                    y: 12
                    width: u.mainW
                    height: u.fieldH
                    color: Ink.paperHi
                    border.width: 1
                    border.color: Ink.paperLo
                    Rectangle {
                        width: parent.width
                        height: 3
                        color: Ink.c(Qt.rgba(0, 0, 0, 0.08), Qt.rgba(0, 0, 0, 0.05))
                    }
                }
                Dots {
                    x: u.mainX + 6
                    y: 12 + Math.round((u.fieldH - 7 * u.p) / 2)
                    width: u.mainW - 12
                    height: 7 * u.p
                    soft: true
                    MatrixText {
                        y: 1
                        width: 5
                        height: 5
                        font: "3x5"
                        text: "+"
                        color: Ink.paperSoft
                    }
                    T.Field {
                        x: 6
                        width: Math.floor((u.mainW - 12) / u.p) - 6
                        height: 7
                        hint: "ADD WITH +LIST DUE:FRI !HIGH"
                        color: Ink.paperInk
                        hintColor: Ink.paperSoft
                        action: "todo add {value}" + (u.list ? " +" + u.list : "")
                    }
                }
                Column {
                    x: u.mainX
                    y: u.listY
                    width: u.mainW
                    Repeater {
                        model: u.shown.slice(0, u.rowsN)
                        Line {
                            required property var modelData
                            width: parent.width
                            height: u.rowH
                            showPrio: true
                            t: modelData
                        }
                    }
                }
                Dots {
                    x: u.mainX
                    y: u.listY
                    width: u.mainW
                    height: pad.height - u.listY - 4
                    soft: true
                    MatrixText {
                        visible: u.shown.length === 0
                        y: 2
                        width: implicitWidth
                        height: 7
                        text: root.words.empty || "ALL DONE"
                        color: Ink.paperSoft
                    }
                    MatrixText {
                        y: Math.floor((u.footY - u.listY) / u.p)
                        width: parent.cols
                        height: 5
                        font: "3x5"
                        scroll: true
                        text: u.shown.filter(t => !t.done).length + " LEFT OF " + u.shown.length + " · ENTER ADDS · CLICK CHECKS"
                        color: Ink.paperSoft
                    }
                }
            }
        }
    }
}
