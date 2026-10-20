import QtQuick
import qs
import qs.tokyo as T

// Todo, 90s Nights: a page of ruled notebook paper in the sunset rim, the
// pink margin down its left. TO DO!! and what is left (♥) at its head in
// pink → blue dots, then a task on each ruled line: its blue box (a pink
// ✓ once done, the words faded and struck through in pink), its day at the
// right in pink, the next one highlighted yellow. A click checks a task;
// the line at the foot adds one. Expanded, LISTS: the lists down the
// margin (the picked one on a leaning yellow slab), the add line boxed in
// blue at the top, and the picked list's tasks with their priority.
T.Face {
    id: root

    readonly property var today: ctx.today ?? []
    readonly property var all: ctx.items ?? []
    readonly property var lists: ctx.lists ?? []
    readonly property int due: today.filter(t => !t.done).length

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : page
    }

    // A task on its ruled line: the highlight and the strike (crisp), in
    // dots its box, words, priority and day.
    component Line: Item {
        id: line
        property var t: ({})
        property bool showPrio: false
        readonly property int p: Tokens.pitch
        readonly property string prio: ({ "!": "!HIGH", ":": "!MED", ".": "!LOW" })[t.prio ?? ""] ?? ""
        Rectangle {
            anchors.fill: parent
            anchors.bottomMargin: 1
            visible: !!line.t.next
            color: Ink.highlight
        }
        Dots {
            id: ink
            anchors.fill: parent
            soft: true
            readonly property int midY: Math.floor((rows - 7) / 2)
            Box {
                y: ink.midY
                size: 7
                done: !!line.t.done
            }
            MatrixText {
                id: words
                x: 10
                y: ink.midY
                width: ink.cols - x - right.implicitWidth - 4
                height: 7
                scroll: true
                text: line.t.text ?? ""
                color: line.t.done ? Ink.paperDone : Ink.paperInk
            }
            // Struck through in pink.
            Rectangle {
                visible: !!line.t.done
                x: words.x
                y: ink.midY + 3
                width: Math.min(words.width, words.implicitWidth)
                height: 1
                color: Ink.pink
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
                    color: Ink.pink
                }
                MatrixText {
                    width: implicitWidth
                    height: 5
                    font: "3x5"
                    text: String(line.t.due ?? "")
                    color: Ink.pink
                }
            }
        }
        T.Hit {
            anchors.fill: parent
            action: "todo toggle " + line.t.n
        }
    }

    // ── Compact: the page ───────────────────────────────────────────
    Component {
        id: page
        Item {
            id: u
            readonly property int p: Tokens.pitch
            // One task per ruled line.
            readonly property real rowH: 8 * p
            readonly property real headY: 3 + 6
            readonly property real listY: headY + rowH
            readonly property int rowsN: Math.max(0, Math.min(root.today.length, Math.floor((height - 3 - listY - rowH - 4) / rowH)))
            // A line's left and right at height y: past the margin, inside the slant.
            function lx(y: real): real {
                return plate.leftAt(y) + 40;
            }
            function rx(y: real): real {
                return plate.rightAt(y) - 12;
            }

            Plate {
                id: plate
                anchors.fill: parent
                paper: true
            }
            // The ruling, cut to the page; the margin leans with it.
            Ruled {
                parent: plate.inside
                x: 3
                y: 3
                width: u.width - 6
                height: u.height - 6
                step: u.rowH
                from: u.listY - 3 + u.rowH
                margin: 0
            }
            Rectangle {
                id: margin
                parent: plate.inside
                x: plate.leftAt(u.height / 2) + 28
                width: 1
                height: u.height
                color: Ink.paperMargin
                antialiasing: true
                transform: Lean {
                    item: margin
                }
            }
            Dots {
                x: u.lx(u.headY + u.rowH)
                y: u.headY
                width: u.rx(u.headY) - x
                height: u.rowH
                soft: true
                Word {
                    width: implicitWidth
                    height: parent.height
                    dots: 7
                    fontAt: 99
                    text: root.words.title || "TO DO!!"
                    stops: [[0, Ink.pink], [1, Ink.blue]]
                }
                Word {
                    x: parent.width - width
                    width: implicitWidth
                    height: parent.height
                    dots: 7
                    fontAt: 99
                    text: root.due + " left ♥"
                    stops: [[0, Ink.pink], [1, Ink.blue]]
                }
            }
            Repeater {
                model: root.today.slice(0, u.rowsN)
                Line {
                    required property var modelData
                    required property int index
                    readonly property real rowTop: u.listY + index * u.rowH
                    x: u.lx(rowTop + u.rowH)
                    y: rowTop
                    width: u.rx(rowTop) - x
                    height: u.rowH
                    t: modelData
                }
            }
            Dots {
                readonly property real rowTop: u.listY + u.rowsN * u.rowH
                x: u.lx(rowTop + u.rowH)
                y: rowTop
                width: u.rx(rowTop) - x
                height: u.rowH
                soft: true
                T.Field {
                    x: 0
                    y: 1
                    width: parent.width
                    height: 7
                    hint: root.words.add || "+ NEW THING TO DO…"
                    action: "todo add {value}"
                    color: Ink.paperInk
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
            readonly property var tabs: [{ name: root.words.title || "Today", key: "", count: root.ctx.left ?? 0 }].concat(root.lists.map(l => ({ name: String(l.name), key: l.name, count: l.count })))
            readonly property var shown: list === "" ? root.today : root.all.filter(t => (t.lists ?? []).includes(list))
            readonly property int p: Tokens.pitch
            readonly property real rowH: 8 * p
            readonly property real sideX: 3 + 40
            readonly property real sideW: Math.round(width * 0.22)
            readonly property real mainX: sideX + sideW + 14
            readonly property real mainW: width - mainX - 3 - 12
            readonly property real fieldH: 9 * p
            readonly property real listY: 3 + 8 + fieldH + 4
            readonly property real footY: height - 3 - 6 - 5 * p
            readonly property int rowsN: Math.max(0, Math.min(shown.length, Math.floor((footY - 4 - listY) / rowH)))

            Plate {
                anchors.fill: parent
                slant: false
                paper: true
            }
            Ruled {
                x: 3
                y: 3
                width: parent.width - 6
                height: parent.height - 6
                step: u.rowH
                from: u.listY - 3 + u.rowH
                margin: 30
            }

            // The lists down the margin; the picked one on a yellow slab.
            Column {
                x: u.sideX
                y: 9
                width: u.sideW
                spacing: 4
                Repeater {
                    model: u.tabs
                    Item {
                        id: tab
                        required property var modelData
                        readonly property bool on: u.list === modelData.key
                        width: parent.width
                        height: 18
                        Rectangle {
                            id: slab
                            anchors.fill: parent
                            visible: tab.on
                            color: Ink.yellow
                            antialiasing: true
                            transform: Lean {
                                item: slab
                            }
                        }
                        Pen {
                            x: 6
                            width: parent.width - 30
                            height: parent.height
                            text: tab.modelData.name
                            size: 10
                            slanted: tab.on
                            color: tab.on ? Ink.night : Ink.blue
                        }
                        Pen {
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            height: parent.height
                            text: tab.modelData.count
                            size: 10
                            color: tab.on ? Ink.night : Ink.blue
                            opacity: 0.7
                        }
                        T.Hit {
                            anchors.fill: parent
                            onTap: u.list = tab.modelData.key
                        }
                    }
                }
            }
            // The add line, boxed in blue.
            Rectangle {
                x: u.mainX
                y: 9
                width: u.mainW
                height: u.fieldH
                color: Ink.paper
                border.width: 2
                border.color: Ink.blue
            }
            Dots {
                x: u.mainX + 6
                y: 9 + Math.round((u.fieldH - 7 * u.p) / 2)
                width: u.mainW - 12
                height: 7 * u.p
                soft: true
                MatrixText {
                    y: 1
                    width: 5
                    height: 5
                    font: "3x5"
                    text: "+"
                    color: Ink.pink
                }
                T.Field {
                    x: 6
                    width: Math.floor((u.mainW - 12) / u.p) - 6
                    height: 7
                    hint: "ADD WITH +LIST DUE:FRI !HIGH"
                    color: Ink.paperInk
                    hintColor: Ink.paperDone
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
                id: foot
                x: u.sideX
                y: u.listY
                width: u.width - u.sideX - 15
                height: u.height - u.listY - 4
                soft: true
                MatrixText {
                    visible: u.shown.length === 0
                    x: Math.round((u.mainX - u.sideX) / u.p)
                    y: 2
                    width: implicitWidth
                    height: 7
                    text: root.words.empty || "ALL DONE ♥"
                    color: Ink.paperDone
                }
                MatrixText {
                    y: Math.floor((u.footY - u.listY) / u.p)
                    width: foot.cols
                    height: 5
                    font: "3x5"
                    scroll: true
                    text: u.shown.filter(t => !t.done).length + " LEFT OF " + u.shown.length + " · QUICK-ADD: +LIST DUE:FRI !HIGH · ENTER ADDS · CLICK CHECKS"
                    color: Ink.blue
                }
            }
        }
    }
}
