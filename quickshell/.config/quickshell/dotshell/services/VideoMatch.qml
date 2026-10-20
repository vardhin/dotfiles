pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// A music video for the track Media follows, for expanded Now playing.
//   Dot TV songs (ytmusic cache) carry their YouTube id: that one, unless it
//   is an art track (a "<artist> - Topic" channel, one still picture); then
//   a search like any other local file, skipping it.
//   Other local files: yt-dlp "ytsearch5:<artist> <title> official video",
//   keeping the first result whose duration is within 3 s of the track.
// Matches live in ~/.cache/dot/videos.json ({ key: { id, bad: [ids] } }); a
// wrong one is marked bad from the panel and the next candidate is tried.
// The stream URL (yt-dlp -g, 360p) is fetched on demand and kept 4 hours.
// Only looked up while something on screen wants a video: want(key, on).
Singleton {
    id: root

    readonly property string file: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/dot/videos.json"

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

    // Local files only: a stream from a browser has its own picture.
    readonly property bool local: Media.url.startsWith("file://") && /\.(mp3|flac|ogg|opus|m4a|wav)$/i.test(Media.url)
    readonly property string key: local && Media.title ? (Media.artist + " - " + Media.title).toLowerCase().replace(/\s+/g, " ").trim() : ""
    readonly property var entry: key ? (store.matches[key] ?? null) : null
    readonly property string id: entry?.id ?? ""
    property string url: ""
    property string urlFor: ""
    property bool searching: false

    onIdChanged: {
        url = "";
        refresh();
    }
    onWantedChanged: refresh()
    onKeyChanged: refresh()

    function refresh(): void {
        if (!wanted)
            return;
        if (id) {
            resolve();
            return;
        }
        if (!key || entry || search.running || probe.running)
            return;
        if (Media.isAudio)
            own(Media.tvId);
        else
            find([]);
    }

    // A song's own id: its video, unless the channel is an art track's.
    function own(vid: string): void {
        searching = true;
        probe.forKey = key;
        probe.vid = vid;
        probe.command = ["yt-dlp", "--skip-download", "--no-warnings", "--print", "%(channel)s", "https://www.youtube.com/watch?v=" + vid];
        probe.running = true;
    }

    Process {
        id: probe
        property string forKey: ""
        property string vid: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const channel = text.trim();
                root.searching = false;
                // Offline or gone: try again with the next track.
                if (!channel)
                    return;
                // The track moved on meanwhile: look up the new one.
                if (probe.forKey !== root.key) {
                    root.refresh();
                    return;
                }
                if (/ - Topic$/.test(channel)) {
                    root.find([probe.vid]);
                    return;
                }
                const m = Object.assign({}, store.matches);
                m[probe.forKey] = { id: probe.vid, bad: [], at: Date.now() };
                store.matches = m;
            }
        }
    }

    function find(bad: var): void {
        searching = true;
        search.forKey = key;
        search.bad = bad;
        search.length = Media.length;
        search.command = ["yt-dlp", "--flat-playlist", "--dump-json", "--no-warnings", "ytsearch5:" + Media.artist + " " + Media.title + " official video"];
        search.running = true;
    }

    Process {
        id: search
        property string forKey: ""
        property var bad: []
        property real length: 0
        stdout: StdioCollector {
            onStreamFinished: {
                root.searching = false;
                let pick = "";
                for (const line of text.split("\n")) {
                    try {
                        const j = JSON.parse(line);
                        if (search.bad.includes(j.id))
                            continue;
                        if (search.length > 0 && Math.abs((j.duration ?? 0) - search.length) > 3)
                            continue;
                        pick = j.id;
                        break;
                    } catch (e) {}
                }
                const m = Object.assign({}, store.matches);
                m[search.forKey] = { id: pick, bad: search.bad, at: Date.now() };
                store.matches = m;
                root.refresh();
            }
        }
    }

    // The match is wrong: remember it, try the next one.
    function markBad(): void {
        if (!key || !entry?.id)
            return;
        const bad = [...(entry.bad ?? []), entry.id];
        const m = Object.assign({}, store.matches);
        m[key] = { id: "", bad: bad, at: Date.now() };
        store.matches = m;
        url = "";
        find(bad);
    }

    function resolve(): void {
        if (!id || (urlFor === id && url) || resolver.running)
            return;
        const cached = store.urls[id];
        if (cached && Date.now() - cached.at < 4 * 3600000) {
            url = cached.url;
            urlFor = id;
            return;
        }
        resolver.forId = id;
        resolver.command = ["yt-dlp", "-g", "--no-warnings", "-f", "bv*[height<=360][vcodec^=avc1]/bv*[height<=480][vcodec^=avc1]/bv*[height<=480][vcodec!^=av01]/b[height<=480]", "https://www.youtube.com/watch?v=" + id];
        resolver.running = true;
    }

    Process {
        id: resolver
        property string forId: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const u = text.trim().split("\n")[0] ?? "";
                if (!u)
                    return;
                const all = Object.assign({}, store.urls);
                all[resolver.forId] = { url: u, at: Date.now() };
                store.urls = all;
                if (resolver.forId === root.id) {
                    root.url = u;
                    root.urlFor = resolver.forId;
                } else {
                    // The track moved on meanwhile.
                    root.refresh();
                }
            }
        }
    }

    FileView {
        path: root.file
        printErrors: false
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                mkdir.running = true;
            }
        }
        JsonAdapter {
            id: store
            property var matches: ({})
            property var urls: ({})
        }
    }
    Process {
        id: mkdir
        command: ["mkdir", "-p", root.file.replace(/\/[^/]*$/, "")]
    }
}
