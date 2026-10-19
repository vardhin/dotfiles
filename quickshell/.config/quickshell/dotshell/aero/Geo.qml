import QtQuick
import Quickshell.Io
import qs

// Where each window sits on its workspace, for drawing the desks:
// `geo` is { ws: [{ x, y, w, h, cls }] } in fractions of the monitor.
// Asks hyprctl on load and whenever `poke()` is called (windows came, went
// or moved).
Item {
    id: g

    property var geo: ({})

    function poke(): void {
        later.restart();
    }

    Process {
        id: query
        command: ["sh", "-c", "printf '{\"clients\":%s,\"monitors\":%s}' \"$(hyprctl -j clients)\" \"$(hyprctl -j monitors)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    const mon = {};
                    for (const m of d.monitors ?? [])
                        mon[m.id] = m;
                    const by = {};
                    for (const c of d.clients ?? []) {
                        const ws = c.workspace?.id ?? 0;
                        if (ws <= 0 || !c.mapped)
                            continue;
                        const m = mon[c.monitor] ?? { x: 0, y: 0, width: 1920, height: 1080 };
                        (by[ws] = by[ws] ?? []).push({ x: (c.at[0] - m.x) / m.width, y: (c.at[1] - m.y) / m.height, w: c.size[0] / m.width, h: c.size[1] / m.height, cls: c.class ?? "" });
                    }
                    g.geo = by;
                } catch (e) {}
            }
        }
    }
    Timer {
        id: later
        interval: 250
        onTriggered: query.running = true
    }
    Component.onCompleted: query.running = true
}
