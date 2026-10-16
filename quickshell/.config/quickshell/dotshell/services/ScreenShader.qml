pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs

// The screen shader: Hyprland's decoration:screen_shader, built from
// shaders/screen.glsl. Glass (always on), full LED (Super Shift T) or off, with
// night warmth folded in; it replaced hyprsunset in Phase 3 and warm.glsl in
// Phase 6. Hyprland passes screen shaders no custom uniforms, so the tokens
// (mode, night, pitch, dot size, depth and the era on screen) are written into
// the template as #defines, saved to the state dir and applied with hyprctl.
//
// Pitch is in device pixels (token pitch x monitor scale), so the screen's dots
// sit on the same grid as the shell's own. One shader serves every monitor;
// its scale comes from the focused monitor.
Singleton {
    id: root

    readonly property string mode: Tokens.screen
    readonly property bool night: Tokens.night
    // Night warmth for the brightness pane.
    readonly property bool on: night

    readonly property real scale: Hyprland.focusedMonitor?.scale ?? Hyprland.monitors.values[0]?.scale ?? 1
    readonly property string templatePath: String(Qt.resolvedUrl("../shaders/screen.glsl")).replace(/^file:\/\//, "")

    function toggle(): void {
        Tokens.toggleNight();
    }

    function vec3(c: color): string {
        const f = x => (Math.round(x * 1000) / 1000).toFixed(3);
        return "vec3(" + f(c.r) + ", " + f(c.g) + ", " + f(c.b) + ")";
    }

    // The #define block for the current tokens, or "" for no shader at all.
    function defines(): string {
        const m = mode === "led" ? 1 : mode === "glass" ? 0 : 2;
        if (m === 2 && !night)
            return "";
        const e = Tokens.current;
        const shape = e.shape === "square" ? 1 : e.shape === "bubble" ? 2 : 0;
        const pitch = Math.max(2, Tokens.pitch * scale);
        const d = [
            ["MODE", m],
            ["NIGHT", night ? 1 : 0],
            ["PITCH", pitch.toFixed(4)],
            ["DOT", Tokens.dotSize.toFixed(3)],
            ["SHAPE", shape],
            ["DEPTH", Tokens.depthBits],
            ["GLOW", Number(e.glow ?? 0.5).toFixed(3)],
            ["TINT", vec3(Qt.color(e.slots[0]))],
            ["GLASS", vec3(Qt.color(e.glass))],
            ["UNLIT", vec3(Qt.color(e.unlit))],
            ["RAMP0", vec3(Qt.color(e.ramp[0]))],
            ["RAMP1", vec3(Qt.color(e.ramp[1]))],
            ["RAMP2", vec3(Qt.color(e.ramp[2]))],
            ["RAMP3", vec3(Qt.color(e.ramp[3]))]
        ];
        return d.map(kv => "#define " + kv[0] + " " + kv[1]).join("\n");
    }

    // What was last handed to Hyprland, so unrelated token changes cost nothing.
    property string applied: ""
    // Alternate between two files so Hyprland always sees a new path.
    property bool useB: false

    function apply(): void {
        if (!Tokens.dirReady || !template.loaded)
            return;
        const defs = defines();
        if (defs === "") {
            if (applied !== "off") {
                applied = "off";
                Quickshell.execDetached(["hyprctl", "keyword", "decoration:screen_shader", "[[EMPTY]]"]);
            }
            return;
        }
        const src = template.text().replace("//@DEFINES", defs);
        if (src === applied)
            return;
        applied = src;
        useB = !useB;
        (useB ? outB : outA).setText(src);
    }

    function hand(path: string): void {
        Quickshell.execDetached(["hyprctl", "keyword", "decoration:screen_shader", path]);
    }

    // Many tokens move at once (an era change swaps every color): settle first.
    Timer {
        id: settle
        interval: 30
        onTriggered: root.apply()
    }
    function schedule(): void {
        settle.restart();
    }

    onModeChanged: schedule()
    onNightChanged: schedule()
    onScaleChanged: schedule()
    Connections {
        target: Tokens
        function onCurrentChanged() {
            root.schedule();
        }
        function onPitchChanged() {
            root.schedule();
        }
        function onDotSizeChanged() {
            root.schedule();
        }
        function onDepthBitsChanged() {
            root.schedule();
        }
        function onDirReadyChanged() {
            root.schedule();
        }
    }

    FileView {
        id: template
        path: root.templatePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.schedule()
    }

    FileView {
        id: outA
        path: Tokens.dir + "/screen-a.glsl"
        onSaved: root.hand(path)
        onSaveFailed: err => console.warn("dotshell: cannot write", path, err)
    }
    FileView {
        id: outB
        path: Tokens.dir + "/screen-b.glsl"
        onSaved: root.hand(path)
        onSaveFailed: err => console.warn("dotshell: cannot write", path, err)
    }

    // A config reload resets the shader; put it back.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded") {
                root.applied = "";
                root.schedule();
            }
        }
    }

    IpcHandler {
        target: "screen"

        // dotshell ipc call screen led   (glass | led | off | toggle)
        function set(mode: string): string {
            if (mode === "toggle")
                return Tokens.toggleLed();
            const m = Tokens.set("screen", mode);
            return m === "ok" ? mode : m;
        }
        function toggle(): string {
            return Tokens.toggleLed();
        }
        function get(): string {
            return root.mode + (root.night ? " night" : "");
        }
    }
}
