pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Replaces hypridle.
//   5 min     dim the backlight      (restored on activity)
//   7.5 min   lock
//   7.75 min  screen off             (on again on activity)
// Caffeine turns all three off. logind is bridged: `loginctl lock-session`
// (Super L) locks, and the screen is locked before suspend through a sleep
// delay inhibitor that is released only once the lock covers every screen.
Singleton {
    id: root

    property bool caffeine: false

    IdleMonitor {
        enabled: !root.caffeine
        timeout: 300
        onIsIdleChanged: isIdle ? Brightness.dim() : Brightness.restore()
    }

    IdleMonitor {
        enabled: !root.caffeine
        timeout: 450
        onIsIdleChanged: {
            if (isIdle)
                Lock.lock();
        }
    }

    IdleMonitor {
        enabled: !root.caffeine
        timeout: 465
        onIsIdleChanged: {
            Hypr.dpms(!isIdle);
            if (!isIdle)
                Brightness.restore();
        }
    }

    function setCaffeine(on: bool): void {
        caffeine = on;
        if (on)
            Brightness.restore();
        Notify.send(on ? "Caffeine on" : "Caffeine off", on ? "Screen stays awake (still blanks when the lid shuts)" : "Normal idle behaviour restored", {
            app: "dotshell-caffeine",
            urgency: "low",
            expire: 1800,
            tag: "dotshell-caffeine",
            transient: true
        });
    }

    // ── Lid while caffeinated ───────────────────────────────────────
    // logind ignores the lid (HandleLidSwitch=ignore), so with idle off
    // nothing would blank a closed laptop. Poll the ACPI lid only then.
    property bool lidClosed: false
    Process {
        id: lidRead
        command: ["sh", "-c", "cat /proc/acpi/button/lid/*/state 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const closed = /closed/i.test(text);
                if (closed !== root.lidClosed) {
                    root.lidClosed = closed;
                    Hypr.dpms(!closed);
                }
            }
        }
    }
    Timer {
        running: root.caffeine
        interval: 1000
        repeat: true
        onTriggered: lidRead.running = true
    }

    // ── logind bridge ───────────────────────────────────────────────
    // Holds a delay inhibitor so logind waits (up to InhibitDelayMaxSec) for
    // the lock before suspending.
    property bool holdSleep: true
    Process {
        running: root.holdSleep
        command: ["systemd-inhibit", "--what=sleep", "--mode=delay", "--who=dotshell", "--why=Lock the screen before sleep", "sleep", "infinity"]
    }

    Connections {
        target: Lock
        function onSecureChanged() {
            // Lock is up: let the pending suspend go ahead.
            if (Lock.secure && root.sleeping)
                root.holdSleep = false;
        }
    }

    property bool sleeping: false
    Process {
        running: true
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1"]
        stdout: SplitParser {
            onRead: line => {
                if (line.includes(".Session.Lock ")) {
                    Lock.lock();
                } else if (line.includes(".PrepareForSleep (true")) {
                    root.sleeping = true;
                    Lock.lock();
                    if (Lock.secure)
                        root.holdSleep = false;
                } else if (line.includes(".PrepareForSleep (false")) {
                    root.sleeping = false;
                    root.holdSleep = true;
                    Hypr.dpms(true);
                }
            }
        }
    }

    IpcHandler {
        target: "caffeine"

        function toggle(): string {
            root.setCaffeine(!root.caffeine);
            return root.caffeine ? "on" : "off";
        }
    }
}
