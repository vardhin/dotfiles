pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Every call the shell makes into Hyprland, in either config language.
//
// Hyprland 0.55+ reads hyprland.lua when it exists. Under Lua, `hyprctl
// keyword` is refused and `dispatch X` means `hl.dispatch(X)`, so legacy
// strings ("workspace 3") fail. This service asks Hyprland which config
// provider it runs (`hyprctl -j status`, configProvider) and speaks that one,
// so the shell works on hyprland.lua and on an old hyprland.conf alike.
//
// Callers never build dispatcher strings themselves: they call the functions
// below, which carry both forms.
Singleton {
    id: root

    // True once Hyprland has said it runs a Lua config.
    property bool lua: false
    property bool known: false

    Process {
        id: status
        running: true
        command: ["hyprctl", "-j", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.lua = JSON.parse(text).configProvider === "lua";
                } catch (e) {
                    root.lua = false; // pre-0.55 answers "unknown request"
                }
                root.known = true;
            }
        }
    }

    // A config reload may switch between hyprland.lua and hyprland.conf.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded")
                status.running = true;
        }
    }

    // ── Lua quoting ─────────────────────────────────────────────────
    // A JS value as a Lua literal: strings, numbers, booleans, arrays, tables.
    function lit(v: var): string {
        if (v === null || v === undefined)
            return "nil";
        if (typeof v === "boolean" || typeof v === "number")
            return String(v);
        if (typeof v === "string")
            return '"' + v.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n") + '"';
        if (Array.isArray(v))
            return "{" + v.map(lit).join(", ") + "}";
        return "{" + Object.keys(v).map(k => (/^[A-Za-z_][A-Za-z0-9_]*$/.test(k) ? k : "[" + lit(k) + "]") + " = " + lit(v[k])).join(", ") + "}";
    }

    // ── Raw ─────────────────────────────────────────────────────────
    function dsp(luaExpr: string, legacy: string): void {
        Hyprland.dispatch(lua ? luaExpr : legacy);
    }
    // Lua code run in Hyprland's own state (no-op on a legacy config).
    function luaEval(code: string): void {
        if (lua)
            Quickshell.execDetached(["hyprctl", "eval", code]);
    }

    // ── Options ─────────────────────────────────────────────────────
    // set({ general: { gaps_in: 5, gaps_out: 5 } }): one hl.config() under
    // Lua, one `keyword section:key value` per leaf under hyprlang.
    function set(tree: var): void {
        if (lua) {
            luaEval("hl.config(" + lit(tree) + ")");
            return;
        }
        const kw = [];
        const walk = (node, path) => {
            for (const k of Object.keys(node)) {
                const v = node[k];
                if (v !== null && typeof v === "object" && !Array.isArray(v))
                    walk(v, path.concat(k));
                else
                    kw.push(`keyword ${path.concat(k).join(":")} ${v === "" ? "[[EMPTY]]" : v}`);
            }
        };
        walk(tree, []);
        if (kw.length)
            Quickshell.execDetached(["hyprctl", "--batch", kw.join(" ; ")]);
    }

    // One animation leaf. off: animation(leaf, false); on: with speed, curve
    // (a bezier name) and an optional style.
    function animation(leaf: string, on: bool, speed: real, curve: string, style: string): void {
        if (lua) {
            const t = on ? { leaf: leaf, enabled: true, speed: speed, bezier: curve } : { leaf: leaf, enabled: false };
            if (on && style)
                t.style = style;
            luaEval("hl.animation(" + lit(t) + ")");
        } else {
            const v = on ? `${leaf},1,${speed},${curve}${style ? "," + style : ""}` : `${leaf},0`;
            Quickshell.execDetached(["hyprctl", "keyword", "animation", v]);
        }
    }

    // ── Dispatchers ─────────────────────────────────────────────────
    // `arg`: what the workspace dispatcher takes: 3, e+1, previous, empty, name:x.
    function workspace(arg: string): void {
        dsp(`hl.dsp.focus({ workspace = ${lit(arg)} })`, "workspace " + arg);
    }
    // Move a window (default: the focused one) to a workspace. follow = false
    // is movetoworkspacesilent.
    function moveTo(arg: string, follow: bool, window: string): void {
        const t = { workspace: arg, follow: follow };
        if (window)
            t.window = window;
        dsp(`hl.dsp.window.move(${lit(t)})`, (follow ? "movetoworkspace " : "movetoworkspacesilent ") + arg + (window ? "," + window : ""));
    }
    function focusWindow(selector: string): void {
        dsp(`hl.dsp.focus({ window = ${lit(selector)} })`, "focuswindow " + selector);
    }
    function closeWindow(selector: string): void {
        dsp(`hl.dsp.window.close({ window = ${lit(selector)} })`, "closewindow " + selector);
    }
    function dpms(on: bool): void {
        dsp(`hl.dsp.dpms({ action = "${on ? "on" : "off"}" })`, on ? "dpms on" : "dpms off");
    }
    function exit(): void {
        dsp("hl.dsp.exit()", "exit");
    }
    // sendShortcut("CTRL SHIFT", "V"): to the focused window.
    function sendShortcut(mods: string, key: string): void {
        dsp(`hl.dsp.send_shortcut({ mods = ${lit(mods)}, key = ${lit(key)} })`, `sendshortcut ${mods}, ${key}, activewindow`);
    }

    // A queued workspace switch as data, so it can wait for a snapshot
    // (services/WsFx.qml, panes/WorkspaceFx.qml): { kind: "go" | "move", arg }.
    function run(req: var): void {
        if (!req)
            return;
        if (req.kind === "move")
            moveTo(req.arg, true, "");
        else
            workspace(req.arg);
    }
}
