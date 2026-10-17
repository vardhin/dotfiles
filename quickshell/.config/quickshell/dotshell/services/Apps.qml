pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs

// Launching apps from the launcher and the dock.
//   Already running = jump: launching an app that has a window focuses that
//   window (Hyprland brings its workspace) instead of opening a second copy.
//   forceNew (Shift Enter): a new window, on a new empty workspace.
// Windows that open on the home workspace are moved to the next empty one
// by Hyprland itself (hypr/.config/hypr/lua/dotshell.lua), so keybinds and
// `dot` launches leave home clear too.
Singleton {
    id: root

    // A query for the launcher to open with (the dock's search, `find`).
    property string query: ""

    function entry(id: string): var {
        if (!id)
            return null;
        return DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id) ?? null;
    }

    // The windows of an app: by its desktop id, its StartupWMClass, or a class
    // that looks it up to the same entry.
    function windowsOf(e: var, cls: string): var {
        const wins = Feeds.windows;
        const want = [cls, e?.id, e?.startupClass].filter(x => x).map(x => String(x).toLowerCase().replace(/\.desktop$/, ""));
        return wins.filter(w => {
            const c = w.cls.toLowerCase();
            if (want.includes(c))
                return true;
            const we = Feeds.entryFor(w.cls);
            return e && we && we.id === e.id;
        });
    }

    function focus(w: var): void {
        Hypr.focusWindow("address:" + w.addr);
    }

    function launch(id: string, forceNew: bool): void {
        const e = entry(id);
        if (!e) {
            console.warn("dotshell: no desktop entry", id);
            return;
        }
        const wins = windowsOf(e, "");
        if (!forceNew && wins.length) {
            focus(wins.find(w => w.active) ?? wins[0]);
            return;
        }
        if (forceNew)
            Hypr.workspace("empty");
        e.execute();
    }

    // The dock's running tiles: focus the app's window (cycling through
    // them if it is already focused), or launch it if it has none.
    function jump(cls: string): void {
        const e = Feeds.entryFor(cls);
        const wins = windowsOf(e, cls);
        if (!wins.length) {
            if (e)
                e.execute();
            return;
        }
        const i = wins.findIndex(w => w.active);
        focus(wins[(i + 1) % wins.length]);
    }
}
