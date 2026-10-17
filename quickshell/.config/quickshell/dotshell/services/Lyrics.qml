pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Synced lyrics for whatever Media follows, from LRCLIB (lrclib.net, no key).
//   GET /api/get?track_name&artist_name&album_name&duration   exact match
//   GET /api/search?q=<artist> <title>                         fallback
// Requests carry a User-Agent naming Dot Shell, as LRCLIB asks. Results are
// cached as .lrc under ~/.cache/dot/lyrics/ (a miss as .none, retried after a
// day), and the current line follows the MPRIS position.
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
    readonly property int index: {
        if (!synced)
            return -1;
        const t = Media.position + 0.3;
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
            miss.path = root.dir + "/" + root.key + ".none";
        }
    }

    // A cached miss younger than a day: do not ask again.
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

    function fetch(): void {
        if (!Media.title)
            return;
        const q = [
            "mkdir -p \"$DIR\"",
            "get() { curl -sfG --max-time 8 -A \"$UA\" \"$@\"; }",
            "r=$(get https://lrclib.net/api/get --data-urlencode \"track_name=$T\" --data-urlencode \"artist_name=$A\" --data-urlencode \"album_name=$B\" --data-urlencode \"duration=$D\")",
            "[ -z \"$r\" ] && r=$(get https://lrclib.net/api/search --data-urlencode \"q=$A $T\" | jq -c '[.[] | select(.syncedLyrics != null)][0] // .[0] // empty')",
            "printf '%s' \"$r\" | jq -r '.syncedLyrics // .plainLyrics // empty'"
        ].join("\n");
        fetcher.environment = {
            DIR: root.dir,
            UA: root.agent,
            T: Media.title,
            A: Media.artist,
            B: Media.album,
            D: String(Math.round(Media.length))
        };
        fetcher.forKey = root.key;
        fetcher.command = ["sh", "-c", q];
        fetcher.running = true;
    }

    Process {
        id: fetcher
        property string forKey: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (fetcher.forKey !== root.key)
                    return;
                const t = text.trim();
                if (t) {
                    store.path = root.dir + "/" + fetcher.forKey + ".lrc";
                    store.setText(t + "\n");
                    root.parse(t);
                } else {
                    store.path = root.dir + "/" + fetcher.forKey + ".none";
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
