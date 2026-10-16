pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs

// Animated LED borders (the `ledfx` token), for every LedRing: panes, desktop
// panels and window rings all run the same animation, each ring a little out of
// step with the others.
//
//   auto    a random animation, a new one on every window or workspace switch;
//           while music plays, the pick is from the music-reactive ones
//   random  the same, but never the music ones
//   music   always music-reactive while music plays (shuffled on switches),
//           random otherwise
//   off     still rings, as before
//
// The music comes from Media.bars (cava, asked for only while it can be used):
// `level`, `bass`, `treble`, a `beat` that flashes on bass hits, and 16 bands.
// See shaders/ledring.frag for the modes.
Singleton {
    id: root

    readonly property string setting: Tokens.ledfx
    readonly property bool on: Tokens.borders && setting !== "off"
    readonly property bool musical: on && setting !== "random" && Media.isPlaying

    readonly property var names: ["comet", "twins", "flow", "breathe", "marquee", "sparkle", "scanner", "wipe", "spectrum", "pulse", "rider", "fizz"]
    readonly property var plain: [0, 1, 2, 3, 4, 5, 6, 7]
    readonly property var music: [8, 9, 10, 11]

    // -1: still.
    property int picked: 0
    property real dir: 1
    readonly property int mode: !on ? -1 : (musical ? music : plain).includes(picked) ? picked : (musical ? music : plain)[0]
    readonly property string modeName: mode < 0 ? "still" : names[mode]

    property real time: 0
    property real phase: 0
    property real kick: 0

    property real level: 0
    property real bass: 0
    property real treble: 0
    property real beat: 0
    property var bands: [Qt.vector4d(0, 0, 0, 0), Qt.vector4d(0, 0, 0, 0), Qt.vector4d(0, 0, 0, 0), Qt.vector4d(0, 0, 0, 0)]
    property real bassAvg: 0

    function shuffle(): void {
        const pool = musical ? music : plain;
        let n = pool[Math.floor(Math.random() * pool.length)];
        if (pool.length > 1)
            while (n === picked)
                n = pool[Math.floor(Math.random() * pool.length)];
        picked = n;
        dir = Math.random() < 0.5 ? 1 : -1;
        kick = 1;
    }
    onMusicalChanged: if (on)
        shuffle()

    function pick(name: string): string {
        const i = names.indexOf(name);
        if (i < 0)
            return "one of: " + names.join(", ");
        picked = i;
        kick = 1;
        return name;
    }

    // cava, only while a music mode can show.
    readonly property bool wantsAudio: on && setting !== "random"
    onWantsAudioChanged: Media.want("ledfx", wantsAudio)
    Component.onCompleted: {
        Media.want("ledfx", wantsAudio);
        shuffle();
    }

    function listen(): void {
        const b = Media.bars, n = b.length;
        if (!n)
            return;
        const sixteen = new Array(16);
        for (let i = 0; i < 16; i++) {
            const a = Math.floor(i * n / 16), z = Math.max(a + 1, Math.floor((i + 1) * n / 16));
            let s = 0;
            for (let j = a; j < z; j++)
                s += b[j];
            sixteen[i] = s / (z - a);
        }
        bands = [0, 4, 8, 12].map(i => Qt.vector4d(sixteen[i], sixteen[i + 1], sixteen[i + 2], sixteen[i + 3]));
        const avg = (from, to) => sixteen.slice(from, to).reduce((x, y) => x + y, 0) / (to - from);
        level = avg(0, 16);
        const lo = avg(0, 3);
        treble = avg(10, 16);
        // A beat: the bass jumps well over its running average.
        if (lo > 0.25 && lo > bassAvg * 1.35 && beat < 0.3)
            beat = 1;
        bassAvg = bassAvg * 0.9 + lo * 0.1;
        bass = lo;
    }
    Connections {
        target: Media
        function onBarsChanged() {
            if (root.musical)
                root.listen();
        }
    }

    // One clock for every ring, at 30 fps while anything animates.
    Timer {
        running: root.on
        interval: 33
        repeat: true
        onTriggered: {
            const dt = interval / 1000;
            root.time += dt;
            const speed = root.musical ? 0.3 + 2.2 * root.level + root.beat : 1;
            root.phase += dt * speed * 0.6;
            root.kick = Math.max(0, root.kick - dt * 2.5);
            root.beat = Math.max(0, root.beat - dt * 4);
            if (!root.musical && root.level > 0) {
                root.level = root.bass = root.treble = 0;
                root.bands = root.bands.map(() => Qt.vector4d(0, 0, 0, 0));
            }
        }
    }

    // A window or workspace switch picks a new animation. Switching workspace
    // also moves focus, so the two events are folded into one.
    Timer {
        id: debounce
        interval: 90
        onTriggered: root.shuffle()
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (!root.on)
                return;
            switch (event.name) {
            case "activewindowv2":
            case "workspacev2":
            case "focusedmonv2":
                debounce.restart();
                break;
            }
        }
    }

    // dotshell ipc call ledfx next | mode comet | status
    IpcHandler {
        target: "ledfx"

        function next(): string {
            root.shuffle();
            return root.modeName;
        }
        function mode(name: string): string {
            return root.pick(name);
        }
        function status(): string {
            return JSON.stringify({
                setting: root.setting,
                mode: root.modeName,
                musical: root.musical,
                level: Math.round(root.level * 100) / 100
            });
        }
    }
}
