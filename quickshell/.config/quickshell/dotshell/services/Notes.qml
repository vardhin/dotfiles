pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// The notes in what plays, for the note bar: Spotify's Basic Pitch run over
// the whole file once (`dotnotes`, mpv/.local/bin; duolightbars' offline
// mode), cached under ~/.cache/dot/notes/, then played back on a smooth song
// clock with duolightbars' mapping (~/Documents/git/duolightbars,
// frontend/src/lib/lighting/mapper.ts): a note lights over 30 ms, as bright
// as it is loud (amplitude x 2), holds while it sounds and fades over `hold`
// ms after; only the `polyphony` loudest at once, only those above the
// sensitivity floor. Only local files can be read ahead (Dot TV songs and
// videos, files): for a stream (a browser) there is no file, and the note
// bar falls back to the peaks of a second cava (Media.notes).
//
//   ready     notes for this song are loaded
//   status    "" | analysing | ready | failed | stream
//   values    MIDI 48..83, 0..1 each, now
//   options   the SCREEN page's rows: polyphony, sensitivity, hold
Singleton {
    id: root

    readonly property string dir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/dot/notes"
    readonly property int low: 48
    readonly property int count: 36

    // ── Settings (notes.json in the state dir) ──────────────────────
    readonly property var options: [
        { key: "polyphony", label: "POLYPHONY", options: [[1, "1"], [2, "2"], [3, "3"], [4, "4"], [6, "6"], [8, "8"], [12, "12"]] },
        { key: "floor", label: "SENSITIVITY", options: [[50, "LOW"], [35, "MID"], [25, "HIGH"], [15, "MAX"]] },
        { key: "hold", label: "NOTE HOLD", options: [[60, "60MS"], [100, "100MS"], [160, "160MS"], [250, "250MS"], [400, "400MS"]] }
    ]
    readonly property var settings: ({
            polyphony: Math.max(1, Math.min(12, store.polyphony)),
            floor: Math.max(5, Math.min(80, store.floor)),
            hold: Math.max(30, Math.min(1000, store.hold))
        })
    function set(key: string, value: var): void {
        store[key] = value;
    }
    function nudge(key: string, dir: int): void {
        const o = options.find(x => x.key === key);
        const i = o.options.findIndex(x => x[0] === settings[key]);
        set(key, o.options[(Math.max(0, i) + dir + o.options.length) % o.options.length][0]);
    }

    FileView {
        path: Tokens.dirReady ? Tokens.dir + "/notes.json" : ""
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }
        JsonAdapter {
            id: store
            property int polyphony: 8
            property int floor: 25
            property int hold: 100
        }
    }

    // ── Who wants notes (NoteBars on screen) ────────────────────────
    property var wants: ({})
    readonly property bool wanted: Object.values(wants).some(v => v)
    function want(key: string, on: bool): void {
        if (!!wants[key] === on)
            return;
        const w = Object.assign({}, wants);
        if (on)
            w[key] = true;
        else
            delete w[key];
        wants = w;
    }

    // ── The song's notes ────────────────────────────────────────────
    readonly property string file: Media.url.startsWith("file://") ? decodeURIComponent(Media.url.slice(7)) : ""
    readonly property string cachePath: file ? dir + "/" + Qt.md5(file) + ".json" : ""
    property var events: []
    property string status: ""
    readonly property bool ready: status === "ready"
    property string loadedFor: ""

    onCachePathChanged: look()
    onWantedChanged: look()
    function look(): void {
        if (!cachePath) {
            events = [];
            loadedFor = "";
            status = Media.active ? "stream" : "";
            return;
        }
        if (!wanted || loadedFor === cachePath)
            return;
        loadedFor = cachePath;
        events = [];
        status = "";
        cache.path = "";
        cache.path = cachePath;
    }

    FileView {
        id: cache
        printErrors: false
        onLoaded: {
            try {
                root.events = JSON.parse(text()).notes ?? [];
                root.status = "ready";
            } catch (e) {
                root.analyse();
            }
        }
        onLoadFailed: if (path) root.analyse()
    }

    function analyse(): void {
        if (job.running)
            job.running = false;
        status = "analysing";
        job.forPath = cachePath;
        job.command = ["dotnotes", file, cachePath];
        job.running = true;
    }
    Process {
        id: job
        property string forPath: ""
        onExited: code => {
            if (forPath !== root.cachePath)
                return;
            if (code === 0) {
                cache.path = "";
                cache.path = root.cachePath;
            } else {
                root.status = "failed";
            }
        }
    }

    // ── Playback: a smooth clock, and the bar's values ──────────────
    property real anchorPos: 0
    property real anchorAt: 0
    Connections {
        target: Media
        function onPositionChanged() {
            root.anchorPos = Media.position;
            root.anchorAt = Date.now();
        }
    }
    property var values: Array(count).fill(0)
    Timer {
        running: root.ready && root.wanted && Media.isPlaying
        interval: 33
        repeat: true
        onTriggered: root.step(root.anchorPos + (Date.now() - root.anchorAt) / 1000)
        onRunningChanged: if (!running) root.values = Array(root.count).fill(0)
    }

    // The values at song time t: duolightbars' semantic(), on our columns.
    function step(t: real): void {
        const ev = events, n = ev.length;
        // The last note starting at or before t.
        let lo = 0, hi = n - 1, last = -1;
        while (lo <= hi) {
            const mid = (lo + hi) >> 1;
            if (ev[mid][0] <= t) {
                last = mid;
                lo = mid + 1;
            } else {
                hi = mid - 1;
            }
        }
        const s = settings, hold = s.hold / 1000, floor = s.floor / 100;
        const on = [];
        for (let i = last; i >= 0 && ev[i][0] > t - 15; i--) {
            const e = ev[i], p = e[2] - low;
            if (p < 0 || p >= count || e[3] < floor || t > e[1] + hold)
                continue;
            const attack = Math.min(1, (t - e[0]) / 0.03);
            const decay = t > e[1] ? Math.max(0, 1 - (t - e[1]) / hold) : 1;
            on.push({ p: p, v: Math.min(1, e[3] * 2) * attack * decay });
        }
        on.sort((a, b) => b.v - a.v);
        const out = Array(count).fill(0);
        for (const x of on.slice(0, s.polyphony))
            if (x.v > out[x.p])
                out[x.p] = x.v;
        values = out;
    }
}
