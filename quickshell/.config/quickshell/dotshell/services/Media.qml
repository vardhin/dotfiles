pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs

// Now playing, for the strip, the MEDIA pane and the media / vis panels.
// Players play, the shell renders: anything on MPRIS counts (mpv with
// mpv-mpris, so Dot TV too; mpd through mpd-mpris; browsers).
//
// `player` is the one pinned in the pane (Tab on NOW), else the one playing,
// else the last that played. Dot TV tracks carry no artist or art over MPRIS;
// they are looked up in the TV library by their YouTube id.
//
// `bars` is a live spectrum from cava, 0 .. 1 per band. cava only runs while
// something on screen wants it (want(key, true)) and a player is playing.
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    property MprisPlayer pinned: null
    property MprisPlayer recent: null
    readonly property MprisPlayer playing: players.find(p => p.isPlaying) ?? null
    onPlayingChanged: {
        if (playing)
            recent = playing;
    }

    readonly property MprisPlayer player: {
        const all = players;
        if (pinned && all.includes(pinned))
            return pinned;
        return playing ?? (recent && all.includes(recent) ? recent : null) ?? all[0] ?? null;
    }

    readonly property bool active: player !== null
    readonly property bool isPlaying: player?.isPlaying ?? false

    // A Dot TV file: ~/Video/TV/<id>-<height>.mp4.
    readonly property string url: String(player?.metadata?.["xesam:url"] ?? "")
    readonly property string tvId: {
        const m = url.match(/\/([A-Za-z0-9_-]{11})-\d{3,4}\.mp4$/) ?? url.match(/[?&]v=([A-Za-z0-9_-]{11})/);
        return m ? m[1] : "";
    }
    readonly property var tvEntry: tvId ? Tv.byId[tvId] ?? null : null
    readonly property bool isTv: (player?.identity ?? "").toLowerCase().includes("mpv") && tvId !== ""

    readonly property string title: player?.trackTitle || tvEntry?.title || ""
    readonly property string artist: player?.trackArtist || tvEntry?.channel || ""
    readonly property string album: player?.trackAlbum ?? ""
    readonly property string art: {
        const a = player?.trackArtUrl ?? "";
        if (a)
            return a;
        if (tvEntry?.thumb)
            return "file://" + tvEntry.thumb;
        return tvId ? "https://i.ytimg.com/vi/" + tvId + "/hqdefault.jpg" : "";
    }
    readonly property string name: (player?.identity ?? "").toUpperCase()

    readonly property real length: player && player.lengthSupported ? player.length : 0
    readonly property real position: player && player.positionSupported ? player.position : 0
    readonly property real progress: length > 0 ? Math.max(0, Math.min(1, position / length)) : 0

    // MprisPlayer.position is not pushed: ask for it while it moves.
    Timer {
        running: root.isPlaying && root.player?.positionSupported
        interval: 500
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    function clock(s: real): string {
        if (!(s > 0))
            return "0:00";
        s = Math.floor(s);
        const h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60, sec = s % 60;
        return (h > 0 ? h + ":" + String(m).padStart(2, "0") : m) + ":" + String(sec).padStart(2, "0");
    }

    function toggle(): void {
        if (player?.canTogglePlaying)
            player.togglePlaying();
    }
    function next(): void {
        if (player?.canGoNext)
            player.next();
    }
    function previous(): void {
        if (player?.canGoPrevious)
            player.previous();
    }
    function seek(by: real): void {
        if (player?.canSeek)
            player.seek(by);
    }
    function seekTo(fraction: real): void {
        if (player?.canSeek && length > 0)
            player.position = Math.max(0, Math.min(1, fraction)) * length;
    }
    // Pin the next player (wraps back to "follow whatever plays").
    function cycle(): string {
        const all = players;
        if (all.length < 2) {
            pinned = null;
            return name;
        }
        const i = all.indexOf(player);
        pinned = all[(i + 1) % all.length];
        return name;
    }

    // ── Spectrum (cava) ─────────────────────────────────────────────
    readonly property int bands: 32
    property var bars: Array(bands).fill(0)
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

    FileView {
        id: cavaConf
        path: Tokens.dirReady ? Tokens.dir + "/cava.conf" : ""
        printErrors: false
        onPathChanged: {
            if (path)
                setText(`# dotshell: cava for Dot Shell's spectrum (services/Media.qml)
[general]
bars = ${root.bands}
framerate = 30
[input]
method = pipewire
source = auto
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 100
bar_delimiter = 59
frame_delimiter = 10
[smoothing]
noise_reduction = 70
`);
        }
    }

    Process {
        id: cava
        running: root.wanted && root.isPlaying && cavaConf.path !== ""
        command: ["cava", "-p", cavaConf.path]
        stdout: SplitParser {
            onRead: line => {
                const v = line.split(";");
                const out = new Array(root.bands);
                for (let i = 0; i < root.bands; i++)
                    out[i] = Math.min(1, (parseInt(v[i]) || 0) / 100);
                root.bars = out;
            }
        }
        onRunningChanged: {
            if (!running)
                root.bars = Array(root.bands).fill(0);
        }
    }

    IpcHandler {
        target: "media"

        function toggle(): void {
            root.toggle();
        }
        function next(): void {
            root.next();
        }
        function previous(): void {
            root.previous();
        }
        // Which player the strip, pane and panels follow.
        function cycle(): string {
            return root.cycle();
        }
        function status(): string {
            return JSON.stringify({
                player: root.name,
                playing: root.isPlaying,
                title: root.title,
                artist: root.artist,
                position: Math.round(root.position),
                length: Math.round(root.length)
            });
        }
    }
}
