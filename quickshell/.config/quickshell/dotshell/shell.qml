//@ pragma UseQApplication
// (QApplication: tray menus open through SystemTrayItem.display().)

// Dot Shell: every pane on one shared dot grid. Since Phase 3 it is the whole
// desktop shell: strip, notifications, OSD, launcher, panes, lock, polkit,
// wallpaper, idle and night warmth. Nothing from AGS remains.
//
//   qs -p ~/.config/quickshell/dotshell   run (saving any file here hot-reloads the shell)
//   qs -p ~/.config/quickshell/dotshell ipc show   list IPC targets
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.panes

ShellRoot {
    id: shell

    property bool stripVisible: true

    // Services with no pane of their own: start them with the shell.
    readonly property var services: [Power, Idle, Night, DropTerm, Lock, DotBus]

    Wallpaper {}
    World {}

    Variants {
        model: shell.stripVisible ? Quickshell.screens : []

        TopStrip {}
    }

    ToastStack {}
    OsdPane {}
    MessagesPane {}
    LauncherPane {}
    SessionPane {}
    CheatsheetPane {}
    CalendarPane {}
    AudioPane {}
    BrightnessPane {}
    WifiPane {}
    BluetoothPane {}
    BatteryPane {}
    ErasPane {}
    PackagesPane {}
    PolkitPane {}
    LockScreen {}

    IpcHandler {
        target: "pane"

        // dotshell ipc call pane toggle launcher
        function toggle(name: string): string {
            if (!Ui.names.includes(name))
                return "unknown pane; one of: " + Ui.names.join(", ");
            Ui.toggle(name, null);
            return Ui.pane === name ? "open" : "closed";
        }
        function close(): void {
            Ui.close();
        }
    }

    IpcHandler {
        target: "night"

        function toggle(): string {
            Night.toggle();
            return Tokens.night ? "on" : "off";
        }
    }

    IpcHandler {
        target: "strip"

        function toggle(): void {
            shell.stripVisible = !shell.stripVisible;
        }
        function show(): void {
            shell.stripVisible = true;
        }
        function hide(): void {
            shell.stripVisible = false;
        }
    }

    IpcHandler {
        target: "shell"

        function reload(): void {
            Quickshell.reload(true);
        }
    }
}
