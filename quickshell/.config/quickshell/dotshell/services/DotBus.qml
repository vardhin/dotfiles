pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import "../Templates.js" as Templates

// The `dot` bus: one Unix socket, one JSON object per line each way.
//   ${XDG_RUNTIME_DIR}/dotshell.sock
// Same API for the `dot` CLI (bin/dot), scripts and agents:
//   {"cmd":"spawn","template":"todo","place":"home","x":52,"y":18,"w":32,"h":28}
//   {"cmd":"spawn","template":"board","id":"ci","feed":"ci","layout":{...}}
//   {"cmd":"feed","id":"ci","data":{"state":"green"},"merge":false}
//   {"cmd":"feeds"}                        feed ids, and what each holds
//   {"cmd":"dock","id":"todo","place":"strip","zone":"r","order":0}
//   {"cmd":"undo"}                         the last dock or undock, within 3 s
//   {"cmd":"home","reset":true}            lay the 15-panel set out again
//   {"cmd":"templates"}
//   {"cmd":"action","run":"ws 3"}          any panel action (services/Actions.qml)
//   {"cmd":"write","id":"sign","text":"RAIN CITY"}
//   {"cmd":"pixels","id":"vis","w":64,"h":32,"data":"<base64 PPM (P6)>"}
//   {"cmd":"move","id":"clock","x":60,"y":20}
//   {"cmd":"set","id":"player","fields":{"dot":false}}
//   {"cmd":"rm","id":"todo"}
//   {"cmd":"list"}
//   {"cmd":"era","name":"tokyo"}          {"cmd":"era","step":1} next, -1 previous
//   {"cmd":"eras"}                         ids, names, the applied one
//   {"cmd":"display","pitch":5,"depth":"16","dotSize":80,"wall":"dots",
//    "wallpaper":"~/w.jpg","hue":"wallpaper","cascade":true,
//    "screen":"led","night":true}
//   {"cmd":"tokens"}
//   {"cmd":"ws","go":"3"}  {"cmd":"ws","move":"e+1"}   workspace switch, with the dissolve
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
            return { panel: Panels.spawn(q.template ?? q.kind, q) };
        case "feed":
            if (q.drop)
                return Feeds.drop(String(q.id));
            return Feeds.push(String(q.id ?? ""), q.data, !!q.merge);
        case "feeds":
            return { feeds: Feeds.ids().map(id => ({ id: id, pushed: Feeds.pushed[id] !== undefined, keys: Object.keys(Feeds.get(id) ?? {}) })) };
        case "dock":
            return { panel: Panels.place(q.id, q.place ?? "strip", q.zone ?? "r", parseInt(q.order ?? 99), parseInt(q.x ?? 4), parseInt(q.y ?? 6), parseInt(q.ws ?? 0)) };
        case "undo":
            return Panels.undoLast();
        case "peek": {
            // Open a docked item's whole panel beside it, as a click would.
            const s = Panels.slots[q.id];
            if (!s)
                return { error: "no docked item " + q.id };
            Panels.peek = { id: q.id, place: s.place, x: s.x + s.w / 2, y: s.y + s.h / 2 };
            Ui.open("peek", null);
            return { ok: true };
        }
        case "home":
            if (q.reset)
                return Panels.reset();
            return { home: Tokens.home, panels: Panels.home.map(p => p.id) };
        case "templates":
            return { templates: Templates.names.map(n => ({ name: n, title: Templates.get(n).title, feed: Templates.get(n).feed ?? "" })) };
        case "action":
            return msgAction(Actions.run(String(q.run ?? "")));
        case "rm":
            return Panels.remove(q.id);
        case "close":
            return { panel: Panels.close(q.id) };
        case "open":
            return { panel: Panels.open(q.id, String(q.place ?? "home")) };
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
            if (q.step !== undefined && q.name === undefined)
                return { era: Tokens.cycleEra(parseInt(q.step) || 1) };
            return msg(Tokens.set("era", String(q.name)));
        case "eras":
            return {
                era: Tokens.era,
                eras: Eras.ids.map(id => ({ id: id, name: Eras.all[id].name, blurb: Eras.all[id].blurb ?? "", light: !!Eras.all[id].light }))
            };
        case "display":
            for (const k of Tokens.keys) {
                if (k === "era")
                    continue;
                if (q[k] === undefined)
                    continue;
                const m = Tokens.set(k, String(q[k]));
                if (m !== "ok")
                    return { error: m };
            }
            return tokens();
        case "tokens":
            return tokens();
        case "ws":
            // Workspace switch through the shell (the dissolve): `dotws go 3`.
            if (q.go !== undefined)
                WsFx.go(String(q.go));
            else if (q.move !== undefined)
                WsFx.move(String(q.move));
            else
                return { error: "ws takes go or move" };
            return {};
        case "wall":
            // The P10 wall (services/Wall.qml): `dot wall on HOST --source clock`.
            if (q.action === "pixels")
                return Wall.pixels(parseInt(q.w), parseInt(q.h), q.data ?? "");
            if (q.action === "status" || q.action === undefined)
                return Wall.status();
            return Wall.configure(Object.assign({}, q.fields ?? {}, q.action === "on" ? { on: true } : q.action === "off" ? { on: false } : {}));
        default:
            return { error: "unknown cmd; one of: spawn rm move set write pixels list feed feeds dock undo home templates action era eras display tokens ws wall" };
        }
    }

    function msgAction(m: string): var {
        return m === "ok" ? {} : { error: m };
    }

    // Tokens.set answers "ok" or a sentence.
    function msg(m: string): var {
        return m === "ok" ? {} : { error: m };
    }

    function tokens(): var {
        return { tokens: Tokens.snapshot() };
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
