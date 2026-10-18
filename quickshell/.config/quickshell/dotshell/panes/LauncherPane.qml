import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services

// Departure-board launcher (Alt Space) on the bottom edge, in front of
// dotd's index (dotd/). Type to search; a prefix picks the mode:
//   (none) apps, then files    a  apps          f  files, by name and text
//   d  downloads dotd sorted   i  images        n  notification history
//   c  clipboard               m  songs         t  Dot TV
//   an anime                   w  tabs and history (with the browser extension)
//   >  a shell command
// With no words, f d i m list the newest. Up/Down (Ctrl J/K, Tab) pick;
// Enter does the first action, Shift Enter a new window (apps) or a terminal
// (>); Alt + a letter on the preview line does the others. Apps you launch
// often rise to the top: counts live in
// ${XDG_STATE_HOME:-~/.local/state}/dotshell/launcher.json.
Pane {
    id: pane

    name: "launcher"
    anchors {
        bottom: true
        left: true
        right: true
    }

    readonly property int slots: 8
    readonly property int inner: maxCols - 8
    cols: maxCols
    rows: 4 + Tokens.lineDots * (slots + 4) + 10

    property string query: ""
    property int selected: 0
    // Rows: { name, cls, status, preview, acts: [{ key, label, verb, arg }] };
    // the first act is Enter's, the rest go by Alt + key.
    property var results: []
    readonly property var picked: results[selected] ?? null
    // dotd replies come back late: one ticket per refresh, stale ones dropped.
    property int ticket: 0
    property bool waiting: false
    property string note: ""

    // Column widths in characters.
    readonly property int gateChars: 4
    readonly property int classChars: 14
    readonly property int statusChars: 9
    readonly property int nameChars: Math.max(10, Math.floor(inner / Tokens.charDots) - gateChars - classChars - statusChars - 3)

    readonly property string home: Quickshell.env("HOME")
    readonly property var modeNames: ({ "": "DEPARTURES", "a": "APPS", "f": "FILES", "d": "DOWNLOADS", "i": "IMAGES", "n": "MESSAGES", "c": "CLIPBOARD", "m": "SONGS", "t": "DOT TV", "an": "ANIME", "w": "WEB", ">": "RUN" })
    // The prefix and the words after it.
    readonly property var parsed: {
        const q = query.replace(/^\s+/, "");
        if (q.startsWith(">"))
            return { mode: ">", text: q.slice(1).trim() };
        const m = q.match(/^(an|[afdincmtw]) ([^]*)$/);
        return m ? { mode: m[1], text: m[2].trim() } : { mode: "", text: q.trim() };
    }

    onOpened: {
        // A query handed over by the dock's search or `find`.
        input.text = Apps.query;
        Apps.query = "";
        refresh();
        input.forceActiveFocus();
    }
    onQueryChanged: soon.restart()
    // The anime lists are read when the MEDIA pane's page first shows; the
    // launcher's `an ` reads them too.
    property string lastMode: ""
    onParsedChanged: {
        if (parsed.mode === "an" && lastMode !== "an")
            Anime.reread();
        lastMode = parsed.mode;
    }
    Connections {
        target: Anime
        function onStChanged() {
            if (pane.shown && pane.parsed.mode === "an")
                pane.refresh();
        }
    }
    // Typing settles before dotd is asked.
    Timer {
        id: soon
        interval: 70
        onTriggered: pane.refresh()
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            if (pane.shown && (pane.parsed.mode === "" || pane.parsed.mode === "a"))
                pane.refresh();
        }
    }

    // ── Apps ────────────────────────────────────────────────────────
    function score(entry: var, q: string): real {
        const name = (entry.name || "").toLowerCase();
        if (!q)
            return 1;
        let s = 0;
        if (name === q)
            s = 100;
        else if (name.startsWith(q))
            s = 80;
        else if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q)))
            s = 60;
        else if (name.includes(q))
            s = 40;
        else {
            const extra = [entry.genericName, ...(entry.keywords ?? []), entry.id, (entry.command ?? [])[0]].join(" ").toLowerCase();
            if (extra.includes(q))
                s = 25;
            else {
                // Subsequence: all letters in order.
                let i = 0;
                for (const c of name)
                    if (c === q[i])
                        i++;
                s = i === q.length ? 10 : 0;
            }
        }
        return s;
    }

    function apps(q: string): var {
        const counts = usage.counts ?? {};
        const scored = [];
        for (const e of DesktopEntries.applications.values) {
            if (e.noDisplay)
                continue;
            const s = score(e, q);
            if (s > 0)
                scored.push({ e: e, s: s, r: s + Math.min(30, Math.log2(1 + (counts[e.id] ?? 0)) * 6) });
        }
        scored.sort((a, b) => b.r - a.r || a.e.name.localeCompare(b.e.name));
        return scored.slice(0, slots).map(x => appRow(x.e, x.s));
    }

    function appRow(e: var, s: real): var {
        const wins = Apps.windowsOf(e, "");
        return {
            name: e.name,
            cls: category(e),
            status: wins.length ? "AT WS " + (wins[0].ws || "?") : "ON TIME",
            preview: e.comment || e.genericName || (e.command ?? []).join(" "),
            match: s,
            acts: [{ key: "", label: wins.length ? "JUMP" : "BOARD", verb: "app", arg: e.id }, { key: "N", label: "NEW WINDOW", verb: "appnew", arg: e.id }]
        };
    }

    function pad(s: string, n: int): string {
        s = String(s ?? "").toUpperCase();
        return s.length > n ? s.slice(0, n - 1) + "." : s + " ".repeat(n - s.length);
    }

    function category(e: var): string {
        const known = ["Development", "Network", "Graphics", "AudioVideo", "Audio", "Video", "Office", "Game", "System", "Settings", "Utility", "Education", "Science"];
        const c = (e.categories ?? []).find(x => known.includes(x)) ?? (e.categories ?? [])[0] ?? "APP";
        return c === "AudioVideo" ? "MEDIA" : c === "Development" ? "DEV" : c;
    }

    // ── Files, from dotd ────────────────────────────────────────────
    function tilde(p: string): string {
        return p && p.startsWith(home) ? "~" + p.slice(home.length) : (p ?? "");
    }
    function ago(ms: real): string {
        const m = (Date.now() - ms) / 60000;
        if (!(m >= 0))
            return "";
        if (m < 2)
            return "NOW";
        if (m < 60)
            return Math.floor(m) + "M AGO";
        if (m < 60 * 24)
            return Math.floor(m / 60) + "H AGO";
        if (m < 60 * 24 * 45)
            return Math.floor(m / 1440) + "D AGO";
        if (m < 60 * 24 * 365)
            return Math.floor(m / 43200) + "MO AGO";
        return Math.floor(m / 525600) + "Y AGO";
    }
    function kind(mime: string, name: string): string {
        const m = mime ?? "";
        if (m.startsWith("image/"))
            return "IMAGE";
        if (m.startsWith("audio/"))
            return "AUDIO";
        if (m.startsWith("video/"))
            return "VIDEO";
        if (m === "application/pdf")
            return "PDF";
        if (/zip|tar|7z|rar|gzip|xz|bzip|zstd/.test(m))
            return "ARCHIVE";
        if (/officedocument|opendocument|msword|ms-excel|ms-powerpoint|epub/.test(m))
            return "DOC";
        if (m.startsWith("text/"))
            return "TEXT";
        const ext = /\.([A-Za-z0-9]{1,8})$/.exec(name ?? "");
        return ext ? ext[1].toUpperCase() : "FILE";
    }
    // dotd marks the matched words with [ ]; the board has no bold.
    function snip(s: string): string {
        return String(s ?? "").replace(/\s+/g, " ").trim();
    }

    function fileRow(h: var): var {
        const k = kind(h.mime, h.name);
        const acts = [{ key: "", label: "OPEN", verb: "open", arg: h.path }, { key: "R", label: "REVEAL", verb: "reveal", arg: h.path }];
        if (k === "IMAGE")
            acts.push({ key: "C", label: "COPY", verb: "copyimg", arg: h.path }, { key: "W", label: "WALLPAPER", verb: "wallpaper", arg: h.path });
        if (k === "AUDIO")
            acts.splice(0, 1, { key: "", label: "PLAY", verb: "song", arg: h.path }, { key: "Q", label: "QUEUE", verb: "songq", arg: h.path });
        acts.push({ key: "P", label: "COPY PATH", verb: "copy", arg: h.path });
        return {
            name: h.name,
            cls: k,
            status: ago(h.mtime),
            // A snippet only when it shows the matched words.
            preview: h.snippet && h.snippet.indexOf("[") >= 0 ? snip(h.snippet) : tilde(h.dir),
            acts: acts
        };
    }

    function downloadRow(m: var): var {
        return {
            name: m.name,
            cls: kind("", m.name),
            status: m.here ? ago(m.at) : "GONE",
            preview: "SORTED TO " + tilde(m.dir),
            acts: [{ key: "", label: "OPEN", verb: "open", arg: m.path }, { key: "R", label: "REVEAL", verb: "reveal", arg: m.path }, { key: "U", label: "UNDO SORT", verb: "undo", arg: String(m.id) }, { key: "P", label: "COPY PATH", verb: "copy", arg: m.path }]
        };
    }

    // One request to dotd; cb(results) runs only if this refresh is still
    // the latest.
    function ask(t: int, req: var, cb: var): void {
        if (!Dotd.up)
            note = "INDEX OFFLINE";
        waiting = true;
        Dotd.request(req, r => {
            if (t !== pane.ticket)
                return;
            pane.waiting = false;
            pane.note = r.ok ? "" : String(r.error ?? "dotd failed").toUpperCase();
            cb(r.ok ? (r.results ?? []) : []);
        });
    }
    function show(rows: var): void {
        results = rows.slice(0, slots);
        selected = Math.min(selected, Math.max(0, results.length - 1));
    }

    // ── Everything else ─────────────────────────────────────────────
    function has(s: var, q: string): bool {
        return !q || q.split(/\s+/).every(w => String(s ?? "").toLowerCase().includes(w));
    }

    function refresh(): void {
        const t = ++ticket;
        const p = parsed, q = p.text.toLowerCase();
        selected = 0;
        waiting = false;
        note = "";
        switch (p.mode) {
        case "": {
            // Strong app matches first, then files, then the weak apps.
            const a = apps(q);
            show(a);
            if (q.length >= 2)
                ask(t, { cmd: "query", q: p.text, limit: 6 }, hits => {
                    const files = hits.map(fileRow);
                    show([...a.filter(x => x.match >= 40), ...files, ...a.filter(x => x.match < 40)]);
                });
            break;
        }
        case "a":
            show(apps(q));
            break;
        case "f":
            show([]);
            ask(t, p.text ? { cmd: "query", q: p.text, limit: slots } : { cmd: "query", q: "", dir: ["~"], limit: slots }, hits => show(hits.map(fileRow)));
            break;
        case "d":
            // What dotd sorted, then what still sits in ~/Downloads.
            show([]);
            ask(t, { cmd: "downloads", q: p.text, limit: slots }, moved => {
                const rows = moved.map(downloadRow);
                show(rows);
                ask(t, { cmd: "query", q: p.text, dir: ["~/Downloads"], limit: slots }, hits => show([...rows, ...hits.map(fileRow)]));
            });
            break;
        case "i":
            show([]);
            ask(t, { cmd: "query", q: p.text, mime: "image/", limit: slots }, hits => show(hits.map(fileRow)));
            break;
        case "m":
            show([]);
            ask(t, { cmd: "query", q: p.text, mime: "audio/", limit: slots }, hits => show(hits.map(fileRow)));
            break;
        case "n":
            show(Notifs.history.filter(n => has(n.app + " " + n.summary + " " + n.body, q)).map(n => ({
                        name: n.summary,
                        cls: n.app,
                        status: ago(n.ts),
                        preview: n.body,
                        acts: [{ key: "", label: "MESSAGES", verb: "pane", arg: "notifs" }, { key: "C", label: "COPY", verb: "copy", arg: n.body ? n.summary + "\n" + n.body : n.summary }]
                    })));
            break;
        case "c":
            show(Clip.items.filter(c => has(c.t, q)).map(c => ({
                        name: c.t.replace(/\s+/g, " ").trim(),
                        cls: c.t.length + " CHARS",
                        status: ago(c.at),
                        preview: c.t.replace(/\s+/g, " ").trim(),
                        acts: [{ key: "", label: "PASTE", verb: "paste", arg: c.t }, { key: "C", label: "COPY", verb: "clipcopy", arg: c.t }, { key: "X", label: "FORGET", verb: "forget", arg: c.t }]
                    })));
            break;
        case "t":
            show(Tv.library.filter(e => has(e.title + " " + e.channel, q)).map(e => ({
                        name: e.title,
                        cls: e.audio ? "SONG" : "VIDEO",
                        status: e.plays ? e.plays + " PLAYS" : "NEW",
                        preview: [e.channel, e.duration].filter(x => x).join("  "),
                        acts: [{ key: "", label: "PLAY", verb: "tv", arg: e.id }, { key: "Q", label: "QUEUE", verb: "tvqueue", arg: e.id }, { key: "N", label: "PLAY NEXT", verb: "tvnext", arg: e.id }]
                    })));
            break;
        case "an": {
            const seen = {}, shows = [];
            for (const m of [...Anime.watch, ...Anime.liked, ...Anime.downloads])
                if (m && !seen[m.id]) {
                    seen[m.id] = true;
                    shows.push(m);
                }
            const left = m => Anime.progress[m.id] ? 0 : 1;
            shows.sort((a, b) => left(a) - left(b));
            show(shows.filter(m => has(m.title, q)).map(m => {
                const pr = Anime.progress[m.id];
                const ep = !pr ? "1" : pr.done ? String(Number(pr.ep) + 1) : String(pr.ep);
                return {
                    name: m.title,
                    cls: "ANIME",
                    status: "EP " + ep,
                    preview: pr ? (pr.done ? "WATCHED EP " + pr.ep + ", NEXT " + ep : "LEFT OFF IN EP " + ep) : "NOT STARTED",
                    acts: [{ key: "", label: "RESUME", verb: "anime", arg: { m: m, ep: ep } }, { key: "O", label: "SHOW PAGE", verb: "animepage", arg: m }]
                };
            }));
            break;
        }
        case "w":
            show([{ name: "TABS AND HISTORY ARRIVE WITH THE BROWSER EXTENSION", cls: "PHASE 15", status: "", preview: "", acts: [] }]);
            break;
        case ">":
            show(p.text ? [{ name: p.text, cls: "SHELL", status: "", preview: "SH -C, OR SHIFT ENTER FOR A TERMINAL", acts: [{ key: "", label: "RUN", verb: "run", arg: p.text }, { key: "T", label: "TERMINAL", verb: "term", arg: p.text }] }] : []);
            break;
        }
    }

    // ── Doing ───────────────────────────────────────────────────────
    function perform(row: var, act: var): void {
        if (!row || !act)
            return;
        if (act.verb === "app" || act.verb === "appnew") {
            const counts = Object.assign({}, usage.counts ?? {});
            counts[act.arg] = (counts[act.arg] ?? 0) + 1;
            usage.counts = counts;
        }
        if (act.verb === "forget") {
            Clip.remove(act.arg);
            refresh();
            return;
        }
        Ui.close();
        const music = home + "/Music/";
        switch (act.verb) {
        case "app":
            Apps.launch(act.arg, false);
            break;
        case "appnew":
            Apps.launch(act.arg, true);
            break;
        case "open":
        case "reveal":
        case "copyimg":
            Actions.run(act.verb + " " + act.arg);
            break;
        case "copy":
        case "clipcopy":
            Clip.use(act.arg, false);
            break;
        case "paste":
            Clip.use(act.arg, true);
            break;
        case "wallpaper":
            Tokens.set("wallpaper", act.arg);
            break;
        case "undo":
            Dotd.send("undo " + act.arg);
            break;
        case "pane":
            Ui.open(act.arg, null);
            break;
        case "song":
        case "songq":
            // Through mpd when it is in ~/Music; anything else opens.
            if (!act.arg.startsWith(music)) {
                Actions.run("open " + act.arg);
                break;
            }
            Quickshell.execDetached(["sh", "-c", act.verb === "songq" ? "rmpc add \"$1\"" : "rmpc add --position +1 \"$1\" 2>/dev/null && rmpc next || { rmpc add \"$1\" && rmpc play; }", "sh", act.arg.slice(music.length)]);
            break;
        case "tv":
            Tv.play(act.arg, "");
            break;
        case "tvqueue":
            Tv.play(act.arg, "queue");
            break;
        case "tvnext":
            Tv.play(act.arg, "next");
            break;
        case "anime":
            Anime.play(act.arg.m, act.arg.ep);
            break;
        case "animepage":
            Ui.openPage("media", "anime", null);
            Anime.open(act.arg);
            break;
        case "run":
            Quickshell.execDetached(["sh", "-c", act.arg]);
            break;
        case "term":
            Quickshell.execDetached(["ghostty", "-e", "sh", "-c", act.arg + "; exec \"${SHELL:-sh}\""]);
            break;
        }
    }

    function launch(i: int, shifted: bool): void {
        const row = results[i];
        if (!row || !row.acts.length)
            return;
        const alt = shifted ? row.acts.find(a => a.key === "N" || a.key === "T") : null;
        perform(row, alt ?? row.acts[0]);
    }

    // Alt + a letter: that action of the picked row.
    function byKey(event: var): bool {
        if (!(event.modifiers & Qt.AltModifier) || event.key < Qt.Key_A || event.key > Qt.Key_Z)
            return false;
        const k = String.fromCharCode(event.key);
        const act = picked?.acts.find(a => a.key === k);
        if (act)
            perform(picked, act);
        return true;
    }

    readonly property string actHint: {
        if (!picked || !picked.acts.length)
            return "";
        return ["ENTER " + picked.acts[0].label, ...picked.acts.slice(1).map(a => "ALT " + a.key + " " + a.label)].join("   ");
    }

    FileView {
        path: Tokens.dirReady ? Tokens.dir + "/launcher.json" : ""
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: usage
            property var counts: ({})
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // ── Board ───────────────────────────────────────────────────────
    Column {
        x: 4
        y: 4
        width: pane.inner
        spacing: 0

        Item {
            width: parent.width
            height: Tokens.lineDots

            DotText {
                text: pane.modeNames[pane.parsed.mode] ?? "DEPARTURES"
                color: Tokens.slot2
            }
            DotText {
                anchors.right: parent.right
                text: (pane.note ? pane.note + "   " : pane.waiting ? "SEARCHING   " : "") + `${pane.results.length} SHOWN   ${Qt.formatDateTime(clock.date, "hh:mm")}`
                color: Tokens.slot1
            }
        }

        // Column heads.
        DotText {
            height: Tokens.lineDots
            text: pane.pad("GATE", pane.gateChars) + " " + pane.pad("DESTINATION", pane.nameChars) + " " + pane.pad("CLASS", pane.classChars) + " " + "STATUS"
            color: Tokens.slot1
            opacity: 0.5
        }

        Rule {}
        Item {
            width: 1
            height: 2
        }

        Repeater {
            model: pane.slots

            Item {
                id: row
                required property int index
                readonly property var entry: pane.results[index] ?? null
                readonly property bool picked: index === pane.selected && entry !== null
                width: pane.inner
                height: Tokens.lineDots

                Frame {
                    anchors.fill: parent
                    visible: row.picked
                }

                FlapText {
                    x: 0
                    target: row.entry ? pane.pad(" " + (row.index + 1), pane.gateChars) : ""
                    color: Tokens.slot2
                }
                FlapText {
                    x: (pane.gateChars + 1) * Tokens.charDots
                    target: row.entry ? pane.pad(row.entry.name, pane.nameChars) : ""
                    color: Tokens.slot0
                }
                FlapText {
                    x: (pane.gateChars + pane.nameChars + 2) * Tokens.charDots
                    target: row.entry ? pane.pad(row.entry.cls, pane.classChars) : ""
                    color: Tokens.slot1
                }
                DotText {
                    x: (pane.gateChars + pane.nameChars + pane.classChars + 3) * Tokens.charDots
                    text: row.entry ? (row.picked && row.entry.status === "ON TIME" ? "BOARDING" : row.entry.status) : ""
                    color: Tokens.slot1
                    opacity: row.picked ? 1 : 0.5
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: row.entry !== null
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: pane.selected = row.index
                    onClicked: pane.launch(row.index, false)
                }
            }
        }

        Item {
            width: 1
            height: 2
        }
        Rule {}
        Item {
            width: 1
            height: 2
        }

        // The picked row's preview (matched text, or where it is), and what
        // its keys do.
        Item {
            width: parent.width
            height: Tokens.lineDots

            DotText {
                width: Math.max(0, parent.width - acts.implicitWidth - Tokens.charDots * 2)
                elide: Text.ElideRight
                text: (pane.picked?.preview ?? "").toUpperCase()
                color: Tokens.slot1
                opacity: 0.7
            }
            DotText {
                id: acts
                anchors.right: parent.right
                text: pane.actHint
                color: Tokens.slot2
                opacity: 0.8
            }
        }

        // ── Query ───────────────────────────────────────────────────
        Item {
            width: parent.width
            height: Tokens.lineDots

            DotText {
                id: prompt
                text: ">"
                color: Tokens.slot2
            }
            DotInput {
                id: input
                x: prompt.width + Tokens.charDots
                width: parent.width - x - hint.width - Tokens.charDots
                onTextChanged: pane.query = text
                keyFilter: event => pane.byKey(event)
                onAccepted: pane.launch(pane.selected, !!(input.acceptMods & Qt.ShiftModifier))

                Keys.onPressed: event => {
                    const ctrl = event.modifiers & Qt.ControlModifier;
                    const n = pane.results.length;
                    if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N))) {
                        if (n)
                            pane.selected = (pane.selected + 1) % n;
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P))) {
                        if (n)
                            pane.selected = (pane.selected + n - 1) % n;
                        event.accepted = true;
                    } else if (ctrl && event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                        pane.launch(event.key - Qt.Key_1, !!(event.modifiers & Qt.ShiftModifier));
                        event.accepted = true;
                    }
                }
            }
            DotText {
                id: hint
                anchors.right: parent.right
                text: "A F D I M N C T AN W >   ESC CLOSE"
                color: Tokens.slot1
                opacity: 0.5
            }
        }
    }
}
