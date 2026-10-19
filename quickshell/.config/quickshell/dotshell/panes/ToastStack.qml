import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs
import qs.services
import "../NotifLook.js" as NotifLook

// New notifications, top right under the strip. Critical ones stay until
// dismissed; the rest leave after their own timeout (or 6 s). Leaving the
// toast does not dismiss the notification: it stays in the MESSAGES pane.
Pane {
    id: pane

    name: "toasts"
    eraFrame: true
    title: "inbox.exe"
    icon: "✉"
    caption: "ARRIVALS"
    captionStatus: Notifs.toasts.length + " IN"
    managed: false
    shown: Notifs.toasts.length > 0 && Ui.pane !== "notifs"
    grab: false
    keyboard: WlrKeyboardFocus.None
    screen: Ui.focusedScreen()

    anchors {
        top: true
        right: true
    }

    cols: 40 * Tokens.charDots + 8
    rows: stack.implicitHeight + 8

    Column {
        id: stack
        x: 4
        y: 4
        width: pane.cols - 8
        spacing: 4

        Repeater {
            model: Notifs.toasts

            Column {
                id: toast
                required property Notification modelData
                required property int index
                width: stack.width
                spacing: 4

                // Rule between toasts: one dim dot row.
                Rectangle {
                    visible: toast.index > 0 && !NotifLook.get(Tokens.era)
                    width: parent.width
                    height: 1
                    color: Tokens.slot1
                    opacity: 0.5
                }

                NotifCard {
                    width: parent.width
                    notif: toast.modelData
                    live: toast.index === 0
                }

                Timer {
                    running: toast.modelData?.urgency !== NotificationUrgency.Critical
                    interval: (toast.modelData?.expireTimeout ?? 0) > 0 ? Math.min(toast.modelData.expireTimeout * 1000, 15000) : 6000
                    onTriggered: Notifs.dropToast(toast.modelData)
                }
            }
        }
    }
}
