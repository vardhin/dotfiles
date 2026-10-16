pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import "WallCtx.js" as WallCtx
import "../panes/Scenes.js" as Scenes

// The P10 wall: a real LED board (2x2 P10 RGB panels on a Raspberry Pi 5,
// 64 x 32 by default) that shows a piece of Dot Shell. The shell renders
// every frame itself, in software at the wall's own size (WallCtx.js), and
// `dotwall feed` sends it over UDP to `p10/dotwall-pi.py` on the Pi, which
// only puts pixels on the panels.
//
// Sources:
//   scene   the era's scene (panes/Scenes.js), in the era's tubes
//   clock   the time, big, with a seconds bar
//   media   now playing: title scrolling, progress, spectrum
//   text    your text scrolling (`dot wall text "OPEN 24 HRS"`)
//   pixels  raw frames you push (`dot wall pixels < frame.rgb`)
//
//   dot wall on 192.168.1.40 --source clock      dot wall off
//   dot wall source scene                         dot wall
// Settings persist in ${XDG_STATE_HOME}/dotshell/wall.json.
Singleton {
    id: root

    readonly property bool on: store.on && store.host !== ""
    readonly property string host: store.host
    readonly property int port: store.port
    readonly property string source: store.source
    readonly property int w: store.w
    readonly property int h: store.h
    readonly property int fps: Math.max(1, Math.min(30, store.fps))
    readonly property var sources: ["scene", "clock", "media", "text", "pixels"]

    // ── Persisted ───────────────────────────────────────────────────
    FileView {
        id: file
        path: Tokens.dirReady ? Tokens.dir + "/wall.json" : ""
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }
        JsonAdapter {
            id: store
            property bool on: false
            property string host: ""
            property int port: 7373
            property string source: "scene"
            property string text: "DOT SHELL"
            property int w: 64
            property int h: 32
            property int fps: 15
        }
    }

    function configure(q: var): var {
        if (q.host !== undefined) {
            const m = String(q.host).match(/^([^:]+)(?::(\d+))?$/);
            if (!m)
                return { error: "host is HOST or HOST:PORT" };
            store.host = m[1];
            if (m[2])
                store.port = parseInt(m[2]);
        }
        if (q.port !== undefined)
            store.port = parseInt(q.port) || 7373;
        if (q.source !== undefined) {
            if (!sources.includes(q.source))
                return { error: "source is one of: " + sources.join(", ") };
            store.source = q.source;
        }
        if (q.text !== undefined)
            store.text = String(q.text);
        if (q.size !== undefined) {
            const m = String(q.size).match(/^(\d+)x(\d+)$/);
            if (!m)
                return { error: "size is WxH, e.g. 64x32" };
            store.w = parseInt(m[1]);
            store.h = parseInt(m[2]);
        }
        if (q.fps !== undefined)
            store.fps = parseInt(q.fps) || 15;
        if (q.on !== undefined)
            store.on = !!q.on;
        return status();
    }

    function status(): var {
        return { wall: { on: on, host: host, port: port, source: source, text: store.text, size: w + "x" + h, fps: fps, sending: feeder.running } };
    }

    // ── Rendering ───────────────────────────────────────────────────
    property var ctx: null
    property var sceneState: null
    property string sceneKey: ""
    property var pushed: null      // the last `pixels` frame (Uint8Array)
    property real scroll: 0
    property real last: 0

    function pal(): var {
        return { s0: String(Tokens.slot0), s1: String(Tokens.slot1), s2: String(Tokens.slot2) };
    }

    function render(): void {
        if (!ctx || ctx.w !== w || ctx.h !== h)
            ctx = WallCtx.make(w, h);
        const now = Date.now();
        const dt = last ? Math.min(0.2, (now - last) / 1000) : 0;
        last = now;
        const p = pal();
        const c = ctx;
        let frame;
        if (source === "pixels") {
            frame = pushed && pushed.length === w * h * 3 ? pushed : new Uint8Array(w * h * 3);
        } else {
            if (source === "scene") {
                const key = (Tokens.current.id ?? Tokens.era) + " " + w + "x" + h;
                if (key !== sceneKey) {
                    sceneKey = key;
                    sceneState = Scenes.make(Tokens.current.id ?? Tokens.era, w, h);
                }
                Scenes.draw(sceneState, c, dt, p, new Date(now));
            } else {
                c.clearRect(0, 0, w, h);
                if (source === "clock")
                    drawClock(c, p, new Date(now));
                else if (source === "media")
                    drawMedia(c, p, dt);
                else
                    drawMarquee(c, p, store.text, Math.floor((h - 14) / 2), 2, dt);
            }
            frame = WallCtx.frame(c, null);
        }
        feeder.write(WallCtx.base64(frame) + "\n");
    }

    function pad(n: int): string {
        return (n < 10 ? "0" : "") + n;
    }

    function drawClock(c: var, p: var, d: var): void {
        const k = h >= 28 ? 2 : 1;
        c.fillStyle = p.s0;
        c.font = (11 * k) + "px mono";
        c.textAlign = "center";
        c.fillText(pad(d.getHours()) + (d.getSeconds() % 2 ? ":" : " ") + pad(d.getMinutes()), w / 2, Math.floor((h - 7 * k) / 2) - 2 * k - (k > 1 ? 3 : 0));
        c.fillStyle = p.s1;
        c.fillRect(0, h - 2, Math.round(w * d.getSeconds() / 59), 1);
        c.fillStyle = p.s2;
        c.font = "11px mono";
        c.textAlign = "center";
        if (k > 1)
            c.fillText(Qt.formatDate(d, w >= 64 ? "d MMM" : "d").toUpperCase(), w / 2, h - 12);
    }

    // Text scrolling right to left at `k` times the 5x7 font.
    function drawMarquee(c: var, p: var, s: string, y: int, k: int, dt: real): void {
        const width = s.length * 6 * k;
        c.font = (11 * k) + "px mono";
        c.textAlign = "left";
        c.fillStyle = p.s0;
        if (width <= w) {
            c.textAlign = "center";
            c.fillText(s, w / 2, y - 2 * k);
            return;
        }
        scroll = (scroll + dt * 18) % (width + w / 2);
        c.fillText(s, w - scroll, y - 2 * k);
        c.fillText(s, w - scroll + width + w / 2, y - 2 * k);
    }

    function drawMedia(c: var, p: var, dt: real): void {
        if (!Media.active) {
            drawMarquee(c, p, "NO MEDIA", 2, 1, dt);
            return;
        }
        drawMarquee(c, p, (Media.title + (Media.artist ? "  ·  " + Media.artist : "")).toUpperCase(), 1, 1, dt);
        c.fillStyle = p.s1;
        c.fillRect(0, 10, Math.round(w * Media.progress), 1);
        const bars = Media.bars ?? [];
        const n = Math.min(bars.length, Math.floor(w / 2));
        for (let i = 0; i < n; i++) {
            const v = Math.max(0, Math.min(1, bars[Math.floor(i * bars.length / n)] ?? 0));
            const bh = Math.round(v * (h - 13));
            c.fillStyle = v > 0.75 ? p.s2 : p.s0;
            c.fillRect(i * 2, h - bh, 1, bh);
        }
    }

    // The spectrum runs only while someone wants it.
    readonly property bool wantsBars: on && source === "media"
    onWantsBarsChanged: Media.want("wall", wantsBars)

    Timer {
        running: root.on && feeder.running
        interval: Math.round(1000 / root.fps)
        repeat: true
        onTriggered: root.render()
    }

    // ── Sending ─────────────────────────────────────────────────────
    // One long-running sender; frames go to its stdin as base64 lines.
    Process {
        id: feeder
        running: root.on
        stdinEnabled: true
        command: ["dotwall", "feed", root.host + ":" + root.port, "--size", root.w + "x" + root.h]
        stderr: SplitParser {
            onRead: line => console.info("dotwall:", line)
        }
        onExited: code => {
            if (root.on)
                restart.restart();
        }
    }
    // The sender died (network down, dotwall missing): try again in a while.
    Timer {
        id: restart
        interval: 5000
        onTriggered: if (root.on)
            feeder.running = true
    }
    onHostChanged: if (feeder.running) {
        feeder.running = false;
        restart.restart();
    }

    // `dot wall pixels`: raw RGB from the bus (base64), shown as is.
    function pixels(width: int, height: int, data: string): var {
        if (width !== w || height !== h)
            return { error: `the wall is ${w}x${h}; send a ${w}x${h} RGB frame` };
        const bin = Qt.atob(data);
        if (bin.length !== w * h * 3)
            return { error: `expected ${w * h * 3} bytes, got ${bin.length}` };
        const a = new Uint8Array(bin.length);
        for (let i = 0; i < bin.length; i++)
            a[i] = bin.charCodeAt(i);
        pushed = a;
        if (store.source !== "pixels")
            store.source = "pixels";
        return {};
    }
}
