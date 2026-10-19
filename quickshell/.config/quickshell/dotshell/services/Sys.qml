pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU load, memory in use and CPU temperature, 0 .. 1 (temperature also in
// degrees), for the side bar's meters. Polls every 2 s, and only while
// something on screen wants it: want(key, true).
//
// Temperature comes from the first hwmon named k10temp, coretemp, zenpower
// or cpu_thermal (temp1_input); -1 when there is none.
Singleton {
    id: root

    property real cpu: 0
    property real mem: 0
    property real memGb: 0
    property real temp: -1
    // The last 60 samples (2 minutes), per-core load, and the busiest
    // processes (only while someone wants "top": want("top-<key>", true)).
    property var cpuHist: []
    property var memHist: []
    // Temperature, 0 .. 1 (tempFraction), sampled with the others.
    property var tempHist: []
    property var cores: []
    property var top: []
    // The 1-minute load average, and how many tasks (threads) exist.
    property real load: 0
    property int tasks: 0
    readonly property real tempFraction: temp < 0 ? 0 : Math.max(0, Math.min(1, (temp - 30) / 70))

    property var wants: ({})
    readonly property bool wanted: Object.values(wants).some(v => v)
    function want(key: string, on: bool): void {
        if (!!wants[key] === on)
            return;
        const w = Object.assign({}, wants);
        if (on)
            w[key] = true;
        else
            delete w[key];
        wants = w;
    }

    property var last: null

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            const rows = text().split("\n").filter(l => /^cpu\d*\s/.test(l)).map(l => l.trim().split(/\s+/).slice(1).map(Number));
            const now = rows.map(f => ({ idle: f[3] + f[4], total: f.reduce((a, b) => a + b, 0) }));
            const load = (a, b) => {
                const dt = a.total - b.total;
                return dt > 0 ? Math.max(0, Math.min(1, 1 - (a.idle - b.idle) / dt)) : 0;
            };
            if (root.last && root.last.length === now.length) {
                root.cpu = load(now[0], root.last[0]);
                root.cores = now.slice(1).map((c, i) => load(c, root.last[i + 1]));
                root.cpuHist = [...root.cpuHist, root.cpu].slice(-60);
                root.memHist = [...root.memHist, root.mem].slice(-60);
                root.tempHist = [...root.tempHist, root.tempFraction].slice(-60);
            }
            root.last = now;
        }
    }
    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            const kb = k => Number((text().match(new RegExp("^" + k + ":\\s+(\\d+)", "m")) ?? [0, 0])[1]);
            const total = kb("MemTotal"), avail = kb("MemAvailable");
            root.mem = total > 0 ? 1 - avail / total : 0;
            root.memGb = (total - avail) / 1048576;
        }
    }
    FileView {
        id: loadavg
        path: "/proc/loadavg"
        onLoaded: {
            const f = text().trim().split(/\s+/);
            root.load = Number(f[0]) || 0;
            root.tasks = Number((f[3] ?? "").split("/")[1]) || 0;
        }
    }
    // A sysfs file reports no size, so FileView never loads it; cat it instead.
    Process {
        id: sensor
        property string path: ""
        command: ["cat", path]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = Number(text.trim());
                if (text.trim() !== "" && !isNaN(v))
                    root.temp = v / 1000;
            }
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do case $(cat $h/name) in k10temp|coretemp|zenpower|cpu_thermal) [ -r $h/temp1_input ] && echo $h/temp1_input && exit;; esac; done"]
        stdout: StdioCollector {
            onStreamFinished: sensor.path = text.trim()
        }
    }

    readonly property bool topWanted: Object.keys(wants).some(k => k.startsWith("top-"))
    Process {
        id: ps
        command: ["ps", "-eo", "comm=,%cpu=,%mem=,rss=,pid=", "--sort=-%cpu"]
        stdout: StdioCollector {
            // mem is a percent; rss the resident size in KiB.
            onStreamFinished: root.top = text.split("\n").filter(l => l.trim()).slice(0, 8).map(l => {
                const f = l.trim().split(/\s+/);
                const pid = f.pop(), rss = Number(f.pop()), mem = f.pop(), cpu = f.pop();
                return { name: f.join(" "), cpu: cpu, mem: mem, rss: rss, pid: pid };
            })
        }
    }

    Timer {
        running: root.wanted
        triggeredOnStart: true
        interval: 2000
        repeat: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
            loadavg.reload();
            if (sensor.path)
                sensor.running = true;
            if (root.topWanted)
                ps.running = true;
        }
    }
}
