import QtQuick
import Quickshell.Services.Notifications
import qs

// One live notification, in dots: app, summary, body, action buttons.
// Clicking the text runs the default action (if any); [X] dismisses.
Column {
    id: card

    required property Notification notif
    readonly property bool critical: notif?.urgency === NotificationUrgency.Critical
    readonly property var defaultAction: (notif?.actions ?? []).find(a => a.identifier === "default") ?? null
    readonly property var buttons: (notif?.actions ?? []).filter(a => a.identifier !== "default")

    spacing: 1

    Item {
        width: card.width
        height: Tokens.lineDots

        DotText {
            text: (card.notif?.appName || "SYSTEM").toUpperCase()
            color: card.critical ? Tokens.slot2 : Tokens.slot1
            width: parent.width - close.width - 2
            elide: Text.ElideRight
        }
        DotButton {
            id: close
            anchors.right: parent.right
            text: "X"
            color: Tokens.slot1
            onClicked: card.notif.dismiss()
        }
    }

    DotLabel {
        width: card.width
        text: card.notif?.summary ?? ""
        color: card.critical ? Tokens.slot2 : Tokens.slot0
        wrapMode: Text.Wrap
        maximumLineCount: 2
    }

    DotLabel {
        width: card.width
        visible: text !== ""
        text: card.notif?.body ?? ""
        color: Tokens.slot1
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
        width: card.width
        visible: card.buttons.length > 0
        spacing: 3

        Repeater {
            model: card.buttons

            DotButton {
                required property var modelData
                text: (modelData.text || modelData.identifier).toUpperCase()
                color: Tokens.slot2
                onClicked: modelData.invoke()
            }
        }
    }
}
