import QtQuick
import qs
import qs.services

// Messages, Tokyo Night: the last few notifications, each in its own neon
// slot (the newest rimmed cyan), app in cyan and what it said in pink.
// Do not disturb dims the whole sign. Expanded, the history grouped by
// app; a notification still on screen offers its own actions.
Face {
    id: root

    readonly property bool dnd: !!ctx.dnd
    readonly property int live: ctx.live ?? 0
    readonly property var items: ctx.items ?? []
    readonly property string count: dnd ? "DND · " + live + " HELD" : live > 0 ? live + " NEW" : "ALL READ"
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
        sourceComponent: root.big ? board : sign
    }

    // ── Compact: the slots ──────────────────────────────────────────
    Component {
        id: sign
        Item {
            id: s
            opacity: root.dnd ? 0.5 : 1
            readonly property int rowH: 10
            readonly property int padX: 5
            readonly property int listY: 13
            readonly property int rowsN: Math.max(0, Math.min(root.items.length, Math.floor((glass.rows - listY - 3) / (rowH + 2))))

            Glass {
                id: glass
                radius: 24

                Words {
                    x: s.padX
                    y: 4
                    small: true
                    room: glass.cols - s.padX * 2 - count.implicitWidth - 4
                    width: room
                    text: "通知 · " + (root.words.title || "MESSAGES")
                    color: Ink.violet
                }
                Words {
                    id: count
                    anchors.right: parent.right
                    anchors.rightMargin: s.padX
                    y: 4
                    small: true
                    text: root.count
                    color: root.dnd ? Ink.violet : Ink.cyan
                    Hit {
                        anchors.fill: parent
                        anchors.margins: -2
                        action: "dnd toggle"
                    }
                }
                Repeater {
                    model: s.rowsN
                    Item {
                        required property int index
                        readonly property var e: root.items[index]
                        x: s.padX
                        y: s.listY + index * (s.rowH + 2)
                        width: glass.cols - s.padX * 2
                        height: s.rowH
                        MatrixText {
                            x: 8
                            y: 3
                            width: parent.width - 11
                            height: 5
                            font: "3x5"
                            text: (parent.e?.app ?? "") + " · " + (parent.e?.summary ?? "")
                            litChars: (parent.e?.app ?? "").length
                            color: Ink.cyan
                            rest: Ink.pink
                        }
                        Hit {
                            anchors.fill: parent
                            action: "pane notifs"
                        }
                    }
                }
                Words {
                    visible: root.items.length === 0
                    anchors.centerIn: parent
                    text: root.words.quiet || "NO MESSAGES"
                    color: Ink.deep
                }
            }
            // The slots' rims and their dots, crisp.
            Repeater {
                model: s.rowsN
                Item {
                    required property int index
                    x: glass.x + s.padX * root.pitch
                    y: glass.y + (s.listY + index * (s.rowH + 2)) * root.pitch
                    width: (glass.cols - s.padX * 2) * root.pitch
                    height: s.rowH * root.pitch
                    Tube {
                        anchors.fill: parent
                        radius: height / 2
                        line: 1.5
                        tint: index === 0 && !root.dnd ? Ink.cyan : Ink.deep
                        glow: index === 0 ? 0.5 : 0.3
                    }
                    Tube {
                        x: 9
                        anchors.verticalCenter: parent.verticalCenter
                        width: 7
                        height: 7
                        radius: 3.5
                        line: 0
                        readonly property bool unread: index < root.live
                        fill: unread ? Ink.pink : Ink.deep
                        tint: fill
                        glow: unread ? 0.6 : 0
                    }
                }
            }
            Sign {
                radius: 24
                tone: root.dnd ? "dim" : "pink"
            }
        }
    }

    // ── Expanded: by app ────────────────────────────────────────────
    Component {
        id: board
        Item {
            id: b
            // [{ app, items: [entries] }], newest app first, three a group.
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
            readonly property int lineH: 8
            // Each group: a name line, then its rows (two at most).
            function groupH(g: var): int {
                return 4 + 7 + Math.min(2, g.items.length) * lineH + 2;
            }
            readonly property var placed: {
                const out = [];
                let y = 13;
                for (const g of groups) {
                    const h = groupH(g);
                    if (y + h > glass.rows - 14)
                        break;
                    out.push({ g: g, y: y, h: h });
                    y += h + 3;
                }
                return out;
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: 28
                color: Ink.glass
            }
            Item {
                anchors.fill: parent
                anchors.margins: 12

                Glass {
                    id: glass
                    radius: 20

                    Words {
                        x: 5
                        y: 4
                        room: glass.cols / 2 - 6
                        text: "通知 · " + (root.words.title || "MESSAGES")
                        color: Ink.violet
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 5
                        y: 4
                        spacing: 6
                        Words {
                            text: "CLEAR"
                            small: true
                            color: Ink.pink
                            y: 2
                            Hit {
                                anchors.fill: parent
                                anchors.margins: -2
                                action: "notifs clear"
                            }
                        }
                        Words {
                            text: root.count
                            color: Ink.violet
                            Hit {
                                anchors.fill: parent
                                anchors.margins: -2
                                action: "dnd toggle"
                            }
                        }
                    }

                    Repeater {
                        model: b.placed
                        Item {
                            id: grp
                            required property var modelData
                            x: 5
                            y: modelData.y
                            width: glass.cols - 10
                            height: modelData.h
                            MatrixText {
                                x: 4
                                y: 3
                                height: 5
                                font: "3x5"
                                text: grp.modelData.g.app
                                color: Ink.cyan
                            }
                            MatrixText {
                                anchors.right: parent.right
                                anchors.rightMargin: 4
                                y: 3
                                height: 5
                                font: "3x5"
                                text: grp.modelData.g.items.length
                                color: Ink.cyan
                            }
                            Repeater {
                                model: grp.modelData.g.items.slice(0, 2)
                                Item {
                                    id: row
                                    required property var modelData
                                    required property int index
                                    readonly property var note: root.liveFor(modelData)
                                    readonly property var acts: note ? Array.from(note.actions ?? []).slice(0, 2) : []
                                    x: 4
                                    y: 11 + index * b.lineH
                                    width: grp.width - 8
                                    height: b.lineH
                                    MatrixText {
                                        width: parent.width - time.width - 4 - (row.acts.length ? 30 * row.acts.length : 0)
                                        height: 5
                                        font: "3x5"
                                        text: row.modelData.summary
                                        color: Ink.pink
                                    }
                                    MatrixText {
                                        id: time
                                        x: parent.width - width - (row.acts.length ? 30 * row.acts.length : 0)
                                        height: 5
                                        font: "3x5"
                                        text: root.ago(row.modelData.ts)
                                        color: Ink.violet
                                    }
                                }
                            }
                        }
                    }
                    Words {
                        visible: root.items.length === 0
                        anchors.centerIn: parent
                        text: root.words.quiet || "NO MESSAGES"
                        color: Ink.deep
                    }
                    MatrixText {
                        x: 5
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 4
                        width: glass.cols - 10
                        height: 5
                        font: "3x5"
                        scroll: true
                        text: "CLICK A GROUP FOR THE MESSAGE CENTRE · HISTORY KEEPS THE LAST 150"
                        color: Ink.violet
                    }
                }

                // Group rims and the live notifications' own buttons, crisp.
                Repeater {
                    model: b.placed
                    Item {
                        id: rim
                        required property var modelData
                        x: glass.x + 5 * root.pitch
                        y: glass.y + modelData.y * root.pitch
                        width: (glass.cols - 10) * root.pitch
                        height: modelData.h * root.pitch
                        Hit {
                            anchors.fill: parent
                            action: "pane notifs"
                        }
                        Tube {
                            anchors.fill: parent
                            radius: 12
                            line: 1.5
                            tint: Ink.deep
                            glow: 0
                        }
                        Repeater {
                            model: rim.modelData.g.items.slice(0, 2)
                            Row {
                                required property var modelData
                                required property int index
                                readonly property var note: root.liveFor(modelData)
                                anchors.right: parent.right
                                anchors.rightMargin: 4 * root.pitch
                                y: (11 + index * b.lineH) * root.pitch - 4
                                spacing: 4
                                Repeater {
                                    model: parent.note ? Array.from(parent.note.actions ?? []).slice(0, 2) : []
                                    Chip {
                                        required property var modelData
                                        width: 28 * root.pitch - 4
                                        size: 9
                                        pad: 4
                                        text: String(modelData.text).toUpperCase().slice(0, 8)
                                        tone: "cyan"
                                        onTap: modelData.invoke()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Sign {
                radius: 28
                inner: true
                innerInset: 12
                tone: root.dnd ? "dim" : "pink"
            }
        }
    }
}
