pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import qs

// Feeds: named JSON objects that panels bind to (Templates.js). Two kinds:
//   pushed    `dot feed <id> '<json>'` or {"cmd":"feed",...} on the socket,
//             from dotd or any script; live data, never saved (dotd re-sends
//             its feeds when it starts). A pushed feed replaces a built-in
//             one of the same name, so dotd's downloads win over the fallback.
//   built-in  the shell's own state, below: clock media workspaces sys power
//             notifs capture caffeine tray downloads files clip todo shots dock
//             tv
// Several panels can bind one feed. Feeds that poll (sys, downloads, files,
// shots, caffeine) only do so while some panel on screen wants them:
// want(feed, key, on).
Singleton {
    id: root

    property var pushed: ({})
    // Bumped on every push, so bindings on get() see it.
    property int rev: 0

    function push(id: string, data: var, merge: bool): var {
        if (!/^[A-Za-z0-9_.-]+$/.test(id))
            return { error: "feed id must be letters, digits, . - or _" };
        if (data === null || typeof data !== "object")
            return { error: "a feed is a JSON object" };
        const p = Object.assign({}, pushed);
        p[id] = merge && pushed[id] ? Object.assign({}, pushed[id], data) : data;
        pushed = p;
        rev++;
        return { feed: id };
    }

    function drop(id: string): var {
        const p = Object.assign({}, pushed);
        delete p[id];
        pushed = p;
        rev++;
        return {};
    }

    function get(id: string): var {
        const p = pushed[id];
        if (p !== undefined)
            return p;
        switch (id) {
        case "clock":
            return clockFeed;
        case "media":
            return mediaFeed;
        case "workspaces":
            return wsFeed;
        case "sys":
            return sysFeed;
        case "power":
            return powerFeed;
        case "notifs":
            return notifsFeed;
        case "capture":
            return captureFeed;
        case "caffeine":
            return caffeineFeed;
        case "tray":
            return trayFeed;
        case "downloads":
            return downloadsFeed;
        case "files":
            return filesFeed;
        case "clip":
            return clipFeed;
        case "todo":
            return Todo.feed;
        case "shots":
            return shotsFeed;
        case "dock":
            return dockFeed;
        case "tv":
            return tvFeed;
        default:
            return ({});
        }
    }

    readonly property var builtin: ["clock", "media", "workspaces", "sys", "power", "notifs", "capture", "caffeine", "tray", "downloads", "files", "clip", "todo", "shots", "dock", "tv"]
    function ids(): var {
        return [...new Set([...builtin, ...Object.keys(pushed)])];
    }

    // ── Wants ───────────────────────────────────────────────────────
    property var wants: ({})
    function want(feed: string, key: string, on: bool): void {
        const cur = wants[feed] ?? {};
        if (!!cur[key] === on)
            return;
        const next = Object.assign({}, cur);
        if (on)
            next[key] = true;
        else
            delete next[key];
        const w = Object.assign({}, wants);
        w[feed] = next;
        wants = w;
        if (feed === "sys")
            Sys.want("feed-" + key, on);
        if (feed === "tv")
            Tv.panels = wanted("tv");
    }
    function wanted(feed: string): bool {
        return Object.keys(wants[feed] ?? {}).length > 0;
    }

    readonly property string home: Quickshell.env("HOME")
    function tilde(p: string): string {
        return p.startsWith(home) ? "~" + p.slice(home.length) : p;
    }

    // ── clock ───────────────────────────────────────────────────────
    SystemClock {
        id: clk
        precision: SystemClock.Seconds
    }
    readonly property var clockFeed: {
        const d = clk.date;
        const first = new Date(d.getFullYear(), d.getMonth(), 1);
        const lead = (first.getDay() + 6) % 7;
        const days = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
        const weeks = [];
        let wk = [];
        for (let i = 0; i < lead; i++)
            wk.push({ d: "", slot: "dim" });
        for (let n = 1; n <= days; n++) {
            const dow = (lead + n - 1) % 7;
            wk.push({ d: String(n), slot: n === d.getDate() ? 2 : dow >= 5 ? 1 : 0 });
            if (wk.length === 7) {
                weeks.push({ days: wk });
                wk = [];
            }
        }
        if (wk.length) {
            while (wk.length < 7)
                wk.push({ d: "", slot: "dim" });
            weeks.push({ days: wk });
        }
        return {
            time: Qt.formatDateTime(d, clk.seconds % 2 ? "hh mm" : "hh:mm"),
            hh: Qt.formatDateTime(d, "hh"),
            mm: Qt.formatDateTime(d, "mm"),
            ss: Qt.formatDateTime(d, "ss"),
            date: Qt.formatDateTime(d, "ddd dd MMM"),
            dateShort: Qt.formatDateTime(d, "ddd dd"),
            day: Qt.formatDateTime(d, "dddd"),
            dd: Qt.formatDateTime(d, "d"),
            month: Qt.formatDateTime(d, "MMMM"),
            year: Qt.formatDateTime(d, "yyyy"),
            utc: String(d.getUTCHours()).padStart(2, "0") + ":" + String(d.getUTCMinutes()).padStart(2, "0"),
            weeks: weeks
        };
    }

    // ── media ───────────────────────────────────────────────────────
    readonly property var mediaFeed: ({
            active: Media.active,
            playing: Media.isPlaying,
            title: Media.title,
            artist: Media.artist,
            album: Media.album,
            art: Media.art,
            pos: Media.position,
            len: Media.length,
            progress: Media.progress,
            player: Media.name,
            hasLyrics: Lyrics.has,
            lyric: Lyrics.line,
            lyricNext: Lyrics.next,
            hasVideo: Media.isVideo || VideoMatch.url !== ""
        })

    // ── tv ──────────────────────────────────────────────────────────
    // Dot TV: what plays (dottv's queue, polled while a panel shows it), up
    // next, and the library, most played first.
    readonly property var tvFeed: {
        const st = Tv.status;
        const cur = st.current ? (Tv.byId[st.current.id] ?? st.current) : null;
        const on = Media.isTv;
        const top = Tv.library.slice(0, 12).map(e => ({ id: e.id, title: e.title, channel: e.channel ?? "", thumb: e.thumb ?? "", plays: e.plays ?? 0, duration: e.duration ?? "" }));
        return {
            running: !!st.running,
            on: on,
            playing: on && Media.isPlaying,
            title: cur?.title ?? "",
            channel: cur?.channel ?? "",
            thumb: cur?.thumb ?? "",
            progress: on ? Media.progress : 0,
            pos: on ? Media.position : 0,
            len: on ? Media.length : 0,
            mix: !!st.mix,
            hasVideo: Media.isVideo,
            next: (st.queue ?? []).slice(0, 6).map(q => ({ id: q.id, title: q.title ?? Tv.byId[q.id]?.title ?? q.id })),
            hasNext: (st.queue ?? []).length > 0,
            top: top,
            // Compact lists up next while playing, the library otherwise.
            shown: on && (st.queue ?? []).length ? (st.queue ?? []).slice(0, 3).map(q => ({ id: q.id, title: q.title ?? q.id })) : top.slice(0, 3),
            mixSlot: st.mix ? 2 : "dim",
            count: Tv.library.length
        };
    }

    // ── workspaces ──────────────────────────────────────────────────
    readonly property var windows: (Hyprland.toplevels?.values ?? []).map(t => ({
                addr: String(t.address ?? ""),
                title: t.title ?? "",
                ws: t.workspace?.id ?? 0,
                cls: String(t.wayland?.appId ?? t.lastIpcObject?.class ?? ""),
                active: !!t.activated || (t.wayland?.activated ?? false),
                urgent: !!t.urgent
            }))
    readonly property var wsFeed: {
        const live = Hyprland.workspaces.values.filter(w => w.id > 0);
        const focused = Hyprland.focusedWorkspace?.id ?? 0;
        const count = Math.max(5, ...live.map(w => w.id));
        const list = [];
        for (let id = 1; id <= count; id++) {
            const w = live.find(x => x.id === id) ?? null;
            const wins = windows.filter(x => x.ws === id);
            list.push({
                id: id,
                windows: wins.length,
                focused: id === focused,
                urgent: w?.urgent ?? false,
                titles: wins.map(x => x.title).join(" · "),
                slot: w?.urgent ? 2 : id === focused ? 0 : 1,
                tslot: id === focused ? 0 : "dim",
                opacity: w === null ? 0.5 : 1
            });
        }
        return {
            focused: focused,
            list: list,
            title: windows.find(x => x.active)?.title ?? ""
        };
    }

    // ── sys ─────────────────────────────────────────────────────────
    readonly property var sysFeed: ({
            cpu: Sys.cpu,
            mem: Sys.mem,
            memGb: Sys.memGb,
            temp: Sys.temp,
            tempF: Sys.tempFraction,
            hasTemp: Sys.temp >= 0,
            cpuHist: Sys.cpuHist,
            memHist: Sys.memHist,
            cores: Sys.cores.map((v, i) => ({ n: i, v: v })),
            top: Sys.top,
            cpuSlot: Sys.cpu > 0.85 ? 2 : 0
        })

    // ── power ───────────────────────────────────────────────────────
    property var powerHist: []
    Timer {
        running: Power.present
        interval: 300000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.powerHist = [...root.powerHist, Power.fraction].slice(-288)
    }
    readonly property var powerFeed: {
        const low = Power.discharging && Power.fraction <= 0.15;
        const prof = Power.profile;
        return {
            present: Power.present,
            pct: Power.percent,
            fraction: Power.fraction,
            charging: Power.charging,
            plus: Power.charging ? "+" : "",
            stateWord: Power.stateText,
            level: low ? "bad" : Power.charging ? "ok" : Power.discharging && Power.fraction <= 0.3 ? "warn" : "ok",
            time: Power.timeText,
            watts: Power.watts,
            health: Power.health >= 0 ? Math.round(Power.health) + "%" : "",
            hasHealth: Power.health >= 0,
            slot: low ? 2 : Power.charging ? 1 : 0,
            hist: powerHist,
            hasPerf: Power.hasPerformance,
            p0: prof === 0 ? 2 : "dim",
            p1: prof === 1 ? 2 : "dim",
            p2: prof === 2 ? 2 : "dim"
        };
    }

    // ── notifs ──────────────────────────────────────────────────────
    readonly property var notifsFeed: {
        const items = Notifs.history.slice(0, 20);
        const apps = {};
        for (const n of Notifs.history.slice(0, 100))
            apps[n.app] = (apps[n.app] ?? 0) + 1;
        return {
            dnd: Notifs.dnd,
            dndSlot: Notifs.dnd ? 2 : "dim",
            live: Notifs.live.length,
            count: Notifs.history.length,
            items: items,
            apps: Object.keys(apps).slice(0, 6).map(a => ({ app: a, count: apps[a] }))
        };
    }

    // ── capture ─────────────────────────────────────────────────────
    readonly property var captureFeed: ({
            recording: Capture.recording,
            elapsed: Capture.clock(Capture.elapsed),
            blink: Capture.elapsed % 2 ? 0.55 : 1,
            audio: Capture.audio,
            last: shotsFeed.latest,
            recent: shotsFeed.items.slice(0, 6)
        })

    // ── caffeine ────────────────────────────────────────────────────
    property real caffeineUntil: 0
    property int caffeineTick: 0
    Timer {
        running: Idle.caffeine && root.caffeineUntil > 0
        interval: 1000
        repeat: true
        onTriggered: {
            root.caffeineTick++;
            if (Date.now() >= root.caffeineUntil) {
                root.caffeineUntil = 0;
                Idle.setCaffeine(false);
            }
        }
    }
    Connections {
        target: Idle
        function onCaffeineChanged() {
            if (!Idle.caffeine)
                root.caffeineUntil = 0;
        }
    }
    function caffeineFor(minutes: int): void {
        caffeineUntil = minutes > 0 ? Date.now() + minutes * 60000 : 0;
        if (!Idle.caffeine)
            Idle.setCaffeine(true);
    }
    property var inhibitors: []
    Process {
        id: inhibit
        command: ["systemd-inhibit", "--list", "--no-legend", "--no-pager"]
        stdout: StdioCollector {
            onStreamFinished: root.inhibitors = text.split("\n").filter(l => l.trim() && /idle|sleep/.test(l)).map(l => {
                const f = l.trim().split(/\s{2,}/);
                return { who: f[0] ?? "", why: f[f.length - 2] ?? "" };
            }).slice(0, 6)
        }
    }
    Timer {
        running: root.wanted("caffeine")
        interval: 30000
        repeat: true
        triggeredOnStart: true
        onTriggered: inhibit.running = true
    }
    readonly property var caffeineFeed: {
        void caffeineTick;
        const left = caffeineUntil > 0 ? Math.max(0, Math.round((caffeineUntil - Date.now()) / 1000)) : 0;
        return {
            on: Idle.caffeine,
            state: Idle.caffeine ? "AWAKE" : "IDLE",
            level: Idle.caffeine ? "warn" : "ok",
            slot: Idle.caffeine ? 2 : "dim",
            left: left > 0 ? (left >= 3600 ? Math.floor(left / 3600) + "H " : "") + Math.floor(left % 3600 / 60) + ":" + String(left % 60).padStart(2, "0") : "",
            holders: inhibitors
        };
    }

    // ── tray ────────────────────────────────────────────────────────
    readonly property var trayFeed: ({
            count: SystemTray.items.values.length,
            items: SystemTray.items.values.map(i => ({ id: i.id, title: i.tooltipTitle || i.title || i.id }))
        })

    // ── downloads (until dotd pushes its own) ───────────────────────
    property var dlFiles: []
    Process {
        id: dlScan
        command: ["sh", "-c", "find \"$HOME/Downloads\" -maxdepth 1 -type f -printf '%T@\\t%s\\t%p\\n' 2>/dev/null | sort -rn | head -12"]
        stdout: StdioCollector {
            onStreamFinished: root.dlFiles = text.split("\n").filter(l => l).map(l => {
                const f = l.split("\t");
                return { ts: Math.round(Number(f[0]) * 1000), size: Number(f[1]), path: f[2], name: f[2].split("/").pop() };
            })
        }
    }
    Timer {
        running: root.wanted("downloads") && root.pushed.downloads === undefined
        interval: 15000
        repeat: true
        triggeredOnStart: true
        onTriggered: dlScan.running = true
    }
    readonly property var downloadsFeed: {
        const part = /\.(part|crdownload|download)$/;
        const active = dlFiles.filter(f => part.test(f.name)).map(f => ({ name: f.name.replace(part, ""), pct: 0, speed: "" }));
        const recent = dlFiles.filter(f => !part.test(f.name)).map(f => ({ name: f.name, path: f.path, bin: "DOWNLOADS", ts: f.ts, undo: false }));
        return {
            active: active,
            recent: recent,
            activeName: active[0]?.name ?? "",
            activePct: active[0]?.pct ?? 0,
            count: recent.length
        };
    }

    // ── files ───────────────────────────────────────────────────────
    property var recentFiles: []
    property var places: []
    Process {
        id: recentScan
        command: ["python3", "-I", "-c", `
import json, os, sys, urllib.parse, xml.etree.ElementTree as ET
out = []
try:
    root = ET.parse(os.path.expanduser("~/.local/share/recently-used.xbel")).getroot()
    for b in root.iter("bookmark"):
        href = b.get("href", "")
        if not href.startswith("file://"):
            continue
        p = urllib.parse.unquote(href[7:])
        if not os.path.exists(p) or "/." in p:
            continue
        out.append({"path": p, "name": os.path.basename(p), "ts": int(os.path.getmtime(p) * 1000), "m": b.get("modified", "")})
except Exception:
    pass
out.sort(key=lambda x: x["m"], reverse=True)
seen, res = set(), []
for o in out:
    if o["path"] in seen:
        continue
    seen.add(o["path"]); o.pop("m"); res.append(o)
places = []
for f in ("~/.config/gtk-3.0/bookmarks",):
    try:
        for line in open(os.path.expanduser(f)):
            u = line.split(" ")[0].strip()
            if u.startswith("file://"):
                p = urllib.parse.unquote(u[7:])
                places.append({"path": p, "name": line.strip().split(" ", 1)[1] if " " in line.strip() else os.path.basename(p)})
    except Exception:
        pass
print(json.dumps({"recent": res[:20], "places": places[:8]}))
`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.recentFiles = d.recent;
                    root.places = d.places;
                } catch (e) {}
            }
        }
    }
    Timer {
        running: root.wanted("files")
        interval: 30000
        repeat: true
        triggeredOnStart: true
        onTriggered: recentScan.running = true
    }
    readonly property var filesFeed: {
        const base = ["Documents", "Downloads", "Pictures", "Music", "Videos"].map(n => ({ name: n, path: home + "/" + n }));
        const pinned = [{ name: "HOME", path: home }, ...(places.length ? places : base)];
        const recent = recentFiles.map(f => Object.assign({ dir: f.path.replace(/\/[^/]*$/, "").replace(home, "~") }, f));
        return {
            pinned: pinned,
            recent: recent,
            recentName: recent[0]?.name ?? "",
            recentPath: recent[0]?.path ?? ""
        };
    }

    // ── clip ────────────────────────────────────────────────────────
    // Clip.items are { t: text, at: ms }.
    // A path shows its name and the folder it is in, not /home/you/...
    function preview(t: string): string {
        const raw = String(t ?? "");
        const s = raw.replace(/\s+/g, " ").trim();
        if (!raw.includes("\n") && /^(\/|~\/)/.test(s)) {
            const parts = s.replace(home, "~").split("/").filter(x => x);
            if (parts.length > 2)
                return parts[parts.length - 1] + "  " + parts[parts.length - 2];
        }
        return s.slice(0, 120);
    }
    readonly property var clipFeed: ({
            count: Clip.items.length,
            items: Clip.items.slice(0, 20).map(x => ({ text: x.t, preview: root.preview(x.t), at: x.at })),
            lastPreview: root.preview(Clip.items[0]?.t ?? "")
        })

    // ── shots ───────────────────────────────────────────────────────
    readonly property string shotDir: home + "/Pictures/Screenshots"
    property var shotFiles: []
    property string ocrText: ""
    Process {
        id: shotScan
        command: ["sh", "-c", "find \"$HOME/Pictures/Screenshots\" -maxdepth 1 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.webp' \\) -printf '%T@\\t%p\\n' 2>/dev/null | sort -rn | head -40; printf 'COUNT\\t'; find \"$HOME/Pictures/Screenshots\" -maxdepth 1 -type f 2>/dev/null | wc -l"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                let count = 0;
                for (const l of text.split("\n")) {
                    if (!l)
                        continue;
                    const f = l.split("\t");
                    if (f[0] === "COUNT")
                        count = Number(f[1]) || 0;
                    else
                        out.push({ ts: Math.round(Number(f[0]) * 1000), path: f[1], name: f[1].split("/").pop() });
                }
                root.shotFiles = out;
                root.shotCount = count;
            }
        }
    }
    property int shotCount: 0
    function rescanShots(): void {
        shotScan.running = true;
    }
    Timer {
        running: root.wanted("shots") || root.wanted("capture")
        interval: 20000
        repeat: true
        triggeredOnStart: true
        onTriggered: shotScan.running = true
    }
    readonly property var shotsFeed: {
        const items = shotFiles;
        const days = [];
        const byDay = {};
        for (const s of items) {
            const d = new Date(s.ts);
            const today = new Date();
            const diff = Math.floor((new Date(today.getFullYear(), today.getMonth(), today.getDate()) - new Date(d.getFullYear(), d.getMonth(), d.getDate())) / 86400000);
            const label = diff === 0 ? "Today" : diff === 1 ? "Yesterday" : Qt.formatDate(d, "ddd dd MMM");
            if (!byDay[label]) {
                byDay[label] = { day: label, shots: [] };
                days.push(byDay[label]);
            }
            byDay[label].shots.push(s);
        }
        return {
            count: shotCount,
            latest: items[0]?.path ?? "",
            thumbs: items.slice(1, 5),
            items: items,
            days: days,
            ocr: ocrText
        };
    }

    // ── dock ────────────────────────────────────────────────────────
    // One Nerd Font glyph per app kind: a dock cell is one glyph wide.
    function glyphFor(entry: var, cls: string): string {
        const c = (entry?.categories ?? []).join(" ") + " " + cls.toLowerCase();
        const kinds = [
            [/TerminalEmulator|ghostty|kitty|alacritty|foot|terminal/i, "\uf120"],
            [/firefox|librewolf/i, "\uf269"],
            [/WebBrowser|chrom/i, "\uf0ac"],
            [/TextEditor|IDE|Development|code/i, "\uf121"],
            [/FileManager|nautilus|thunar|nemo/i, "\uf07b"],
            [/InstantMessaging|Chat|telegram|discord|vesktop/i, "\uf086"],
            [/Audio|Music|spotify|rmpc/i, "\uf001"],
            [/Video|mpv|dottv/i, "\uf03d"],
            [/Graphics|gimp|inkscape|krita/i, "\uf1fc"],
            [/Office|libreoffice/i, "\uf15c"],
            [/Game|steam/i, "\uf11b"],
            [/Settings|System/i, "\uf013"]
        ];
        for (const [re, g] of kinds)
            if (re.test(c))
                return g;
        return (entry?.name ?? cls).slice(0, 1).toUpperCase() || "?";
    }
    function entryFor(cls: string): var {
        if (!cls)
            return null;
        return DesktopEntries.heuristicLookup(cls) ?? DesktopEntries.byId(cls) ?? null;
    }
    readonly property var dockFeed: {
        const groups = {};
        const order = [];
        for (const w of windows) {
            if (!w.cls || w.cls.startsWith("dotshell."))
                continue;
            if (!groups[w.cls]) {
                groups[w.cls] = [];
                order.push(w.cls);
            }
            groups[w.cls].push(w);
        }
        const running = order.map(cls => {
            const ws = groups[cls];
            const e = entryFor(cls);
            const active = ws.some(w => w.active), urgent = ws.some(w => w.urgent);
            return {
                cls: cls,
                id: e?.id ?? cls,
                name: e?.name ?? cls,
                glyph: glyphFor(e, cls),
                ws: ws[0].ws > 0 ? String(ws[0].ws) : "",
                title: ws[0].title,
                addr: ws[0].addr,
                windows: ws.length,
                dots: "•".repeat(Math.min(4, ws.length)),
                slot: urgent ? 2 : active ? 0 : 1
            };
        });
        const runningIds = running.map(r => r.id);
        const pinned = Panels.pinned.filter(id => !runningIds.includes(id)).map(id => {
            const e = DesktopEntries.byId(id) ?? entryFor(id);
            return { id: id, name: e?.name ?? id, glyph: glyphFor(e, id) };
        });
        return { running: running, pinned: pinned };
    }
}
