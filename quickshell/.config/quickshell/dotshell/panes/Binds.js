// Turns `hyprctl -j binds` into cheatsheet groups.
// Each bind is described by its `bindd` description when there is one,
// otherwise by a guess from the dispatcher. Binds that differ only in a
// digit key ("Go to workspace" on 1..0) collapse into one line ("1-0").
.pragma library

const MODS = [[64, "SUP"], [4, "CTL"], [8, "ALT"], [1, "SHF"]];

const KEYS = {
    grave: "`", equal: "=", minus: "-", slash: "/", space: "SPACE", Return: "ENTER",
    Print: "PRTSC", BackSpace: "BKSP", Backspace: "BKSP", Tab: "TAB", Escape: "ESC",
    KP_ADD: "NUM+", KP_SUBTRACT: "NUM-", left: "LEFT", right: "RIGHT", up: "UP", down: "DOWN",
    XF86AudioRaiseVolume: "VOL+", XF86AudioLowerVolume: "VOL-", XF86AudioMute: "MUTE",
    XF86AudioPlay: "PLAY", XF86AudioNext: "NEXT", XF86AudioPrev: "PREV",
    XF86MonBrightnessUp: "BRT+", XF86MonBrightnessDown: "BRT-", XF86PowerOff: "POWER",
    mouse_down: "WHEEL DN", mouse_up: "WHEEL UP", "mouse:272": "LMB", "mouse:273": "RMB", "mouse:274": "MMB"
};

const ORDER = ["Shell", "Apps", "Windows", "Workspaces", "Media", "Audio & display", "Capture", "Power", "Zoom", "Other"];

function keyName(b) {
    const k = b.key || (b.keycode ? "code:" + b.keycode : "");
    return KEYS[k] || k.toUpperCase();
}

function mods(mask) {
    return MODS.filter(([bit]) => (mask & bit) !== 0).map(([, n]) => n);
}

function guess(b) {
    const a = (b.arg || "").trim();
    switch (b.dispatcher) {
    case "workspace":
        return a === "previous" ? "Previous workspace" : a === "empty" ? "Empty workspace" : a === "e+1" ? "Next workspace" : a === "e-1" ? "Previous workspace" : "Go to workspace";
    case "movetoworkspace":
        return "Move window to workspace";
    case "movetoworkspacesilent":
        return "Send window to workspace";
    case "movefocus":
        return "Focus " + ({ l: "left", r: "right", u: "up", d: "down" }[a] || a);
    case "movewindow":
        return "Move window (drag)";
    case "resizewindow":
        return "Resize window (drag)";
    case "killactive":
        return "Close window";
    case "fullscreen":
        return "Fullscreen";
    case "togglefloating":
        return "Toggle floating";
    case "togglegroup":
        return "Toggle group";
    case "layoutmsg":
        return "Layout: " + a;
    case "exec": {
        const cmd = a.split(/\s+/)[0] || a;
        return "Run " + (cmd.split("/").pop() || cmd);
    }
    default:
        return b.dispatcher + (a ? " " + a : "");
    }
}

function groupOf(b, action) {
    const a = action.toLowerCase();
    const d = b.dispatcher;
    if (/workspace/.test(d) || a.includes("workspace"))
        return "Workspaces";
    if (["movefocus", "movewindow", "resizewindow", "killactive", "fullscreen", "togglefloating", "togglegroup", "layoutmsg"].includes(d))
        return "Windows";
    if (/screenshot|capture|colou?r/.test(a))
        return "Capture";
    if (/zoom/.test(a))
        return "Zoom";
    if (/volume|mute|brightness|night/.test(a))
        return "Audio & display";
    if (/track|play|pause/.test(a))
        return "Media";
    if (/lock|suspend|power|reboot|session|logout/.test(a))
        return "Power";
    if (/launcher|messages|disturb|shortcut|strip|era|dot shell|dropdown|caffeine|calendar|pane/.test(a))
        return "Shell";
    if (d === "exec")
        return "Apps";
    return "Other";
}

function group(binds) {
    const rows = [];
    const byKey = new Map();
    for (const b of binds) {
        const action = (b.has_description && b.description) ? b.description : guess(b);
        const m = mods(b.modmask).join("+");
        const k = keyName(b);
        if (!k)
            continue;
        const merge = m + "|" + action;
        if (/^[0-9]$/.test(k) && byKey.has(merge)) {
            byKey.get(merge).digits.push(k);
            continue;
        }
        const row = { mods: m, key: k, action: action, group: groupOf(b, action), digits: /^[0-9]$/.test(k) ? [k] : null };
        if (row.digits)
            byKey.set(merge, row);
        rows.push(row);
    }

    const seen = new Set();
    const groups = {};
    for (const r of rows) {
        let key = r.key;
        if (r.digits && r.digits.length > 1) {
            const sorted = r.digits.slice().sort((x, y) => (x === "0" ? 10 : +x) - (y === "0" ? 10 : +y));
            key = sorted[0] + "-" + sorted[sorted.length - 1];
        }
        const combo = (r.mods ? r.mods + "+" : "") + key;
        const id = combo + "|" + r.action;
        if (seen.has(id))
            continue;
        seen.add(id);
        (groups[r.group] = groups[r.group] || []).push({ combo: combo, action: r.action });
    }
    return ORDER.filter(g => groups[g]).map(g => ({ name: g, items: groups[g] }));
}
