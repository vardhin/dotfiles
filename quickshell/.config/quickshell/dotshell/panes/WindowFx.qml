import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services

// Window open/close as LED dots. Hyprland has only built-in window animations
// (no custom shader per window), so the shell draws the effect itself: on
// openwindow / closewindow it puts a short-lived, click-through overlay over
// the window's rect and plays shaders/winfx.frag there, in era colors, on the
// shell's dot grid. Hyprland's own windowsIn/Out are cut down to a fade
// (hypr/.config/hypr/lua/look.lua) so the two do not fight.
//
// Close needs the rect of a window that is already gone, so rects are cached
// from `hyprctl -j clients` after every event that can move a window.
// The dropdown terminal (services/DropTerm.qml) is never closed, only moved
// to and from its parking workspace; those moves play open and close.
// Off with the `winfx` token. Skipped: specials, fullscreen, tiny windows and
// windows on workspaces not on screen.
Scope {
    id: root

    property var rects: ({})
    property var effects: []
    property int serial: 0
    // Addresses that opened before the clients query came back.
    property var waiting: []

    readonly property int openMs: 420
    readonly property int closeMs: 360

    function addrOf(data: string): string {
        const a = data.split(",")[0];
        return a.startsWith("0x") ? a : "0x" + a;
    }

    function play(kind: string, c: var): void {
        if (!Tokens.winfx || !c)
            return;
        if (c.fullscreen > 0 || (c.workspace?.id ?? -1) < 0)
            return;
        const mon = Hyprland.monitors.values.find(m => m.id === c.monitor);
        if (!mon || mon.activeWorkspace?.id !== c.workspace.id && !c.pinned)
            return;
        const scr = Quickshell.screens.find(s => s.name === mon.name);
        // Effect dots: twice the pitch when it is fine, so they read as dots
        // and not a flat block; still on the grid, as a multiple of it.
        const p = Tokens.pitch < 5 ? Tokens.pitch * 2 : Tokens.pitch;
        if (!scr || c.size[0] < 6 * p || c.size[1] < 6 * p)
            return;
        // Snap outward onto the dot grid, so the board lines up with the glass.
        const x0 = Math.floor((c.at[0] - mon.x) / p) * p;
        const y0 = Math.floor((c.at[1] - mon.y) / p) * p;
        const x1 = Math.ceil((c.at[0] - mon.x + c.size[0]) / p) * p;
        const y1 = Math.ceil((c.at[1] - mon.y + c.size[1]) / p) * p;
        effects = effects.concat([{
            id: ++serial,
            kind: kind,
            screen: scr,
            x: x0,
            y: y0,
            w: x1 - x0,
            h: y1 - y0,
            // Progress comes from the clock, so boards can be rebuilt (the
            // list changes whenever another effect starts) without restarting.
            // Two frames' grace for the overlay to take its new size.
            born: Date.now() + 32,
            ms: kind === "close" ? closeMs : openMs,
            pitch: p
        }]);
    }

    function prune(now: real): void {
        const left = effects.filter(e => now < e.born + e.ms);
        if (left.length !== effects.length)
            effects = left;
    }

    Process {
        id: clients
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list = [];
                try {
                    list = JSON.parse(text);
                } catch (e) {
                    return;
                }
                const next = {};
                for (const c of list)
                    next[c.address] = c;
                root.rects = next;
                for (const a of root.waiting)
                    root.play("open", next[a]);
                root.waiting = [];
            }
        }
        onExited: if (root.again) {
            root.again = false;
            running = true;
        }
    }
    property bool again: false

    function refresh(): void {
        if (clients.running)
            again = true;
        else
            clients.running = true;
    }

    // Layout settles a moment after most events (tiling reflow, animations).
    Timer {
        id: settle
        interval: 250
        onTriggered: root.refresh()
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            switch (event.name) {
            case "openwindow":
                if (!Tokens.winfx)
                    break;
                root.waiting = root.waiting.concat([root.addrOf(event.data)]);
                root.refresh();
                settle.restart();
                break;
            case "closewindow":
                root.play("close", root.rects[root.addrOf(event.data)]);
                settle.restart();
                break;
            case "movewindowv2":
                {
                    // address,workspaceid,workspacename
                    const f = event.data.split(",");
                    const a = root.addrOf(f[0]);
                    if (Tokens.winfx && a === DropTerm.address) {
                        if (f[2] === DropTerm.parking) {
                            root.play("close", root.rects[a]);
                        } else {
                            root.waiting = root.waiting.concat([a]);
                            root.refresh();
                        }
                    }
                }
                settle.restart();
                break;
            case "changefloatingmode":
            case "fullscreen":
            case "workspacev2":
            case "activewindowv2":
            case "pin":
                settle.restart();
                break;
            }
        }
    }

    Component.onCompleted: refresh()

    // One overlay per screen, kept mapped: a new window per effect would build
    // a new GL context and show up ~300 ms late. Idle, it is 1x1 and empty;
    // during effects it covers their bounding box.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: fx
            required property ShellScreen modelData
            screen: modelData

            readonly property var mine: root.effects.filter(e => e.screen === fx.modelData)
            readonly property bool busy: mine.length > 0
            readonly property int bx: busy ? Math.min(...mine.map(e => e.x)) : 0
            readonly property int by: busy ? Math.min(...mine.map(e => e.y)) : 0
            readonly property int bw: busy ? Math.max(...mine.map(e => e.x + e.w)) - bx : 1
            readonly property int bh: busy ? Math.max(...mine.map(e => e.y + e.h)) - by : 1

            anchors {
                top: true
                left: true
            }
            margins {
                left: fx.bx
                top: fx.by
            }
            implicitWidth: fx.bw
            implicitHeight: fx.bh
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            mask: Region {}

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "dotshell-fx"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            property real now: Date.now()
            FrameAnimation {
                running: fx.busy
                onTriggered: {
                    fx.now = Date.now();
                    root.prune(fx.now);
                }
            }

            Repeater {
                model: fx.mine

                ShaderEffect {
                    id: board
                    required property var modelData
                    x: modelData.x - fx.bx
                    y: modelData.y - fx.by
                    width: modelData.w
                    height: modelData.h
                    property vector2d grid: Qt.vector2d(Math.round(modelData.w / modelData.pitch), Math.round(modelData.h / modelData.pitch))
                    property real t: Math.max(0, Math.min(1, (fx.now - modelData.born) / modelData.ms))
                    property real kind: modelData.kind === "close" ? 1 : 0
                    property real dotSize: Tokens.dotSize
                    property real shape: Tokens.current.shape === "square" ? 1 : Tokens.current.shape === "bubble" ? 2 : 0
                    property real glow: Tokens.current.glow ?? 0.5
                    property color litColor: Tokens.slot0
                    property color edgeColor: Tokens.slot1
                    fragmentShader: Qt.resolvedUrl("../shaders/winfx.frag.qsb")
                }
            }
        }
    }
}
