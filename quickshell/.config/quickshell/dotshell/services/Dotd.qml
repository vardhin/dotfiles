pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs

// The shell's side of dotd (dotd/ in the dotfiles), the event daemon. dotd
// pushes feeds and notifications to the shell over the dot socket; this is
// the other direction: one line of JSON per request to dotd's own socket,
//   ${XDG_RUNTIME_DIR}/dotd.sock
// and the shell events dotd gates its heavy work on (idle, AC power, CPU
// temperature), sent whenever they change.
//   send("undo 42")            {"cmd":"undo","arg":"42"}
//   query("f red bike", cb)    {"cmd":"query","q":"f red bike"} -> cb(reply)
Singleton {
    id: root

    readonly property string path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/dotd.sock"
    property bool up: false
    property var pending: []
    property int seq: 0
    property var callbacks: ({})

    function send(line: string): void {
        const words = String(line).trim().split(/\s+/);
        request({ cmd: words[0], arg: words.slice(1).join(" ") }, null);
    }

    function query(q: string, cb: var): void {
        request({ cmd: "query", q: q }, cb);
    }

    function request(obj: var, cb: var): void {
        seq++;
        const req = Object.assign({ id: seq }, obj);
        if (cb) {
            const c = Object.assign({}, callbacks);
            c[seq] = cb;
            callbacks = c;
        }
        if (sock.connected) {
            sock.write(JSON.stringify(req) + "\n");
            sock.flush();
        } else {
            pending = [...pending, req].slice(-50);
            connect();
        }
    }

    // Socket keeps wanting a connection after one fails, so setting
    // connected again is a no-op: drop the want, then ask again.
    function connect(): void {
        sock.connected = false;
        sock.connected = true;
    }

    Socket {
        id: sock
        path: root.path
        onConnectionStateChanged: {
            root.up = connected;
            if (connected) {
                for (const r of root.pending)
                    write(JSON.stringify(r) + "\n");
                root.pending = [];
                flush();
                root.sendState();
            }
        }
        parser: SplitParser {
            onRead: line => {
                let r;
                try {
                    r = JSON.parse(line);
                } catch (e) {
                    return;
                }
                const cb = root.callbacks[r.id];
                if (cb) {
                    const c = Object.assign({}, root.callbacks);
                    delete c[r.id];
                    root.callbacks = c;
                    cb(r);
                }
            }
        }
    }

    // dotd starts after the shell, or restarts: try again every 30 s.
    Timer {
        running: !sock.connected
        interval: 30000
        repeat: true
        onTriggered: root.connect()
    }

    // ── Shell events in ─────────────────────────────────────────────
    readonly property bool idle: idleMon.isIdle
    readonly property bool ac: !Power.discharging
    readonly property int temp: Math.round(Sys.temp)
    onIdleChanged: sendState()
    onAcChanged: sendState()
    // At most every 5 s: the temperature moves on every 2 s poll.
    onTempChanged: if (!tempSend.running) tempSend.start()

    IdleMonitor {
        id: idleMon
        timeout: 120
        respectInhibitors: false
    }
    Timer {
        id: tempSend
        interval: 5000
        onTriggered: root.sendState()
    }
    // dotd needs the temperature even with no panel showing it.
    Component.onCompleted: {
        Sys.want("dotd", true);
        connect();
    }

    function sendState(): void {
        if (!sock.connected)
            return;
        sock.write(JSON.stringify({ cmd: "shell", idle: idle, ac: ac, temp: temp }) + "\n");
        sock.flush();
    }
}
