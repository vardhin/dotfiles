pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Synced lyrics for whatever Media follows: a .lrc beside a local file, else
// LRCLIB (lrclib.net, no key), matched the way MeowMuzic does it
// (~/Documents/git/meowmuzic, lib/src/data/lyrics_service.dart): the title
// and artist are tried as several identities (as given; a video title cleaned
// of "(Official Video)", "Lyrics" and the like; "Artist - Title" split; what
// comes before "| credits"; the artist without "- Topic" or "VEVO"), each
// asked by field and as free text; every result is scored on title and
// artist similarity, duration and being synced, and the best one wins if it
// scores 75 or more. Requests carry a User-Agent naming Dot Shell, as LRCLIB
// asks. Results are cached as .lrc under ~/.cache/dot/lyrics/ (a miss as
// .miss, retried after a day), and the current line follows Media's position
// on a smooth clock.
//
//   lines    [{ t: seconds (-1 when unsynced), text }]
//   index    the line playing now (-1 before the first)
//   line, next  the current and the following line's text
Singleton {
    id: root

    readonly property string dir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/dot/lyrics"
    readonly property string agent: "Dot Shell (Quickshell desktop shell; lyrics panel)"

    property var lines: []
    property bool synced: false
    property string status: ""      // "", looking, found, none
    property string forKey: ""

    readonly property bool has: lines.length > 0

    // A smooth clock: MPRIS only tells the position when asked (twice a
    // second, Media.qml), so between samples it runs on from the last one.
    // Lines change on the beat instead of up to half a second late.
    property real clock: 0
    property real anchorPos: 0
    property real anchorAt: 0
    Connections {
        target: Media
        function onPositionChanged() {
            root.anchorPos = Media.position;
            root.anchorAt = Date.now();
            // A seek, or the clock ran off: jump; else let it run.
            if (!Media.isPlaying || Math.abs(root.clock - Media.position) > 0.35)
                root.clock = Media.position;
        }
    }
    Timer {
        running: root.has && root.synced && Media.isPlaying
        interval: 40
        repeat: true
        onTriggered: root.clock = root.anchorPos + (Date.now() - root.anchorAt) / 1000
    }

    readonly property int index: {
        if (!synced)
            return -1;
        const t = clock + 0.15;
        let i = -1;
        for (let k = 0; k < lines.length; k++) {
            if (lines[k].t <= t)
                i = k;
            else
                break;
        }
        return i;
    }
    readonly property string line: index >= 0 ? lines[index].text : ""
    readonly property string next: index + 1 < lines.length ? lines[index + 1].text : ""
    // How far through the current line, 0 .. 1 (to the next line's start,
    // or 4 s for the last): what a karaoke wipe lights.
    readonly property real lineProgress: {
        if (index < 0)
            return 0;
        const a = lines[index].t, b = index + 1 < lines.length ? lines[index + 1].t : a + 4;
        return Math.max(0, Math.min(1, (clock + 0.15 - a) / Math.max(0.3, b - a)));
    }

    readonly property string key: {
        if (!Media.active || !Media.title)
            return "";
        return (Media.artist + " - " + Media.title).toLowerCase().replace(/[^a-z0-9 ._-]+/g, "").replace(/\s+/g, " ").trim().slice(0, 120);
    }
    onKeyChanged: lookTimer.restart()

    // Wait for MPRIS metadata to settle (title, then artist, then length).
    Timer {
        id: lookTimer
        interval: 900
        onTriggered: root.look()
    }

    function look(): void {
        if (key === forKey)
            return;
        forKey = key;
        lines = [];
        synced = false;
        if (!key) {
            status = "";
            return;
        }
        status = "looking";
        cache.path = "";
        cache.path = dir + "/" + key + ".lrc";
    }

    function parse(text: string): void {
        const out = [];
        let timed = false;
        for (const raw of text.split("\n")) {
            const m = raw.match(/^\s*\[(\d+):(\d+(?:\.\d+)?)\](.*)$/);
            if (m) {
                timed = true;
                out.push({ t: parseInt(m[1]) * 60 + parseFloat(m[2]), text: m[3].trim() });
            } else if (raw.trim() !== "" && !/^\s*\[[a-z]+:/.test(raw)) {
                out.push({ t: -1, text: raw.trim() });
            }
        }
        synced = timed;
        lines = timed ? out.filter(l => l.t >= 0) : out;
        status = lines.length ? "found" : "none";
    }

    FileView {
        id: cache
        printErrors: false
        onLoaded: root.parse(text())
        onLoadFailed: {
            if (!path)
                return;
            miss.path = "";
            miss.path = root.dir + "/" + root.key + ".miss";
        }
    }

    // A cached miss younger than a day: do not ask again. (.none files are
    // misses from the old exact-match lookup: ignored, asked again.)
    FileView {
        id: miss
        printErrors: false
        onLoaded: {
            const when = Number(text().trim()) || 0;
            if (Date.now() - when < 86400000)
                root.status = "none";
            else
                root.fetch();
        }
        onLoadFailed: if (path) root.fetch()
    }

    // ── Matching (MeowMuzic's LrclibClient) ─────────────────────────
    // Lower case; every run of punctuation, symbols and spaces one space.
    // Letters of any script stay (Telugu, Tamil titles), emoji go.
    function norm(v: string): string {
        return String(v ?? "").toLowerCase().replace(/[\s!-\/:-@\[-`{-~ -¿ -⁯⸀-⹿　-〿︐-︟︰-﹏\ud800-\udfff]+/g, " ").trim();
    }
    function beforeCredits(v: string): string {
        return v.split(/\s*[|｜]\s*/)[0].replace(/\s+/g, " ").trim();
    }
    function cleanTitle(v: string): string {
        return v.replace(/\s*[\[(][^\])]*(?:official|music\s*video|lyrics?|audio|visuali[sz]er|mv|hd|4k)[^\])]*[\])]/gi, "")
            .replace(/\b(?:official\s*)?(?:music\s*)?(?:video|audio|lyrics?|visuali[sz]er)\b/gi, " ")
            .replace(/\s+/g, " ")
            // What the words left behind: "Song - | credits", "Song -".
            .replace(/\s*[-–—]\s*(?=[|｜])/g, " ").replace(/\s*[-–—]\s*$/, "").trim();
    }
    function cleanArtist(v: string): string {
        const n = norm(v);
        if (n === "unknown artist" || n === "youtube")
            return "";
        return v.replace(/\s*-\s*topic\s*$/i, "").replace(/\s*vevo\s*$/i, "").trim();
    }
    function identities(title: string, artist: string): var {
        const out = [], keys = {};
        const add = (t, a) => {
            t = String(t ?? "").trim();
            a = String(a ?? "").trim();
            const k = norm(t) + "|" + norm(a);
            if (t && !keys[k]) {
                keys[k] = true;
                out.push({ title: t, artist: a });
            }
        };
        add(title, artist);
        const ct = cleanTitle(title), ca = cleanArtist(artist);
        const split = ct.split(/\s+(?:-|–|—)\s+/);
        if (split.length >= 2)
            add(beforeCredits(split.slice(1).join(" - ")), split[0]);
        add(beforeCredits(ct), ca);
        add(ct, ca);
        return out;
    }
    function similarity(a: string, b: string): real {
        if (!a || !b)
            return 0;
        if (a === b)
            return 1;
        if (a.includes(b) || b.includes(a))
            return 0.78 + 0.22 * Math.min(a.length, b.length) / Math.max(a.length, b.length);
        const ta = new Set(a.split(" ")), tb = new Set(b.split(" "));
        let shared = 0;
        for (const t of ta)
            if (tb.has(t))
                shared++;
        return shared / Math.max(ta.size, tb.size);
    }
    function score(c: var, ids: var, duration: real): real {
        const ct = norm(c.trackName), ca = norm(c.artistName);
        let best = -Infinity;
        for (const id of ids) {
            const ts = similarity(ct, norm(id.title));
            if (ts < 0.35)
                continue;
            const wa = norm(id.artist);
            best = Math.max(best, ts * 110 + (wa ? similarity(ca, wa) : 0) * 45);
        }
        if (!isFinite(best))
            return -Infinity;
        if (typeof c.duration === "number" && duration > 0) {
            const d = Math.abs(c.duration - duration);
            best += d <= 2 ? 45 : d <= 5 ? 28 : d <= 12 ? 12 : -Math.min(50, d);
        }
        if (c.syncedLyrics && String(c.syncedLyrics).trim())
            best += 15;
        return best;
    }
    // The LRCLIB URLs to ask, best first: the exact match, each identity by
    // field, then each as free text, then the cleaned titles alone.
    function queries(ids: var): var {
        const q = (o) => Object.keys(o).filter(k => o[k] !== "").map(k => k + "=" + encodeURIComponent(o[k])).join("&");
        const out = [];
        const first = ids[0];
        if (first.artist && Media.length > 0)
            out.push("https://lrclib.net/api/get?" + q({ track_name: first.title, artist_name: first.artist, album_name: Media.album, duration: String(Math.round(Media.length)) }));
        for (const id of ids)
            out.push("https://lrclib.net/api/search?" + q({ track_name: id.title, artist_name: id.artist }));
        for (const id of ids)
            out.push("https://lrclib.net/api/search?" + q({ q: [id.artist, id.title].filter(s => !!s).join(" ") }));
        // Last, the title alone: a video's "artist" is often just the channel
        // that posted it (Sun Pictures, not Anirudh), which no record has.
        for (const id of ids.slice(1))
            out.push("https://lrclib.net/api/search?" + q({ q: id.title }));
        return out.filter((u, i) => out.indexOf(u) === i).slice(0, 10);
    }
    // A .lrc beside a local file (song.mp3: song.lrc).
    function localLrc(): string {
        const u = Media.url;
        if (!u.startsWith("file://"))
            return "";
        const path = decodeURIComponent(u.slice(7));
        return path.replace(/\.[^\/.]+$/, "") + ".lrc";
    }

    function fetch(): void {
        if (!Media.title)
            return;
        const ids = identities(Media.title, Media.artist);
        const script = [
            "mkdir -p \"$DIR\"",
            "if [ -n \"$L\" ] && [ -s \"$L\" ]; then printf 'LOCAL\\n'; cat \"$L\"; exit 0; fi",
            "printf '%s\\n' \"$Q\" | while IFS= read -r u; do",
            "  [ -n \"$u\" ] || continue",
            "  r=$(curl -sf --max-time 8 -A \"$UA\" -H 'Accept: application/json' \"$u\") || r='[]'",
            "  printf '%s' \"$r\" | jq -c 'if type == \"array\" then . elif type == \"object\" then [.] else [] end' 2>/dev/null || echo '[]'",
            "done"
        ].join("\n");
        fetcher.environment = {
            DIR: root.dir,
            UA: root.agent,
            L: localLrc(),
            Q: queries(ids).join("\n")
        };
        fetcher.forKey = root.key;
        fetcher.ids = ids;
        fetcher.duration = Media.length;
        fetcher.command = ["sh", "-c", script];
        fetcher.running = true;
    }

    // The best candidate's lyrics (synced first), or "" when none scores 75.
    function pick(out: string, ids: var, duration: real): string {
        if (out.startsWith("LOCAL\n"))
            return out.slice(6).trim();
        let best = null, bestScore = -Infinity;
        for (const line of out.split("\n")) {
            let list = [];
            try {
                list = JSON.parse(line);
            } catch (e) {
                continue;
            }
            for (const c of list) {
                if (!c || !(String(c.syncedLyrics ?? "").trim() || String(c.plainLyrics ?? "").trim()))
                    continue;
                const sc = score(c, ids, duration);
                if (sc > bestScore) {
                    bestScore = sc;
                    best = c;
                }
            }
        }
        if (!best || bestScore < 75)
            return "";
        return String(best.syncedLyrics ?? "").trim() || String(best.plainLyrics ?? "").trim();
    }

    Process {
        id: fetcher
        property string forKey: ""
        property var ids: []
        property real duration: 0
        stdout: StdioCollector {
            onStreamFinished: {
                if (fetcher.forKey !== root.key)
                    return;
                const t = root.pick(text, fetcher.ids, fetcher.duration);
                if (t) {
                    store.path = root.dir + "/" + fetcher.forKey + ".lrc";
                    store.setText(t + "\n");
                    root.parse(t);
                } else {
                    store.path = root.dir + "/" + fetcher.forKey + ".miss";
                    store.setText(String(Date.now()));
                    root.status = "none";
                }
            }
        }
    }

    FileView {
        id: store
        printErrors: false
    }
}
