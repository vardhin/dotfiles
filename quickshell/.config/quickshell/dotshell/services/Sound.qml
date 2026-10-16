pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import qs

// The era's UI sounds (the `sounds` token: off | soft | full). Export runs
// `dotsound` for the era on screen, which writes
//   ${XDG_STATE_HOME}/dotshell/sounds/<era>/{open,close,toast,alert,flip,ws,shutter,rec}.wav
// and this plays them with pw-play: a pane opening or closing, a toast (or
// an alert for a critical one), the era cascade, a workspace switch, a
// screenshot, a recording starting. Nothing plays while the screen is locked,
// and one event never repeats faster than its gap.
Singleton {
    id: root

    readonly property string mode: Tokens.sounds
    readonly property real volume: mode === "full" ? 0.8 : 0.32
    readonly property string era: Tokens.current.id ?? Tokens.era
    readonly property string dir: Tokens.dir + "/sounds/" + era

    property var last: ({})

    function play(event: string): void {
        if (mode === "off" || Lock.locked)
            return;
        const now = Date.now();
        const gap = event === "ws" ? 120 : event === "flip" ? 900 : 70;
        if (now - (last[event] ?? 0) < gap)
            return;
        last[event] = now;
        Quickshell.execDetached(["pw-play", "--volume", String(volume), dir + "/" + event + ".wav"]);
    }

    // ── Hooks ───────────────────────────────────────────────────────
    Connections {
        target: Ui
        function onPaneChanged() {
            root.play(Ui.pane !== "" ? "open" : "close");
        }
    }
    Connections {
        target: Notifs
        function onArrived(n) {
            root.play(n.urgency === NotificationUrgency.Critical ? "alert" : "toast");
        }
    }
    Connections {
        target: Tokens
        function onFlipStarting() {
            root.play("flip");
        }
    }
    // Not the first workspace the shell sees at login.
    readonly property int wsId: Hyprland.focusedWorkspace?.id ?? 0
    property int lastWs: 0
    onWsIdChanged: {
        if (lastWs > 0 && wsId > 0)
            play("ws");
        lastWs = wsId;
    }
    Connections {
        target: Capture
        function onCaptured(kind) {
            root.play(kind === "rec" ? "rec" : "shutter");
        }
    }
}
