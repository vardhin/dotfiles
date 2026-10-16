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
//   library   [{id, title, channel, duration, plays, added, quality, path, thumb}]
//             most played first; reread when the library's JSON files change
//   lists     playlists.json as is: [{id, name, itemIds, coverVideoId}]
//   status    {running, mix, led, current, queue}, polled while `watching`
//   results   the last YouTube search, [{id, title, channel, duration, saved}]
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
    property var status: ({ running: false, mix: false, led: false, current: null, queue: [] })
    property var results: []
    property bool searching: false
    property string searched: ""
    // Set while a pane shows the queue: status is polled only then.
    property bool watching: false

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
        running: root.watching
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
