pragma Singleton

import QtQuick
import Quickshell

// Send a notification from inside the shell. It goes out over D-Bus and
// comes back in through Notifs, so it gets a toast and a history entry
// like any other app's.
Singleton {
    function send(summary: string, body: string, opts: var): void {
        const o = opts ?? {};
        const args = ["notify-send", "--app-name", o.app ?? "dotshell"];
        if (o.urgency)
            args.push("--urgency", o.urgency);
        if (o.icon)
            args.push("--icon", o.icon);
        if (o.expire !== undefined)
            args.push("--expire-time", String(o.expire));
        if (o.tag)
            args.push("--hint", "string:x-canonical-private-synchronous:" + o.tag);
        if (o.transient)
            args.push("--transient");
        args.push(summary);
        if (body)
            args.push(body);
        Quickshell.execDetached(args);
    }
}
