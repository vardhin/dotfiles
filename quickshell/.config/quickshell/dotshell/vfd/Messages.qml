import QtQuick
import QtQuick.Effects
import qs
import qs.services
import qs.tokyo as T

// Messages, VFD: an answering machine. The display shows the new count in
// big amber dots, the message you are on (its app and what it said) and
// where it sits in the tape; beside it a red lamp that is lit while
// something is new, and the machine's keys: PLAY (the message centre),
// SKIP (the next one), ERASE (this one). Do not disturb dims the whole
// machine. Expanded, the history grouped by app in ruled cards; a
// notification still on screen offers its own actions as keys.
T.Face {
    id: root

    readonly property bool dnd: !!ctx.dnd
    readonly property int live: ctx.live ?? 0
    readonly property var items: ctx.items ?? []
    property int at: 0
    readonly property var cur: items[Math.min(at, items.length - 1)] ?? null
    onItemsChanged: at = Math.min(at, Math.max(0, items.length - 1))

    function ago(ts: real): string {
        const d = new Date(ts);
        const today = new Date();
        return d.toDateString() === today.toDateString() ? Qt.formatTime(d, "hh:mm") : Qt.formatDate(d, "ddd").toUpperCase();
    }
    // The notification still open for a history entry, if any.
    function liveFor(e: var): var {
        return Notifs.live.find(n => (n.appName || "System") === e.app && (n.summary || n.body || "").trim() === e.summary) ?? null;
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : machine
    }

    // ── Compact: the machine ────────────────────────────────────────
    Component {
        id: machine
        Unit {
            id: u
            opacity: root.dnd ? 0.55 : 1
            side: Math.round(Math.min(110, root.width * 0.28))
            readonly property int padX: 4
            readonly property int size: rows >= 40 ? 3 : 2

            // MSG  NEW  DND
            Row {
                x: u.padX
                y: 3
                spacing: 5
                Repeater {
                    model: [["MSG", true, Ink.cyan], ["NEW", root.live > 0, Ink.amber], ["DND", root.dnd, Ink.cyan]]
                    MatrixText {
                        required property var modelData
                        height: 5
                        font: "3x5"
                        text: modelData[0]
                        color: modelData[1] ? modelData[2] : Ink.ghost
                    }
                }
            }
            // 3   FIREFOX
            //     DOWNLOAD FINISHED
            Digits {
                id: count
                x: u.padX
                y: 10 + Math.max(0, Math.floor((u.rows - 20 - height) / 2))
                width: implicitWidth
                height: implicitHeight
                size: u.size
                cells: 1
                text: Math.min(9, root.live)
                color: root.live > 0 ? Ink.amber : Ink.teal
            }
            Column {
                x: u.padX + count.width + 5
                anchors.verticalCenter: count.verticalCenter
                width: u.cols - x - u.padX
                spacing: 3
                MatrixText {
                    width: parent.width
                    height: 5
                    font: "3x5"
                    text: root.cur?.app ?? ""
                    color: Ink.cyan
                }
                MatrixText {
                    width: parent.width
                    height: 5
                    font: "3x5"
                    scroll: true
                    text: root.cur?.summary ?? (root.words.quiet || "NO MESSAGES")
                    color: Ink.cyan
                }
            }
            // 1/3 · 21:46
            MatrixText {
                x: u.padX
                y: u.rows - 8
                height: 5
                font: "3x5"
                text: root.cur ? (root.at + 1) + "/" + root.items.length + " · " + root.ago(root.cur.ts) : "TAPE EMPTY"
                color: Ink.teal
            }

            rack: Column {
                anchors.fill: parent
                spacing: 6
                readonly property real keyH: (height - 16 - spacing * 3) / 3
                // The lamp.
                Item {
                    width: parent.width
                    height: 16
                    Rectangle {
                        anchors.centerIn: parent
                        width: 10
                        height: 10
                        radius: 5
                        readonly property bool on: root.live > 0 && !root.dnd
                        color: on ? Ink.red : "#5a2a22"
                        layer.enabled: on
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: Ink.red
                            shadowBlur: 0.6
                            blurMax: 14
                            shadowHorizontalOffset: 0
                            shadowVerticalOffset: 0
                        }
                    }
                    T.Hit {
                        anchors.fill: parent
                        action: "dnd toggle"
                    }
                }
                Key {
                    width: parent.width
                    height: parent.keyH
                    size: 9
                    text: "▶ PLAY"
                    action: "pane notifs"
                }
                Key {
                    width: parent.width
                    height: parent.keyH
                    size: 9
                    text: "▸▸ SKIP"
                    onTap: root.at = root.items.length ? (root.at + 1) % root.items.length : 0
                }
                Key {
                    width: parent.width
                    height: parent.keyH
                    size: 9
                    text: "× ERASE"
                    action: root.cur ? "notifs forget " + root.cur.ts : ""
                }
            }
        }
    }

    // ── Expanded: by app ────────────────────────────────────────────
    Component {
        id: board
        Unit {
            id: u
            opacity: root.dnd ? 0.7 : 1
            // [{ app, items: [entries] }], newest app first.
            readonly property var groups: {
                const out = [], by = {};
                for (const e of root.items) {
                    if (!by[e.app]) {
                        by[e.app] = { app: e.app, items: [] };
                        out.push(by[e.app]);
                    }
                    by[e.app].items.push(e);
                }
                return out;
            }
            readonly property int padX: 4
            readonly property int lineH: 9
            readonly property int topY: 4 + 14 + 5
            function groupH(g: var): int {
                return 3 + 5 + 3 + Math.min(2, g.items.length) * lineH + 1;
            }
            readonly property var placed: {
                const out = [];
                let y = topY;
                for (const g of groups) {
                    const h = groupH(g);
                    if (y + h > rows - 10)
                        break;
                    out.push({ g: g, y: y, h: h });
                    y += h + 4;
                }
                return out;
            }

            // MESSAGES                               3 NEW
            Digits {
                id: title
                x: u.padX
                y: 4
                width: implicitWidth
                height: implicitHeight
                size: 2
                ghosts: false
                text: root.words.title || "MESSAGES"
            }
            Digits {
                anchors.right: parent.right
                anchors.rightMargin: u.padX
                anchors.bottom: title.bottom
                width: implicitWidth
                height: implicitHeight
                size: title.width + 8 + text.length * 12 <= u.cols - u.padX * 2 ? 2 : 1
                ghosts: false
                text: root.dnd ? "DND" : root.live + " NEW"
                T.Hit {
                    anchors.fill: parent
                    action: "dnd toggle"
                }
            }

            Repeater {
                model: u.placed
                Item {
                    id: grp
                    required property var modelData
                    x: u.padX
                    y: modelData.y
                    width: u.cols - u.padX * 2
                    height: modelData.h
                    MatrixText {
                        x: 4
                        y: 3
                        height: 5
                        font: "3x5"
                        text: grp.modelData.g.app
                        color: Ink.amber
                    }
                    MatrixText {
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        y: 3
                        width: implicitWidth
                        height: 5
                        font: "3x5"
                        text: grp.modelData.g.items.length
                        color: Ink.amber
                    }
                    Repeater {
                        model: grp.modelData.g.items.slice(0, 2)
                        Item {
                            id: row
                            required property var modelData
                            required property int index
                            readonly property var note: root.liveFor(modelData)
                            readonly property int keysW: note ? Math.min(2, (note.actions ?? []).length) * 24 : 0
                            x: 4
                            y: 11 + index * u.lineH
                            width: grp.width - 8
                            height: u.lineH
                            MatrixText {
                                y: 1
                                width: parent.width - time.width - 6 - row.keysW
                                height: 5
                                font: "3x5"
                                text: row.modelData.summary
                                color: Ink.cyan
                            }
                            MatrixText {
                                id: time
                                x: parent.width - width - row.keysW
                                y: 1
                                width: implicitWidth
                                height: 5
                                font: "3x5"
                                text: root.ago(row.modelData.ts)
                                color: Ink.teal
                            }
                        }
                    }
                }
            }
            MatrixText {
                visible: root.items.length === 0
                anchors.centerIn: parent
                width: implicitWidth
                height: implicitHeight
                text: root.words.quiet || "NO MESSAGES"
                color: Ink.teal
            }
            MatrixText {
                x: u.padX
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3
                width: u.cols - u.padX * 2
                height: 5
                font: "3x5"
                scroll: true
                text: "CLICK A CARD FOR THE MESSAGE CENTRE · CLICK THE COUNT FOR DO NOT DISTURB · HISTORY KEEPS THE LAST 150"
                color: Ink.teal
            }

            // Cards' rules, and the live notifications' own keys, crisp.
            over: Repeater {
                model: u.placed
                Item {
                    id: rim
                    required property var modelData
                    x: u.px(u.padX)
                    y: u.px(modelData.y)
                    width: u.px(u.cols - u.padX * 2)
                    height: u.px(modelData.h)
                    T.Hit {
                        anchors.fill: parent
                        action: "pane notifs"
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.width: 1
                        border.color: Ink.deep
                    }
                    Repeater {
                        model: rim.modelData.g.items.slice(0, 2)
                        Row {
                            required property var modelData
                            required property int index
                            readonly property var note: root.liveFor(modelData)
                            anchors.right: parent.right
                            anchors.rightMargin: u.px(4)
                            y: u.px(11 + index * u.lineH) - 2
                            spacing: 4
                            Repeater {
                                model: parent.note ? Array.from(parent.note.actions ?? []).slice(0, 2) : []
                                Key {
                                    required property var modelData
                                    width: u.px(22)
                                    height: u.px(u.lineH) - 2
                                    size: 8
                                    pad: 2
                                    text: String(modelData.text).toUpperCase().slice(0, 7)
                                    onTap: modelData.invoke()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
