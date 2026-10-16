pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Which pane is open, and on which screen. One pane at a time, like one
// sign board: opening a pane closes the previous one.
//
//   Ui.toggle("wifi")            from QML (strip glyphs)
//   dotshell ipc call pane toggle launcher   from binds
Singleton {
    id: root

    // "" = nothing open. Names: launcher session notifs cheatsheet calendar
    // audio brightness wifi bluetooth battery eras packages media
    property string pane: ""
    property ShellScreen screen: focusedScreen()

    // Top strips register themselves so a pane's click-outside grab lets
    // clicks on the strip through (clicking another glyph switches panes).
    property list<QtObject> strips: []

    readonly property var names: ["launcher", "session", "notifs", "cheatsheet", "calendar", "audio", "brightness", "wifi", "bluetooth", "battery", "eras", "packages", "media"]

    function focusedScreen(): ShellScreen {
        const name = Hyprland.focusedMonitor?.name;
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0] ?? null;
    }

    function open(name: string, onScreen: ShellScreen): void {
        screen = onScreen ?? focusedScreen();
        pane = name;
    }

    function toggle(name: string, onScreen: ShellScreen): void {
        if (pane === name)
            close();
        else
            open(name, onScreen);
    }

    function close(): void {
        pane = "";
    }

    function addStrip(win: QtObject): void {
        strips = [...strips, win];
    }

    function removeStrip(win: QtObject): void {
        strips = strips.filter(w => w !== win);
    }
}
