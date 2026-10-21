import QtQuick
import QtQuick.Effects
import qs
import qs.services
import qs.tokyo as T

// Messages, 90s Nights: a pager. The green LCD shows how many are live and
// the time, the newest page big, the one before it small (a click there
// opens the message centre); beside it the LED blinks hot pink while pages
// are live, READ opens the message centre, CLEAR clears them, and BEEP!
// (a click) holds them: do not disturb greys the whole pager and the LCD
// says HOLD. Expanded, PAGES: the LCD grown big, the history grouped by
// app in dark dots between rules (the app and its count, each page with
// its time and, while it is still on screen, its own actions as yellow
// tags), and READ, CLEAR and HOLD pills at the foot.
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
    function line(e: var): string {
        return e ? (String(e.app) + " · " + e.summary).toUpperCase() : "";
    }

    Item {
        anchors.fill: parent
        layer.enabled: root.dnd
        layer.effect: MultiEffect {
            saturation: -0.85
            brightness: -0.1
        }
        Loader {
            anchors.fill: parent
            sourceComponent: root.big ? board : leanPager
        }
    }

    // Compact, leaning with the signs.
    Component {
        id: leanPager
        Item {
            Plate {
                anchors.fill: parent
            }
            Leaning {
                anchors.fill: parent
                anchors.margins: 10
                Loader {
                    anchors.fill: parent
                    sourceComponent: pager
                }
            }
        }
    }

    // ── Compact: the pager ──────────────────────────────────────────
    Component {
        id: pager
        Item {
            id: c
            readonly property real side: 54
            readonly property real small: Math.max(13, Math.min(15, height * 0.11))
            readonly property real bigPx: Math.max(16, Math.min(26, height * 0.19))

            Pager {
                anchors.fill: parent
                bare: true
                lcd: Qt.rect(0, 0, c.width - c.side - 10, c.height)
            }
            // The LCD's text.
            Item {
                x: 10
                y: 6
                width: c.width - c.side - 10 - 20
                height: c.height - 12
                Mono {
                    width: parent.width * 0.65
                    height: c.small
                    text: root.dnd ? "HOLD · " + root.live : root.live + " MSG"
                    size: c.small
                }
                Mono {
                    anchors.right: parent.right
                    height: c.small
                    text: Qt.formatTime(new Date(root.ctx.now ?? Date.now()), "hh:mm")
                    size: c.small
                }
                Mono {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: c.bigPx
                    text: root.items.length ? String(root.items[0].summary || root.items[0].app).toUpperCase() : String(root.words.quiet || "NO PAGES").toUpperCase()
                    size: c.bigPx
                }
                Mono {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: c.small
                    text: root.items.length > 1 ? root.line(root.items[1]) : root.items.length ? String(root.items[0].app).toUpperCase() : ""
                    size: c.small
                }
                T.Hit {
                    anchors.fill: parent
                    action: "pane notifs"
                }
            }
            // The LED, READ, CLEAR, BEEP!
            Column {
                x: c.width - c.side
                y: 0
                width: c.side
                height: c.height
                spacing: Math.max(4, (height - 10 - 22 * 2 - 14) / 3)
                Rectangle {
                    id: led
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 10
                    height: 10
                    radius: 5
                    property bool lit: root.live > 0 && !root.dnd
                    color: lit ? Ink.pink : Ink.dim
                    opacity: lit && blinker.on ? 0.35 : 1
                    Timer {
                        id: blinker
                        property bool on: false
                        interval: 700
                        repeat: true
                        running: led.lit && led.visible
                        onTriggered: on = !on
                        onRunningChanged: on = false
                    }
                    Rectangle {
                        visible: led.lit && Tokens.neon
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        radius: 9
                        color: Ink.pink
                        opacity: 0.3 * led.opacity
                    }
                }
                Pill {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 46
                    height: 22
                    text: "READ"
                    tone: "read"
                    action: "pane notifs"
                }
                Pill {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 46
                    height: 22
                    text: "CLEAR"
                    tone: "clear"
                    action: "notifs clear"
                }
                Pen {
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 14
                    text: root.dnd ? "HOLD" : "BEEP"
                    size: 10
                    slanted: true
                    color: Ink.yellow
                    T.Hit {
                        anchors.fill: parent
                        anchors.margins: -4
                        action: "dnd toggle"
                    }
                }
            }
        }
    }

    // ── Expanded: pages by app ──────────────────────────────────────
    Component {
        id: board
        Item {
            id: b
            readonly property int p: Tokens.pitch
            // The LCD, px; inside it the words.
            readonly property real pad: 12
            readonly property rect lcd: Qt.rect(pad, pad, width - pad * 2, height - pad * 2)
            readonly property real inX: lcd.x + 12
            readonly property real inW: lcd.width - 24
            readonly property real titleY: lcd.y + 10
            readonly property real titleH: 9 * p
            readonly property real listY: titleY + titleH + 8
            readonly property real keysY: lcd.y + lcd.height - 10 - 18
            readonly property real footY: keysY + 4
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
                return 6 + 9 * p + Math.min(2, g.items.length) * lineH + 4;
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

            Plate {
                anchors.fill: parent
                slant: false
            }
            Pager {
                anchors.fill: parent
                bare: true
                lcd: b.lcd
            }
            // PAGES                                             3 NEW
            Dots {
                id: head
                x: b.inX
                y: b.titleY
                width: b.inW
                height: b.titleH
                soft: true
                halo: Ink.lcdSoft
                MatrixText {
                    y: 1
                    width: implicitWidth
                    height: 7
                    text: "PAGES"
                    color: Ink.lcdInk
                }
                MatrixText {
                    x: head.cols - width
                    y: 1
                    width: implicitWidth
                    height: 7
                    text: root.dnd ? "HOLD · " + root.live : root.live + " NEW"
                    color: Ink.lcdInk
                }
            }
            Repeater {
                model: b.placed
                Item {
                    id: card
                    required property var modelData
                    x: b.inX
                    y: modelData.y
                    width: b.inW
                    height: modelData.h
                    // The rule over each app.
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Ink.c(Qt.rgba(10 / 255, 42 / 255, 34 / 255, 0.4), Qt.rgba(10 / 255, 42 / 255, 34 / 255, 0.4))
                    }
                    T.Hit {
                        anchors.fill: parent
                        action: "pane notifs"
                    }
                    Dots {
                        id: ink
                        y: 5
                        width: parent.width
                        height: 9 * b.p
                        soft: true
                        halo: Ink.lcdSoft
                        MatrixText {
                            width: ink.cols - 8
                            height: 7
                            text: String(card.modelData.g.app).toUpperCase()
                            color: Ink.lcdInk
                        }
                        MatrixText {
                            x: ink.cols - width
                            width: implicitWidth
                            height: 7
                            text: card.modelData.g.items.length
                            color: Ink.lcdInk
                        }
                    }
                    Repeater {
                        model: card.modelData.g.items.slice(0, 2)
                        Item {
                            id: row
                            required property var modelData
                            required property int index
                            readonly property var note: root.liveFor(modelData)
                            y: 5 + 9 * b.p + index * b.lineH
                            width: card.width
                            height: b.lineH
                            Row {
                                id: acts
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                Repeater {
                                    model: row.note ? Array.from(row.note.actions ?? []).slice(0, 2) : []
                                    Pill {
                                        required property var modelData
                                        height: 16
                                        radius: 6
                                        textPx: 8
                                        text: String(modelData.text).toUpperCase().slice(0, 10)
                                        onTap: modelData.invoke()
                                    }
                                }
                            }
                            Dots {
                                id: words
                                width: parent.width - acts.width - 8
                                height: parent.height
                                soft: true
                                halo: Ink.lcdSoft
                                MatrixText {
                                    y: Math.round((words.rows - 7) / 2)
                                    width: words.cols - time.implicitWidth - 4
                                    height: 7
                                    scroll: true
                                    text: row.modelData.summary
                                    color: Ink.lcdInk
                                }
                                MatrixText {
                                    id: time
                                    x: words.cols - width
                                    y: Math.round((words.rows - 5) / 2)
                                    width: implicitWidth
                                    height: 5
                                    font: "3x5"
                                    text: root.ago(row.modelData.ts)
                                    color: Ink.lcdSoft
                                }
                            }
                        }
                    }
                }
            }
            Dots {
                id: foot
                x: b.inX
                y: b.listY
                width: b.inW
                height: b.keysY + 18 - b.listY
                soft: true
                halo: Ink.lcdSoft
                MatrixText {
                    visible: root.items.length === 0
                    y: 4
                    width: implicitWidth
                    height: 7
                    text: root.words.quiet || "NO PAGES"
                    color: Ink.lcdSoft
                }
                MatrixText {
                    y: foot.rows - 6
                    width: Math.max(0, foot.cols - Math.ceil(keys.width / b.p) - 4)
                    height: 5
                    font: "3x5"
                    scroll: true
                    text: "READ · CLEAR · HOLD = DND · " + root.items.length + " KEPT"
                    color: Ink.lcdSoft
                }
            }
            Row {
                id: keys
                anchors.right: parent.right
                anchors.rightMargin: b.width - b.inX - b.inW
                y: b.keysY
                spacing: 6
                Pill {
                    height: 18
                    text: "READ"
                    tone: "read"
                    action: "pane notifs"
                }
                Pill {
                    height: 18
                    text: "CLEAR"
                    tone: "clear"
                    action: "notifs clear"
                }
                Pill {
                    height: 18
                    text: "HOLD"
                    on: root.dnd
                    action: "dnd toggle"
                }
            }
        }
    }
}
