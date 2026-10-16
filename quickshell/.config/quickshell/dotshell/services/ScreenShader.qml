pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs

// The screen shader: Hyprland's decoration:screen_shader, built from
// shaders/screen.glsl. Since it covers every window, it now carries only the
// night warmth (it replaced hyprsunset in Phase 3); the glass / LED / board
// look runs on the wallpaper alone (panes/Wallpaper.qml, shaders/wall.frag).
// This file still owns the `screen` IPC target for that token.
Singleton {
    id: root

    readonly property string mode: Tokens.screen
    readonly property bool night: Tokens.night
    // Night warmth for the brightness pane.
    readonly property bool on: night

    readonly property string templatePath: String(Qt.resolvedUrl("../shaders/screen.glsl")).replace(/^file:\/\//, "")

    function toggle(): void {
        Tokens.toggleNight();
    }

    // The #define block, or "" for no shader at all.
    function defines(): string {
        return night ? "#define NIGHT 1" : "";
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
        // Stamped: FileView skips a write whose text the file already holds,
        // and then never says `saved`, so going back to an earlier setting
        // would never reach Hyprland.
        (useB ? outB : outA).setText(src + "\n// applied " + Date.now() + "\n");
    }

    function hand(path: string): void {
        Quickshell.execDetached(["hyprctl", "keyword", "decoration:screen_shader", path]);
    }

    // Settle first, so a burst of changes writes once.
    Timer {
        id: settle
        interval: 30
        onTriggered: root.apply()
    }
    function schedule(): void {
        settle.restart();
    }

    onNightChanged: schedule()
    Connections {
        target: Tokens
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

        // dotshell ipc call screen set led   (glass | led | board | off | toggle)
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
