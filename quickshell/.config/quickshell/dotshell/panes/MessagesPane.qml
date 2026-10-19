import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs
import qs.services
import "../NotifLook.js" as NotifLook

// MESSAGES (Super N): live notifications with their actions, then the log.
// [DND] holds back toasts and the ticker (critical ones still come through).
// In the finished eras (NotifLook.js) it is the design's Messages board: the
// era's frame, the live ones as cards, and the log grouped by app on ruled
// cards (a click on a line opens it in full).
Pane {
    id: pane

    name: "notifs"
    eraFrame: true
    title: "inbox.exe — History"
    icon: "✉"
    caption: "ARRIVALS · ALL MESSAGES"
    captionStatus: Notifs.dnd ? "HELD" : "LIVE"
    readonly property var look: NotifLook.get(Tokens.era)
    // The log grouped by app, newest app first: [{ app, items }].
    readonly property var groups: {
        if (!look)
            return [];
        const out = [], by = {};
        for (const e of Notifs.history) {
            if (!by[e.app]) {
                by[e.app] = { app: e.app, items: [] };
                out.push(by[e.app]);
            }
            by[e.app].items.push(e);
        }
        return out;
    }
    function stamp(ts: real): string {
        const d = new Date(ts);
        const today = new Date().toDateString() === d.toDateString();
        return Qt.formatDateTime(d, today ? "hh:mm" : "dd MMM").toUpperCase();
    }
    anchors {
        top: true
        right: true
    }

    readonly property int inner: 40 * Tokens.charDots
    // The log entry opened in full (its ts; 0 = none). Click a row to toggle.
    property real openTs: 0
    onOpened: openTs = 0
    cols: inner + 8
    rows: Math.min(maxRows - 2, flick.y + Math.max(body.implicitHeight, Tokens.lineDots * 12) + 4)

    // ── Header ──────────────────────────────────────────────────────
    Item {
        id: header
        x: 4
        y: 4
        width: pane.inner
        height: Tokens.lineDots

        DotText {
            id: title
            text: pane.look ? "MESSAGES  " + (Notifs.dnd ? "DND" : Notifs.live.length + " NEW") : "MESSAGES"
            color: pane.look?.head ?? Tokens.slot2
        }
        Row {
            anchors.right: parent.right
            spacing: 3

            NotifKey {
                look: pane.look
                text: "DND"
                active: Notifs.dnd
                onClicked: Notifs.setDnd(!Notifs.dnd)
            }
            NotifKey {
                look: pane.look
                text: "CLEAR"
                enabled: Notifs.live.length > 0
                onClicked: Notifs.clearLive()
            }
            NotifKey {
                look: pane.look
                text: "WIPE LOG"
                enabled: Notifs.history.length > 0
                onClicked: Notifs.clearHistory()
            }
        }
    }

    Rectangle {
        visible: !pane.look
        x: 4
        y: header.y + header.height + 1
        width: pane.inner
        height: 1
        color: Tokens.slot1
        opacity: 0.5
    }

    // ── Body: live, then log; scrolls ───────────────────────────────
    Flickable {
        id: flick
        x: 4
        y: header.y + header.height + 4
        width: pane.inner
        height: pane.rows - y - 4
        contentHeight: body.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: body
            width: flick.width
            spacing: 4

            DotText {
                height: Tokens.lineDots
                text: `LIVE ${Notifs.live.length}`
                color: pane.look?.sub ?? Tokens.slot1
            }

            DotText {
                visible: Notifs.live.length === 0
                height: Tokens.lineDots
                text: "ALL CAUGHT UP"
                color: pane.look?.body ?? Tokens.slot0
                opacity: 0.5
            }

            Repeater {
                model: Notifs.live

                NotifCard {
                    required property Notification modelData
                    required property int index
                    width: body.width
                    notif: modelData
                    live: index === 0
                }
            }

            Item {
                width: 1
                height: 2
            }

            DotText {
                height: Tokens.lineDots
                text: `LOG ${Notifs.history.length}`
                color: pane.look?.sub ?? Tokens.slot1
            }

            // The finished eras: by app, on ruled cards.
            Repeater {
                model: pane.groups

                Item {
                    id: grp
                    required property var modelData
                    width: body.width
                    height: lines.implicitHeight + 6

                    Rectangle {
                        anchors.fill: parent
                        radius: pane.look?.radius ?? 0
                        color: pane.look?.fill ?? "transparent"
                        border.width: 1
                        border.color: pane.look?.rim ?? "transparent"
                    }
                    Column {
                        id: lines
                        x: 4
                        y: 3
                        width: parent.width - 8
                        spacing: 1

                        Item {
                            width: lines.width
                            height: Tokens.lineDots
                            Rectangle {
                                id: marble
                                visible: !!pane.look?.marble
                                anchors.verticalCenter: parent.verticalCenter
                                width: visible ? 5 : 0
                                height: 5
                                radius: 2.5
                                color: NotifLook.marble(grp.modelData.app)
                            }
                            DotText {
                                x: marble.visible ? marble.width + 3 : 0
                                width: parent.width - x - count.implicitWidth - 2
                                text: grp.modelData.app.toUpperCase()
                                color: pane.look?.app ?? Tokens.slot1
                                elide: Text.ElideRight
                            }
                            DotText {
                                id: count
                                anchors.right: parent.right
                                text: grp.modelData.items.length
                                color: pane.look?.sub ?? Tokens.slot1
                            }
                        }

                        Repeater {
                            model: grp.modelData.items

                            Item {
                                id: line
                                required property var modelData
                                readonly property bool open: pane.openTs === modelData.ts
                                readonly property color ink: modelData.urgency === "critical" ? pane.look.crit : pane.look.text
                                width: lines.width
                                height: open ? Tokens.lineDots + 2 + full.implicitHeight : Tokens.lineDots

                                DotText {
                                    width: parent.width - when.implicitWidth - Tokens.charDots
                                    height: Tokens.lineDots
                                    text: line.modelData.summary + (!line.open && line.modelData.body ? " · " + line.modelData.body : "")
                                    color: line.ink
                                    elide: Text.ElideRight
                                }
                                DotText {
                                    id: when
                                    anchors.right: parent.right
                                    height: Tokens.lineDots
                                    text: pane.stamp(line.modelData.ts)
                                    color: pane.look.time
                                }
                                // Opened: the body, wrapped.
                                DotLabel {
                                    id: full
                                    visible: line.open
                                    y: Tokens.lineDots + 2
                                    width: parent.width
                                    text: line.modelData.body || line.modelData.summary
                                    color: pane.look.body
                                    wrapMode: Text.Wrap
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: pane.openTs = line.open ? 0 : line.modelData.ts
                                }
                            }
                        }
                    }
                }
            }

            // Plain eras: one line per entry.
            Repeater {
                model: pane.look ? [] : Notifs.history

                Item {
                    id: row
                    required property var modelData
                    readonly property bool open: pane.openTs === modelData.ts
                    width: body.width
                    height: open ? Tokens.lineDots + 2 + more.implicitHeight : Tokens.lineDots

                    readonly property string time: {
                        const d = new Date(modelData.ts);
                        const today = new Date().toDateString() === d.toDateString();
                        return Qt.formatDateTime(d, today ? "hh:mm" : "dd MMM").toUpperCase();
                    }

                    DotText {
                        id: stamp
                        height: Tokens.lineDots
                        width: 6 * Tokens.charDots
                        text: row.time
                        color: Tokens.slot1
                        opacity: 0.5
                    }
                    DotText {
                        id: app
                        height: Tokens.lineDots
                        x: stamp.width + Tokens.charDots
                        width: 10 * Tokens.charDots
                        text: row.modelData.app.toUpperCase()
                        color: row.modelData.urgency === "critical" ? Tokens.slot2 : Tokens.slot1
                        elide: Text.ElideRight
                    }
                    DotText {
                        x: app.x + app.width + Tokens.charDots
                        width: row.width - x
                        height: Tokens.lineDots
                        visible: !row.open
                        text: row.modelData.summary + (row.modelData.body ? " · " + row.modelData.body : "")
                        elide: Text.ElideRight
                    }
                    // Opened: the whole summary and body, wrapped.
                    Column {
                        id: more
                        visible: row.open
                        y: Tokens.lineDots + 2
                        width: row.width
                        spacing: 2

                        DotLabel {
                            width: parent.width
                            text: row.modelData.summary
                            color: row.modelData.urgency === "critical" ? Tokens.slot2 : Tokens.slot0
                            wrapMode: Text.Wrap
                        }
                        DotLabel {
                            width: parent.width
                            visible: text !== ""
                            text: row.modelData.body ?? ""
                            color: Tokens.slot1
                            wrapMode: Text.Wrap
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pane.openTs = row.open ? 0 : row.modelData.ts
                    }
                }
            }
        }
    }

    // Keyboard scroll.
    onKeyPressed: event => {
        const step = Tokens.lineDots * 3;
        if (event.key === Qt.Key_Up || event.key === Qt.Key_K)
            flick.contentY = Math.max(0, flick.contentY - step);
        else if (event.key === Qt.Key_Down || event.key === Qt.Key_J)
            flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), flick.contentY + step);
    }
}
