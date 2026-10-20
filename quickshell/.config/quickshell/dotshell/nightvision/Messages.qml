import QtQuick
import QtQuick.Effects
import qs
import qs.services
import qs.tokyo as T

// Messages, Night Vision: the comms log. COMMS · 3 INBOUND in dim small
// print (SILENT and CLEAR across from it: do not disturb, clear them all),
// then the latest traffic, a zulu stamp dim and the app and summary bright
// (a click opens the message centre). Do not disturb greys the scope and
// says COMMS · SILENT · 3 HELD. Expanded, COMMS LOG on the CRT: grouped by
// app behind a green rule, the app and its count in dim small print, each
// message with its time and, while it is still on screen, its own actions
// as bright keys; ACK, CLEAR and SILENT at the foot.
T.Face {
    id: root

    readonly property bool dnd: !!ctx.dnd
    readonly property int live: ctx.live ?? 0
    readonly property var items: ctx.items ?? []
    function zulu(ts: real): string {
        const d = new Date(ts);
        return String(d.getUTCHours()).padStart(2, "0") + String(d.getUTCMinutes()).padStart(2, "0") + "Z";
    }
    function ago(ts: real): string {
        const d = new Date(ts);
        return d.toDateString() === new Date().toDateString() ? Qt.formatTime(d, "hh:mm") : Qt.formatDate(d, "ddd").toUpperCase();
    }
    // The notification still open for a history entry, if any.
    function liveFor(e: var): var {
        return Notifs.live.find(n => (n.appName || "System") === e.app && (n.summary || n.body || "").trim() === e.summary) ?? null;
    }
    readonly property string head: dnd ? "COMMS · SILENT · " + root.items.length + " HELD" : "COMMS · " + (live || root.items.length) + " INBOUND"

    Item {
        anchors.fill: parent
        layer.enabled: root.dnd
        layer.effect: MultiEffect {
            saturation: -0.85
            brightness: -0.12
        }
        Loader {
            anchors.fill: parent
            sourceComponent: root.big ? board : traffic
        }
    }

    // ── Compact: the traffic ────────────────────────────────────────
    Component {
        id: traffic
        Scope {
            id: s
            readonly property int l: dx((Math.max(18, rx * 0.5) + 8))
            readonly property int w: dx(width - (Math.max(18, rx * 0.5) + 8)) - l
            readonly property int t: (Math.max(2, Math.round(rows * 0.14)) + 2)
            readonly property bool roomy: w >= 150
            readonly property int lineH: roomy ? 10 : 8
            readonly property int fit: Math.max(1, Math.floor((rows - t * 2 - 9 + 2) / lineH))

            MatrixText {
                x: s.l
                y: s.t
                width: s.w - keys.width - 4
                height: 5
                font: "3x5"
                text: root.head.length * 4 + 46 <= s.w ? root.head : root.dnd ? "SILENT · " + root.items.length : "COMMS · " + (root.live || root.items.length)
                color: Ink.dim
            }
            Row {
                id: keys
                x: s.l + s.w - width
                y: s.t
                spacing: 4
                Repeater {
                    id: keyRep
                    model: [["SILENT", "dnd toggle", root.dnd], ["CLEAR", "notifs clear", false]]
                    MatrixText {
                        required property var modelData
                        width: implicitWidth
                        height: 5
                        font: "3x5"
                        text: modelData[0]
                        color: modelData[2] ? Ink.bright : Ink.dim
                    }
                }
            }
            Column {
                x: s.l
                y: s.t + 9
                width: s.w
                spacing: s.lineH - (s.roomy ? 7 : 5)
                Repeater {
                    model: root.items.slice(0, s.fit)
                    Row {
                        required property var modelData
                        spacing: s.roomy ? 4 : 3
                        MatrixText {
                            width: implicitWidth
                            height: s.roomy ? 7 : 5
                            font: s.roomy ? "5x7" : "3x5"
                            text: root.zulu(modelData.ts)
                            color: Ink.dim
                        }
                        MatrixText {
                            width: s.w - x
                            height: s.roomy ? 7 : 5
                            font: s.roomy ? "5x7" : "3x5"
                            text: (String(modelData.app) + " · " + modelData.summary).toUpperCase()
                            color: Ink.bright
                        }
                    }
                }
                MatrixText {
                    visible: root.items.length === 0
                    width: s.w
                    height: 5
                    font: "3x5"
                    text: root.words.quiet || "NO TRAFFIC · LISTENING"
                    color: Ink.dim
                }
            }
            T.Hit {
                parent: s.over
                x: s.px(s.l)
                y: s.py(s.t + 7)
                width: s.w * Tokens.pitch
                height: s.height - y - s.py(s.t) + s.surface.y
                action: "pane notifs"
            }
            Repeater {
                parent: s.over
                model: 2
                T.Hit {
                    required property int index
                    readonly property Item word: keyRep.count > index ? keyRep.itemAt(index) : null
                    x: word ? s.px(keys.x + word.x) - 3 : 0
                    y: s.py(s.t) - 3
                    width: word ? word.width * Tokens.pitch + 6 : 0
                    height: 5 * Tokens.pitch + 6
                    action: index === 0 ? "dnd toggle" : "notifs clear"
                }
            }
        }
    }

    // ── Expanded: the log ───────────────────────────────────────────
    Component {
        id: board
        Scope {
            id: b
            crt: true
            readonly property int p: Tokens.pitch
            readonly property real padX: (Math.max(16, rx * 0.36) + 10)
            readonly property real padY: (Math.max(12, ry * 0.6) + 8)
            readonly property real inW: width - padX * 2
            readonly property real titleH: 9 * p
            readonly property real listY: padY + titleH + 6
            readonly property real keysY: height - padY - 20
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
            readonly property bool roomy: inW / p >= 200
            readonly property real lineH: (roomy ? 10 : 8) * p
            function groupH(g: var): real {
                return 7 * p + Math.min(2, g.items.length) * lineH + 8;
            }
            readonly property var placed: {
                const out = [];
                let y = listY;
                for (const g of groups) {
                    const h = groupH(g);
                    if (y + h > keysY - 6)
                        break;
                    out.push({ g: g, y: y, h: h });
                    y += h;
                }
                return out;
            }

            // COMMS LOG                                         3 NEW
            MatrixText {
                x: b.dx(b.padX)
                y: b.dy(b.padY) + 1
                width: implicitWidth
                height: 7
                text: "COMMS LOG"
                color: Ink.bright
            }
            MatrixText {
                x: b.dx(b.width - b.padX) - width
                y: b.dy(b.padY) + 1
                width: implicitWidth
                height: 7
                text: root.dnd ? "SILENT · " + root.items.length + " HELD" : (root.live || root.items.length) + " NEW"
                color: Ink.bright
            }
            MatrixText {
                visible: root.items.length === 0
                x: b.dx(b.padX)
                y: b.dy(b.listY) + 3
                width: implicitWidth
                height: 7
                text: root.words.quiet || "NO TRAFFIC · LISTENING"
                color: Ink.dim
            }
            MatrixText {
                x: b.dx(b.padX)
                y: b.dy(b.keysY + 10) - 2
                width: Math.max(0, b.dx(b.width - b.padX - keys.width - 8) - x)
                height: 5
                font: "3x5"
                scroll: true
                text: "ACK TO OPEN · CLEAR TO DISMISS · SILENT = DND · " + root.items.length + " KEPT"
                color: Ink.dim
            }

            Repeater {
                parent: b.over
                model: b.placed
                Item {
                    id: card
                    required property var modelData
                    x: b.padX
                    y: modelData.y
                    width: b.inW
                    height: modelData.h - 6
                    // The green rule down each app.
                    Rectangle {
                        width: 1.5
                        height: parent.height
                        color: Ink.rule
                    }
                    T.Hit {
                        anchors.fill: parent
                        action: "pane notifs"
                    }
                    Repeater {
                        model: card.modelData.g.items.slice(0, 2)
                        Item {
                            id: row
                            required property var modelData
                            required property int index
                            readonly property var note: root.liveFor(modelData)
                            x: 6
                            y: 7 * b.p + index * b.lineH
                            width: card.width - 6
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
                                        height: 18
                                        tone: "bright"
                                        text: String(modelData.text).toUpperCase().slice(0, 10)
                                        onTap: modelData.invoke()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            // The cards' words, on the dots.
            Repeater {
                model: b.placed
                Item {
                    id: words
                    required property var modelData
                    x: b.dx(b.padX + 6)
                    y: b.dy(modelData.y)
                    width: b.dx(b.width - b.padX) - x
                    height: Math.floor(modelData.h / b.p)
                    MatrixText {
                        width: parent.width - 10
                        height: 5
                        font: "3x5"
                        gap: 2
                        text: String(words.modelData.g.app).toUpperCase()
                        color: Ink.dim
                    }
                    MatrixText {
                        x: parent.width - width
                        width: implicitWidth
                        height: 5
                        font: "3x5"
                        text: words.modelData.g.items.length
                        color: Ink.dim
                    }
                    Repeater {
                        model: words.modelData.g.items.slice(0, 2)
                        Item {
                            id: line
                            required property var modelData
                            required property int index
                            readonly property var note: root.liveFor(modelData)
                            readonly property int keysW: note ? Math.ceil(Math.min(2, (note.actions ?? []).length) * 70 / b.p) : 0
                            y: 7 + index * (b.roomy ? 10 : 8)
                            width: words.width
                            height: b.roomy ? 10 : 8
                            MatrixText {
                                y: b.roomy ? 2 : 2
                                width: parent.width - line.keysW - time.implicitWidth - 6
                                height: b.roomy ? 7 : 5
                                font: b.roomy ? "5x7" : "3x5"
                                scroll: true
                                text: line.modelData.summary
                                color: Ink.bright
                            }
                            MatrixText {
                                id: time
                                x: parent.width - line.keysW - width - 2
                                y: b.roomy ? 3 : 2
                                width: implicitWidth
                                height: 5
                                font: "3x5"
                                text: root.ago(line.modelData.ts)
                                color: Ink.dim
                            }
                        }
                    }
                }
            }
            Row {
                id: keys
                parent: b.over
                anchors.right: parent.right
                anchors.rightMargin: b.padX
                y: b.keysY
                spacing: 6
                Key {
                    height: 20
                    text: "ACK"
                    tone: "bright"
                    action: "pane notifs"
                }
                Key {
                    height: 20
                    text: "CLEAR"
                    action: "notifs clear"
                }
                Key {
                    height: 20
                    text: "SILENT"
                    on: root.dnd
                    action: "dnd toggle"
                }
            }
        }
    }
}
