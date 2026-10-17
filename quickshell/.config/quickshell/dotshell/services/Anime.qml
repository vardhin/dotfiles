pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Anime for the shell, through the `dotanime` CLI (quickshell/.local/bin),
// which asks AniList for covers, trending shows and categories, and ani-cli
// for the episodes: it plays, downloads and keeps the lists. The shell only
// shows and asks; playback and downloads go on when the shell reloads.
//
//   featured   trending now: [{id, title, alt, cover, episodes, aired,
//              format, year, score, status, genres}]
//   genres     the categories; `genre` the one picked, `genreItems` its shows
//   results    the last search (`searched`)
//   liked, watch, downloads   the lists (downloads add saved: [episodes] and
//              pending: [episodes queued or downloading])
//   progress   {id: {ep, done, pos}}: where each show was left off
//   playing    {id, ep, title, cover, local, phase} while an episode loads
//              (phase "finding": ani-cli looks for the stream) or plays
//   jobs       {current: {aid, ep, title, pct}, queue, failed: [{.., why}]}
//   show       the show open on the page (its meta, then `info` with the
//              synopsis and `source`: ani-cli's match and episodes)
//   folds      {section: true|false}, the sections folded by hand
//              (${XDG_STATE_HOME}/dotshell/anime-ui.json); an empty section
//              is folded anyway
Singleton {
    id: root

    property var featured: []
    property bool featuring: false
    property var genres: []
    property string genre: ""
    property var genreItems: []
    property bool genreLoading: false
    property var results: []
    property bool searching: false
    property string searched: ""
    property string offline: ""

    property var st: ({ mode: "sub", liked: [], watch: [], downloads: [], progress: {}, prefetch: [], playing: null, error: "", jobs: { current: null, queue: [], failed: [] } })
    readonly property var liked: st.liked
    readonly property var watch: st.watch
    readonly property var downloads: st.downloads
    readonly property var progress: st.progress
    readonly property var playing: st.playing
    readonly property var jobs: st.jobs
    readonly property string mode: st.mode
    readonly property bool busy: jobs.current !== null || jobs.queue.length > 0

    property var show: null
    property var info: null
    property var source: null
    property bool finding: false
    property string notFound: ""

    function isLiked(id: int): bool {
        return liked.some(x => x.id === id);
    }
    function inWatch(id: int): bool {
        return watch.some(x => x.id === id);
    }
    function prefetching(id: int): bool {
        return st.prefetch.includes(id);
    }
    function saved(id: int): var {
        return downloads.find(x => x.id === id)?.saved ?? [];
    }
    function pending(id: int): var {
        return downloads.find(x => x.id === id)?.pending ?? [];
    }
    function failed(id: int): var {
        return jobs.failed.filter(f => f.aid === id);
    }
    // The episode to play next: the one left off, or the one after it.
    function resume(id: int, eps: var): string {
        const p = progress[id];
        if (!p)
            return eps[0] ?? "1";
        if (!p.done)
            return p.ep;
        const i = eps.indexOf(p.ep);
        return i >= 0 && i + 1 < eps.length ? eps[i + 1] : p.ep;
    }
    // What went wrong, in words, and what to try: [text, fixes] where fixes
    // are "mode" (the other of sub/dub), "source" (ani-cli's next match),
    // "retry".
    function explain(why: string, ep: string): var {
        const w = String(why ?? "");
        const e = ep ? "EP " + ep + ": " : "";
        if (/no sources found for (sub|dub)/i.test(w))
            return [e + "NO " + w.match(/for (sub|dub)/i)[1].toUpperCase() + " VERSION ON THIS SOURCE", ["mode", "source", "retry"]];
        if (/not released/i.test(w))
            return [e + "NOT OUT YET", ["retry"]];
        if (/invalid episode/i.test(w))
            return [e + "THIS MATCH HAS NO SUCH EPISODE", ["source", "retry"]];
        if (/cloudflare/i.test(w))
            return [e + "THE SOURCE BLOCKED US (CLOUDFLARE)", ["retry"]];
        if (/connection|could not fetch|timed out|took too long/i.test(w))
            return [e + "COULD NOT REACH THE SOURCE", ["retry"]];
        if (/not found on ani-cli/i.test(w))
            return [e + "NOT FOUND ON THE SOURCE", ["source", "retry"]];
        return [e + w.toUpperCase(), ["retry", "source"]];
    }
    function watched(id: int, ep: string): bool {
        const p = progress[id];
        if (!p)
            return false;
        return Number(ep) < Number(p.ep) || ep === p.ep && p.done;
    }

    // ── Folds ───────────────────────────────────────────────────────
    readonly property var folds: ui.folds
    function fold(key: string, folded: bool): void {
        const f = Object.assign({}, ui.folds);
        f[key] = folded;
        ui.folds = f;
    }

    FileView {
        path: Tokens.dirReady ? Tokens.dir + "/anime-ui.json" : ""
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: ui
            property var folds: ({})
        }
    }

    // ── Reading ─────────────────────────────────────────────────────
    // Featured, the categories and the lists, once, when the page first shows.
    property bool awake: false
    function wake(): void {
        reread();
        if (awake)
            return;
        awake = true;
        featuring = true;
        featuredProc.running = true;
        genresProc.running = true;
    }
    function refresh(): void {
        featuring = true;
        featuredProc.command = ["dotanime", "featured", "--fresh"];
        featuredProc.running = true;
    }

    function parse(text: string, fallback: var): var {
        try {
            return JSON.parse(text);
        } catch (e) {
            return fallback;
        }
    }

    Process {
        id: featuredProc
        command: ["dotanime", "featured"]
        stdout: StdioCollector {
            onStreamFinished: root.featured = root.parse(text, root.featured)
        }
        stderr: StdioCollector {
            onStreamFinished: root.offline = text.trim().replace(/^dotanime: /, "")
        }
        onExited: root.featuring = false
    }
    Process {
        id: genresProc
        command: ["dotanime", "genres"]
        stdout: StdioCollector {
            onStreamFinished: root.genres = root.parse(text, [])
        }
    }

    function reread(): void {
        if (stateProc.running)
            statePending = true;
        else
            stateProc.running = true;
    }
    property bool statePending: false

    Process {
        id: stateProc
        command: ["dotanime", "state"]
        stdout: StdioCollector {
            onStreamFinished: root.st = root.parse(text, root.st)
        }
        onExited: code => {
            if (code !== 0 && code !== null)
                console.warn("dotshell: `dotanime state` failed (" + code + "); is quickshell/.local/bin stowed?");
            if (root.statePending) {
                root.statePending = false;
                running = true;
            }
        }
    }

    // dotanime rewrites these on every change: a download's progress, a
    // player starting or stopping, a list.
    FileView {
        path: Tokens.dirReady ? Tokens.dir + "/anime.json" : ""
        watchChanges: true
        printErrors: false
        onFileChanged: stateTimer.restart()
    }
    FileView {
        path: Tokens.dirReady ? Tokens.dir + "/anime-jobs.json" : ""
        watchChanges: true
        printErrors: false
        onFileChanged: stateTimer.restart()
    }
    Timer {
        id: stateTimer
        interval: 250
        onTriggered: root.reread()
    }
    // A file that did not exist when the shell started is not watched: read
    // again while anything moves.
    Timer {
        running: root.awake && (root.busy || root.playing !== null)
        interval: 2000
        repeat: true
        onTriggered: root.reread()
    }

    // ── Search and categories ───────────────────────────────────────
    function search(q: string): void {
        q = q.trim();
        if (!q)
            return clearSearch();
        searched = q;
        searching = true;
        results = [];
        searchProc.command = ["dotanime", "search", q];
        searchProc.running = false;
        searchProc.running = true;
    }
    function clearSearch(): void {
        searchProc.running = false;
        results = [];
        searched = "";
        searching = false;
    }
    Process {
        id: searchProc
        stdout: StdioCollector {
            onStreamFinished: root.results = root.parse(text, [])
        }
        onExited: root.searching = false
    }

    // The same category again puts it away.
    function pickGenre(g: string): void {
        genreProc.running = false;
        if (g === genre) {
            genre = "";
            genreItems = [];
            genreLoading = false;
            return;
        }
        genre = g;
        genreItems = [];
        genreLoading = true;
        genreProc.command = ["dotanime", "genre", g];
        genreProc.running = true;
    }
    Process {
        id: genreProc
        stdout: StdioCollector {
            onStreamFinished: root.genreItems = root.parse(text, [])
        }
        onExited: root.genreLoading = false
    }

    // ── One show ────────────────────────────────────────────────────
    function open(m: var): void {
        show = m;
        info = null;
        source = null;
        notFound = "";
        infoProc.running = false;
        infoProc.command = ["dotanime", "info", String(m.id)];
        infoProc.running = true;
        findEpisodes(["episodes", String(m.id)]);
    }
    function close(): void {
        show = null;
        info = null;
        source = null;
        infoProc.running = false;
        epProc.running = false;
        finding = false;
    }
    // Episodes again (--fresh), or from ani-cli's nth candidate.
    function reloadEpisodes(): void {
        if (show)
            findEpisodes(["episodes", String(show.id), "--fresh"]);
    }
    function nextSource(): void {
        if (!show || !source || source.candidates.length < 2)
            return;
        findEpisodes(["source", String(show.id), String(source.index % source.candidates.length + 1)]);
    }
    function findEpisodes(args: var): void {
        finding = true;
        notFound = "";
        epProc.running = false;
        epProc.command = ["dotanime"].concat(args);
        epProc.running = true;
    }

    Process {
        id: infoProc
        stdout: StdioCollector {
            onStreamFinished: {
                const i = root.parse(text, null);
                if (i && root.show && i.id === root.show.id)
                    root.info = i;
            }
        }
    }
    Process {
        id: epProc
        stdout: StdioCollector {
            onStreamFinished: {
                const s = root.parse(text, null);
                if (s && root.show && s.id === root.show.id)
                    root.source = s;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: root.notFound = text.trim().replace(/^dotanime: /, "")
        }
        onExited: root.finding = false
    }

    // ── Doing ───────────────────────────────────────────────────────
    // Fire and forget; the state is read again when dotanime writes it.
    function run(args: var): void {
        Quickshell.execDetached(["dotanime"].concat(args));
        after.restart();
    }
    Timer {
        id: after
        interval: 700
        onTriggered: root.reread()
    }

    function play(m: var, ep: string): void {
        st = Object.assign({}, st, { error: "", playing: { id: m.id, ep: ep, title: m.title, cover: m.cover, local: saved(m.id).includes(ep), phase: "finding" } });
        run(["play", String(m.id), ep]);
    }
    function get(m: var, eps: var): void {
        run(["get", String(m.id)].concat(eps));
    }
    // One episode, or (ep "") every download of the show; aid 0: all of them.
    function cancel(aid: int, ep: string): void {
        run(["cancel", aid ? String(aid) : "all"].concat(ep ? [ep] : []));
    }
    function remove(m: var, ep: string): void {
        run(["rm", String(m.id), ep]);
    }
    function prefetch(m: var): void {
        const p = st.prefetch.includes(m.id) ? st.prefetch.filter(x => x !== m.id) : st.prefetch.concat([m.id]);
        st = Object.assign({}, st, { prefetch: p });
        run(["prefetch", String(m.id)]);
    }
    // Lists change here at once; dotanime's state follows.
    function like(m: var): void {
        st = Object.assign({}, st, { liked: isLiked(m.id) ? liked.filter(x => x.id !== m.id) : [m].concat(liked) });
        run(["like", String(m.id)]);
    }
    function toggleWatch(m: var): void {
        st = Object.assign({}, st, { watch: inWatch(m.id) ? watch.filter(x => x.id !== m.id) : [m].concat(watch) });
        run(["watch", String(m.id)]);
    }
    function toggleMode(): void {
        setMode(mode === "sub" ? "dub" : "sub");
    }
    function setMode(want: string): void {
        if (want === mode)
            return;
        st = Object.assign({}, st, { mode: want });
        run(["mode", want]);
        if (show)
            after2.restart();
    }
    // The match depends on the mode: read the episodes again after it lands.
    Timer {
        id: after2
        interval: 500
        onTriggered: root.reloadEpisodes()
    }
}
