//@ pragma UseQApplication
// (QApplication: tray menus open through SystemTrayItem.display().)

// Dot Shell: every pane on one shared dot grid. Since Phase 3 it is the whole
// desktop shell: strip, notifications, OSD, launcher, panes, lock, polkit,
// wallpaper, idle and the screen shader. Nothing from AGS remains.
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

    // Services with no pane of their own: start them with the shell.
    readonly property var services: [Power, Idle, ScreenShader, DropTerm, Lock, DotBus, Export, WsFx, LedFx, Clip, Capture, Sound, Wall]

    Wallpaper {}
    World {}
    WindowFx {}
    WorkspaceFx {}
    WindowBorders {}

    SideBar {}

    Variants {
        model: Tokens.top ? Quickshell.screens : []

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
    MediaPane {}
    CapturePane {}
    ClipPane {}
    OverviewPane {}
    PolkitPane {}
    Scene {}
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
        // dotshell ipc call pane page eras walls
        function page(name: string, pageName: string): string {
            if (!Ui.names.includes(name))
                return "unknown pane; one of: " + Ui.names.join(", ");
            Ui.togglePage(name, pageName, null);
            return Ui.pane === name ? "open" : "closed";
        }
        function close(): void {
            Ui.close();
        }
    }

    IpcHandler {
        target: "night"

        function toggle(): string {
            ScreenShader.toggle();
            return Tokens.night ? "on" : "off";
        }
    }

    IpcHandler {
        target: "strip"

        function toggle(): void {
            Tokens.set("top", String(!Tokens.top));
        }
        function show(): void {
            Tokens.set("top", "true");
        }
        function hide(): void {
            Tokens.set("top", "false");
        }
    }

    IpcHandler {
        target: "shell"

        function reload(): void {
            Quickshell.reload(true);
        }
    }
}
