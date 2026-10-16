pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// The `dot` bus: one Unix socket, one JSON object per line each way.
//   ${XDG_RUNTIME_DIR}/dotshell.sock
// Same API for the `dot` CLI (bin/dot), scripts and agents:
//   {"cmd":"spawn","kind":"note","id":"todo","shape":"circle","x":52,"y":18,"w":32,"h":28}
//   {"cmd":"write","id":"sign","text":"RAIN CITY"}
//   {"cmd":"pixels","id":"vis","w":64,"h":32,"data":"<base64 PPM (P6)>"}
//   {"cmd":"move","id":"clock","x":60,"y":20}
//   {"cmd":"set","id":"player","fields":{"dot":false}}
//   {"cmd":"rm","id":"todo"}
//   {"cmd":"list"}
//   {"cmd":"era","name":"tokyo"}
//   {"cmd":"display","pitch":5,"depth":"16","dotSize":80,"wallpaper":"~/w.jpg"}
//   {"cmd":"tokens"}
// Replies: {"ok":true, ...} or {"ok":false,"error":"..."}.
Singleton {
    id: root

    readonly property string path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/dotshell.sock"

    function handle(line: string): var {
        let req;
        try {
            req = JSON.parse(line);
        } catch (e) {
            return { ok: false, error: "not JSON: " + e.message };
        }
        const r = dispatch(req ?? {});
        // Panels answers {error} directly or inside `panel`.
        const err = r?.error ?? r?.panel?.error;
        if (err)
            return { ok: false, error: err };
        return Object.assign({ ok: true }, r ?? {});
    }

    function dispatch(q: var): var {
        switch (q.cmd) {
        case "spawn":
            return { panel: Panels.spawn(q.kind, q) };
        case "rm":
            return Panels.remove(q.id);
        case "move":
            return { panel: Panels.move(q.id, q.x, q.y) };
        case "set":
            return { panel: Panels.set(q.id, q.fields ?? {}) };
        case "write":
            return { panel: Panels.set(q.id, { text: q.text ?? "" }) };
        case "pixels":
            return Panels.pixels(q.id, q.w, q.h, q.data ?? "");
        case "list":
            // Panel resolution in dots at the current pitch, for `dot pixels`.
            return {
                unit: Panels.unit,
                pitch: Tokens.pitch,
                panels: Panels.panels.map(p => Object.assign({}, p, {
                    cols: Math.floor(p.w * Panels.unit / Tokens.pitch),
                    rows: Math.floor(p.h * Panels.unit / Tokens.pitch)
                }))
            };
        case "era":
            return msg(Tokens.set("era", String(q.name)));
        case "display":
            for (const k of ["pitch", "depth", "dotSize", "wallpaper", "night"]) {
                if (q[k] === undefined)
                    continue;
                const m = Tokens.set(k, String(q[k]));
                if (m !== "ok")
                    return { error: m };
            }
            return tokens();
        case "tokens":
            return tokens();
        default:
            return { error: "unknown cmd; one of: spawn rm move set write pixels list era display tokens" };
        }
    }

    // Tokens.set answers "ok" or a sentence.
    function msg(m: string): var {
        return m === "ok" ? {} : { error: m };
    }

    function tokens(): var {
        return { tokens: { era: Tokens.era, pitch: Tokens.pitch, dotSize: Math.round(Tokens.dotSize * 100), depth: Tokens.depth, wallpaper: Tokens.wallpaper, night: Tokens.night } };
    }

    SocketServer {
        active: true
        path: root.path

        handler: Socket {
            id: conn
            parser: SplitParser {
                onRead: line => {
                    if (line.trim() === "")
                        return;
                    conn.write(JSON.stringify(root.handle(line)) + "\n");
                    conn.flush();
                }
            }
        }
    }
}
