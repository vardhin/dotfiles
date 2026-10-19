import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs
import qs.services

// MESSAGES (Super N): live notifications with their actions, then the log.
// [DND] holds back toasts and the ticker (critical ones still come through).
Pane {
    id: pane

    name: "notifs"
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
            text: "MESSAGES"
            color: Tokens.slot2
        }
        Row {
            anchors.right: parent.right
            spacing: 3

            DotButton {
                text: "DND"
                active: Notifs.dnd
                onClicked: Notifs.setDnd(!Notifs.dnd)
            }
            DotButton {
                text: "CLEAR"
                enabled: Notifs.live.length > 0
                onClicked: Notifs.clearLive()
            }
            DotButton {
                text: "WIPE LOG"
                enabled: Notifs.history.length > 0
                onClicked: Notifs.clearHistory()
            }
        }
    }

    Rectangle {
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
                color: Tokens.slot1
            }

            DotText {
                visible: Notifs.live.length === 0
                height: Tokens.lineDots
                text: "ALL CAUGHT UP"
                opacity: 0.5
            }

            Repeater {
                model: Notifs.live

                NotifCard {
                    required property Notification modelData
                    width: body.width
                    notif: modelData
                }
            }

            Item {
                width: 1
                height: 2
            }

            DotText {
                height: Tokens.lineDots
                text: `LOG ${Notifs.history.length}`
                color: Tokens.slot1
            }

            Repeater {
                model: Notifs.history

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
