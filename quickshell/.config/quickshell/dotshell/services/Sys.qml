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
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = f[3] + f[4], total = f.reduce((a, b) => a + b, 0);
            if (root.last) {
                const dt = total - root.last.total;
                root.cpu = dt > 0 ? Math.max(0, Math.min(1, 1 - (idle - root.last.idle) / dt)) : 0;
            }
            root.last = { idle: idle, total: total };
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
        id: sensor
        path: ""
        onLoaded: root.temp = Number(text()) / 1000
    }

    Process {
        running: true
        command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do case $(cat $h/name) in k10temp|coretemp|zenpower|cpu_thermal) [ -r $h/temp1_input ] && echo $h/temp1_input && exit;; esac; done"]
        stdout: StdioCollector {
            onStreamFinished: sensor.path = text.trim()
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
            if (sensor.path)
                sensor.reload();
        }
    }
}
