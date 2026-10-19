import QtQuick
import QtQuick.Effects
import qs
import qs.services
import qs.tokyo as T

// Messages, Split-Flap: the ARRIVALS board. A row of flap tiles per
// message, its time in yellow and its app in off-white, newest first; "●
// 3 IN" in the corner (a click turns do not disturb on or off, which
// dims the board and says HELD). A click on a row opens the message
// centre. Expanded, ARRIVALS · ALL MESSAGES: TODAY and the count in
// yellow, the history grouped by app on cards (the app and its count in
// yellow, each message in off-white dots with its time, and, while it is
// still on screen, its own actions as yellow tags), and OPEN, CLEAR and
// DND keys at the foot.
T.Face {
    id: root

    readonly property bool dnd: !!ctx.dnd
    readonly property int live: ctx.live ?? 0
    readonly property var items: ctx.items ?? []
    function hhmm(ts: real): string {
        const d = new Date(ts);
        return d.toDateString() === new Date().toDateString() ? Qt.formatTime(d, "hhmm") : Qt.formatDate(d, "ddd").toUpperCase().padEnd(4, " ");
    }
    function ago(ts: real): string {
        const d = new Date(ts);
        return d.toDateString() === new Date().toDateString() ? Qt.formatTime(d, "hh:mm") : Qt.formatDate(d, "ddd").toUpperCase();
    }
    // The notification still open for a history entry, if any.
    function liveFor(e: var): var {
        return Notifs.live.find(n => (n.appName || "System") === e.app && (n.summary || n.body || "").trim() === e.summary) ?? null;
    }

    Item {
        anchors.fill: parent
        layer.enabled: root.dnd
        layer.effect: MultiEffect {
            saturation: -0.7
            brightness: -0.25
        }

        Housing {
            id: box
            anchors.fill: parent
            label: root.big ? "ARRIVALS · ALL MESSAGES" : "ARRIVALS · MESSAGES"
            status: root.dnd ? "HELD" : root.big ? "LIVE" : root.live + " IN"
            statusInk: root.dnd || root.big ? Ink.label : Ink.yellow
            statusAction: "dnd toggle"
        }
        Loader {
            anchors.fill: parent
            sourceComponent: root.big ? board : arrivals
        }
    }

    // ── Compact: the arrivals ───────────────────────────────────────
    Component {
        id: arrivals
        Item {
            Rows {
                x: 14
                y: box.bodyY + 2
                width: parent.width - 28
                height: parent.height - y - 10
                gap: 4
                least: 3
                lines: root.items.length ? root.items.slice(0, 6).map(e => ({
                            spans: [[root.hhmm(e.ts) + " ", Ink.yellow], [String(e.app) + " ", Ink.white], [e.summary, Ink.dim]],
                            action: "pane notifs"
                        })) : [[[root.words.quiet || "NO MESSAGES", Ink.dim]]]
            }
        }
    }

    // ── Expanded: by app ────────────────────────────────────────────
    Component {
        id: board
        Item {
            id: b
            readonly property int p: Tokens.pitch
            readonly property real padX: 14
            readonly property real keysY: height - 12 - 22
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
            readonly property int x0: Math.ceil(padX / p)
            readonly property int w0: Math.floor((width - padX * 2) / p)
            readonly property int topY: Math.ceil((box.bodyY + 4) / p)
            readonly property int lineH: 10
            readonly property int listY: topY + 11
            function groupH(g: var): int {
                return 4 + 8 + Math.min(2, g.items.length) * lineH + 2;
            }
            readonly property var placed: {
                const out = [];
                let y = listY;
                const end = Math.floor((keysY - 6) / p);
                for (const g of groups) {
                    const h = groupH(g);
                    if (y + h > end)
                        break;
                    out.push({ g: g, y: y, h: h });
                    y += h + 3;
                }
                return out;
            }

            // The cards, and the live messages' own actions.
            Repeater {
                model: b.placed
                Card {
                    id: rim
                    required property var modelData
                    x: b.x0 * b.p - 6
                    y: modelData.y * b.p
                    width: b.w0 * b.p + 12
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
                            anchors.rightMargin: 6
                            y: (12 + index * b.lineH) * b.p + Math.round((b.lineH * b.p - 14) / 2) - 2
                            spacing: 6
                            Repeater {
                                model: parent.note ? Array.from(parent.note.actions ?? []).slice(0, 2) : []
                                Tag {
                                    required property var modelData
                                    text: String(modelData.text).toUpperCase().slice(0, 8)
                                    onTap: modelData.invoke()
                                }
                            }
                        }
                    }
                }
            }
            Row {
                x: b.padX
                y: b.keysY
                spacing: 6
                Key {
                    width: 70
                    height: 22
                    text: "OPEN"
                    action: "pane notifs"
                }
                Key {
                    width: 70
                    height: 22
                    text: "CLEAR"
                    action: "notifs clear"
                }
                Key {
                    width: 130
                    height: 22
                    text: "DO NOT DISTURB"
                    on: root.dnd
                    action: "dnd toggle"
                }
            }

            Dots {
                anchors.fill: parent

                // TODAY                                       3 NEW
                MatrixText {
                    x: b.x0
                    y: b.topY
                    width: implicitWidth
                    height: 7
                    text: (root.words.title || "TODAY").toUpperCase()
                    color: Ink.yellow
                }
                MatrixText {
                    x: b.x0 + b.w0 - width
                    y: b.topY
                    width: implicitWidth
                    height: 7
                    text: root.dnd ? "HELD" : root.live + " NEW"
                    color: Ink.yellow
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
                        x: b.x0
                        y: modelData.y + 4
                        width: b.w0
                        height: modelData.h - 4
                        MatrixText {
                            width: parent.width - 16
                            height: 7
                            text: grp.modelData.g.app
                            color: Ink.yellow
                        }
                        MatrixText {
                            anchors.right: parent.right
                            width: implicitWidth
                            height: 7
                            text: grp.modelData.g.items.length
                            color: Ink.yellow
                        }
                        Repeater {
                            model: grp.modelData.g.items.slice(0, 2)
                            Item {
                                id: row
                                required property var modelData
                                required property int index
                                readonly property var note: root.liveFor(modelData)
                                readonly property int keysW: note ? Math.min(2, (note.actions ?? []).length) * Math.ceil(56 / b.p) : 0
                                y: 8 + index * b.lineH
                                width: grp.width
                                height: b.lineH
                                MatrixText {
                                    width: parent.width - time.width - 6 - row.keysW
                                    y: 1
                                    height: 7
                                    scroll: true
                                    text: row.modelData.summary
                                    color: Ink.white
                                }
                                MatrixText {
                                    id: time
                                    x: parent.width - width - row.keysW - 2
                                    y: 2
                                    width: implicitWidth
                                    height: 5
                                    font: "3x5"
                                    text: root.ago(row.modelData.ts)
                                    color: Ink.label
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
