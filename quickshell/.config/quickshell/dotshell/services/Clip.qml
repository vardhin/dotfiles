pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Clipboard history for the CLIP pane (Super V): every text copy, newest
// first, kept in ${XDG_STATE_HOME}/dotshell/clipboard.json (100 entries,
// 64 KB each). Copies a password manager marks as secret
// (x-kde-passwordManagerHint, KeePassXC and others) are never recorded.
// Images are not kept.
//
//   dotshell ipc call clip clear
//   dotshell ipc call clip forget "some text"
Singleton {
    id: root

    readonly property int keep: 100
    readonly property var items: store.items ?? []

    // Put text back on the clipboard; `paste` also sends the paste shortcut to
    // the focused window once the pane has closed (Ctrl Shift V in terminals).
    function use(text: string, paste: bool): void {
        Ui.close();
        Quickshell.execDetached(["wl-copy", "--", text]);
        if (paste)
            Quickshell.execDetached(["sh", "-c", "sleep 0.2; c=$(hyprctl activewindow -j | jq -r '.class // \"\"'); case $c in *ghostty*|*kitty*|foot*|*lacritty*|*wezterm*|*konsole*) m='CTRL SHIFT' ;; *) m=CTRL ;; esac; hyprctl dispatch sendshortcut \"$m, V, activewindow\" >/dev/null"]);
    }

    function remove(text: string): void {
        store.items = items.filter(x => x.t !== text);
    }

    function clear(): void {
        store.items = [];
    }

    function add(text: string): void {
        if (!text || !text.trim())
            return;
        store.items = [{ t: text, at: Date.now() }].concat(items.filter(x => x.t !== text)).slice(0, keep);
    }

    FileView {
        path: Tokens.dirReady ? Tokens.dir + "/clipboard.json" : ""
        // Only you can read the history (writes keep the mode).
        onLoaded: Quickshell.execDetached(["chmod", "600", path])
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: store
            property var items: []
        }
    }

    // One JSON string per copy on stdout (jq keeps the UTF-8 intact).
    Process {
        id: watcher
        running: Tokens.dirReady
        command: ["wl-paste", "--type", "text", "--watch", "sh", "-c", "wl-paste --list-types 2>/dev/null | grep -q passwordManagerHint && exit 0; head -c 65536 | jq -Rsc ."]
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.add(JSON.parse(line));
                } catch (e) {}
            }
        }
        // wl-paste exits when the compositor restarts; come back with it.
        onExited: restart.start()
    }
    Timer {
        id: restart
        interval: 2000
        onTriggered: watcher.running = Tokens.dirReady
    }

    IpcHandler {
        target: "clip"

        function clear(): void {
            root.clear();
        }
        function forget(text: string): void {
            root.remove(text);
        }
    }
}
