pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Dot TV for the shell: the library, playlists, YouTube search and the
// player's queue, all through the `dottv` CLI (mpv/.local/bin/dottv), which
// owns the files in ~/Video/TV and drives mpv. The shell only shows and asks;
// playback keeps going when the shell reloads.
//
//   library   [{id, title, channel, duration, plays, added, quality, audio,
//             path, thumb}] most played first; reread when the library's JSON
//             files change. `audio`: a song from YouTube Music (the
//             ytmusic-helper sync, linked at ~/Music/ytmusic), an mp3
//   lists     playlists.json as is: [{id, name, itemIds, coverVideoId}]
//   stations  the YouTube Music stations, read-only lists of songs that
//             `dottv sync` rewrites: [{id, name, itemIds, station: true}]
//   status    {running, mix, led, current, queue, sync: {available, running,
//             line}}, polled while `watching` or a sync runs
//   results   the last YouTube search, [{id, title, channel, duration, saved}]
//   screen    how the video is drawn as dots, in the MEDIA pane and in the Dot TV
//             window alike (persisted in ${XDG_STATE_HOME}/dotshell/tv.json):
//               pitch    px per dot: 2 3 4 6 8 12 16
//               dotSize  % of the pitch, 40 .. 100
//               shape    era | round | square | bubble
//               color    era (the era's four levels) | mono (one tube, every
//                        level) | 8 (RGB332) | 16 (RGB565) | 24 (full color) |
//                        raw (no dots: the plain video)
//               glow     0 .. 100;  dither  ordered dither on or off
Singleton {
    id: root

    readonly property string dir: (Quickshell.env("DOTTV_DIR") || Quickshell.env("HOME") + "/Video/TV").replace(/\/$/, "")

    property var library: []
    readonly property var byId: {
        const m = {};
        for (const e of library)
            m[e.id] = e;
        return m;
    }
    property var lists: []
    property var stations: []
    property var status: ({ running: false, mix: false, led: false, current: null, queue: [], sync: { available: false, running: false, line: "" } })
    readonly property bool syncing: status.sync?.running ?? false
    // A sync that ends leaves new songs and titles: read the library again.
    onSyncingChanged: {
        if (!syncing)
            reload();
    }
    property var results: []
    property bool searching: false
    property string searched: ""
    // Set while a pane shows the queue: status is polled only then.
    property bool watching: false
    // Set while a Dot TV panel is on screen (Feeds.want): polled then too.
    property bool panels: false

    // ── Screen settings ─────────────────────────────────────────────
    readonly property var screen: ({
            pitch: [2, 3, 4, 6, 8, 12, 16].includes(screenStore.pitch) ? screenStore.pitch : 6,
            dotSize: Math.max(40, Math.min(100, screenStore.dotSize)),
            shape: ["era", "round", "square", "bubble"].includes(screenStore.shape) ? screenStore.shape : "era",
            color: ["era", "mono", "8", "16", "24", "raw"].includes(screenStore.color) ? screenStore.color : "era",
            glow: Math.max(0, Math.min(100, screenStore.glow)),
            dither: screenStore.dither
        })
    readonly property var screenOptions: [
        { key: "pitch", label: "PITCH", options: [[2, "2"], [3, "3"], [4, "4"], [6, "6"], [8, "8"], [12, "12"], [16, "16"]] },
        { key: "dotSize", label: "DOT SIZE", options: [[50, "50"], [60, "60"], [70, "70"], [80, "80"], [90, "90"], [100, "100"]] },
        { key: "shape", label: "SHAPE", options: [["era", "ERA"], ["round", "ROUND"], ["square", "SQUARE"], ["bubble", "BUBBLE"]] },
        { key: "color", label: "COLOR", options: [["era", "ERA"], ["mono", "MONO"], ["8", "8 BIT"], ["16", "16 BIT"], ["24", "FULL"], ["raw", "RAW"]] },
        { key: "glow", label: "GLOW", options: [[0, "0"], [25, "25"], [50, "50"], [75, "75"], [100, "100"]] },
        { key: "dither", label: "DITHER", options: [[true, "ON"], [false, "OFF"]] }
    ]
    function setScreen(key: string, value: var): void {
        screenStore[key] = value;
    }
    function nudgeScreen(key: string, dir: int): void {
        const o = screenOptions.find(x => x.key === key);
        const i = o.options.findIndex(x => x[0] === screen[key]);
        setScreen(key, o.options[(Math.max(0, i) + dir + o.options.length) % o.options.length][0]);
    }

    FileView {
        path: Tokens.dirReady ? Tokens.dir + "/tv.json" : ""
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: screenStore
            property int pitch: 6
            property int dotSize: 80
            property string shape: "era"
            property string color: "era"
            property int glow: 50
            property bool dither: true
        }
    }

    // ── Reading ─────────────────────────────────────────────────────
    function reload(): void {
        if (libProc.running)
            libPending = true;
        else
            libProc.running = true;
    }
    property bool libPending: false

    Process {
        id: libProc
        command: ["dottv", "lib", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.library = JSON.parse(text);
                } catch (e) {
                    console.warn("dotshell: dottv lib gave no JSON");
                }
            }
        }
        onExited: code => {
            if (code !== 0 && code !== null)
                console.warn("dotshell: `dottv lib` failed (" + code + "); is the mpv module stowed?");
            if (root.libPending) {
                root.libPending = false;
                running = true;
            }
        }
    }

    // Titles land in video-meta.json when a download finishes; play counts
    // move on every track. Either way, the library is read again.
    FileView {
        path: root.dir + "/video-meta.json"
        watchChanges: true
        onFileChanged: reloadTimer.restart()
    }
    FileView {
        path: root.dir + "/play-counts.json"
        watchChanges: true
        onFileChanged: reloadTimer.restart()
    }
    FileView {
        id: listsFile
        path: root.dir + "/playlists.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const l = JSON.parse(text());
                root.lists = Array.isArray(l) ? l : [];
            } catch (e) {
                root.lists = [];
            }
        }
    }
    FileView {
        path: root.dir + "/stations.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const l = JSON.parse(text());
                root.stations = Array.isArray(l) ? l : [];
            } catch (e) {
                root.stations = [];
            }
        }
        onLoadFailed: root.stations = []
    }
    Timer {
        id: reloadTimer
        interval: 400
        onTriggered: root.reload()
    }
    Component.onCompleted: reload()

    function poll(): void {
        if (!statusProc.running)
            statusProc.running = true;
    }

    Process {
        id: statusProc
        command: ["dottv", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.status = JSON.parse(text);
                } catch (e) {}
            }
        }
    }
    Timer {
        running: root.watching || root.panels || root.syncing
        triggeredOnStart: true
        interval: 1500
        repeat: true
        onTriggered: root.poll()
    }

    // ── Search ──────────────────────────────────────────────────────
    function search(q: string): void {
        q = q.trim();
        if (!q)
            return;
        searched = q;
        searching = true;
        searchProc.command = ["dottv", "search", "-n", "12", "--json", q];
        searchProc.running = false;
        searchProc.running = true;
    }
    function clearSearch(): void {
        results = [];
        searched = "";
    }

    Process {
        id: searchProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.results = JSON.parse(text);
                } catch (e) {
                    root.results = [];
                }
            }
        }
        onExited: root.searching = false
    }

    // ── Doing ───────────────────────────────────────────────────────
    // Fire and forget; the queue is polled again a moment later.
    function run(args: var): void {
        Quickshell.execDetached(["dottv"].concat(args));
        after.restart();
    }
    Timer {
        id: after
        interval: 600
        onTriggered: root.poll()
    }

    // how: "" play now, "queue" after everything, "next" after this one
    function play(id: string, how: string): void {
        run(how ? ["play", id, "--" + how] : ["play", id]);
    }
    function save(id: string): void {
        run(["get", id]);
    }
    function remove(id: string): void {
        run(["rm", id]);
    }
    function mix(on: bool): void {
        status = Object.assign({}, status, { mix: on });
        run(["mix", on ? "on" : "off"]);
    }
    function led(): void {
        status = Object.assign({}, status, { led: !status.led });
        run(["led", "toggle"]);
    }
    function open(): void {
        run(["open"]);
    }
    function clear(): void {
        run(["clear"]);
    }
    // Fetch new songs and stations from YouTube Music, in the background.
    function sync(): void {
        if (syncing || !(status.sync?.available ?? false))
            return;
        status = Object.assign({}, status, { sync: { available: true, running: true, line: "STARTING" } });
        run(["sync"]);
    }
    // name: a list's name or id (stations go by id: "station:<dir>")
    function listPlay(name: string, shuffle: bool): void {
        run(shuffle ? ["list", "play", name, "--shuffle"] : ["list", "play", name]);
    }
    function listToggle(name: string, id: string): void {
        run(["list", "toggle", name, id]);
    }
    function listNew(name: string): void {
        run(["list", "new", name]);
    }
    function listDrop(name: string): void {
        run(["list", "drop", name]);
    }
    function inList(name: string, id: string): bool {
        const l = lists.find(p => p.name === name);
        return !!l && (l.itemIds ?? []).includes(id);
    }
}
