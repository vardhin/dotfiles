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
    // audio brightness wifi bluetooth battery eras packages media capture clip
    // overview
    property string pane: ""
    // Which page a pane with pages opens on ("" = its own default), e.g.
    // the era switcher's "walls"; set by openPage / togglePage.
    property string page: ""
    // The pane out over its panel (Pane.qml `from`): open, or still
    // shrinking back into it. The panel stays hidden until it is "".
    property string grown: ""
    // Where the click that opened the pane came from: "rail" or "strip" for
    // a docked item, "" otherwise. Panes that sit under the strip (the
    // calendar) move beside the rail when it is "rail".
    property string from: ""
    property ShellScreen screen: focusedScreen()

    // Top strips register themselves so a pane's click-outside grab lets
    // clicks on the strip through (clicking another glyph switches panes).
    property list<QtObject> strips: []

    readonly property var names: ["launcher", "session", "notifs", "cheatsheet", "calendar", "audio", "brightness", "wifi", "bluetooth", "battery", "eras", "packages", "media", "capture", "clip", "overview", "panels"]

    function focusedScreen(): ShellScreen {
        const name = Hyprland.focusedMonitor?.name;
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0] ?? null;
    }

    function open(name: string, onScreen: ShellScreen): void {
        page = "";
        screen = onScreen ?? focusedScreen();
        pane = name;
    }

    function openPage(name: string, pageName: string, onScreen: ShellScreen): void {
        screen = onScreen ?? focusedScreen();
        page = pageName;
        pane = name;
    }

    // Closes the pane only when it is already open on that page.
    function togglePage(name: string, pageName: string, onScreen: ShellScreen): void {
        if (pane === name && page === pageName)
            close();
        else
            openPage(name, pageName, onScreen);
    }

    function toggle(name: string, onScreen: ShellScreen): void {
        if (pane === name)
            close();
        else
            open(name, onScreen);
    }

    function close(): void {
        pane = "";
        from = "";
    }

    function addStrip(win: QtObject): void {
        strips = [...strips, win];
    }

    function removeStrip(win: QtObject): void {
        strips = strips.filter(w => w !== win);
    }
}
