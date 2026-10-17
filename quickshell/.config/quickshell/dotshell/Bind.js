.pragma library

// Bindings for panel layouts (Templates.js, PanelNode.qml): how a field's
// text, value or condition reads its feed.
//
// A context is the feed object. Inside a list item it is the item, with the
// feed behind it, so a path is looked up in the item first:
//   "title"         a field of the item or the feed
//   "art.small"     a nested field          "items.0.name"   an array index
//   "."             the item itself         "$.dnd"          the feed only
//   "@text"         a field of the panel     "~title"         the era's word
// In text, {path} is replaced, with an optional format after a bar and a
// default after an equals sign:
//   "{pos|clock} / {len|clock}"   "{cpu|pct}%"   "{~title=TODAY}"
// Formats: upper lower clock pct int fixed1 gb size ago base dir day date
//          pad2 bool
// Conditions ("when"): "playing", "!dnd", "count>0", "state==charging".

function lookup(obj, parts) {
    let v = obj;
    for (const p of parts) {
        if (v === null || v === undefined)
            return undefined;
        v = v[p];
    }
    return v;
}

function get(ctx, path) {
    if (ctx === null || ctx === undefined || path === undefined || path === null)
        return undefined;
    path = String(path).trim();
    if (path === ".")
        return ctx.$item !== undefined ? ctx.$item : ctx;
    if (path[0] === "~") {
        const key = path.slice(1);
        return ctx["~"] ? ctx["~"][key] : undefined;
    }
    if (path[0] === "@")
        return ctx["@"] ? lookup(ctx["@"], path.slice(1).split(".")) : undefined;
    if (path.startsWith("$."))
        return lookup(ctx.$root !== undefined ? ctx.$root : ctx, path.slice(2).split("."));
    const parts = path.split(".");
    if (ctx.$item !== undefined) {
        const v = lookup(ctx.$item, parts);
        if (v !== undefined)
            return v;
        return lookup(ctx.$root, parts);
    }
    return lookup(ctx, parts);
}

// A child context for one list element.
function item(ctx, element, index) {
    const root = ctx && ctx.$root !== undefined ? ctx.$root : ctx;
    const it = (element !== null && typeof element === "object") ? Object.assign({ $index: index }, element) : { $value: element, $index: index };
    return { $item: it, $root: root, "~": ctx ? ctx["~"] : undefined, "@": ctx ? ctx["@"] : undefined };
}

function pad2(n) {
    return String(n).padStart(2, "0");
}

function clock(s) {
    s = Math.floor(Number(s) || 0);
    if (s <= 0)
        return "0:00";
    const h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60, sec = s % 60;
    return (h > 0 ? h + ":" + pad2(m) : m) + ":" + pad2(sec);
}

function size(b) {
    b = Number(b) || 0;
    const u = ["B", "K", "M", "G", "T"];
    let i = 0;
    while (b >= 1000 && i < u.length - 1) {
        b /= 1024;
        i++;
    }
    return (i > 0 && b < 10 ? b.toFixed(1) : Math.round(b)) + u[i];
}

function ago(ms) {
    const s = Math.max(0, (Date.now() - Number(ms)) / 1000);
    if (s < 60)
        return "NOW";
    if (s < 3600)
        return Math.floor(s / 60) + "M";
    if (s < 86400)
        return Math.floor(s / 3600) + "H";
    return Math.floor(s / 86400) + "D";
}

function format(v, f) {
    switch (f) {
    case "upper":
        return String(v === undefined || v === null ? "" : v).toUpperCase();
    case "lower":
        return String(v === undefined || v === null ? "" : v).toLowerCase();
    case "clock":
        return clock(v);
    case "pct":
        return String(Math.round((Number(v) || 0) * 100));
    case "int":
        return String(Math.round(Number(v) || 0));
    case "fixed1":
        return (Number(v) || 0).toFixed(1);
    case "gb":
        return (Number(v) || 0).toFixed(1) + "G";
    case "size":
        return size(v);
    case "ago":
        return v ? ago(v) : "";
    case "base":
        return String(v || "").replace(/\/+$/, "").split("/").pop();
    case "dir":
        return String(v || "").replace(/\/[^/]*$/, "").replace(/^\/home\/[^/]+/, "~");
    case "pad2":
        return pad2(Math.round(Number(v) || 0));
    case "bool":
        return v ? "ON" : "OFF";
    default:
        return v === undefined || v === null ? "" : String(v);
    }
}

// "{a|upper} and {b=none}" with values from ctx.
function text(ctx, s) {
    if (s === undefined || s === null)
        return "";
    s = String(s);
    if (s.indexOf("{") < 0)
        return s;
    return s.replace(/\{([^{}]+)\}/g, (m, expr) => {
        // {path|fmt|fmt=default}; a default of ~word is the era's word, and
        // takes formats of its own: {title=~idle|upper}.
        let def = null;
        const eq = expr.indexOf("=");
        if (eq >= 0) {
            def = expr.slice(eq + 1);
            expr = expr.slice(0, eq);
        }
        const bar = expr.split("|");
        let v = get(ctx, bar[0]);
        let fmts = bar.slice(1);
        if (v === undefined || v === null || v === "" || (Array.isArray(v) && v.length === 0)) {
            if (def === null)
                return "";
            const d = def.split("|");
            v = d[0][0] === "~" ? get(ctx, d[0]) : d[0];
            if (v === undefined || v === null)
                v = "";
            fmts = d.slice(1);
        }
        if (Array.isArray(v))
            v = v.join(" · ");
        for (const f of fmts)
            v = format(v, f.trim());
        return String(v);
    });
}

// A number: a literal, or a path to one.
function num(ctx, v, fallback) {
    if (typeof v === "number")
        return v;
    if (v === undefined || v === null || v === "")
        return fallback === undefined ? 0 : fallback;
    const n = Number(get(ctx, v));
    return isNaN(n) ? (fallback === undefined ? 0 : fallback) : n;
}

function truth(ctx, cond) {
    if (cond === undefined || cond === null || cond === "")
        return true;
    if (typeof cond === "boolean")
        return cond;
    cond = String(cond).trim();
    if (cond.indexOf("||") >= 0)
        return cond.split("||").some(c => truth(ctx, c));
    if (cond.indexOf("&&") >= 0)
        return cond.split("&&").every(c => truth(ctx, c));
    if (cond[0] === "!")
        return !truth(ctx, cond.slice(1));
    const m = cond.match(/^([^<>=!]+)(==|!=|>=|<=|>|<)(.*)$/);
    if (m) {
        const a = get(ctx, m[1].trim()), b = m[3].trim();
        const na = Number(a), nb = Number(b);
        const numeric = !isNaN(na) && !isNaN(nb) && b !== "";
        switch (m[2]) {
        case "==":
            return numeric ? na === nb : String(a) === b;
        case "!=":
            return numeric ? na !== nb : String(a) !== b;
        case ">":
            return na > nb;
        case "<":
            return na < nb;
        case ">=":
            return na >= nb;
        case "<=":
            return na <= nb;
        }
    }
    const v = get(ctx, cond);
    if (Array.isArray(v))
        return v.length > 0;
    return !!v;
}

// An array from a path (or a literal array).
function list(ctx, v) {
    if (Array.isArray(v))
        return v;
    const a = get(ctx, v);
    return Array.isArray(a) ? a : [];
}
