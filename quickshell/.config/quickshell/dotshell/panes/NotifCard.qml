import QtQuick
import Quickshell.Services.Notifications
import qs
import "../NotifLook.js" as NotifLook

// One live notification, in dots: app, summary, body, action buttons.
// Clicking the text runs the default action (if any); [X] dismisses.
// In the finished eras (NotifLook.js) it is the design's Messages card: a
// ruled (aero: white glass) card, the live one ruled in the accent, the
// app in the era's accent (aero: with its marble), the words, and the
// actions as the era's keys.
Item {
    id: card

    required property Notification notif
    // Ruled in the accent: the newest, still on screen.
    property bool live: true
    readonly property var look: NotifLook.get(Tokens.era, Tokens.flipped)
    readonly property bool critical: notif?.urgency === NotificationUrgency.Critical
    readonly property var defaultAction: (notif?.actions ?? []).find(a => a.identifier === "default") ?? null
    readonly property var buttons: (notif?.actions ?? []).filter(a => a.identifier !== "default")
    // Room inside the card's rule.
    readonly property int padX: look ? 4 : 0
    readonly property int padY: look ? 3 : 0

    implicitHeight: col.implicitHeight + padY * 2

    Rectangle {
        visible: !!card.look
        anchors.fill: parent
        radius: card.look?.radius ?? 0
        color: card.look?.fill ?? "transparent"
        border.width: 1
        border.color: card.critical ? (card.look?.crit ?? "transparent") : card.live ? (card.look?.live ?? "transparent") : (card.look?.rim ?? "transparent")
    }

    Column {
        id: col
        x: card.padX
        y: card.padY
        width: card.width - card.padX * 2
        spacing: 1

        Item {
            width: col.width
            height: Tokens.lineDots

            // Aero: the app's marble.
            Rectangle {
                id: marble
                visible: !!card.look?.marble
                anchors.verticalCenter: parent.verticalCenter
                width: visible ? 5 : 0
                height: 5
                radius: 2.5
                color: NotifLook.marble(card.notif?.appName || "System")
            }
            DotText {
                x: marble.visible ? marble.width + 3 : 0
                text: card.look ? (card.notif?.appName || "System") : (card.notif?.appName || "SYSTEM").toUpperCase()
                color: card.critical ? (card.look?.crit ?? Tokens.slot2) : (card.look?.app ?? Tokens.slot1)
                width: parent.width - x - close.width - 2
                elide: Text.ElideRight
            }
            NotifKey {
                id: close
                anchors.right: parent.right
                look: null
                text: "X"
                plain: card.look?.time ?? Tokens.slot1
                onClicked: card.notif.dismiss()
            }
        }

        DotLabel {
            width: col.width
            text: card.notif?.summary ?? ""
            color: card.critical ? (card.look?.crit ?? Tokens.slot2) : (card.look?.text ?? Tokens.slot0)
            wrapMode: Text.Wrap
            maximumLineCount: 2
        }

        DotLabel {
            width: col.width
            visible: text !== ""
            text: card.notif?.body ?? ""
            color: card.look?.body ?? Tokens.slot1
            wrapMode: Text.Wrap
            maximumLineCount: 3

            MouseArea {
                anchors.fill: parent
                enabled: card.defaultAction !== null
                cursorShape: Qt.PointingHandCursor
                onClicked: card.defaultAction.invoke()
            }
        }

        Flow {
            width: col.width
            visible: card.buttons.length > 0
            spacing: 3

            Repeater {
                model: card.buttons

                NotifKey {
                    required property var modelData
                    look: card.look
                    text: (modelData.text || modelData.identifier).toUpperCase()
                    onClicked: modelData.invoke()
                }
            }
        }
    }
}
