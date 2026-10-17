import QtQuick
import Quickshell.Io
import qs
import qs.services

// The MEDIA pane's ANIME page (services/Anime.qml, the `dotanime` CLI over
// ani-cli and AniList).
//
// Shelves of covers: SEARCH (after Enter in the field), FEATURED (trending
// now), CATEGORIES (pick one for a shelf of its most popular), LIKED,
// WATCHLIST, DOWNLOADS. A shelf folds and unfolds on its header (or Ctrl X);
// an empty one stays folded. The shelves left open share the height: each
// gets a row of covers, then more rows while there is room and it has more.
// Down leaves the field for the covers, arrows move, Enter opens a show,
// Ctrl L likes, Ctrl W adds to the watchlist; typing goes back to the field.
// AUDIO by the field: the framed one of SUB and DUB is in use.
//
// A show: its cover and facts, then what it is now (WATCHED, SAVED, PLAYER),
// a bar while it downloads, what went wrong and the fixes to try (the other
// of sub and dub, ani-cli's next match, again). The picked episode's actions,
// the show's (like, watchlist, download all, download from where it was left
// off), its switches (AUDIO, KEEP NEXT 3 SAVED: the framed choice is how it
// is), ani-cli's match, then the episodes under a legend. A click picks an
// episode; a double click or Enter plays it (a saved one from disk). G gets
// it (or takes it out of the queue), D deletes it (twice), A all, N from
// where it was left off (twice), X stops, P keep next 3, L like, W watchlist,
// U sub or dub, S next match, Ctrl R reads the episodes again, Q the queue,
// Backspace goes back.
//
// The queue (Ctrl Q, or the download button by the field): what downloads
// now with its bar, what waits, what failed (RETRY), what is saved.
Item {
    id: page

    required property int inner
    // The pane's canvas: gets the keyboard while the field does not.
    required property Item surface
    property bool active: false

    width: inner

    readonly property int ln: Tokens.lineDots
    readonly property int ch: Tokens.charDots
    readonly property int gap: 3
    readonly property int chars: Math.floor(inner / ch)
    readonly property bool wide: chars >= 40
    readonly property var m: Anime.show

    onActiveChanged: {
        if (active) {
            Anime.wake();
            if (!m)
                focusField();
        }
    }

    function focusField(): void {
        field.forceActiveFocus();
    }
    function focusGrid(): void {
        surface.forceActiveFocus();
    }
    readonly property bool inField: field.activeFocus

    function up(s: string): string {
        return String(s ?? "").toUpperCase();
    }
    function facts(e: var): string {
        if (!e)
            return "";
        const f = [];
        if (e.format)
            f.push(e.format);
        if (e.year)
            f.push(e.year);
        if (e.episodes)
            f.push(e.episodes + " EP");
        else if (e.aired)
            f.push(e.aired + " EP SO FAR");
        if (e.score)
            f.push(e.score + "%");
        if (e.status === "RELEASING")
            f.push("AIRING");
        return f.join("  ");
    }
    // Words into lines of n characters, `most` lines at most.
    function wrap(text: string, n: int, most: int): var {
        const lines = [];
        if (!(most > 0))
            return lines;
        let line = "";
        for (const w of String(text ?? "").split(/\s+/)) {
            if (!w)
                continue;
            if (line && line.length + 1 + w.length > n) {
                lines.push(line);
                line = "";
                if (lines.length === most)
                    break;
            }
            line = line ? line + " " + w : w.slice(0, n);
        }
        if (line && lines.length < most)
            lines.push(line);
        else if (most > 0 && lines.length === most && lines[most - 1].length < n - 3)
            lines[most - 1] += "...";
        return lines;
    }

    // ── Shelves ─────────────────────────────────────────────────────
    readonly property var sections: {
        const s = [];
        if (Anime.searched)
            s.push({ key: "search", label: "SEARCH " + up(Anime.searched), items: Anime.results, busy: Anime.searching, empty: "NOTHING FOUND" });
        s.push({ key: "featured", label: "FEATURED", items: Anime.featured, busy: Anime.featuring, empty: Anime.offline ? "OFFLINE" : "NOTHING" });
        s.push({ key: "categories", label: "CATEGORIES", items: Anime.genres, chips: true, busy: false, empty: "OFFLINE" });
        if (Anime.genre)
            s.push({ key: "genre", label: up(Anime.genre), items: Anime.genreItems, busy: Anime.genreLoading, empty: "NOTHING" });
        s.push({ key: "liked", label: "LIKED", items: Anime.liked, busy: false, empty: "NONE YET" });
        s.push({ key: "watch", label: "WATCHLIST", items: Anime.watch, busy: false, empty: "NONE YET" });
        s.push({ key: "downloads", label: "DOWNLOADS", items: Anime.downloads, busy: false, empty: "NONE YET" });
        return s;
    }
    // Empty shelves fold themselves; a loading one stays open for its line.
    function folded(s: var): bool {
        if (s.items.length === 0)
            return !s.busy;
        return Anime.folds[s.key] ?? false;
    }
    function toggle(s: var): void {
        if (s.items.length)
            Anime.fold(s.key, !folded(s));
    }

    // Category chips wrap like words: their rows, for the height.
    function chipRows(list: var): int {
        let rows = 1, x = 0;
        for (const g of list) {
            const w = g.length * ch + 4;
            if (x > 0 && x + w > inner) {
                rows++;
                x = 0;
            }
            x += w + gap;
        }
        return rows;
    }

    // Covers are 2:3 posters. Every open shelf gets one row; the rows left go
    // one at a time, top first, to shelves with more to show.
    readonly property int listH: height - 2 * ln - 2 * gap - ln - gap
    readonly property var layout: {
        const secs = sections;
        let fixed = 0;
        const shelves = [];
        for (const s of secs) {
            fixed += ln + 2;
            if (folded(s))
                continue;
            fixed += 1;
            if (s.chips)
                fixed += chipRows(s.items) * (ln + 1 + gap) - gap;
            else if (!s.items.length)
                fixed += ln;
            else
                shelves.push(s.key);
        }
        const free = Math.max(0, listH - fixed);
        const n = shelves.length;
        let perRow = Math.max(3, Math.min(9, Math.floor((inner + gap) / (40 + gap))));
        let w = Math.floor((inner - gap * (perRow - 1)) / perRow);
        let h = Math.round(w * 1.42);
        if (n && n * (h + gap) > free) {
            // Not a row each at full size: smaller covers, more to a row.
            h = Math.max(ln * 2, Math.floor(free / n) - gap);
            w = Math.round(h / 1.42);
            perRow = Math.max(3, Math.floor((inner + gap) / (w + gap)));
            w = Math.floor((inner - gap * (perRow - 1)) / perRow);
        }
        const rows = {};
        let left = Math.floor(free / (h + gap)) - n;
        for (const k of shelves)
            rows[k] = 1;
        let grew = true;
        while (left > 0 && grew) {
            grew = false;
            for (const s of secs) {
                if (left <= 0 || !shelves.includes(s.key))
                    continue;
                if (rows[s.key] < Math.ceil(s.items.length / perRow)) {
                    rows[s.key]++;
                    left--;
                    grew = true;
                }
            }
        }
        return { perRow: perRow, w: w, h: h, rows: rows };
    }

    // The cursor: a section and an index in it. Offsets: the first row shown.
    property string curKey: "featured"
    property int curIdx: 0
    property var offsets: ({})
    readonly property var curSec: sections.find(s => s.key === curKey) ?? null
    readonly property var picked: curSec && !curSec.chips ? curSec.items[curIdx] ?? null : null

    function openSecs(): var {
        return sections.filter(s => !folded(s) && s.items.length);
    }
    function offset(key: string): int {
        return offsets[key] ?? 0;
    }
    function setOffset(key: string, v: int): void {
        const o = Object.assign({}, offsets);
        o[key] = v;
        offsets = o;
    }
    function reveal(): void {
        const s = curSec;
        if (!s || s.chips)
            return;
        const per = layout.perRow;
        const rows = layout.rows[s.key] ?? 1;
        const row = Math.floor(curIdx / per);
        const off = offset(s.key);
        if (row < off)
            setOffset(s.key, row);
        else if (row >= off + rows)
            setOffset(s.key, row - rows + 1);
    }
    function scroll(s: var, by: int): void {
        const per = layout.perRow;
        const rows = layout.rows[s.key] ?? 1;
        const most = Math.max(0, Math.ceil(s.items.length / per) - rows);
        setOffset(s.key, Math.max(0, Math.min(most, offset(s.key) + by)));
    }
    function go(key: string, idx: int): void {
        curKey = key;
        curIdx = idx;
        reveal();
    }
    // Into the shelves from the field, or onto a shelf just filled.
    function enter(key: string): void {
        const open = openSecs();
        const s = open.find(x => x.key === key) ?? open[0];
        if (!s)
            return;
        focusGrid();
        go(s.key, s.chips ? Math.max(0, s.items.indexOf(Anime.genre)) : offset(s.key) * layout.perRow);
    }

    function moveH(by: int): void {
        const s = curSec;
        if (!s || !s.items.length)
            return enter("");
        go(s.key, Math.max(0, Math.min(s.items.length - 1, curIdx + by)));
    }
    function moveV(by: int): void {
        const open = openSecs();
        let i = open.findIndex(s => s.key === curKey);
        if (i < 0)
            return enter("");
        const s = open[i];
        const per = layout.perRow;
        if (!s.chips) {
            const next = curIdx + by * per;
            const lastRow = Math.floor((s.items.length - 1) / per);
            if (next >= 0 && Math.floor(next / per) <= lastRow)
                return go(s.key, Math.min(next, s.items.length - 1));
        }
        const col = s.chips ? 0 : (curIdx - offset(s.key) * per) % per;
        i += by;
        if (i < 0)
            return focusField();
        if (i >= open.length)
            return;
        const t = open[i];
        if (t.chips)
            return go(t.key, Math.max(0, t.items.indexOf(Anime.genre)));
        const rows = layout.rows[t.key] ?? 1;
        const row = offset(t.key) + (by > 0 ? 0 : rows - 1);
        go(t.key, Math.min(t.items.length - 1, row * per + col));
    }
    function activate(): void {
        const s = curSec;
        if (!s || !s.items.length)
            return;
        if (s.chips) {
            Anime.pickGenre(s.items[curIdx]);
            return;
        }
        openShow(s.items[curIdx]);
    }
    function openShow(e: var): void {
        if (!e)
            return;
        queueOpen = false;
        Anime.open(e);
        epIdx = -1;
        epOff = 0;
        confirm = "";
        focusGrid();
    }
    function back(): void {
        Anime.close();
        if (curSec && curSec.items.length)
            focusGrid();
        else
            focusField();
    }

    // dotshell ipc call anime search frieren | open 154587 | back | queue
    // (opens the MEDIA pane on this page first)
    IpcHandler {
        target: "anime"

        function search(q: string): void {
            page.summon();
            field.text = q;
            Anime.search(q);
            page.enter("search");
        }
        function open(id: int): void {
            page.summon();
            const all = page.sections.filter(s => !s.chips).reduce((a, s) => a.concat(s.items), []);
            page.openShow(all.find(e => e.id === id) ?? { id: id, title: "", cover: "" });
        }
        function back(): void {
            page.back();
        }
        function queue(): void {
            page.summon();
            page.openQueue();
        }
    }
    signal summon

    // A picked category's shelf: go to it when it fills.
    Connections {
        target: Anime
        function onGenreItemsChanged(): void {
            if (Anime.genreItems.length && page.curKey === "categories")
                page.setOffset("genre", 0);
        }
        function onResultsChanged(): void {
            page.setOffset("search", 0);
            if (Anime.results.length && !page.m && !page.inField)
                page.go("search", 0);
        }
    }

    // ── A show ──────────────────────────────────────────────────────
    readonly property var eps: Anime.source?.episodes ?? []
    readonly property var savedEps: m ? Anime.saved(m.id) : []
    readonly property var pendingEps: m ? Anime.pending(m.id) : []
    readonly property string resumeEp: m ? Anime.resume(m.id, eps) : ""
    // Not saved and not queued, from where it was left off: DOWNLOAD REST.
    readonly property var restEps: {
        const i = Math.max(0, eps.indexOf(resumeEp));
        return eps.slice(i).filter(e => !savedEps.includes(e) && !pendingEps.includes(e));
    }
    readonly property var missingEps: eps.filter(e => !savedEps.includes(e) && !pendingEps.includes(e))
    property int epIdx: -1
    property int epOff: 0
    property string confirm: ""
    readonly property int pickedEp: epIdx >= 0 && epIdx < eps.length ? epIdx : Math.max(0, eps.indexOf(resumeEp))
    readonly property string epPicked: eps[pickedEp] ?? ""
    readonly property int epW: (Math.max(2, ...eps.map(e => e.length)) + 1) * ch + 2
    readonly property int epPer: Math.max(1, Math.floor((inner + 2) / (epW + 2)))

    // A second press confirms (GET ALL, DELETE); it forgets after a while.
    onConfirmChanged: {
        if (confirm)
            forget.restart();
    }
    Timer {
        id: forget
        interval: 4000
        onTriggered: page.confirm = ""
    }

    function moveEp(by: int): void {
        if (!eps.length)
            return;
        pickEp(Math.max(0, Math.min(eps.length - 1, pickedEp + by)));
    }
    function pickEp(i: int): void {
        epIdx = i;
        confirm = "";
        const row = Math.floor(i / epPer);
        if (row < epOff)
            epOff = row;
        else if (row >= epOff + epRows.rows)
            epOff = row - epRows.rows + 1;
    }

    // The state of one episode of the open show.
    function epState(ep: string): string {
        if (!m)
            return "new";
        const cur = Anime.jobs.current;
        if (cur && cur.aid === m.id && cur.ep === ep)
            return "getting";
        if (pendingEps.includes(ep))
            return "queued";
        if (savedEps.includes(ep))
            return "saved";
        return "new";
    }

    function act(what: string): void {
        if (!m)
            return;
        const ep = epPicked;
        const st = epState(ep);
        if (what === "play" && ep)
            Anime.play(m, ep);
        else if (what === "get" && ep) {
            // The same key takes a queued one back out.
            if (st === "new")
                Anime.get(m, [ep]);
            else if (st === "queued" || st === "getting")
                Anime.cancel(m.id, ep);
        } else if (what === "all" || what === "rest") {
            const list = what === "all" ? missingEps : restEps;
            if (!list.length)
                return;
            if (confirm === what) {
                Anime.get(m, list);
                confirm = "";
            } else {
                confirm = what;
            }
            return;
        } else if (what === "delete" && st === "saved") {
            if (confirm === "del" + ep) {
                Anime.remove(m, ep);
                confirm = "";
            } else {
                confirm = "del" + ep;
            }
            return;
        } else if (what === "stop")
            Anime.cancel(m.id, "");
        else if (what === "prefetch")
            Anime.prefetch(m);
        else if (what === "like")
            Anime.like(m);
        else if (what === "watch")
            Anime.toggleWatch(m);
        else if (what === "mode")
            Anime.toggleMode();
        else if (what === "source")
            Anime.nextSource();
        else if (what === "reload")
            Anime.reloadEpisodes();
        confirm = "";
    }

    // ── What the open show is doing ─────────────────────────────────
    readonly property bool playingHere: !!m && !!Anime.playing && Anime.playing.id === m.id
    readonly property var jobHere: m && Anime.jobs.current && Anime.jobs.current.aid === m.id ? Anime.jobs.current : null

    readonly property string watchedText: {
        if (!m)
            return "";
        const pr = Anime.progress[m.id];
        const of = eps.length ? " OF " + eps.length : "";
        if (!pr)
            return "NOT STARTED";
        const where = pr.done ? "FINISHED EP " + pr.ep + of : "STOPPED IN EP " + pr.ep + of + (pr.pos ? " AT " + pr.pos + "%" : "");
        return where + (resumeEp && resumeEp !== pr.ep ? "  NEXT: EP " + resumeEp : "");
    }
    readonly property string savedText: {
        if (!m)
            return "";
        const of = eps.length ? " OF " + eps.length : "";
        return (savedEps.length ? savedEps.length + of : "NONE") + (pendingEps.length ? "  +" + pendingEps.length + " COMING" : "");
    }
    readonly property string playerText: {
        if (!playingHere)
            return Anime.playing ? "PLAYING ANOTHER SHOW" : "NOTHING PLAYING";
        const p = Anime.playing;
        if (p.phase === "finding")
            return "FINDING A STREAM FOR EP " + p.ep + "...";
        return (p.local ? "PLAYING EP " + p.ep + " FROM DISK" : "STREAMING EP " + p.ep) + " IN MPV";
    }

    // A problem with the open show: [text, fixes, ep, kind], or null. A play
    // that failed, else the last download that failed.
    property string dismissed: ""
    readonly property var problem: {
        if (!m)
            return null;
        let got = null;
        if (Anime.st.error && Anime.st.errorId === m.id && !playingHere)
            got = Anime.explain(Anime.st.error, Anime.st.errorEp).concat([Anime.st.errorEp, "play"]);
        else {
            const f = Anime.failed(m.id);
            if (f.length)
                got = Anime.explain(f[f.length - 1].why, f[f.length - 1].ep).concat([f[f.length - 1].ep, "get"]);
        }
        if (got && (Anime.source?.candidates.length ?? 0) < 2)
            got[1] = got[1].filter(x => x !== "source");
        return got && got[0] + got[3] !== dismissed ? got : null;
    }
    function fix(how: string): void {
        const p = problem;
        if (!p)
            return;
        const retry = () => p[3] === "play" ? Anime.play(m, p[2]) : Anime.get(m, [p[2]]);
        if (how === "dismiss") {
            dismissed = p[0] + p[3];
            if (p[3] === "get")
                Anime.cancel(m.id, p[2]);
        } else if (how === "mode") {
            Anime.toggleMode();
            later.what = retry;
            later.restart();
        } else if (how === "source") {
            Anime.nextSource();
        } else {
            retry();
        }
    }
    // After a switch to sub or dub, wait for the new match before retrying.
    Timer {
        id: later
        property var what: null
        interval: 2500
        onTriggered: {
            if (what)
                what();
            what = null;
        }
    }

    // ── The queue ───────────────────────────────────────────────────
    property bool queueOpen: false
    property int queueOff: 0
    readonly property var queueRows: {
        const j = Anime.jobs;
        const r = [];
        r.push({ kind: "head", text: "DOWNLOADING NOW" });
        if (j.current) {
            r.push({ kind: "job", text: up(j.current.title) + "  EP " + j.current.ep, aid: j.current.aid, ep: j.current.ep });
            r.push({ kind: "bar", pct: j.current.pct ?? 0 });
        } else {
            r.push({ kind: "note", text: "NOTHING" });
        }
        r.push({ kind: "head", text: "WAITING  " + j.queue.length });
        if (!j.queue.length)
            r.push({ kind: "note", text: "NOTHING QUEUED" });
        for (const q of j.queue)
            r.push({ kind: "queued", text: up(q.title) + "  EP " + q.ep, aid: q.aid, ep: q.ep });
        if (j.failed.length) {
            r.push({ kind: "head", text: "FAILED  " + j.failed.length });
            for (const f of j.failed)
                r.push({ kind: "failed", text: up(f.title).slice(0, 18) + "  " + Anime.explain(f.why, f.ep)[0], aid: f.aid, ep: f.ep });
        }
        r.push({ kind: "head", text: "SAVED" });
        const saved = Anime.downloads.filter(d => d.saved.length);
        if (!saved.length)
            r.push({ kind: "note", text: "NOTHING SAVED YET" });
        for (const d of saved)
            r.push({ kind: "saved", text: up(d.title), count: d.saved.length + " EP", show: d });
        return r;
    }
    readonly property int queueFit: Math.max(1, Math.floor((height - ln - gap - 1 - gap) / (ln + 1)))
    function scrollQueue(by: int): void {
        queueOff = Math.max(0, Math.min(queueRows.length - queueFit, queueOff + by));
    }
    function openQueue(): void {
        queueOpen = true;
        queueOff = 0;
        focusGrid();
    }

    // ── Keys ────────────────────────────────────────────────────────
    function key(event: var): bool {
        const k = event.key;
        const ctrl = event.modifiers & Qt.ControlModifier;
        if (queueOpen) {
            if (k === Qt.Key_Backspace || k === Qt.Key_Q || k === Qt.Key_B)
                queueOpen = false;
            else if (k === Qt.Key_Down || k === Qt.Key_J)
                scrollQueue(1);
            else if (k === Qt.Key_Up || k === Qt.Key_K)
                scrollQueue(-1);
            else
                return false;
            if (!queueOpen && !m)
                focusField();
            return true;
        }
        if (m) {
            if (k === Qt.Key_Backspace || k === Qt.Key_B)
                back();
            else if (k === Qt.Key_Right)
                moveEp(1);
            else if (k === Qt.Key_Left)
                moveEp(-1);
            else if (k === Qt.Key_Down || k === Qt.Key_J)
                moveEp(epPer);
            else if (k === Qt.Key_Up || k === Qt.Key_K)
                moveEp(-epPer);
            else if (k === Qt.Key_PageDown)
                moveEp(epPer * epRows.rows);
            else if (k === Qt.Key_PageUp)
                moveEp(-epPer * epRows.rows);
            else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space)
                act("play");
            else if (k === Qt.Key_G)
                act("get");
            else if (k === Qt.Key_A)
                act("all");
            else if (k === Qt.Key_N)
                act("rest");
            else if (k === Qt.Key_D)
                act("delete");
            else if (k === Qt.Key_X)
                act("stop");
            else if (k === Qt.Key_P)
                act("prefetch");
            else if (k === Qt.Key_L)
                act("like");
            else if (k === Qt.Key_W)
                act("watch");
            else if (k === Qt.Key_U)
                act("mode");
            else if (k === Qt.Key_S)
                act("source");
            else if (k === Qt.Key_R && ctrl)
                act("reload");
            else if (k === Qt.Key_Q)
                openQueue();
            else
                return false;
            return true;
        }
        if (ctrl && k === Qt.Key_Q) {
            openQueue();
            return true;
        }
        if (inField) {
            if (k === Qt.Key_Down) {
                enter(curKey);
                return true;
            }
            return false;
        }
        if (k === Qt.Key_Right)
            moveH(1);
        else if (k === Qt.Key_Left)
            moveH(-1);
        else if (k === Qt.Key_Down)
            moveV(1);
        else if (k === Qt.Key_Up)
            moveV(-1);
        else if (k === Qt.Key_Return || k === Qt.Key_Enter)
            activate();
        else if (ctrl && k === Qt.Key_X && curSec) {
            toggle(curSec);
            if (folded(curSec))
                enter("");
        }
        else if (ctrl && k === Qt.Key_L && picked)
            Anime.like(picked);
        else if (ctrl && k === Qt.Key_W && picked)
            Anime.toggleWatch(picked);
        else if (ctrl && k === Qt.Key_U)
            Anime.toggleMode();
        else if (k === Qt.Key_Backspace) {
            focusField();
            field.text = field.text.slice(0, -1);
        } else if (!ctrl && event.text && event.text.length === 1 && event.text >= " ") {
            // Typing goes to the field.
            focusField();
            field.text += event.text;
        } else
            return false;
        return true;
    }

    readonly property var hints: {
        if (queueOpen)
            return ["UP DOWN SCROLL  BKSP OR Q BACK"];
        if (!wide)
            return ["ENTER OPEN  BKSP BACK"];
        if (m)
            return ["CLICK PICKS  DOUBLE CLICK OR ENTER PLAYS", "G GET  D DEL  A ALL  X STOP  Q QUEUE  BKSP BACK"];
        if (inField)
            return ["ENTER SEARCH  DOWN COVERS  ^Q QUEUE  TAB PAGE"];
        return ["ENTER OPEN  ^X FOLD  ^L LIKE  ^W WATCHLIST  ^Q QUEUE", "ARROWS MOVE  TYPE TO SEARCH  ^U SUB DUB"];
    }

    // ═════════════════════════════════════════════════════════════════
    // The field, and what is going on.
    Item {
        id: top
        visible: !page.m && !page.queueOpen
        width: page.inner
        height: page.ln

        DotText {
            id: prompt
            text: Anime.searching ? "~" : "?"
            color: Tokens.slot2
        }
        DotInput {
            id: field
            x: prompt.width + page.ch
            width: status.x - x - page.ch
            onAccepted: {
                const q = text.trim();
                if (!q)
                    Anime.clearSearch();
                else if (q !== Anime.searched)
                    Anime.search(q);
                page.enter(q ? "search" : "featured");
            }
        }
        Row {
            id: status
            anchors.right: parent.right
            spacing: 6

            DotButton {
                text: " " + (Anime.jobs.current ? Math.round(Anime.jobs.current.pct) + "%" + (Anime.jobs.queue.length ? " +" + Anime.jobs.queue.length : "") : "QUEUE") + (Anime.jobs.failed.length ? " !" + Anime.jobs.failed.length : "")
                color: Anime.busy || Anime.jobs.failed.length ? Tokens.slot2 : Tokens.slot1
                onClicked: page.openQueue()
            }
            AnimeSwitch {
                label: page.wide ? "AUDIO" : ""
                choices: [["sub", "SUB"], ["dub", "DUB"]]
                value: Anime.mode
                onPicked: v => Anime.setMode(v)
            }
        }
    }

    // ── Shelves ─────────────────────────────────────────────────────
    Column {
        id: shelves
        visible: !page.m && !page.queueOpen
        y: page.ln + page.gap
        width: page.inner
        height: page.listH
        spacing: 2
        clip: true

        Repeater {
            model: page.sections

            Column {
                id: sec
                required property var modelData
                readonly property var s: modelData
                readonly property bool isFolded: page.folded(s)
                readonly property int rows: page.layout.rows[s.key] ?? 1
                readonly property int off: page.offset(s.key)
                readonly property int per: page.layout.perRow
                readonly property bool current: page.curKey === s.key && !page.inField
                width: page.inner
                spacing: 1

                // Header: fold mark, name, count; the page of covers.
                Item {
                    width: page.inner
                    height: page.ln

                    DotText {
                        text: (sec.isFolded ? "\uf105 " : "\uf107 ") + sec.s.label
                        color: sec.current ? Tokens.slot2 : sec.s.items.length ? Tokens.slot0 : Tokens.slot1
                        width: parent.width - count.width - page.ch
                        elide: Text.ElideRight
                    }
                    Row {
                        id: count
                        anchors.right: parent.right
                        spacing: 3

                        DotButton {
                            visible: !sec.s.chips && !sec.isFolded && sec.off > 0
                            text: "<"
                            color: Tokens.slot1
                            onClicked: page.scroll(sec.s, -1)
                        }
                        DotText {
                            text: sec.s.busy ? "LOADING" : !sec.s.items.length ? sec.s.empty : sec.s.chips || sec.isFolded || sec.s.items.length <= sec.rows * sec.per ? String(sec.s.items.length) : (sec.off * sec.per + 1) + "-" + Math.min(sec.s.items.length, (sec.off + sec.rows) * sec.per) + "/" + sec.s.items.length
                            color: Tokens.slot1
                        }
                        DotButton {
                            visible: !sec.s.chips && !sec.isFolded && (sec.off + sec.rows) * sec.per < sec.s.items.length
                            text: ">"
                            color: Tokens.slot1
                            onClicked: page.scroll(sec.s, 1)
                        }
                    }
                    MouseArea {
                        width: parent.width - count.width - page.ch
                        height: parent.height
                        cursorShape: sec.s.items.length ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: page.toggle(sec.s)
                    }
                }

                // A shelf that is still coming.
                DotText {
                    visible: !sec.isFolded && !sec.s.items.length
                    height: page.ln
                    text: "  ..."
                    color: Tokens.slot1
                }

                // Categories.
                Flow {
                    visible: !!sec.s.chips && !sec.isFolded
                    width: page.inner
                    spacing: page.gap

                    Repeater {
                        model: sec.s.chips && !sec.isFolded ? sec.s.items : []

                        Item {
                            id: chip
                            required property string modelData
                            required property int index
                            readonly property bool here: sec.current && page.curIdx === index
                            width: label.width
                            height: page.ln + 1

                            DotButton {
                                id: label
                                text: page.up(chip.modelData)
                                color: Anime.genre === chip.modelData ? Tokens.slot2 : Tokens.slot0
                                active: Anime.genre === chip.modelData || chip.here
                                onClicked: {
                                    page.focusGrid();
                                    page.go("categories", chip.index);
                                    Anime.pickGenre(chip.modelData);
                                }
                            }
                        }
                    }
                }

                // Covers.
                Item {
                    visible: !sec.s.chips && !sec.isFolded && sec.s.items.length > 0
                    width: page.inner
                    height: visible ? sec.rows * (page.layout.h + page.gap) : 0

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: event => page.scroll(sec.s, event.angleDelta.y < 0 ? 1 : -1)
                    }

                    Repeater {
                        model: sec.isFolded || sec.s.chips ? 0 : Math.min(sec.s.items.length - sec.off * sec.per, sec.rows * sec.per)

                        Item {
                            id: card
                            required property int index
                            readonly property int at: sec.off * sec.per + index
                            readonly property var e: sec.s.items[at] ?? null
                            readonly property bool here: sec.current && page.curIdx === at
                            readonly property var pr: e ? Anime.progress[e.id] ?? null : null
                            x: 1 + (index % sec.per) * (page.layout.w + page.gap)
                            y: 1 + Math.floor(index / sec.per) * (page.layout.h + page.gap)
                            width: page.layout.w - 2
                            height: page.layout.h - 2

                            Frame {
                                anchors.fill: parent
                                visible: !art.ready
                                border.color: Tokens.slot1
                                opacity: 0.4
                            }
                            PlainArt {
                                id: art
                                anchors.fill: parent
                                source: card.e?.cover ?? ""
                            }
                            // Where it was left off, along the bottom.
                            Rectangle {
                                visible: card.pr !== null && (card.e?.episodes ?? card.e?.aired ?? 0) > 0
                                y: parent.height - 2
                                width: Math.round(parent.width * Math.min(1, Number(card.pr?.ep ?? 0) / (card.e?.episodes || card.e?.aired || 1)))
                                height: 2
                                color: Tokens.slot2
                            }
                            Frame {
                                x: -1
                                y: -1
                                width: parent.width + 2
                                height: parent.height + 2
                                visible: card.here
                                border.color: Tokens.slot2
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                onEntered: {
                                    if (!page.inField)
                                        page.go(sec.s.key, card.at);
                                    else
                                        page.hover = card.e;
                                }
                                onExited: page.hover = null
                                onClicked: mouse => {
                                    page.focusGrid();
                                    page.go(sec.s.key, card.at);
                                    if (mouse.button === Qt.MiddleButton)
                                        Anime.toggleWatch(card.e);
                                    else
                                        page.openShow(card.e);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    property var hover: null

    // The cover under the cursor: its name and facts. Else what plays.
    Column {
        visible: !page.m && !page.queueOpen
        anchors.bottom: parent.bottom
        width: page.inner
        spacing: page.gap

        readonly property var e: page.hover ?? (page.inField ? null : page.picked)

        Scroller {
            width: page.inner
            height: page.ln
            text: {
                const e = parent.e;
                if (e)
                    return page.up(e.title);
                const p = Anime.playing;
                if (p)
                    return (p.phase === "finding" ? "NOW: FINDING A STREAM FOR " : p.local ? "NOW: PLAYING " : "NOW: STREAMING ") + page.up(p.title) + " EP " + p.ep;
                return Anime.offline ? "ANILIST: " + page.up(Anime.offline) : "";
            }
            color: parent.e ? Tokens.slot0 : Tokens.slot2
        }
        DotText {
            width: page.inner
            height: page.ln
            elide: Text.ElideRight
            color: Tokens.slot1
            text: {
                const e = parent.e;
                if (!e) {
                    const c = Anime.jobs.current;
                    return c ? "DOWNLOADING " + page.up(c.title) + " EP " + c.ep + "  " + Math.round(c.pct) + "%" : "";
                }
                const pr = Anime.progress[e.id];
                const marks = (Anime.isLiked(e.id) ? "LIKED  " : "") + (Anime.inWatch(e.id) ? "ON WATCHLIST  " : "") + (e.saved?.length ? e.saved.length + " SAVED  " : "") + (pr ? "AT EP " + pr.ep + "  " : "");
                return marks + page.facts(e) + (page.wide ? "  " + page.up((e.genres ?? []).slice(0, 2).join(" ")) : "");
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════
    // The download queue.
    Column {
        id: queue
        visible: page.queueOpen
        width: page.inner
        spacing: page.gap

        Line {
            label: "DOWNLOADS"
            labelColor: Tokens.slot2

            DotButton {
                visible: Anime.busy
                text: "STOP ALL"
                onClicked: Anime.cancel(0, "")
            }
            DotButton {
                text: "BACK"
                color: Tokens.slot1
                onClicked: {
                    page.queueOpen = false;
                    if (!page.m)
                        page.focusField();
                }
            }
        }
        Rule {}

        Column {
            width: page.inner
            spacing: 1

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => page.scrollQueue(event.angleDelta.y < 0 ? 1 : -1)
            }

            Repeater {
                model: page.queueRows.slice(page.queueOff, page.queueOff + page.queueFit)

                Item {
                    id: qrow
                    required property var modelData
                    readonly property var r: modelData
                    width: page.inner
                    height: page.ln

                    DotText {
                        visible: qrow.r.kind !== "bar"
                        x: qrow.r.kind === "head" ? 0 : 2 * page.ch
                        width: parent.width - x - tail.width - page.ch
                        elide: Text.ElideRight
                        text: qrow.r.text ?? ""
                        color: qrow.r.kind === "head" ? Tokens.slot2 : qrow.r.kind === "note" ? Tokens.slot1 : qrow.r.kind === "failed" ? Tokens.slot2 : Tokens.slot0
                    }
                    // The progress bar.
                    Frame {
                        id: qtrack
                        visible: qrow.r.kind === "bar"
                        x: 2 * page.ch
                        y: 2
                        width: parent.width - x - 6 * page.ch
                        height: 9
                        border.color: Tokens.slot1
                    }
                    Rectangle {
                        visible: qtrack.visible
                        x: qtrack.x + 2
                        y: 4
                        width: Math.round((qtrack.width - 4) * Math.max(0, Math.min(100, qrow.r.pct ?? 0)) / 100)
                        height: 5
                        color: Tokens.slot2
                    }
                    Row {
                        id: tail
                        anchors.right: parent.right
                        height: page.ln
                        spacing: 3

                        DotText {
                            visible: qrow.r.kind === "bar" || qrow.r.kind === "saved"
                            text: qrow.r.kind === "bar" ? Math.round(qrow.r.pct) + "%" : qrow.r.count ?? ""
                            color: Tokens.slot1
                        }
                        DotButton {
                            visible: qrow.r.kind === "job" || qrow.r.kind === "queued"
                            text: qrow.r.kind === "job" ? "STOP" : "DROP"
                            color: Tokens.slot1
                            onClicked: Anime.cancel(qrow.r.aid, qrow.r.ep)
                        }
                        DotButton {
                            visible: qrow.r.kind === "failed"
                            text: "RETRY"
                            onClicked: Anime.get({ id: qrow.r.aid }, [qrow.r.ep])
                        }
                        DotButton {
                            visible: qrow.r.kind === "failed"
                            text: "DISMISS"
                            color: Tokens.slot1
                            onClicked: Anime.cancel(qrow.r.aid, qrow.r.ep)
                        }
                        DotButton {
                            visible: qrow.r.kind === "saved"
                            text: "OPEN"
                            onClicked: {
                                page.queueOpen = false;
                                page.openShow(qrow.r.show);
                            }
                        }
                    }
                }
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════
    // One show.
    Column {
        id: detail
        visible: page.m !== null && !page.queueOpen
        width: page.inner
        spacing: page.gap

        readonly property var e: page.m ? Object.assign({}, page.m, Anime.info?.id === page.m.id ? Anime.info : {}) : null
        readonly property int posterW: Math.min(Math.round(page.inner * 0.22), 72)
        readonly property int posterH: Math.round(posterW * 1.42)

        // Cover; name, facts, and the three things to know.
        Item {
            width: page.inner
            height: Math.max(detail.posterH, side.height)

            Frame {
                width: detail.posterW
                height: detail.posterH
                visible: !poster.ready
                border.color: Tokens.slot1
                opacity: 0.4
            }
            PlainArt {
                id: poster
                width: detail.posterW
                height: detail.posterH
                source: detail.e?.cover ?? ""
            }

            Column {
                id: side
                x: detail.posterW + 6
                width: page.inner - x

                Scroller {
                    width: parent.width
                    height: page.ln
                    text: page.up(detail.e?.title)
                }
                DotText {
                    width: parent.width
                    height: page.ln
                    elide: Text.ElideRight
                    text: page.facts(detail.e)
                    color: Tokens.slot1
                }
                DotText {
                    width: parent.width
                    height: page.ln
                    elide: Text.ElideRight
                    text: page.up((detail.e?.genres ?? []).join(" ")) + (detail.e?.studio ? "  " + page.up(detail.e.studio) : "")
                    color: Tokens.slot1
                    opacity: 0.7
                }
                Item {
                    width: 1
                    height: 4
                }
                AnimeState {
                    label: "WATCHED"
                    value: page.watchedText
                }
                AnimeState {
                    label: "SAVED"
                    value: page.savedText
                }
                AnimeState {
                    label: "PLAYER"
                    value: page.playerText
                    tone: page.playingHere ? Tokens.slot2 : Tokens.slot1
                }
            }
        }

        // This show's download: a bar while it runs.
        Item {
            visible: page.jobHere !== null || page.pendingEps.length > 0
            width: page.inner
            height: page.ln

            DotText {
                id: getLabel
                text: page.jobHere ? "GETTING EP " + page.jobHere.ep : page.pendingEps.length + " WAITING"
                color: Tokens.slot2
            }
            Frame {
                id: gtrack
                visible: page.jobHere !== null
                x: getLabel.width + page.ch
                y: 2
                width: getTail.x - x - page.ch
                height: 9
                border.color: Tokens.slot1
            }
            Rectangle {
                visible: gtrack.visible
                x: gtrack.x + 2
                y: 4
                width: Math.round((gtrack.width - 4) * Math.max(0, Math.min(100, page.jobHere?.pct ?? 0)) / 100)
                height: 5
                color: Tokens.slot2
            }
            Row {
                id: getTail
                anchors.right: parent.right
                height: page.ln
                spacing: 3

                DotText {
                    text: (page.jobHere ? Math.round(page.jobHere.pct) + "%" : "") + (page.jobHere && page.pendingEps.length > 1 ? " +" + (page.pendingEps.length - 1) : "")
                    color: Tokens.slot1
                }
                DotButton {
                    text: "STOP"
                    color: Tokens.slot1
                    onClicked: page.act("stop")
                }
                DotButton {
                    text: "QUEUE"
                    color: Tokens.slot1
                    onClicked: page.openQueue()
                }
            }
        }

        // Something went wrong: what, and what to try.
        Item {
            visible: page.problem !== null
            width: page.inner
            height: page.ln

            DotText {
                width: fixes.x - page.ch
                elide: Text.ElideRight
                text: " " + (page.problem?.[0] ?? "")
                color: Tokens.slot2
            }
            Row {
                id: fixes
                anchors.right: parent.right
                spacing: 3

                Repeater {
                    model: (page.problem?.[1] ?? []).concat(["dismiss"])
                    DotButton {
                        required property string modelData
                        text: modelData === "mode" ? "TRY " + (Anime.mode === "sub" ? "DUB" : "SUB") : modelData === "source" ? "OTHER MATCH" : modelData === "retry" ? "RETRY" : "OK"
                        color: modelData === "dismiss" ? Tokens.slot1 : Tokens.slot0
                        onClicked: page.fix(modelData)
                    }
                }
            }
        }

        Rule {}

        // The picked episode.
        Item {
            width: page.inner
            height: page.ln

            Row {
                spacing: 3

                DotText {
                    text: page.epPicked ? "EPISODE " + page.epPicked : Anime.finding ? "FINDING EPISODES..." : "NO EPISODES"
                    color: Tokens.slot2
                    width: 12 * page.ch
                }
                DotButton {
                    visible: page.epPicked !== ""
                    text: " PLAY"
                    onClicked: page.act("play")
                }
                DotButton {
                    readonly property string s: page.epState(page.epPicked)
                    visible: page.epPicked !== ""
                    text: s === "new" ? " DOWNLOAD" : s === "saved" ? (page.confirm === "del" + page.epPicked ? "SURE? DELETE" : " DELETE FILE") : s === "getting" ? "STOP DOWNLOAD" : "TAKE OUT OF QUEUE"
                    color: page.confirm === "del" + page.epPicked ? Tokens.slot2 : Tokens.slot0
                    onClicked: page.act(s === "saved" ? "delete" : "get")
                }
            }
        }

        // The whole show.
        Flow {
            width: page.inner
            spacing: 3

            DotButton {
                readonly property bool on: page.m !== null && Anime.isLiked(page.m.id)
                text: on ? " LIKED" : " LIKE"
                active: on
                onClicked: page.act("like")
            }
            DotButton {
                readonly property bool on: page.m !== null && Anime.inWatch(page.m.id)
                text: on ? " ON WATCHLIST" : " WATCHLIST"
                active: on
                onClicked: page.act("watch")
            }
            DotButton {
                visible: page.missingEps.length > 0
                text: page.confirm === "all" ? "SURE? GET " + page.missingEps.length + " EP" : " ALL " + page.missingEps.length
                color: page.confirm === "all" ? Tokens.slot2 : Tokens.slot0
                onClicked: page.act("all")
            }
            DotButton {
                visible: page.restEps.length > 0 && page.restEps.length < page.missingEps.length
                text: page.confirm === "rest" ? "SURE? GET " + page.restEps.length + " EP" : " FROM EP " + page.restEps[0]
                color: page.confirm === "rest" ? Tokens.slot2 : Tokens.slot0
                onClicked: page.act("rest")
            }
            DotButton {
                text: "BACK"
                color: Tokens.slot1
                onClicked: page.back()
            }
        }

        // Settings, each showing how it is now.
        Flow {
            width: page.inner
            spacing: 4 * page.ch

            AnimeSwitch {
                label: "AUDIO"
                choices: [["sub", "SUB"], ["dub", "DUB"]]
                value: Anime.mode
                onPicked: v => Anime.setMode(v)
            }
            AnimeSwitch {
                label: "KEEP NEXT 3 SAVED"
                choices: [[false, "OFF"], [true, "ON"]]
                value: page.m !== null && Anime.prefetching(page.m.id)
                onPicked: v => {
                    if (v !== (page.m !== null && Anime.prefetching(page.m.id)))
                        page.act("prefetch");
                }
            }
        }

        // Which show on ani-cli's source this is; another if it is wrong.
        Item {
            width: page.inner
            height: page.ln

            DotText {
                text: "MATCH"
                color: Tokens.slot1
            }
            DotText {
                x: 8 * page.ch
                width: srcNext.x - x - page.ch
                elide: Text.ElideRight
                text: Anime.finding ? "SEARCHING THE SOURCE..." : Anime.source ? page.up(Anime.source.title) : page.up(Anime.notFound)
                color: !Anime.source && Anime.notFound ? Tokens.slot2 : Tokens.slot0
            }
            DotButton {
                id: srcNext
                anchors.right: parent.right
                visible: (Anime.source?.candidates.length ?? 0) > 1 && !Anime.finding
                text: "WRONG? NEXT " + (Anime.source?.index ?? 1) + "/" + (Anime.source?.candidates.length ?? 1)
                color: Tokens.slot1
                onClicked: page.act("source")
            }
        }

        // Synopsis: what fits.
        Repeater {
            model: page.wrap(detail.e?.description ?? "", page.chars, Math.max(0, Math.min(3, Math.floor((page.height - detail.posterH - 9 * (page.ln + page.gap) - 3 * (page.ln + 2)) / (page.ln + page.gap)))))

            DotText {
                required property string modelData
                width: page.inner
                height: page.ln
                text: page.up(modelData)
                color: Tokens.slot1
            }
        }

        Rule {}

        // The legend: what the episode marks mean.
        Flow {
            width: page.inner
            spacing: page.ch
            visible: page.eps.length > 0

            Repeater {
                model: [["new", "", "NOT SAVED"], ["saved", "", "SAVED"], ["getting", "", "DOWNLOADING"], ["queued", "", "QUEUED"], ["new", "seen", "WATCHED"], ["new", "playing", "PLAYING"]]

                Row {
                    required property var modelData
                    spacing: 1

                    AnimeEp {
                        width: 2 * page.ch + 2
                        ep: "7"
                        mark: parent.modelData[0]
                        seen: parent.modelData[1] === "seen"
                        playing: parent.modelData[1] === "playing"
                        pct: 50
                    }
                    DotText {
                        text: parent.modelData[2]
                        color: Tokens.slot1
                    }
                }
            }
        }

        // Episodes. Click picks one, a double click (or Enter) plays it.
        Item {
            id: epRows
            readonly property int rows: Math.max(1, Math.floor((page.height - y) / (page.ln + 2)))
            width: page.inner
            height: Math.min(rows, Math.ceil(page.eps.length / page.epPer)) * (page.ln + 2)

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    const most = Math.max(0, Math.ceil(page.eps.length / page.epPer) - epRows.rows);
                    page.epOff = Math.max(0, Math.min(most, page.epOff + (event.angleDelta.y < 0 ? 1 : -1)));
                }
            }

            Repeater {
                model: Math.max(0, Math.min(page.eps.length - page.epOff * page.epPer, epRows.rows * page.epPer))

                AnimeEp {
                    id: epChip
                    width: page.epW
                    required property int index
                    readonly property int at: page.epOff * page.epPer + index
                    x: (index % page.epPer) * (page.epW + 2)
                    y: Math.floor(index / page.epPer) * (page.ln + 2)
                    ep: page.eps[at] ?? ""
                    mark: page.epState(ep)
                    seen: page.m !== null && Anime.watched(page.m.id, ep)
                    playing: page.playingHere && Anime.playing.ep === ep
                    pct: page.jobHere?.pct ?? 0
                    picked: at === page.pickedEp
                    warn: page.confirm === "del" + ep

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.pickEp(epChip.at)
                        onDoubleClicked: {
                            page.pickEp(epChip.at);
                            page.act("play");
                        }
                    }
                }
            }
        }
        DotText {
            visible: !Anime.finding && Anime.source !== null && page.eps.length === 0
            height: page.ln
            text: "NO EPISODES OUT YET"
            color: Tokens.slot1
        }
    }
}
