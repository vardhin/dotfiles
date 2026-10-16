pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Backlight level from sysfs. sysfs has no change notifications, so the
// file is re-read four times a second; that is what lets the OSD react to
// the brightness keys (brightnessctl) without any IPC.
Singleton {
    id: root

    property string device: ""
    property int max: 0
    property int current: 0
    readonly property bool available: device !== "" && max > 0
    readonly property real value: available ? current / max : 1

    // Idle dimming sets this so the dim does not pop the OSD.
    property bool quiet: false

    signal changed

    Process {
        running: true
        command: ["brightnessctl", "-m", "-c", "backlight", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                // name,class,current,percent,max
                const f = text.trim().split("\n")[0].split(",");
                if (f.length >= 5) {
                    root.device = f[0];
                    root.max = parseInt(f[4]);
                    root.current = parseInt(f[2]);
                    // Started while idle-dimmed (a shell restart mid-dim): the
                    // new shell never saw the dim, so no activity would undo
                    // it. Put back the level brightnessctl saved.
                    if (root.current === root.dimLevel) {
                        root.quiet = true;
                        root.restore();
                    }
                }
            }
        }
    }

    FileView {
        id: file
        path: root.device ? `/sys/class/backlight/${root.device}/brightness` : ""
        printErrors: false
        onLoaded: {
            const v = parseInt(text());
            if (!isNaN(v) && v !== root.current) {
                root.current = v;
                if (!root.quiet)
                    root.changed();
            }
        }
    }

    Timer {
        running: root.available
        interval: 250
        repeat: true
        onTriggered: file.reload()
    }

    function set(fraction: real): void {
        const pct = Math.round(Math.max(0.01, Math.min(1, fraction)) * 100);
        Quickshell.execDetached(["brightnessctl", "-q", "set", pct + "%"]);
    }

    // Idle dim and restore, like hypridle's brightnessctl -s / -r.
    // Raw backlight units while idle-dimmed.
    readonly property int dimLevel: 10

    function dim(): void {
        quiet = true;
        Quickshell.execDetached(["brightnessctl", "-q", "-s", "set", String(dimLevel)]);
    }
    function restore(): void {
        if (!quiet)
            return;
        Quickshell.execDetached(["brightnessctl", "-q", "-r"]);
        quietTimer.restart();
    }

    Timer {
        id: quietTimer
        interval: 800
        onTriggered: root.quiet = false
    }
}
