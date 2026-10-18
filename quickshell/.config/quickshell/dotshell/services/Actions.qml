pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import qs

// Panel actions: what a click in a panel layout (Templates.js) does. An
// action is one line, a verb and its argument, with {fields} already filled
// in from the feed. Feeds pushed by dotd or scripts can carry actions too.
//   ws N | ws empty            go to a workspace (with the dissolve)
//   pane NAME | launcher       toggle a pane
//   media toggle|next|previous|seek F
//   launch DESKTOP-ID          on the next empty workspace (from home)
//   jump CLASS                 focus the app's window, or launch it
//   launch-query TEXT          the launcher with this query
//   open PATH | reveal PATH | edit PATH | copyimg PATH | ocr PATH | trash PATH
//   paste N | clip forget N | clip clear
//   todo add TEXT | todo toggle N | todo rm N
//   dnd toggle | notifs clear
//   caffeine toggle|on|off | caffeine for MINUTES
//   capture shot area|window|screen | capture rec area|screen | capture stop
//   capture audio | capture pick
//   power profile 0|1|2
//   tray ID                    activate a tray item
//   pin CLASS | unpin ID | movehere ADDR | closeall CLASS
//   video bad                  the matched video is wrong; try the next
//   tv play|queue|next ID | tv mix | tv window | tv library | tv skip
//   find TEXT                  the launcher in files mode (dotd's index)
//   dotd VERB ARGS             passed to dotd's socket
//   run CMD                    sh -c CMD
// Panel verbs (panel expand|fold|pop|keys) are taken by DeskPanel first.
Singleton {
    id: root

    function arg(a: string): string {
        return a.replace(/^\S+\s*/, "");
    }

    function sh(cmd: var): void {
        Quickshell.execDetached(cmd);
    }

    function run(action: string): string {
        const a = String(action ?? "").trim();
        if (!a)
            return "empty action";
        const words = a.split(/\s+/);
        const verb = words[0], rest = arg(a), w1 = words[1] ?? "";
        switch (verb) {
        case "ws":
            WsFx.go(rest || "1");
            return "ok";
        case "pane":
            Ui.toggle(rest, null);
            return "ok";
        case "launcher":
            Ui.toggle("launcher", null);
            return "ok";
        case "media":
            if (w1 === "toggle")
                Media.toggle();
            else if (w1 === "next")
                Media.next();
            else if (w1 === "previous" || w1 === "prev")
                Media.previous();
            else if (w1 === "seek")
                Media.seekTo(Number(words[2] ?? 0));
            return "ok";
        case "launch":
            Apps.launch(rest, false);
            return "ok";
        case "jump":
            Apps.jump(rest);
            return "ok";
        case "launch-query":
            Apps.query = rest;
            Ui.open("launcher", null);
            return "ok";
        case "open":
            sh(["xdg-open", rest]);
            return "ok";
        case "reveal":
            sh(["nautilus", "--select", rest]);
            return "ok";
        case "edit":
            sh(["sh", "-c", "command -v satty >/dev/null && satty --filename \"$1\" || xdg-open \"$1\"", "sh", rest]);
            return "ok";
        case "copyimg":
            sh(["sh", "-c", "wl-copy < \"$1\"", "sh", rest]);
            return "ok";
        case "ocr":
            ocr.command = ["sh", "-c", "tesseract \"$1\" - -l eng+tam 2>/dev/null || tesseract \"$1\" - 2>/dev/null", "sh", rest];
            ocr.running = true;
            return "ok";
        case "trash":
            sh(["gio", "trash", rest]);
            Qt.callLater(Feeds.rescanShots);
            return "ok";
        case "paste": {
            const t = Clip.items[Number(rest)];
            if (t !== undefined)
                Clip.use(t, true);
            return "ok";
        }
        case "clip":
            if (w1 === "clear")
                Clip.clear();
            else if (w1 === "forget") {
                const t = Clip.items[Number(words[2])];
                if (t !== undefined)
                    Clip.remove(t);
            }
            return "ok";
        case "todo":
            if (w1 === "add")
                Todo.add(arg(rest));
            else if (w1 === "toggle")
                Todo.toggle(Number(words[2]));
            else if (w1 === "rm")
                Todo.remove(Number(words[2]));
            return "ok";
        case "dnd":
            Notifs.setDnd(!Notifs.dnd);
            return "ok";
        case "notifs":
            if (w1 === "clear") {
                Notifs.clearLive();
                Notifs.clearHistory();
            }
            return "ok";
        case "caffeine":
            if (w1 === "for")
                Feeds.caffeineFor(Number(words[2]) || 60);
            else if (w1 === "on")
                Feeds.caffeineFor(0);
            else if (w1 === "off")
                Idle.setCaffeine(false);
            else
                Idle.setCaffeine(!Idle.caffeine);
            return "ok";
        case "capture":
            if (w1 === "shot")
                Capture.shot(({ area: "area", window: "window", screen: "fullscreen" })[words[2]] ?? "area");
            else if (w1 === "rec")
                Capture.rec(words[2] === "area" ? "area" : "screen");
            else if (w1 === "stop")
                Capture.stop();
            else if (w1 === "audio")
                Capture.audio = !Capture.audio;
            else if (w1 === "pick")
                Capture.pick();
            Qt.callLater(Feeds.rescanShots);
            return "ok";
        case "power":
            if (w1 === "profile")
                Power.setProfile(Number(words[2]));
            return "ok";
        case "tray": {
            const it = SystemTray.items.values.find(i => i.id === rest);
            if (it)
                it.activate();
            return "ok";
        }
        case "pin":
            Panels.pin(Feeds.entryFor(rest)?.id ?? rest, true);
            return "ok";
        case "unpin":
            Panels.pin(rest, false);
            return "ok";
        case "movehere":
            Hypr.moveTo(String(Hyprland.focusedWorkspace?.id ?? 1), false, "address:" + rest);
            return "ok";
        case "closeall":
            for (const t of Feeds.windows.filter(x => x.cls === rest))
                Hypr.closeWindow("address:" + t.addr);
            return "ok";
        case "video":
            if (w1 === "bad")
                VideoMatch.markBad();
            return "ok";
        case "find":
            Apps.query = "f " + rest;
            Ui.open("launcher", null);
            return "ok";
        case "dotd":
            Dotd.send(rest);
            return "ok";
        case "tv":
            if (w1 === "play" || w1 === "queue" || w1 === "next")
                Tv.play(words[2] ?? "", w1 === "play" ? "" : w1);
            else if (w1 === "mix")
                Tv.mix(!Tv.status.mix);
            else if (w1 === "window")
                Tv.open();
            else if (w1 === "library")
                Ui.openPage("media", "tv", null);
            else if (w1 === "skip")
                Media.next();
            return "ok";
        case "run":
            sh(["sh", "-c", rest]);
            return "ok";
        case "files":
            sh(["nautilus", "--new-window"]);
            return "ok";
        default:
            console.warn("dotshell: unknown panel action", a);
            return "unknown action " + verb;
        }
    }

    Process {
        id: ocr
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                Feeds.ocrText = t;
                if (t) {
                    Quickshell.execDetached(["wl-copy", t]);
                    Notify.send("Text copied", t.slice(0, 120), {
                        app: "dotshell-ocr",
                        urgency: "low",
                        transient: true
                    });
                }
            }
        }
    }
}
