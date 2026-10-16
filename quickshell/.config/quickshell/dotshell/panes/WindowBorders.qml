import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services

// LED borders for windows (the `borders` token): a one-dot ring of LEDs around
// every window on the workspaces on screen, animated by services/LedFx.qml
// (bright on the focused window, dim on the rest; with `ledfx` off, lit in
// the first tube for the focused window and dark for the rest). Hyprland draws only flat
// borders, so the shell draws the rings, each a small DotSurface cut to a ring.
//
// While borders are on, the gaps become one dot wide (gaps_in and gaps_out =
// pitch, set with hyprctl and again after a config reload), and tiled rings sit
// in them on the Bottom layer, under every window. Floating windows get their
// ring on the Top layer, as a bezel over whatever is behind them.
//
// Rects come from `hyprctl -j clients` after window events, plus a slow poll
// for resizes (Hyprland sends no event for those).
Scope {
    id: root

    property var clients: []
    readonly property bool on: Tokens.borders
    readonly property int pitch: Tokens.pitch

    // ── Gaps ────────────────────────────────────────────────────────
    function gaps(): void {
        const inner = on ? pitch : 2, outer = on ? pitch : 0;
        Hypr.set({ general: { gaps_in: inner, gaps_out: outer } });
    }
    onOnChanged: {
        gaps();
        refresh();
    }
    onPitchChanged: gaps()
    Component.onCompleted: {
        gaps();
        refresh();
    }

    // ── Rects ───────────────────────────────────────────────────────
    Process {
        id: query
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.clients = JSON.parse(text);
                } catch (e) {}
            }
        }
        onExited: if (root.again) {
            root.again = false;
            running = true;
        }
    }
    property bool again: false

    function refresh(): void {
        if (!on) {
            clients = [];
            return;
        }
        if (query.running)
            again = true;
        else
            query.running = true;
    }

    // Tiling settles over the animation; read it now and once it is done.
    Timer {
        id: settle
        interval: 300
        onTriggered: root.refresh()
    }
    Timer {
        running: root.on
        interval: 1500
        repeat: true
        onTriggered: root.refresh()
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            switch (event.name) {
            case "configreloaded":
                root.gaps();
            // fallthrough
            case "openwindow":
            case "closewindow":
            case "movewindowv2":
            case "changefloatingmode":
            case "fullscreen":
            case "workspacev2":
            case "activewindowv2":
            case "focusedmonv2":
            case "pin":
                root.refresh();
                settle.restart();
                break;
            }
        }
    }

    readonly property string focused: {
        const a = String(Hyprland.activeToplevel?.address ?? "");
        return !a ? "" : a.startsWith("0x") ? a : "0x" + a;
    }

    // Windows that get a ring on a screen: on a workspace shown there, mapped,
    // not fullscreen.
    function rings(scr: ShellScreen, floating: bool): var {
        const mon = Hyprland.monitors.values.find(m => m.name === scr.name);
        if (!mon)
            return [];
        const ws = mon.activeWorkspace?.id;
        const special = mon.lastIpcObject?.specialWorkspace?.id ?? 0;
        return clients.filter(c => c.mapped && !c.hidden && c.fullscreen === 0 && !!c.floating === floating && (c.workspace?.id === ws || special !== 0 && c.workspace?.id === special || c.pinned)).map(c => ({
                    address: c.address,
                    x: c.at[0] - mon.x,
                    y: c.at[1] - mon.y,
                    w: c.size[0],
                    h: c.size[1]
                }));
    }

    component Rings: PanelWindow {
        id: win
        required property ShellScreen modelData
        property bool floating: false
        screen: modelData
        visible: root.on
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region {}
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Repeater {
            model: root.on ? root.rings(win.modelData, win.floating) : []

            // One ring: the window's rect grown by one dot on every side.
            DotSurface {
                id: ring
                required property var modelData
                readonly property bool lit: modelData.address === root.focused
                x: modelData.x - root.pitch
                y: modelData.y - root.pitch
                cols: Math.max(3, Math.round(modelData.w / root.pitch) + 2)
                rows: Math.max(3, Math.round(modelData.h / root.pitch) + 2)
                shape: `M 0 0 H ${cols} V ${rows} H 0 Z M 1 1 V ${rows - 1} H ${cols - 1} V 1 Z`

                // Animated by LedFx: full on the focused window, dim on the
                // rest. Still (ledfx off): lit on the focused window only.
                LedRing {
                    width: ring.cols
                    height: ring.rows
                    visible: ring.lit || LedFx.on
                    gain: ring.lit ? 1 : 0.4
                    offset: parseInt(ring.modelData.address.slice(-4), 16) % 997 / 997
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        Rings {
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "dotshell-borders"
        }
    }
    Variants {
        model: Quickshell.screens

        Rings {
            floating: true
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "dotshell-borders-float"
        }
    }
}
