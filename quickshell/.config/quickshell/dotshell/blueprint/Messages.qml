import QtQuick
import QtQuick.Effects
import qs
import qs.services
import qs.tokyo as T

// Messages, Blueprint: the sheet's notes. "NOTES — 3 OPEN" over a rule,
// then the latest as numbered notes, a circled number, the app in pale
// blue and what it said, all crisp; a click opens the message centre, the
// heading toggles do not disturb, which greys the whole sheet ("HELD").
// Expanded, SHEET 6, the revision notes: the history grouped by app in
// ruled frames, in dots; a notification still on screen offers its own
// actions as boxed words.
T.Face {
    id: root

    readonly property bool dnd: !!ctx.dnd
    readonly property int live: ctx.live ?? 0
    readonly property var items: ctx.items ?? []

    function ago(ts: real): string {
        const d = new Date(ts);
        const today = new Date();
        return d.toDateString() === today.toDateString() ? Qt.formatTime(d, "hh:mm") : Qt.formatDate(d, "ddd").toUpperCase();
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
            brightness: -0.1
        }

        Paper {
            anchors.fill: parent
        }

        Loader {
            anchors.fill: parent
            sourceComponent: root.big ? board : notes
        }
    }

    // ── Compact: the notes ──────────────────────────────────────────
    Component {
        id: notes
        Item {
            id: c
            readonly property real padX: 14
            readonly property real rowH: 22
            readonly property int fit: Math.max(1, Math.floor((height - 34) / rowH))

            Item {
                x: c.padX
                y: 8
                width: parent.width - c.padX * 2
                height: 18
                Pen {
                    height: parent.height
                    width: parent.width
                    text: root.dnd ? "NOTES (HELD — DND)" : "NOTES — " + root.live + " OPEN"
                    T.Hit {
                        anchors.fill: parent
                        action: "dnd toggle"
                    }
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Ink.line
                }
            }

            Column {
                x: c.padX
                y: 30
                width: parent.width - c.padX * 2
                Repeater {
                    model: root.items.slice(0, c.fit)
                    Item {
                        id: note
                        required property var modelData
                        required property int index
                        width: parent.width
                        height: c.rowH
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            height: 18
                            radius: 9
                            color: "transparent"
                            border.width: 1
                            border.color: Ink.ink
                            Pen {
                                anchors.centerIn: parent
                                text: note.index + 1
                                color: Ink.ink
                            }
                        }
                        Text {
                            x: 26
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - x
                            elide: Text.ElideRight
                            textFormat: Text.StyledText
                            text: "<font color='" + Ink.line + "'>" + String(note.modelData.app).toUpperCase().replace(/</g, "&lt;") + "</font> — " + String(note.modelData.summary).toUpperCase().replace(/</g, "&lt;")
                            color: Ink.ink
                            font.family: Ink.family
                            font.pixelSize: 12
                        }
                        T.Hit {
                            anchors.fill: parent
                            action: "pane notifs"
                        }
                    }
                }
            }
            Pen {
                visible: root.items.length === 0
                anchors.horizontalCenter: parent.horizontalCenter
                y: 30 + (parent.height - 30 - height) / 2 - 4
                text: (root.words.quiet || "NO NOTES").toUpperCase()
                size: 12
            }
        }
    }

    // ── Expanded: SHEET 6 ───────────────────────────────────────────
    Component {
        id: board
        Item {
            id: b
            readonly property int p: Tokens.pitch
            readonly property int cols: Math.floor(width / p)
            readonly property int rows: Math.floor(height / p)
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
            readonly property int padX: Math.ceil(16 / p)
            readonly property int lineH: 10
            readonly property int topY: Math.ceil(30 / p) + 7 + 4
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

            Sheet {
                title: "SHEET 6 — REVISION NOTES"
                rev: "REV " + String.fromCharCode(65 + Math.min(25, root.items.length % 26))
            }
            // The frames, their rules and the live notes' keys, crisp.
            Repeater {
                model: b.placed
                Item {
                    id: rim
                    required property var modelData
                    x: b.padX * b.p
                    y: modelData.y * b.p
                    width: (b.cols - b.padX * 2) * b.p
                    height: modelData.h * b.p
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.width: 1
                        border.color: Ink.line
                    }
                    T.Hit {
                        anchors.fill: parent
                        action: "pane notifs"
                    }
                    Repeater {
                        model: rim.modelData.g.items.slice(0, 2)
                        Item {
                            required property var modelData
                            required property int index
                            readonly property var note: root.liveFor(modelData)
                            x: 3 * b.p
                            y: (10 + index * b.lineH) * b.p
                            width: rim.width - 6 * b.p
                            height: b.lineH * b.p
                            Rectangle {
                                width: parent.width
                                height: 1
                                color: Ink.faint
                            }
                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.verticalCenterOffset: 1
                                spacing: 6
                                Repeater {
                                    model: parent.parent.note ? Array.from(parent.parent.note.actions ?? []).slice(0, 2) : []
                                    Tag {
                                        required property var modelData
                                        width: 24 * b.p
                                        text: String(modelData.text).toUpperCase().slice(0, 8)
                                        onTap: modelData.invoke()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Dots {
                anchors.fill: parent

                // NOTES                                      3 NEW
                MatrixText {
                    x: b.padX
                    y: Math.ceil(30 / b.p)
                    height: 7
                    text: root.words.title || "NOTES"
                    color: Ink.white
                }
                MatrixText {
                    anchors.right: parent.right
                    anchors.rightMargin: b.padX
                    y: Math.ceil(30 / b.p)
                    width: implicitWidth
                    height: 7
                    text: root.dnd ? "HELD" : root.live + " NEW"
                    color: Ink.white
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
                        x: b.padX
                        y: modelData.y
                        width: b.cols - b.padX * 2
                        height: modelData.h
                        MatrixText {
                            x: 3
                            y: 3
                            width: parent.width - 16
                            height: 5
                            font: "3x5"
                            text: grp.modelData.g.app
                            color: Ink.line
                        }
                        MatrixText {
                            anchors.right: parent.right
                            anchors.rightMargin: 3
                            y: 3
                            width: implicitWidth
                            height: 5
                            font: "3x5"
                            text: grp.modelData.g.items.length
                            color: Ink.line
                        }
                        Repeater {
                            model: grp.modelData.g.items.slice(0, 2)
                            Item {
                                id: row
                                required property var modelData
                                required property int index
                                readonly property var note: root.liveFor(modelData)
                                readonly property int keysW: note ? Math.min(2, (note.actions ?? []).length) * 26 : 0
                                x: 3
                                y: 10 + index * b.lineH
                                width: grp.width - 6
                                height: b.lineH
                                MatrixText {
                                    y: 2
                                    width: parent.width - time.width - 6 - row.keysW
                                    height: 7
                                    text: row.modelData.summary
                                    color: Ink.ink
                                }
                                MatrixText {
                                    id: time
                                    x: parent.width - width - row.keysW
                                    y: 3
                                    width: implicitWidth
                                    height: 5
                                    font: "3x5"
                                    text: root.ago(row.modelData.ts)
                                    color: Ink.line
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
                    text: root.words.quiet || "NO NOTES"
                    color: Ink.line
                }
                MatrixText {
                    x: b.padX
                    y: b.rows - 7
                    width: b.cols - b.padX * 2
                    height: 5
                    font: "3x5"
                    scroll: true
                    text: "NOTE: CLICK A NOTE FOR THE MESSAGE CENTRE · CLICK THE COUNT TO HOLD THEM."
                    color: Ink.line
                }
            }
        }
    }
}
