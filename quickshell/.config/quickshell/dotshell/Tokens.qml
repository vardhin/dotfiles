pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The one tokens file: era, pitch, dot size, color depth, wallpaper, night warmth.
// Lives outside the repo so runtime changes never dirty the dotfiles:
//   ${XDG_STATE_HOME:-~/.local/state}/dotshell/tokens.json
// Edit it by hand (picked up live) or over IPC:
//   qs -p ~/.config/quickshell/dotshell ipc call tokens set era tokyo
//   qs -p ~/.config/quickshell/dotshell ipc call tokens set pitch 5
//   qs -p ~/.config/quickshell/dotshell ipc call tokens cycleEra
Singleton {
    id: root

    // ── Persisted tokens ────────────────────────────────────────────
    readonly property string era: Eras.all[store.era] ? store.era : "phosphor"
    readonly property int pitch: [3, 5, 8, 12].includes(store.pitch) ? store.pitch : 3
    readonly property real dotSize: Math.max(40, Math.min(100, store.dotSize)) / 100
    readonly property string depth: ["era", "8", "16", "24"].includes(store.depth) ? store.depth : "era"
    // "~" is expanded; "" shows bare glass.
    readonly property string wallpaper: store.wallpaper.replace(/^~(?=\/|$)/, Quickshell.env("HOME"))
    readonly property bool night: store.night

    // ── Derived ─────────────────────────────────────────────────────
    readonly property var current: Eras.get(era)
    readonly property color slot0: current.slots[0]
    readonly property color slot1: current.slots[1]
    readonly property color slot2: current.slots[2]
    readonly property color unlit: current.unlit
    readonly property color glass: current.glass
    readonly property int depthBits: depth === "era" ? 0 : Number(depth)

    // Pixel font: 5x7 capitals on an 11 px grid. In a DotSurface 1 px = 1 dot.
    readonly property string font: "DepartureMono Nerd Font"
    readonly property int fontPx: 11
    readonly property int charDots: 7       // advance of one glyph
    readonly property int lineDots: 13      // one text line in multi-line panes

    // ── Storage ─────────────────────────────────────────────────────
    readonly property string dir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/dotshell"

    // FileView writes atomically but does not create directories.
    // Other state files (notifications, launcher counts) wait for dirReady too.
    property bool dirReady: false

    Process {
        running: true
        command: ["mkdir", "-p", root.dir]
        onExited: {
            root.dirReady = true;
            file.path = root.dir + "/tokens.json";
        }
    }

    FileView {
        id: file
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: store
            property string era: "phosphor"
            property int pitch: 3
            property int dotSize: 80
            property string depth: "era"
            property string wallpaper: "~/wallpaper/frozen-winter/2006_toyota_corolla_xrs-pic-2322350110483638351-1600x1200.jpeg"
            property bool night: false
        }
    }

    function set(key: string, value: string): string {
        switch (key) {
        case "era":
            if (!Eras.all[value])
                return "unknown era; one of: " + Eras.ids.join(", ");
            store.era = value;
            break;
        case "pitch":
            store.pitch = parseInt(value);
            break;
        case "dotSize":
            store.dotSize = parseInt(value);
            break;
        case "depth":
            store.depth = value;
            break;
        case "wallpaper":
            store.wallpaper = value;
            break;
        case "night":
            store.night = value === "true" || value === "on" || value === "1";
            break;
        default:
            return "unknown token; one of: era, pitch, dotSize, depth, wallpaper, night";
        }
        return "ok";
    }

    function toggleNight(): void {
        store.night = !store.night;
    }

    IpcHandler {
        target: "tokens"

        function set(key: string, value: string): string {
            return root.set(key, value);
        }
        function get(): string {
            return JSON.stringify({ era: root.era, pitch: root.pitch, dotSize: Math.round(root.dotSize * 100), depth: root.depth, wallpaper: store.wallpaper, night: root.night });
        }
        function cycleEra(): string {
            const ids = Eras.ids;
            store.era = ids[(ids.indexOf(root.era) + 1) % ids.length];
            return store.era;
        }
    }
}
