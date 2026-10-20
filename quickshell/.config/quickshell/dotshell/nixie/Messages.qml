import QtQuick
import QtQuick.Effects
import qs
import qs.services
import qs.tokyo as T

// Messages, Nixie: the telegraph office. Two tubes count the live messages
// over TELEGRAMS in brass (a click there turns do not disturb on or off,
// which greys the whole case and says HELD); beside them each message is a
// typed ivory slip, APP — SUMMARY, newest first (a click opens the message
// centre). Expanded, HISTORY BY APP: the title glowing big on the wood and
// the count, the history grouped by app on ivory cards (the app and its
// count, each message in dark dots with its time and, while it is still on
// screen, its own actions as brass keys), and OPEN, CLEAR and DO NOT
// DISTURB keys at the foot.
T.Face {
    id: root

    readonly property bool dnd: !!ctx.dnd
    readonly property int live: ctx.live ?? 0
    readonly property var items: ctx.items ?? []
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
            saturation: -0.85
            brightness: -0.12
        }
        Wood {
            anchors.fill: parent
        }
        Loader {
            anchors.fill: parent
            sourceComponent: root.big ? board : office
        }
    }

    // ── Compact: the slips ──────────────────────────────────────────
    Component {
        id: office
        Item {
            id: c
            readonly property real tubeH: Math.max(26, Math.min(62, height - 44))
            readonly property real slipH: 19
            readonly property int slips: Math.max(1, Math.min(4, Math.floor((height - 20 + 5) / (slipH + 5))))

            Column {
                id: count
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Tubes {
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: c.tubeH
                    tubeW: c.tubeH * 0.55
                    gap: 3
                    text: String(Math.min(99, root.live)).padStart(2, "0")
                    lit: !root.dnd
                }
                Print {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.dnd ? "HELD" : String(root.words.title || "TELEGRAMS").toUpperCase()
                    size: 7
                }
            }
            T.Hit {
                anchors.fill: count
                action: "dnd toggle"
            }
            Column {
                x: count.x + count.width + 12
                anchors.verticalCenter: parent.verticalCenter
                width: c.width - x - 14
                spacing: 5
                Repeater {
                    model: root.items.length ? root.items.slice(0, c.slips) : [null]
                    Paper {
                        required property var modelData
                        width: parent.width
                        height: c.slipH
                        lift: 1
                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            verticalAlignment: Text.AlignVCenter
                            text: parent.modelData ? (String(parent.modelData.app) + " — " + parent.modelData.summary).toUpperCase() : String(root.words.quiet || "NO MESSAGES").toUpperCase()
                            color: Ink.paperInk
                            font.family: Ink.mono
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                        T.Hit {
                            anchors.fill: parent
                            action: "pane notifs"
                        }
                    }
                }
            }
        }
    }

    // ── Expanded: by app ────────────────────────────────────────────
    Component {
        id: board
        Item {
            id: b
            readonly property int p: Tokens.pitch
            readonly property real padX: 18
            readonly property real titleH: Math.max(9 * p, Math.min(40, height * 0.11))
            readonly property real listY: 14 + titleH + 10
            readonly property real keysY: height - 14 - 20
            readonly property real footY: keysY - 8 - 5 * p
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
            readonly property real lineH: 10 * p
            function groupH(g: var): real {
                return 6 + 9 * p + Math.min(2, g.items.length) * lineH + 6;
            }
            readonly property var placed: {
                const out = [];
                let y = listY;
                for (const g of groups) {
                    const h = groupH(g);
                    if (y + h > footY - 6)
                        break;
                    out.push({ g: g, y: y, h: h });
                    y += h + 8;
                }
                return out;
            }

            // Telegrams                                        3 NEW
            Dots {
                x: b.padX
                y: 14
                width: b.width - b.padX * 2
                height: b.titleH
                Word {
                    width: implicitWidth
                    height: parent.height
                    dots: height
                    text: root.words.title || "Telegrams"
                    color: Ink.digit
                }
                Word {
                    x: parent.width - width
                    width: implicitWidth
                    height: parent.height
                    dots: height
                    text: root.dnd ? "HELD" : root.live + " NEW"
                    color: Ink.digit
                    T.Hit {
                        anchors.fill: parent
                        action: "dnd toggle"
                    }
                }
            }
            Repeater {
                model: b.placed
                Paper {
                    id: card
                    required property var modelData
                    x: b.padX
                    y: modelData.y
                    width: b.width - b.padX * 2
                    height: modelData.h
                    T.Hit {
                        anchors.fill: parent
                        action: "pane notifs"
                    }
                    Dots {
                        id: ink
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        anchors.topMargin: 6
                        soft: true
                        MatrixText {
                            width: ink.cols - 8
                            height: 7
                            text: String(card.modelData.g.app).toUpperCase()
                            color: Ink.paperInk
                        }
                        MatrixText {
                            x: ink.cols - width
                            width: implicitWidth
                            height: 7
                            text: card.modelData.g.items.length
                            color: Ink.paperInk
                        }
                    }
                    Repeater {
                        model: card.modelData.g.items.slice(0, 2)
                        Item {
                            id: row
                            required property var modelData
                            required property int index
                            readonly property var note: root.liveFor(modelData)
                            x: 10
                            y: 6 + 9 * b.p + index * b.lineH
                            width: card.width - 20
                            height: b.lineH
                            Row {
                                id: acts
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                Repeater {
                                    model: row.note ? Array.from(row.note.actions ?? []).slice(0, 2) : []
                                    Key {
                                        required property var modelData
                                        width: Math.max(44, text.length * 7 + 16)
                                        height: 16
                                        text: String(modelData.text).toUpperCase().slice(0, 10)
                                        on: true
                                        onTap: modelData.invoke()
                                    }
                                }
                            }
                            Dots {
                                id: line
                                width: parent.width - acts.width - 8
                                height: parent.height
                                soft: true
                                MatrixText {
                                    y: Math.round((line.rows - 7) / 2)
                                    width: line.cols - time.implicitWidth - 4
                                    height: 7
                                    scroll: true
                                    text: row.modelData.summary
                                    color: Ink.paperInk
                                }
                                MatrixText {
                                    id: time
                                    x: line.cols - width
                                    y: Math.round((line.rows - 5) / 2)
                                    width: implicitWidth
                                    height: 5
                                    font: "3x5"
                                    text: root.ago(row.modelData.ts)
                                    color: Ink.paperSoft
                                }
                            }
                        }
                    }
                }
            }
            Dots {
                anchors.fill: parent
                MatrixText {
                    visible: root.items.length === 0
                    x: Math.ceil(b.padX / b.p)
                    y: Math.ceil(b.listY / b.p) + 2
                    width: implicitWidth
                    height: 7
                    text: root.words.quiet || "NO MESSAGES"
                    color: Ink.brass
                }
                MatrixText {
                    x: Math.ceil(b.padX / b.p)
                    y: Math.round(b.footY / b.p)
                    width: Math.floor((b.width - b.padX * 2) / b.p)
                    height: 5
                    font: "3x5"
                    scroll: true
                    text: "CLICK TO OPEN · HISTORY BY APP · " + root.items.length + " KEPT"
                    color: Ink.brass
                }
            }
            Row {
                x: b.padX
                y: b.keysY
                spacing: 8
                Key {
                    width: 70
                    height: 20
                    text: "OPEN"
                    action: "pane notifs"
                }
                Key {
                    width: 70
                    height: 20
                    text: "CLEAR"
                    action: "notifs clear"
                }
                Key {
                    width: 130
                    height: 20
                    text: "DO NOT DISTURB"
                    on: root.dnd
                    action: "dnd toggle"
                }
            }
        }
    }
}
