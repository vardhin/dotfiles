pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs

// The notification daemon. Dot Shell is the server, so nothing else
// (mako, swaync, AGS) may run alongside it.
//
//   live      notifications still open (shown in the MESSAGES pane)
//   toasts    the ones currently popped up top right
//   history   every non-transient notification, newest first, persisted to
//             ${XDG_STATE_HOME:-~/.local/state}/dotshell/notifications.json
//   arrived   fires for each new popup; the strip ticker listens to it
Singleton {
    id: root

    readonly property var live: server.trackedNotifications.values
    property var toasts: []
    readonly property var history: store.items
    readonly property bool dnd: store.dnd
    readonly property int historyLimit: 150

    signal arrived(Notification n)

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false

        onNotification: n => {
            // A replace tag (notify-send --hint string:x-canonical-private-synchronous:TAG)
            // updates the previous notification with the same tag instead of stacking.
            const tag = root.tagOf(n);
            if (tag !== "") {
                for (const old of server.trackedNotifications.values) {
                    if (old !== n && root.tagOf(old) === tag)
                        old.expire();
                }
            }

            n.tracked = true;
            n.closed.connect(() => root.dropToast(n));
            if (!n.transient)
                root.record(n);
            if (!root.dnd || n.urgency === NotificationUrgency.Critical) {
                root.toasts = [n, ...root.toasts.filter(t => t !== n)].slice(0, 4);
                root.arrived(n);
            }
        }
    }

    function tagOf(n: Notification): string {
        const h = n.hints ?? {};
        return String(h["x-canonical-private-synchronous"] ?? h["synchronous"] ?? "");
    }

    function urgencyName(u: int): string {
        return u === NotificationUrgency.Critical ? "critical" : u === NotificationUrgency.Low ? "low" : "normal";
    }

    function record(n: Notification): void {
        const entry = {
            app: n.appName || "System",
            summary: (n.summary || n.body || n.appName || "Notification").trim(),
            body: (n.body || "").trim(),
            urgency: urgencyName(n.urgency),
            ts: Date.now()
        };
        store.items = [entry, ...store.items].slice(0, historyLimit);
    }

    function dropToast(n: Notification): void {
        toasts = toasts.filter(t => t !== n);
    }

    function setDnd(on: bool): void {
        store.dnd = on;
    }

    function clearLive(): void {
        for (const n of [...server.trackedNotifications.values])
            n.dismiss();
    }

    function clearHistory(): void {
        store.items = [];
    }

    // One message out of the history (by its time), and off the screen if
    // it is still there.
    function forget(ts: real): void {
        const e = store.items.find(x => x.ts === ts);
        if (!e)
            return;
        for (const n of [...server.trackedNotifications.values])
            if ((n.appName || "System") === e.app && (n.summary || n.body || n.appName || "Notification").trim() === e.summary)
                n.dismiss();
        store.items = store.items.filter(x => x !== e);
    }

    // ── Persistence ─────────────────────────────────────────────────
    FileView {
        id: file
        path: Tokens.dirReady ? Tokens.dir + "/notifications.json" : ""
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: store
            property var items: []
            property bool dnd: false
        }
    }

    IpcHandler {
        target: "notifs"

        function dnd(): string {
            root.setDnd(!root.dnd);
            return root.dnd ? "dnd on" : "dnd off";
        }
        function clear(): void {
            root.clearLive();
        }
        function clearHistory(): void {
            root.clearHistory();
        }
        function count(): int {
            return root.live.length;
        }
    }
}
