import QtQuick
import QtQuick.Effects
import qs
import qs.services
import qs.tokyo as T

// Messages, Vaporwave: inbox.exe, the message box. The round ⓘ marble,
// "You have 3 new messages." and the latest as "· App: what it said" in
// VT323, with OK (the message centre) and Clear all. A click on a message
// opens the message centre, on the heading turns do not disturb on or
// off, which greys the whole window ("Do not disturb is on."). Expanded,
// inbox.exe — History: a white sheet, "Inbox" big in dots and the count
// (a click holds them), the history grouped by app in pink with dotted
// rules between, each message with its time and, while it is still on
// screen, its own actions as push buttons.
T.Face {
    id: root

    readonly property bool dnd: !!ctx.dnd
    readonly property int live: ctx.live ?? 0
    readonly property var items: ctx.items ?? []
    function ago(ts: real): string {
        const d = new Date(ts);
        return d.toDateString() === new Date().toDateString() ? Qt.formatTime(d, "hh:mm") : Qt.formatDate(d, "ddd");
    }
    // The notification still open for a history entry, if any.
    function liveFor(e: var): var {
        return Notifs.live.find(n => (n.appName || "System") === e.app && (n.summary || n.body || "").trim() === e.summary) ?? null;
    }

    Item {
        anchors.fill: parent
        layer.enabled: root.dnd
        layer.effect: MultiEffect {
            saturation: -1
            brightness: -0.18
        }

        Win {
            id: win
            anchors.fill: parent
            icon: "✉"
            title: root.big ? "inbox.exe — History" : "inbox.exe"
            controls: root.big ? "max" : "close"
            big: root.big
        }
        Loader {
            anchors.fill: parent
            sourceComponent: root.big ? board : box
        }
    }

    // ── Compact: the message box ────────────────────────────────────
    Component {
        id: box
        Item {
            id: c
            readonly property real topY: win.bodyY + 8
            readonly property real lineH: 20
            readonly property real keysH: 24
            readonly property int fit: Math.max(0, Math.floor((height - topY - 26 - keysH - 10) / lineH))

            // ⓘ
            Rectangle {
                x: 14
                y: c.topY + 2
                width: 34
                height: 34
                radius: 17
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Ink.yellow
                    }
                    GradientStop {
                        position: 1
                        color: Ink.pink
                    }
                }
                Rectangle {
                    x: 3
                    y: 3
                    width: parent.width
                    height: parent.height
                    radius: width / 2
                    z: -1
                    color: Ink.shade
                }
                Pen {
                    anchors.centerIn: parent
                    text: "i"
                    size: 22
                }
            }
            Pen {
                id: head
                x: 60
                y: c.topY
                width: parent.width - x - 10
                height: 24
                text: root.dnd ? "Do not disturb is on." : root.live > 0 ? "You have " + root.live + " new message" + (root.live === 1 ? "." : "s.") : root.items.length ? "No new messages." : (root.words.quiet || "No messages").toLowerCase().replace(/^./, ch => ch.toUpperCase()) + "."
                size: 19
                T.Hit {
                    anchors.fill: parent
                    action: "dnd toggle"
                }
            }
            Column {
                x: 60
                y: head.y + 26
                width: parent.width - x - 10
                Repeater {
                    model: root.items.slice(0, c.fit)
                    Item {
                        id: line
                        required property var modelData
                        width: parent.width
                        height: c.lineH
                        Pen {
                            width: parent.width
                            height: parent.height
                            text: "· " + line.modelData.app + ": " + line.modelData.summary
                            size: 16
                            color: Ink.label
                        }
                        T.Hit {
                            anchors.fill: parent
                            action: "pane notifs"
                        }
                    }
                }
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                spacing: 6
                Key {
                    width: 50
                    height: c.keysH
                    text: "OK"
                    action: "pane notifs"
                }
                Key {
                    width: 96
                    height: c.keysH
                    text: "Clear all"
                    action: "notifs clear"
                }
            }
        }
    }

    // ── Expanded: History ───────────────────────────────────────────
    Component {
        id: board
        Item {
            id: b
            readonly property int p: Tokens.pitch
            readonly property real wellY: win.bodyY + 8
            readonly property real wellH: height - wellY - 10
            readonly property real keysY: wellY + wellH - 10 - 22
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
            readonly property int x0: Math.ceil(22 / p)
            readonly property int w0: Math.floor((width - 44) / p)
            readonly property int topY: Math.ceil((wellY + 10) / p)
            readonly property int lineH: 10
            readonly property int listY: topY + 18
            function groupH(g: var): int {
                return 8 + Math.min(2, g.items.length) * lineH + 4;
            }
            readonly property var placed: {
                const out = [];
                let y = listY;
                const end = Math.floor((keysY - 4) / p);
                for (const g of groups) {
                    const h = groupH(g);
                    if (y + h > end)
                        break;
                    out.push({ g: g, y: y, h: h });
                    y += h + 3;
                }
                return out;
            }

            Well {
                x: 10
                y: b.wellY
                width: parent.width - 20
                height: b.wellH
                paper: true
            }
            // The live messages' own actions, crisp.
            Repeater {
                model: b.placed
                Item {
                    id: rim
                    required property var modelData
                    x: b.x0 * b.p
                    y: modelData.y * b.p
                    width: b.w0 * b.p
                    height: modelData.h * b.p
                    T.Hit {
                        anchors.fill: parent
                        action: "pane notifs"
                    }
                    Repeater {
                        model: rim.modelData.g.items.slice(0, 2)
                        Row {
                            required property var modelData
                            required property int index
                            readonly property var note: root.liveFor(modelData)
                            anchors.right: parent.right
                            y: (8 + index * b.lineH) * b.p
                            height: b.lineH * b.p
                            spacing: 6
                            Repeater {
                                model: parent.note ? Array.from(parent.note.actions ?? []).slice(0, 2) : []
                                Key {
                                    required property var modelData
                                    width: 22 * b.p
                                    height: b.lineH * b.p - 4
                                    textPx: 15
                                    text: String(modelData.text).toUpperCase().slice(0, 8)
                                    onTap: modelData.invoke()
                                }
                            }
                        }
                    }
                }
            }
            Row {
                x: 22
                y: b.keysY
                spacing: 6
                Key {
                    width: 70
                    height: 22
                    text: "Open"
                    action: "pane notifs"
                }
                Key {
                    width: 70
                    height: 22
                    text: "Clear"
                    action: "notifs clear"
                }
                Key {
                    width: 130
                    height: 22
                    text: "Do Not Disturb"
                    on: root.dnd
                    action: "dnd toggle"
                }
            }

            Dots {
                anchors.fill: parent

                // Inbox                                       3 NEW
                MatrixText {
                    x: b.x0
                    y: b.topY
                    width: implicitWidth
                    height: 14
                    size: 2
                    dot: 1
                    text: root.words.title ? String(root.words.title).charAt(0) + String(root.words.title).slice(1).toLowerCase() : "Inbox"
                    color: Ink.ink
                }
                MatrixText {
                    x: b.x0 + b.w0 - width
                    y: b.topY + 2
                    width: implicitWidth
                    height: 7
                    text: root.dnd ? "HELD" : root.live + " NEW"
                    color: Ink.ink
                    T.Hit {
                        anchors.fill: parent
                        anchors.margins: -2
                        action: "dnd toggle"
                    }
                }
                Repeater {
                    model: b.placed
                    Item {
                        id: grp
                        required property var modelData
                        readonly property int keysW: 0
                        x: b.x0
                        y: modelData.y
                        width: b.w0
                        height: modelData.h
                        MatrixText {
                            width: parent.width - 16
                            height: 5
                            font: "3x5"
                            text: grp.modelData.g.app
                            color: Ink.pink
                        }
                        MatrixText {
                            anchors.right: parent.right
                            width: implicitWidth
                            height: 5
                            font: "3x5"
                            text: grp.modelData.g.items.length
                            color: Ink.pink
                        }
                        Repeater {
                            model: grp.modelData.g.items.slice(0, 2)
                            Item {
                                id: row
                                required property var modelData
                                required property int index
                                readonly property var note: root.liveFor(modelData)
                                readonly property int keysW: note ? Math.min(2, (note.actions ?? []).length) * (22 + 2) : 0
                                y: 8 + index * b.lineH
                                width: grp.width
                                height: b.lineH
                                MatrixText {
                                    width: parent.width - time.width - 6 - row.keysW
                                    font: String(row.modelData.summary).length * 6 <= width ? "5x7" : "3x5"
                                    y: font === "5x7" ? 1 : 2
                                    height: font === "5x7" ? 7 : 5
                                    text: row.modelData.summary
                                    color: Ink.ink
                                }
                                MatrixText {
                                    id: time
                                    x: parent.width - width - row.keysW - 2
                                    y: 2
                                    width: implicitWidth
                                    height: 5
                                    font: "3x5"
                                    text: root.ago(row.modelData.ts)
                                    color: Ink.pink
                                }
                            }
                        }
                        // The dotted rule under the group.
                        Row {
                            y: grp.height - 2
                            spacing: 1
                            Repeater {
                                model: Math.floor(grp.width / 2)
                                Rectangle {
                                    width: 1
                                    height: 1
                                    color: Ink.violet
                                }
                            }
                        }
                    }
                }
                MatrixText {
                    visible: root.items.length === 0
                    x: b.x0
                    y: b.listY + 4
                    width: implicitWidth
                    height: 7
                    text: root.words.quiet || "NO MESSAGES"
                    color: Ink.label
                }
            }
        }
    }
}
