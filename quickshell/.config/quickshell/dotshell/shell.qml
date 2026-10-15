//@ pragma UseQApplication
// (QApplication: tray menus open through SystemTrayItem.display().)

// Dot Shell: every pane on one shared dot grid.
// Phase 2 runs beside AGS: only the top LED strip lives here so far.
//
//   qs -p ~/.config/quickshell/dotshell   run (saving any file here hot-reloads the shell)
//   qs -p ~/.config/quickshell/dotshell ipc show   list IPC targets
import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: shell

    property bool stripVisible: true

    Variants {
        model: shell.stripVisible ? Quickshell.screens : []

        TopStrip {}
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
