pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Screen capture: screenshots (hypr/scripts/screenshot.sh), recordings
// (gpu-screen-recorder) and the color picker (hyprpicker). The CAPTURE pane
// (Super Shift P) drives it; while a recording runs the strip shows REC.
//
//   dotshell ipc call capture shot area     area | screen | window | edit | delay
//   dotshell ipc call capture rec area      area | screen; again stops it
//   dotshell ipc call capture stop
//   dotshell ipc call capture pick
//
// SCREEN and FULL take the focused monitor only. Recordings land in
// ~/Videos/Recordings, screenshots in ~/Pictures/Screenshots.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string shots: home + "/.config/hypr/scripts/screenshot.sh"
    readonly property string videos: home + "/Videos/Recordings"

    readonly property bool recording: recorder.running
    property string file: ""
    property bool audio: true
    property real startedAt: 0
    // Seconds since the recording started, ticking while it runs.
    property int elapsed: 0

    function stamp(): string {
        return Qt.formatDateTime(new Date(), "yyyy-MM-dd_hh-mm-ss");
    }

    // The pane closes first, so the capture never shows it.
    function later(cmd: var): void {
        Ui.close();
        Quickshell.execDetached(["sh", "-c", "sleep 0.3; exec \"$@\"", "capture"].concat(cmd));
    }

    // For services/Sound.qml: "shot" when a picture is taken at once, "rec"
    // when a recording starts. (Area shots wait on the selection: no sound.)
    signal captured(string kind)

    function shot(mode: string): void {
        const modes = { area: ["area"], screen: ["monitor"], window: ["window"], edit: ["edit-area"], delay: ["delay", "5"] };
        later([shots].concat(modes[mode] ?? ["area"]));
        if (mode === "screen" || mode === "window")
            shutterLater.restart();
        else if (mode === "delay")
            shutterDelayed.restart();
    }
    Timer {
        id: shutterLater
        interval: 300
        onTriggered: root.captured("shot")
    }
    Timer {
        id: shutterDelayed
        interval: 5300
        onTriggered: root.captured("shot")
    }

    function pick(): void {
        later(["sh", "-c", "c=$(hyprpicker -a -n -f hex) && [ -n \"$c\" ] && notify-send --app-name dotshell --urgency low \"Color $c\" 'Copied to the clipboard'"]);
    }

    // area: slurp first (in the recorder's own shell, after the pane is gone).
    function rec(mode: string): void {
        if (recording) {
            stop();
            return;
        }
        Ui.close();
        file = videos + "/" + (mode === "area" ? "area_" : "screen_") + stamp() + ".mp4";
        const sound = audio ? " -a default_output" : "";
        recorder.command = ["sh", "-c", "sleep 0.3; mkdir -p \"$1\"; " + (mode === "area" ? "g=$(slurp -f '%wx%h+%x+%y') || exit 1; " : "") + "exec gpu-screen-recorder " + (mode === "area" ? "-w region -region \"$g\"" : "-w \"$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')\"") + " -f 60" + sound + " -o \"$2\"", "rec", videos, file];
        recorder.running = true;
    }

    function stop(): void {
        if (recorder.running)
            recorder.signal(2); // SIGINT: the recorder finishes the file
    }

    Process {
        id: recorder
        onStarted: {
            root.startedAt = Date.now();
            root.elapsed = 0;
            root.captured("rec");
        }
        onExited: (code, status) => {
            const f = root.file;
            // A cancelled slurp exits 1 before anything was recorded.
            if (root.elapsed >= 1)
                Quickshell.execDetached(["sh", "-c", "[ -s \"$1\" ] && notify-send --app-name dotshell --urgency low 'Recording saved' \"$(basename \"$1\")\"", "rec", f]);
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.recording
        onTriggered: root.elapsed = Math.round((Date.now() - root.startedAt) / 1000)
    }

    function clock(s: int): string {
        const m = Math.floor(s / 60), r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }

    IpcHandler {
        target: "capture"

        function shot(mode: string): void {
            root.shot(mode);
        }
        function rec(mode: string): string {
            const was = root.recording;
            root.rec(mode || "screen");
            return was ? "stopped" : "recording";
        }
        function stop(): void {
            root.stop();
        }
        function pick(): void {
            root.pick();
        }
    }
}
