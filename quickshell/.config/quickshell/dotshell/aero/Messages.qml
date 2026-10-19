import QtQuick
import QtQuick.Effects
import qs
import qs.services
import qs.tokyo as T

// Messages, Frutiger Aero: "Notifications" and how many are new over the
// latest ones as white glass pills, each with its app's glossy marble, the
// app and what it said, and when. A click opens the message centre, the
// count toggles do not disturb, which greys the whole glass. Expanded, the
// history grouped by app on white cards in bubble dots; a notification
// still on screen offers its own actions as glossy keys.
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
    // One marble colour per app, steady across reloads.
    function hue(app: string): int {
        let h = 0;
        for (const ch of String(app))
            h = (h * 31 + ch.charCodeAt(0)) % 997;
        return h % 3;
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

        Sky {
            anchors.fill: parent
            radius: root.big ? 28 : Math.min(26, height * 0.2)
            gloss: false
        }

        Loader {
            anchors.fill: parent
            sourceComponent: root.big ? board : pills
        }
    }

    // ── Compact: the latest ─────────────────────────────────────────
    Component {
        id: pills
        Item {
            id: c
            readonly property real padX: 14
            readonly property real rowH: 26
            readonly property int fit: Math.max(1, Math.floor((height - 44) / (rowH + 5)))

            Item {
                x: c.padX + 2
                y: 10
                width: parent.width - c.padX * 2 - 4
                height: 20
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.words.title || "Notifications"
                    color: Ink.blue
                    font.family: Ink.family
                    font.pixelSize: 13
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.dnd ? "Do not disturb" : root.live + " new"
                    color: Ink.blue
                    font.family: Ink.family
                    font.pixelSize: 13
                    T.Hit {
                        anchors.fill: parent
                        anchors.margins: -4
                        action: "dnd toggle"
                    }
                }
            }

            Column {
                x: c.padX
                y: 34
                width: parent.width - c.padX * 2
                spacing: 5
                Repeater {
                    model: root.items.slice(0, c.fit)
                    Item {
                        id: pill
                        required property var modelData
                        width: parent.width
                        height: c.rowH
                        Card {
                            anchors.fill: parent
                            radius: height / 2
                            to: Ink.ice
                        }
                        Orb {
                            x: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: 17
                            height: 17
                            hue: root.hue(pill.modelData.app)
                        }
                        Text {
                            x: 30
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - x - time.width - 14
                            elide: Text.ElideRight
                            textFormat: Text.StyledText
                            text: "<font color='" + Ink.blue + "'>" + String(pill.modelData.app).replace(/</g, "&lt;") + "</font> — " + String(pill.modelData.summary).replace(/</g, "&lt;")
                            color: Ink.navy
                            font.family: Ink.family
                            font.pixelSize: 13
                        }
                        Text {
                            id: time
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.ago(pill.modelData.ts)
                            color: Ink.mist
                            font.family: Ink.family
                            font.pixelSize: 11
                        }
                        T.Hit {
                            anchors.fill: parent
                            action: "pane notifs"
                        }
                    }
                }
            }
            Text {
                visible: root.items.length === 0
                anchors.horizontalCenter: parent.horizontalCenter
                y: 34 + (parent.height - 34 - height) / 2 - 6
                text: root.words.quiet || "No notifications"
                color: Ink.blue
                font.family: Ink.family
                font.pixelSize: 13
            }
        }
    }

    // ── Expanded: by app ────────────────────────────────────────────
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
            readonly property int padX: 6
            readonly property int lineH: 9
            readonly property int topY: 5 + 7 + 5
            function groupH(g: var): int {
                return 3 + 5 + 3 + Math.min(2, g.items.length) * lineH + 2;
            }
            readonly property var placed: {
                const out = [];
                let y = topY;
                for (const g of groups) {
                    const h = groupH(g);
                    if (y + h > rows - 11)
                        break;
                    out.push({ g: g, y: y, h: h });
                    y += h + 4;
                }
                return out;
            }

            // The cards and the live notifications' keys, crisp.
            Repeater {
                model: b.placed
                Item {
                    id: rim
                    required property var modelData
                    x: b.padX * b.p
                    y: modelData.y * b.p
                    width: (b.cols - b.padX * 2) * b.p
                    height: modelData.h * b.p
                    Card {
                        anchors.fill: parent
                        radius: 14
                    }
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
                            anchors.rightMargin: 4 * b.p
                            y: (11 + index * b.lineH) * b.p - 3
                            spacing: 4
                            Repeater {
                                model: parent.note ? Array.from(parent.note.actions ?? []).slice(0, 2) : []
                                Key {
                                    required property var modelData
                                    width: 24 * b.p
                                    height: b.lineH * b.p - 2
                                    radius: height / 2
                                    textPx: 11
                                    text: String(modelData.text).toUpperCase().slice(0, 8)
                                    onTap: modelData.invoke()
                                }
                            }
                        }
                    }
                }
            }

            Dots {
                anchors.fill: parent

                // Notifications                              3 NEW
                MatrixText {
                    x: b.padX
                    y: 5
                    height: 7
                    text: root.words.title || "Notifications"
                    color: Ink.navy
                }
                MatrixText {
                    anchors.right: parent.right
                    anchors.rightMargin: b.padX
                    y: 5
                    width: implicitWidth
                    height: 7
                    text: root.dnd ? "DND" : root.live + " NEW"
                    color: Ink.navy
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
                            x: 5
                            y: 3
                            height: 5
                            font: "3x5"
                            text: grp.modelData.g.app
                            color: Ink.blue
                        }
                        MatrixText {
                            anchors.right: parent.right
                            anchors.rightMargin: 5
                            y: 3
                            width: implicitWidth
                            height: 5
                            font: "3x5"
                            text: grp.modelData.g.items.length
                            color: Ink.blue
                        }
                        Repeater {
                            model: grp.modelData.g.items.slice(0, 2)
                            Item {
                                id: row
                                required property var modelData
                                required property int index
                                readonly property var note: root.liveFor(modelData)
                                readonly property int keysW: note ? Math.min(2, (note.actions ?? []).length) * 26 : 0
                                x: 5
                                y: 10 + index * b.lineH
                                width: grp.width - 10
                                height: b.lineH
                                MatrixText {
                                    y: 1
                                    width: parent.width - time.width - 6 - row.keysW
                                    height: 7
                                    text: row.modelData.summary
                                    color: Ink.navy
                                }
                                MatrixText {
                                    id: time
                                    x: parent.width - width - row.keysW
                                    y: 2
                                    width: implicitWidth
                                    height: 5
                                    font: "3x5"
                                    text: root.ago(row.modelData.ts)
                                    color: Ink.mist
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
                    text: root.words.quiet || "NO NOTIFICATIONS"
                    color: Ink.blue
                }
                MatrixText {
                    x: b.padX
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 5
                    width: b.cols - b.padX * 2
                    height: 5
                    font: "3x5"
                    scroll: true
                    text: "CLICK A NOTIFICATION FOR THE MESSAGE CENTRE · CLICK THE COUNT FOR DO NOT DISTURB"
                    color: Ink.blue
                }
            }
        }
    }
}
