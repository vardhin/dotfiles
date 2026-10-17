pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The one tokens file: era, display config, wallpaper, night warmth.
// Lives outside the repo so runtime changes never dirty the dotfiles:
//   ${XDG_STATE_HOME:-~/.local/state}/dotshell/tokens.json
// Edit it by hand (picked up live) or over IPC:
//   qs -p ~/.config/quickshell/dotshell ipc call tokens set era tokyo
//   qs -p ~/.config/quickshell/dotshell ipc call tokens set wall dots
//   qs -p ~/.config/quickshell/dotshell ipc call tokens cycleEra
//
// Tokens:
//   era        an id from Eras.qml
//   pitch      3 | 5 | 8 | 12 px per dot (panels keep their size)
//   dotSize    40 .. 100, dot diameter in % of pitch
//   depth      era | 8 | 16 | 24 (era ramp, RGB332, RGB565, true color)
//   wall       dots | image | off: wallpaper drawn by the matrix, the plain
//              image with parallax (only panels stay LED), or unlit glass
//   wallpaper  image path ("~" is expanded)
//   hue        era | wallpaper: keep the era's own hues, or rotate the era
//              onto the wallpaper's hue (picked by matugen); the mood (levels,
//              glow, shape) always stays the era's
//   cascade    true: an era change flips every dot over in a wave, like a
//              flip-disc board; false: switch at once
//   night      warmth in the screen shader, on/off
//   screen     glass | led | board | off: the look of the wallpaper layer
//              (panes/Wallpaper.qml, shaders/wall.frag; windows are left
//              alone): faint dot mask and tint; the wallpaper as LED dots in
//              era colors, every pixel kept inside its dot (Super Shift T);
//              one color per dot, a true LED board; or nothing
//   winfx      true: windows open and close as LED dots (panes/WindowFx.qml)
//   wsfx       true: workspace switches dissolve into LED dots
//              (panes/WorkspaceFx.qml); false: Hyprland's slide
//   borders    true: a one-dot LED ring around every pane, desktop panel and
//              window (panes/WindowBorders.qml; windows get a one-dot gap)
//   ledfx      auto | random | music | off: the borders' animation
//              (services/LedFx.qml): a random one, new on every window or
//              workspace switch, reacting to music while it plays (auto);
//              never to music (random); always to music when it can (music);
//              still rings (off)
//   top        true: the top strip
//   title      true: the focused window's title on the top strip
//   side       off | on | auto: the right side bar (panes/SideBar.qml); auto
//              hides it until the pointer touches the right edge
//   winshade   off | dim | all: windows on the dot grid, drawn by Hyprland
//              through the Hypr-DarkWindow plugin (hypr/.config/hypr/lua/
//              dotshell.lua): unfocused windows as LED dots in the era ramp
//              (dim), plus a faint dot mask on the focused one (all). Without
//              the plugin, unfocused windows are dimmed as before
//   scene      true: the era's scene plays full screen after three minutes
//              idle, before the screen dims (not while a video plays) (panes/Scene.qml; Super Shift S now)
//   sounds     off | soft | full: the era's UI sounds (services/Sound.qml):
//              panes, toasts, the cascade, workspace switches
//   frosted    true: panes are LED dots on frosted glass: the glass between
//              the dots turns translucent and Hyprland blurs what is behind
//              (a layer rule from hypr/.config/hypr/lua/dotshell.lua)
Singleton {
    id: root

    // ── Persisted tokens ────────────────────────────────────────────
    readonly property string era: Eras.all[store.era] ? store.era : "phosphor"
    readonly property int pitch: [3, 5, 8, 12].includes(store.pitch) ? store.pitch : 3
    readonly property real dotSize: Math.max(40, Math.min(100, store.dotSize)) / 100
    readonly property string depth: ["era", "8", "16", "24"].includes(store.depth) ? store.depth : "era"
    readonly property string wall: walls.includes(store.wall) ? store.wall : "image"
    readonly property string wallpaper: store.wallpaper.replace(/^~(?=\/|$)/, Quickshell.env("HOME"))
    readonly property string hue: store.hue === "wallpaper" ? "wallpaper" : "era"
    readonly property bool cascade: store.cascade
    readonly property bool night: store.night
    readonly property string screen: screens.includes(store.screen) ? store.screen : "glass"
    readonly property bool winfx: store.winfx
    readonly property bool wsfx: store.wsfx
    readonly property bool borders: store.borders
    readonly property string ledfx: ledfxes.includes(store.ledfx) ? store.ledfx : "auto"
    readonly property var ledfxes: ["auto", "random", "music", "off"]
    readonly property bool top: store.top
    readonly property bool title: store.title
    readonly property string side: sides.includes(store.side) ? store.side : "auto"
    readonly property var sides: ["off", "on", "auto"]
    readonly property string winshade: winshades.includes(store.winshade) ? store.winshade : "off"
    readonly property var winshades: ["off", "dim", "all"]
    readonly property bool scene: store.scene
    readonly property string sounds: soundModes.includes(store.sounds) ? store.sounds : "soft"
    readonly property var soundModes: ["off", "soft", "full"]
    readonly property bool frosted: store.frosted

    readonly property var walls: ["dots", "image", "off"]
    readonly property var screens: ["glass", "led", "board", "off"]
    readonly property var keys: ["era", "pitch", "dotSize", "depth", "wall", "wallpaper", "hue", "cascade", "night", "screen", "winfx", "wsfx", "borders", "ledfx", "top", "title", "side", "winshade", "scene", "sounds", "frosted"]

    // ── What is on screen ───────────────────────────────────────────
    // `current` is the era as displayed: its colors after the wallpaper hue,
    // set by the cascade (below) rather than bound, so the old era stays on
    // screen until the wave passes. `previous` is what the wave flips away from.
    property var current: Eras.get("phosphor")
    property var previous: current
    // 0 -> 1 while a cascade runs; 1 when idle.
    property real flip: 1

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

    // DotSurfaces snapshot their canvas when this fires; the era swaps two
    // frames later, so the snapshot still holds the old colors.
    signal flipStarting

    // ── Wallpaper hue ───────────────────────────────────────────────
    // Hue of matugen's source color for the wallpaper, 0 .. 1; -1 = unknown.
    property real wallHue: -1

    // Rotate a color's hue by `dh` (0 .. 1), keeping saturation and lightness.
    // Greys stay grey.
    function rotate(c: string, dh: real): string {
        const q = Qt.color(c);
        if (q.hslSaturation < 0.04 || q.hslHue < 0)
            return c;
        return Qt.hsla((q.hslHue + dh + 2) % 1, q.hslSaturation, q.hslLightness, 1).toString();
    }

    // An era as it should look: hues moved onto the wallpaper's when hue = wallpaper.
    function effective(id: string, hueMode: string, wh: real): var {
        const base = Eras.get(id);
        const e = Object.assign({ id: id }, base);
        if (hueMode !== "wallpaper" || wh < 0)
            return e;
        const h0 = Qt.color(base.slots[0]).hslHue;
        if (h0 < 0)
            return e;
        const dh = wh - h0;
        e.slots = base.slots.map(c => rotate(c, dh));
        e.ramp = base.ramp.map(c => rotate(c, dh));
        e.unlit = rotate(base.unlit, dh);
        e.glass = rotate(base.glass, dh);
        if (base.mono)
            e.ansi = base.ansi.map(c => rotate(c, dh));
        return e;
    }

    readonly property var target: effective(era, hue, wallHue)
    // No cascade while the shell starts (tokens file, matugen arriving).
    property bool live: false
    Timer {
        running: root.dirReady
        interval: 3000
        onTriggered: root.live = true
    }
    property string shownKey: ""
    onTargetChanged: retarget()

    function retarget(): void {
        const key = JSON.stringify(target);
        if (key === shownKey)
            return;
        // Login, cascade off, or nothing on screen yet: switch at once.
        if (!cascade || !live || shownKey === "") {
            shownKey = key;
            flipAnim.stop();
            flip = 1;
            previous = target;
            current = target;
            return;
        }
        // Finish any running wave, grab, then swap: until the swap the live
        // canvas still shows the old era, so flip stays 1 meanwhile.
        shownKey = key;
        flipAnim.stop();
        flip = 1;
        previous = current;
        flipStarting();
        swap.restart();
    }

    Timer {
        id: swap
        // Two frames: every visible DotSurface has grabbed its old canvas.
        interval: 40
        onTriggered: {
            root.current = root.target;
            flipAnim.restart();
        }
    }

    NumberAnimation {
        id: flipAnim
        target: root
        property: "flip"
        from: 0
        to: 1
        duration: 1100
        easing.type: Easing.InOutSine
    }

    // matugen picks the hue: the source color it would theme the wallpaper with.
    // Runs only while hue = wallpaper; needs matugen (extra/matugen, 4.x).
    Process {
        id: matugen
        property string forPath: ""
        command: ["matugen", "image", forPath, "--dry-run", "--json", "hex", "--quiet", "--source-color-index", "0"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    const s = d.colors?.source_color;
                    const hex = typeof s === "string" ? s : (s?.default?.color ?? s?.dark?.color ?? s?.color ?? "");
                    const h = hex ? Qt.color(hex).hslHue : -1;
                    root.wallHue = h >= 0 ? h : -1;
                } catch (e) {
                    console.warn("dotshell: matugen gave no colors for", matugen.forPath);
                }
            }
        }
        onExited: code => {
            if (code !== 0)
                console.warn("dotshell: matugen failed (" + code + "); is extra/matugen installed? Keeping era hues.");
            // The wallpaper changed while it ran.
            if (root.hue === "wallpaper" && root.wallpaper && root.wallpaper !== forPath)
                Qt.callLater(root.pickHue);
        }
    }

    function pickHue(): void {
        if (hue !== "wallpaper" || !wallpaper) {
            wallHue = -1;
            return;
        }
        // Busy: onExited picks up the newest wallpaper.
        if (matugen.running)
            return;
        matugen.forPath = wallpaper;
        matugen.running = true;
    }
    onHueChanged: pickHue()
    onWallpaperChanged: pickHue()

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
            property string wall: "image"
            property string wallpaper: "~/wallpaper/frozen-winter/2006_toyota_corolla_xrs-pic-2322350110483638351-1600x1200.jpeg"
            property string hue: "era"
            property bool cascade: true
            property bool night: false
            property string screen: "glass"
            property bool winfx: true
            property bool wsfx: true
            property bool borders: true
            property string ledfx: "auto"
            property bool top: true
            property bool title: true
            property string side: "auto"
            property string winshade: "off"
            property bool scene: true
            property string sounds: "soft"
            property bool frosted: false
        }
    }

    function truthy(v: string): bool {
        return v === "true" || v === "on" || v === "1" || v === "yes";
    }

    function set(key: string, value: string): string {
        switch (key) {
        case "era":
            if (!Eras.all[value])
                return "unknown era; one of: " + Eras.ids.join(", ");
            store.era = value;
            break;
        case "pitch":
            if (![3, 5, 8, 12].includes(parseInt(value)))
                return "pitch is one of: 3, 5, 8, 12";
            store.pitch = parseInt(value);
            break;
        case "dotSize":
            if (isNaN(parseInt(value)))
                return "dotSize is a number, 40 .. 100";
            store.dotSize = parseInt(value);
            break;
        case "depth":
            if (!["era", "8", "16", "24"].includes(value))
                return "depth is one of: era, 8, 16, 24";
            store.depth = value;
            break;
        case "wall":
            if (!walls.includes(value))
                return "wall is one of: " + walls.join(", ");
            store.wall = value;
            break;
        case "wallpaper":
            store.wallpaper = value;
            break;
        case "hue":
            if (value !== "era" && value !== "wallpaper")
                return "hue is one of: era, wallpaper";
            store.hue = value;
            break;
        case "cascade":
            store.cascade = truthy(value);
            break;
        case "night":
            store.night = truthy(value);
            break;
        case "screen":
            if (!screens.includes(value))
                return "screen is one of: " + screens.join(", ");
            store.screen = value;
            break;
        case "winfx":
            store.winfx = truthy(value);
            break;
        case "wsfx":
            store.wsfx = truthy(value);
            break;
        case "borders":
            store.borders = truthy(value);
            break;
        case "ledfx":
            if (!ledfxes.includes(value))
                return "ledfx is one of: " + ledfxes.join(", ");
            store.ledfx = value;
            break;
        case "top":
            store.top = truthy(value);
            break;
        case "title":
            store.title = truthy(value);
            break;
        case "side":
            if (!sides.includes(value))
                return "side is one of: " + sides.join(", ");
            store.side = value;
            break;
        case "winshade":
            if (!winshades.includes(value))
                return "winshade is one of: " + winshades.join(", ");
            store.winshade = value;
            break;
        case "scene":
            store.scene = truthy(value);
            break;
        case "frosted":
            store.frosted = truthy(value);
            break;
        case "sounds":
            if (!soundModes.includes(value))
                return "sounds is one of: " + soundModes.join(", ");
            store.sounds = value;
            break;
        default:
            return "unknown token; one of: " + keys.join(", ");
        }
        return "ok";
    }

    function snapshot(): var {
        return {
            era: era,
            pitch: pitch,
            dotSize: Math.round(dotSize * 100),
            depth: depth,
            wall: wall,
            wallpaper: store.wallpaper,
            hue: hue,
            cascade: cascade,
            night: night,
            screen: screen,
            winfx: winfx,
            wsfx: wsfx,
            borders: borders,
            ledfx: ledfx,
            top: top,
            title: title,
            side: side,
            winshade: winshade,
            scene: scene,
            sounds: sounds,
            frosted: frosted
        };
    }

    function cycleEra(step: int): string {
        const ids = Eras.ids;
        store.era = ids[(ids.indexOf(era) + ids.length + step) % ids.length];
        return store.era;
    }

    function toggleNight(): void {
        store.night = !store.night;
    }

    // Super Shift W: off → dim → all → off.
    function cycleWinshade(): string {
        store.winshade = winshades[(winshades.indexOf(winshade) + 1) % winshades.length];
        return store.winshade;
    }

    // Super Shift T: LED and back to glass (from board or off: to LED).
    function toggleLed(): string {
        store.screen = screen === "led" ? "glass" : "led";
        return store.screen;
    }

    IpcHandler {
        target: "tokens"

        function set(key: string, value: string): string {
            return root.set(key, value);
        }
        function get(): string {
            return JSON.stringify(root.snapshot());
        }
        function cycleEra(): string {
            return root.cycleEra(1);
        }
    }

    IpcHandler {
        target: "winshade"

        // dotshell ipc call winshade cycle | set dim
        function cycle(): string {
            return root.cycleWinshade();
        }
        function set(mode: string): string {
            return root.set("winshade", mode);
        }
        function get(): string {
            return root.winshade;
        }
    }
}
