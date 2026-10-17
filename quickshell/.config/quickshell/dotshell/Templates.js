.pragma library

// Panel templates: what a desktop panel draws, as data. A panel is a template
// plus a feed (services/Feeds.qml); one renderer (PanelNode.qml) draws every
// template in four modes, picked from where the panel sits:
//   compact   on home (the default)        expanded  on home, after a click
//   strip     docked in the top strip      rail      docked in the side rail
//
// A layout is a tree of nodes, sized in dots:
//   { col: [nodes] }  { row: [nodes] }        stack down / left to right
//   { field: "<type>", ... }                  a leaf
// Every node takes: w / h (dots, "fill" or "auto"), lines (h in text lines),
// gap, pad, when (a condition, Bind.js), action (run on click, Actions.qml),
// slot (0 1 2 tube, or "dim").
// Field types:
//   label    text, one line: text, size, align, scroll (runs when too long)
//   big      one large number or word, as big as fits: text
//   meter    a 0..1 bar: value          vmeter  the same, standing up
//   progress value of total, a growing line: value, total
//   spark    the last N values: values  status  a word in ok/warn/bad: text, level
//   list     rows from an array: items, item (a node per element), max, dir
//   art      an image, plain or dithered: src, dots
//   marquee  scrolling text: text       glyph   one Nerd Font icon: text
//   image    a file: src                pixels  frames from `dot pixels`
//   spectrum cava bars                  notebar one column per semitone
//   lyrics   synced lines (LRCLIB)      video   the matched video, muted
//   tray     tray icons                 input   a line to type in: hint, action
//   rule     a one-dot line             space   empty room
// Text binds with {path|format=default} (Bind.js); {~word} is the era's word
// for this template (Skins.js), falling back to `words` below.
//
// A template:
//   name, title     id and the name its frame header shows
//   feed            the feed it binds by default (a panel may name another)
//   wants           services to wake while shown ("sys", "media")
//   size, big       compact and expanded size in grid units (Panels.unit px)
//   words           default words, overridden per era
//   compact, expanded, strip, rail   the layouts
//   click           what a click does on home: "expand" (default) or an action

function L(text, o) {
    return Object.assign({ field: "label", text: text }, o || {});
}
function S(text, level, o) {
    return Object.assign({ field: "status", text: text, level: level }, o || {});
}
function B(text, o) {
    return Object.assign({ field: "big", text: text }, o || {});
}
function R(kids, o) {
    return Object.assign({ row: kids }, o || {});
}
function C(kids, o) {
    return Object.assign({ col: kids }, o || {});
}
function F(type, o) {
    return Object.assign({ field: type }, o || {});
}
function LIST(items, item, o) {
    return Object.assign({ field: "list", items: items, item: item }, o || {});
}
const SPACE = { field: "space" };
const RULE = { field: "rule", slot: "dim" };
const GAP = { field: "space", w: 4, h: 2 };

// One header line: a title on the left, a note on the right.
function head(left, right, o) {
    return R([L(left, { slot: 2, w: "fill" }), L(right, { slot: 1, align: "right" })], o);
}

var all = {};

// ── Now playing ──────────────────────────────────────────────────────
all.nowplaying = {
    name: "nowplaying", title: "Now playing", feed: "media", wants: ["media"],
    size: { w: 36, h: 12 }, big: { w: 48, h: 34 },
    words: { idle: "NOTHING PLAYING", none: "NO PLAYER", lyr: "LYRICS", prev: "", play: "", pause: "", next: "", vis: "VIS", lyrw: "LYR" },
    compact: R([
        F("art", { src: "art", w: "square", when: "art" }),
        C([
            L("{title=~idle|upper}", { scroll: "always" }),
            L("{artist|upper}", { slot: 1 }),
            F("progress", { value: "progress", h: 3 }),
            R([
                L("{~prev}", { action: "media previous" }), GAP,
                L("{~pause}", { action: "media toggle", when: "playing" }),
                L("{~play}", { action: "media toggle", when: "!playing" }), GAP,
                L("{~next}", { action: "media next" }),
                SPACE,
                L("{~vis}", { slot: 2, action: "panel pop vis" }), GAP,
                L("{~lyrw}", { slot: 2, action: "panel pop lyrics", when: "hasLyrics" })
            ]),
            F("spectrum", { when: "playing" })
        ], { pad: 2 })
    ], { gap: 3 }),
    expanded: C([
        R([
            F("art", { src: "art", w: "square", h: 60, when: "!hasVideo" }),
            F("video", { h: 60, w: 107, when: "hasVideo" }),
            C([
                L("{title=~idle|upper}", { scroll: true }),
                L("{artist|upper}", { slot: 1, scroll: true }),
                L("{album|upper}", { slot: "dim", scroll: true }),
                SPACE,
                R([L("{pos|clock}", { slot: 1 }), SPACE, L("{len|clock}", { slot: 1 })]),
                F("progress", { value: "progress", h: 3, action: "media seek" }),
                R([
                    L("{~prev}", { action: "media previous" }), GAP,
                    L("{~pause}", { action: "media toggle", when: "playing" }),
                    L("{~play}", { action: "media toggle", when: "!playing" }), GAP,
                    L("{~next}", { action: "media next" }), SPACE,
                    L("{player|upper}", { slot: "dim" })
                ])
            ], { pad: 2 })
        ], { gap: 3, h: 60 }),
        F("spectrum", { h: 18 }),
        F("notebar", { h: 14 }),
        L("{~lyr}", { slot: 2, when: "hasLyrics" }),
        F("lyrics", { when: "hasLyrics" }),
        L("VIDEO MATCH IS WRONG? MARK IT BAD", { slot: "dim", action: "video bad", when: "hasVideo" })
    ], { gap: 2 }),
    strip: R([
        L("{~pause}", { slot: 2, when: "playing", action: "media toggle" }),
        L("{~play}", { slot: 2, when: "!playing", action: "media toggle" }),
        L("{title|upper}", { slot: 2, scroll: "always", w: 112, action: "panel expand" })
    ], { gap: 7, when: "active" }),
    rail: C([
        L("{~prev}", { align: "center", action: "media previous" }),
        L("{~pause}", { align: "center", slot: 2, action: "media toggle", when: "playing" }),
        L("{~play}", { align: "center", slot: 2, action: "media toggle", when: "!playing" }),
        L("{~next}", { align: "center", action: "media next" })
    ], { gap: 2, when: "active" })
};

// ── Clock ────────────────────────────────────────────────────────────
all.clock = {
    name: "clock", title: "Clock", feed: "clock",
    size: { w: 24, h: 10 }, big: { w: 34, h: 30 },
    words: { foot: "" },
    compact: C([B("{time}", { slot: 0 }), L("{date|upper}", { slot: 2, align: "center" })], { pad: 2 }),
    expanded: C([
        R([B("{time}", { h: 33 }), C([L("{day|upper}", { slot: 2 }), L("{dd} {month|upper} {year}", { slot: 1 }), L("UTC {utc}", { slot: "dim" })], { w: "fill" })], { gap: 6, h: 39 }),
        RULE,
        L("{month|upper} {year}", { slot: 2, align: "center" }),
        R(["MO", "TU", "WE", "TH", "FR", "SA", "SU"].map(d => L(d, { slot: "dim", align: "center", w: "fill" }))),
        LIST("weeks", LIST("days", L("{d}", { align: "center", w: "fill", slot: "{slot}" }), { dir: "row", w: "fill", h: 13 }), { max: 6 }),
        L("{~foot}", { slot: "dim", align: "center", when: "~foot" })
    ], { gap: 1, pad: 2 }),
    strip: R([L("{dateShort|upper}", { slot: 2 }), L("{time}", { slot: 0 })], { gap: 4, action: "pane calendar" }),
    rail: C([L("{hh}", { align: "center" }), L("{mm}", { align: "center", slot: 1 })], { action: "pane calendar" })
};

// ── Workspaces ───────────────────────────────────────────────────────
all.workspaces = {
    name: "workspaces", title: "Workspaces", feed: "workspaces",
    size: { w: 30, h: 8 }, big: { w: 40, h: 26 },
    compact: C([
        LIST("list", L("{id}", { slot: "{slot}", action: "ws {id}", opacity: "{opacity}" }), { dir: "row", gap: 5, h: 13 }),
        L("{title|upper}", { slot: "dim", scroll: true })
    ], { pad: 2 }),
    expanded: C([
        LIST("list", R([
            L("{id}", { slot: "{slot}", w: 14, action: "ws {id}" }),
            L("{titles|upper=EMPTY}", { slot: "{tslot}", scroll: true, w: "fill", action: "ws {id}" }),
            L("{windows}", { slot: "dim" })
        ], { gap: 4 }), { max: 10 }),
        L("+ NEW WORKSPACE", { slot: 2, action: "ws empty" })
    ], { pad: 2 }),
    strip: R([
        LIST("list", L("{id}", { slot: "{slot}", action: "ws {id}", opacity: "{opacity}", underline: "focused" }), { dir: "row", gap: 3 }),
        L("+", { slot: 2, action: "ws empty" })
    ], { gap: 3 }),
    rail: LIST("list", L("{id}", { align: "center", slot: "{slot}", action: "ws {id}", opacity: "{opacity}" }), { max: 6 })
};

// ── System ───────────────────────────────────────────────────────────
all.system = {
    name: "system", title: "System", feed: "sys", wants: ["sys"],
    size: { w: 30, h: 11 }, big: { w: 42, h: 30 },
    compact: C([
        R([L("CPU", { slot: 1, w: 28 }), F("meter", { value: "cpu", w: "fill", h: 5 }), L("{cpu|pct}", { w: 21, align: "right" })], { gap: 2 }),
        R([L("MEM", { slot: 1, w: 28 }), F("meter", { value: "mem", w: "fill", h: 5 }), L("{memGb|fixed1}", { w: 28, align: "right" })], { gap: 2 }),
        R([L("TMP", { slot: 1, w: 28 }), F("meter", { value: "tempF", w: "fill", h: 5 }), L("{temp|int}", { w: 21, align: "right" })], { gap: 2, when: "hasTemp" }),
        F("spark", { values: "cpuHist" })
    ], { pad: 2, gap: 1 }),
    expanded: C([
        R([L("CPU {cpu|pct}%", { slot: 0, w: "fill" }), L("MEM {memGb|fixed1}G", { slot: 1 }), GAP, L("{temp|int}C", { slot: 2, when: "hasTemp" })]),
        F("spark", { values: "cpuHist", h: 16 }),
        LIST("cores", F("vmeter", { value: "v", w: "fill" }), { dir: "row", gap: 1, h: 16 }),
        RULE,
        R([L("PROCESS", { slot: "dim", w: "fill" }), L("CPU", { slot: "dim", w: 35, align: "right" }), L("MEM", { slot: "dim", w: 42, align: "right" })]),
        LIST("top", R([L("{name|upper}", { w: "fill" }), L("{cpu}", { w: 35, align: "right", slot: 1 }), L("{mem}", { w: 42, align: "right", slot: 1 })]), { max: 6 }),
        L("{~foot}", { slot: "dim", when: "~foot" })
    ], { pad: 2, gap: 1 }),
    strip: R([
        L("CPU {cpu|pct}", { slot: "{cpuSlot}" }),
        L("MEM {mem|pct}", { slot: 1 }),
        L("{temp|int}C", { slot: 2, when: "hasTemp" })
    ], { gap: 6 }),
    rail: R([F("vmeter", { value: "cpu", w: 3 }), F("vmeter", { value: "mem", w: 3 }), F("vmeter", { value: "tempF", w: 3, when: "hasTemp" })], { gap: 1, h: 40, pad: 2 })
};

// ── Battery ──────────────────────────────────────────────────────────
all.battery = {
    name: "battery", title: "Battery", feed: "power",
    size: { w: 24, h: 10 }, big: { w: 36, h: 22 },
    compact: C([
        R([B("{pct}", { slot: "{slot}", w: "fill" }), C([S("{stateWord}", "{level}"), L("{time}", { slot: 1 })], { w: "auto" })], { gap: 4 }),
        F("meter", { value: "fraction", h: 5, slot: "{slot}" })
    ], { pad: 2, gap: 2 }),
    expanded: C([
        R([B("{pct}%", { slot: "{slot}", h: 33 }), C([S("{stateWord}", "{level}"), L("{time}", { slot: 1 }), L("{watts|fixed1} W", { slot: "dim" })])], { gap: 6, h: 39 }),
        F("meter", { value: "fraction", h: 5, slot: "{slot}" }),
        F("spark", { values: "hist", h: 14 }),
        R([L("HEALTH", { slot: "dim", w: "fill" }), L("{health}", { slot: 1 })], { when: "hasHealth" }),
        R([L("PROFILE", { slot: "dim", w: "fill" }),
           L("SAVER", { slot: "{p0}", action: "power profile 0" }), GAP,
           L("BAL", { slot: "{p1}", action: "power profile 1" }), GAP,
           L("PERF", { slot: "{p2}", action: "power profile 2", when: "hasPerf" })])
    ], { pad: 2, gap: 2 }),
    strip: R([L("BAT {pct}{plus}", { slot: "{slot}" })], { when: "present", action: "pane battery" }),
    rail: C([F("vmeter", { value: "fraction", w: 5, h: 24, slot: "{slot}" }), L("{pct}", { align: "center", slot: "{slot}", when: "pct<100" })], { when: "present", gap: 2, action: "pane battery" })
};

// ── Messages ─────────────────────────────────────────────────────────
all.messages = {
    name: "messages", title: "Messages", feed: "notifs",
    size: { w: 30, h: 14 }, big: { w: 42, h: 30 },
    words: { title: "MESSAGES", icon: "MSG", quiet: "NO MESSAGES", dndw: "DND" },
    compact: C([
        R([L("{~title}", { slot: 2, w: "fill" }), L("{~dndw}", { slot: "{dndSlot}", action: "dnd toggle" })]),
        LIST("items", R([L("{app|upper}", { slot: 1, w: 49 }), L("{summary|upper}", { w: "fill", scroll: true })], { gap: 4 }), { max: 4, empty: "{~quiet}" })
    ], { pad: 2 }),
    expanded: C([
        R([L("{~title}", { slot: 2, w: "fill" }), L("CLEAR", { slot: 1, action: "notifs clear" }), GAP, L("{~dndw}", { slot: "{dndSlot}", action: "dnd toggle" })]),
        LIST("apps", L("{app|upper} {count}", { slot: 1 }), { dir: "row", gap: 7, h: 13 }),
        RULE,
        LIST("items", C([
            R([L("{app|upper}", { slot: 1, w: "fill" }), L("{ts|ago}", { slot: "dim" })]),
            L("{summary|upper}", { scroll: true }),
            L("{body|upper}", { slot: "dim", scroll: true, when: "body" })
        ]), { max: 6, gap: 2, empty: "{~quiet}" })
    ], { pad: 2, gap: 1 }),
    strip: R([L("{~dndw}", { slot: 1, when: "dnd" }), L("{~icon} {live}", { slot: 2, when: "!dnd" })], { action: "pane notifs", when: "dnd||live>0" }),
    rail: C([L("{live}", { align: "center", slot: 2 })], { action: "pane notifs", when: "live>0" })
};

// ── Capture ──────────────────────────────────────────────────────────
all.capture = {
    name: "capture", title: "Capture", feed: "capture",
    size: { w: 24, h: 10 }, big: { w: 36, h: 24 },
    words: { shot: "SHOT", rec: "REC", stop: "STOP" },
    compact: C([
        R([L(" {~shot}", { action: "capture shot area" }), SPACE, L(" {~rec}", { slot: 2, action: "capture rec screen", when: "!recording" }), L(" {~stop} {elapsed}", { slot: 2, action: "capture stop", when: "recording" })]),
        L("{last|base|upper=NO CAPTURES YET}", { slot: "dim", scroll: true })
    ], { pad: 2, gap: 2 }),
    expanded: C([
        R([L("SHOT", { slot: "dim", w: 35 }), L("AREA", { action: "capture shot area" }), GAP, L("WINDOW", { action: "capture shot window" }), GAP, L("SCREEN", { action: "capture shot screen" })]),
        R([L("REC", { slot: "dim", w: 35 }), L("AREA", { slot: 2, action: "capture rec area" }), GAP, L("SCREEN", { slot: 2, action: "capture rec screen" }), SPACE, L("{~stop} {elapsed}", { slot: 2, action: "capture stop", when: "recording" })]),
        R([L("AUDIO", { slot: "dim", w: 49 }), L("{audio|bool}", { slot: 1, action: "capture audio" }), SPACE, L("PICK COLOR", { action: "capture pick" })]),
        RULE,
        LIST("recent", R([L("{name|upper}", { w: "fill", scroll: true, action: "open {path}" }), L("{ts|ago}", { slot: "dim" })]), { max: 5, empty: "NO CAPTURES YET" })
    ], { pad: 2, gap: 2 }),
    strip: R([L("REC {elapsed}", { slot: 2, opacity: "{blink}" })], { action: "capture stop", when: "recording" }),
    rail: C([L("", { align: "center", slot: 2, opacity: "{blink}" })], { action: "capture stop", when: "recording" })
};

// ── Caffeine ─────────────────────────────────────────────────────────
all.caffeine = {
    name: "caffeine", title: "Caffeine", feed: "caffeine",
    size: { w: 22, h: 9 }, big: { w: 32, h: 20 },
    words: { icon: "CAF", onw: "AWAKE", offw: "IDLE" },
    compact: C([
        R([B("{~icon}", { slot: "{slot}", w: "fill" })]),
        R([S("{state}", "{level}"), SPACE, L("{left}", { slot: 1, when: "left" })])
    ], { pad: 2, action: "caffeine toggle" }),
    expanded: C([
        R([S("{state}", "{level}", { w: "fill" }), L("{left}", { slot: 1, when: "left" })]),
        L("{on|bool}", { size: 2, slot: "{slot}", action: "caffeine toggle", h: 24 }),
        R([L("FOR", { slot: "dim" }), GAP, L("15M", { action: "caffeine for 15" }), GAP, L("1H", { action: "caffeine for 60" }), GAP, L("2H", { action: "caffeine for 120" }), GAP, L("ALWAYS", { action: "caffeine on" })]),
        RULE,
        L("HOLDING THE SCREEN ON", { slot: "dim" }),
        LIST("holders", L("{who|upper} · {why|upper}", { scroll: true, slot: 1 }), { max: 4, empty: "NOTHING ELSE" })
    ], { pad: 2, gap: 2 }),
    strip: R([L("{~icon}", { slot: 2 }), L("{left}", { slot: 1, when: "left" })], { gap: 4, when: "on", action: "caffeine toggle" }),
    rail: C([L("", { align: "center", slot: 2 })], { when: "on", action: "caffeine toggle" })
};

// ── Tray ─────────────────────────────────────────────────────────────
all.tray = {
    name: "tray", title: "Tray", feed: "tray",
    size: { w: 24, h: 6 }, big: { w: 32, h: 20 },
    compact: C([F("tray", { h: 13 })], { pad: 2 }),
    expanded: C([LIST("items", R([F("tray", { only: "{id}", w: 13, h: 13 }), L("{title|upper}", { w: "fill", scroll: true, action: "tray {id}" })], { gap: 3 }), { max: 10, empty: "NO TRAY ICONS" })], { pad: 2 }),
    strip: F("tray", { w: "auto" }),
    rail: F("tray", { vertical: true, h: "auto" })
};

// ── Downloads ────────────────────────────────────────────────────────
all.downloads = {
    name: "downloads", title: "Downloads", feed: "downloads",
    size: { w: 32, h: 12 }, big: { w: 44, h: 28 },
    words: { none: "NO DOWNLOADS", today: "TODAY" },
    compact: C([
        LIST("active", C([R([L("{name|upper}", { w: "fill", scroll: true }), L("{pct|pct}%", { slot: 1 })]), F("progress", { value: "pct", h: 3 })]), { max: 2 }),
        LIST("recent", R([L("{name|upper}", { w: "fill", scroll: true, action: "open {path}" }), L("{ts|ago}", { slot: "dim" })], { gap: 4 }), { max: 4, empty: "{~none}", when: "!active" })
    ], { pad: 2, gap: 1 }),
    expanded: C([
        LIST("active", C([R([L("{name|upper}", { w: "fill", scroll: true }), L("{speed}", { slot: "dim" }), GAP, L("{pct|pct}%", { slot: 1 })]), F("progress", { value: "pct", h: 3 })]), { max: 3, h: "auto" }),
        L("{~today}", { slot: 2 }),
        LIST("recent", R([
            L("{name|upper}", { w: "fill", scroll: true, action: "open {path}" }),
            L("{bin|upper}", { slot: 1, action: "reveal {path}" }), GAP,
            L("UNDO", { slot: 2, action: "dotd undo {id}", when: "undo" })
        ], { gap: 3 }), { max: 8, empty: "{~none}" })
    ], { pad: 2, gap: 1 }),
    strip: R([L(" {activeName|upper}", { slot: 1, scroll: true, w: 98 }), L("{activePct|pct}%", { slot: 2 })], { gap: 4, when: "active" }),
    rail: C([F("vmeter", { value: "activePct", w: 5, h: 30, slot: 1 }), L("", { align: "center", slot: 2 })], { gap: 2, when: "active" })
};

// ── Files ────────────────────────────────────────────────────────────
all.files = {
    name: "files", title: "Files", feed: "files",
    size: { w: 30, h: 14 }, big: { w: 44, h: 30 },
    words: { find: "FIND" },
    compact: C([
        LIST("pinned", L("{name|upper}", { slot: 2, action: "open {path}" }), { dir: "row", gap: 7, h: 13, max: 4 }),
        LIST("recent", R([L("{name|upper}", { w: "fill", scroll: true, action: "open {path}" }), L("{ts|ago}", { slot: "dim" })]), { max: 4, empty: "NOTHING RECENT" })
    ], { pad: 2 }),
    expanded: C([
        R([L("{~find}", { slot: 2 }), F("input", { w: "fill", hint: "NAME, TEXT OR MEANING", action: "find {value}" })], { gap: 4 }),
        LIST("pinned", L("{name|upper}", { slot: 2, action: "open {path}" }), { dir: "row", gap: 7, h: 13, max: 6 }),
        RULE,
        LIST("recent", R([
            L("{name|upper}", { w: "fill", scroll: true, action: "open {path}" }),
            L("{dir|upper}", { slot: "dim", w: 84, scroll: true, action: "reveal {path}" }), GAP,
            L("{ts|ago}", { slot: "dim" })
        ]), { max: 10, empty: "NOTHING RECENT" })
    ], { pad: 2, gap: 1 }),
    strip: R([L(" {recentName|upper}", { slot: 1, scroll: true, w: 98, action: "open {recentPath}" })], { when: "recentName" }),
    rail: C([L("", { align: "center", slot: 1, action: "files" })])
};

// ── Clipboard ────────────────────────────────────────────────────────
all.clipboard = {
    name: "clipboard", title: "Clipboard", feed: "clip",
    size: { w: 30, h: 14 }, big: { w: 44, h: 28 },
    words: { icon: "CLIP", empty: "NOTHING COPIED" },
    compact: C([
        LIST("items", L("{preview|upper}", { scroll: true, action: "paste {$index}" }), { max: 5, empty: "{~empty}" })
    ], { pad: 2 }),
    expanded: C([
        R([L("{count} SAVED", { slot: 2, w: "fill" }), L("CLEAR", { slot: 1, action: "clip clear" })]),
        LIST("items", R([
            L("{$index}", { slot: "dim", w: 14 }),
            L("{preview|upper}", { w: "fill", scroll: true, action: "paste {$index}" }),
            L("{~del}", { slot: 2, action: "clip forget {$index}" })
        ], { gap: 3 }), { max: 10, empty: "{~empty}" })
    ], { pad: 2, gap: 1 }),
    strip: R([L("{~icon}", { slot: 2 }), L("{lastPreview|upper}", { slot: 1, scroll: true, w: 84, action: "paste 0" })], { gap: 4, when: "count>0" }),
    rail: C([L("", { align: "center", slot: 1, action: "pane clip" })])
};

// ── Todo ─────────────────────────────────────────────────────────────
all.todo = {
    name: "todo", title: "Todo", feed: "todo",
    size: { w: 30, h: 16 }, big: { w: 44, h: 32 },
    words: { title: "TODAY", on: "x", off: "o", add: "+ ADD A TASK", left: "LEFT", empty: "ALL DONE" },
    compact: C([
        R([L("{~title}", { slot: 2, w: "fill" }), L("{left} {~left}", { slot: 1 })]),
        LIST("today", R([
            L("{mark}", { slot: "{markSlot}", w: 14, action: "todo toggle {n}" }),
            L("{text|upper}", { w: "fill", scroll: true, slot: "{textSlot}", opacity: "{opacity}" }),
            L("{due|upper}", { slot: 1, when: "due" })
        ], { gap: 3 }), { max: 5, empty: "{~empty}" }),
        F("input", { hint: "{~add}", action: "todo add {value}" })
    ], { pad: 2 }),
    expanded: C([
        R([L("{~title}", { slot: 2, w: "fill" }), L("{done}/{total}", { slot: 1 })]),
        LIST("lists", L("+{name|upper} {count}", { slot: 1 }), { dir: "row", gap: 7, h: 13, max: 6 }),
        RULE,
        LIST("items", R([
            L("{mark}", { slot: "{markSlot}", w: 14, action: "todo toggle {n}" }),
            L("{prio}", { slot: 2, w: 14 }),
            L("{text|upper}", { w: "fill", scroll: true, slot: "{textSlot}", opacity: "{opacity}" }),
            L("{due|upper}", { slot: 1, when: "due" }), GAP,
            L("{~del}", { slot: "dim", action: "todo rm {n}" })
        ], { gap: 3 }), { max: 12, empty: "{~empty}" }),
        F("input", { hint: "{~add}  +LIST DUE:FRI !HIGH", action: "todo add {value}" })
    ], { pad: 2, gap: 1 }),
    strip: R([L("{~off}", { slot: 2 }), L("{next|upper=~empty}", { slot: 1, scroll: true, w: 112 }), L("{left}", { slot: 2 })], { gap: 4 }),
    rail: C([L("{left}", { align: "center", slot: 2 }), L("", { align: "center", slot: 1 })])
};

// ── Screenshots ──────────────────────────────────────────────────────
all.screenshots = {
    name: "screenshots", title: "Screenshots", feed: "shots",
    size: { w: 30, h: 22 }, big: { w: 46, h: 34 },
    compact: C([
        F("art", { src: "latest", h: "fill", action: "open {latest}" }),
        LIST("thumbs", F("art", { src: "path", w: "fill", action: "open {path}" }), { dir: "row", gap: 2, h: 18, max: 4 }),
        R([L("COPY", { action: "copyimg {latest}" }), L("EDIT", { action: "edit {latest}" }), L("OCR", { action: "ocr {latest}" }), SPACE, L("{~del}", { slot: 2, action: "trash {latest}" })], { gap: 7 })
    ], { pad: 2, gap: 2 }),
    expanded: C([
        R([L("{count} SHOTS", { slot: 2, w: "fill" }), L("NEW", { slot: 1, action: "capture shot area" })]),
        LIST("days", C([
            L("{day|upper}", { slot: 1 }),
            LIST("shots", F("art", { src: "path", w: 40, action: "open {path}" }), { dir: "row", gap: 2, h: 24, max: 6 })
        ], { gap: 1 }), { max: 4, gap: 2 }),
        L("{ocr|upper}", { slot: "dim", scroll: true, when: "ocr" })
    ], { pad: 2, gap: 2 }),
    strip: R([L(" {count}", { slot: 1, action: "open {latest}" })]),
    rail: C([L("", { align: "center", slot: 1, action: "open {latest}" })])
};

// ── Dock ─────────────────────────────────────────────────────────────
// A vertical strip on home: the launch tile, running apps (their workspace
// as a badge), pinned apps (dim). Click jumps; a pinned app launches on the
// next empty workspace.
all.dock = {
    name: "dock", title: "Dock", feed: "dock",
    size: { w: 5, h: 40 }, big: { w: 26, h: 40 }, click: "none",
    words: { title: "RUNNING" },
    compact: C([
        L("", { align: "center", slot: 2, action: "launcher" }),
        RULE,
        LIST("running", C([
            L("{glyph}", { align: "center", slot: "{slot}", action: "jump {cls}" }),
            L("{ws}", { align: "center", slot: "dim", when: "ws" })
        ]), { max: 10, gap: 2, h: "auto" }),
        RULE,
        LIST("pinned", L("{glyph}", { align: "center", slot: "dim", action: "launch {id}" }), { max: 8, gap: 2, h: "auto" }),
        SPACE,
        L("", { align: "center", slot: "dim", action: "panel expand" })
    ], { pad: 2, gap: 3 }),
    expanded: C([
        R([L("{~title}", { slot: 2, w: "fill" }), L("", { slot: "dim", action: "panel fold" })]),
        F("input", { hint: "SEARCH APPS", action: "launch-query {value}" }),
        RULE,
        LIST("running", C([
            R([L("{glyph}", { slot: "{slot}", w: 14 }), L("{name|upper}", { w: "fill", scroll: true, action: "jump {cls}" }), L("{ws}", { slot: 1 })], { gap: 3 }),
            R([L("", { w: 14 }), L("{title|upper}", { slot: "dim", w: "fill", scroll: true }), L("{dots}", { slot: 2 })], { gap: 3 }),
            R([L("", { w: 14 }), L("MOVE", { slot: "dim", action: "movehere {addr}" }), GAP, L("PIN", { slot: "dim", action: "pin {cls}" }), GAP, L("CLOSE", { slot: 2, action: "closeall {cls}" })], { gap: 3 })
        ]), { max: 8, gap: 2 }),
        RULE,
        LIST("pinned", R([L("{glyph}", { slot: "dim", w: 14 }), L("{name|upper}", { slot: "dim", w: "fill", action: "launch {id}" }), L("UNPIN", { slot: "dim", action: "unpin {id}" })], { gap: 3 }), { max: 8 })
    ], { pad: 2, gap: 2 }),
    strip: R([L("", { slot: 2, action: "launcher" }), LIST("running", L("{glyph}", { slot: "{slot}", action: "jump {cls}" }), { dir: "row", gap: 5, max: 8 })], { gap: 6 }),
    rail: C([L("", { align: "center", slot: 2, action: "launcher" }), LIST("running", L("{glyph}", { align: "center", slot: "{slot}", action: "jump {cls}" }), { max: 8, h: "auto", gap: 2 })], { gap: 3 })
};

// ── Popped boards (Now playing's VIS and LYR) ────────────────────────
all.vis = {
    name: "vis", title: "Spectrum", feed: "media", wants: ["media"], size: { w: 30, h: 10 }, big: { w: 40, h: 20 },
    compact: C([F("spectrum"), F("notebar", { h: 10 })], { pad: 1, gap: 1 }),
    strip: F("spectrum", { w: 84 }),
    rail: F("spectrum", { h: 40 })
};
all.lyrics = {
    name: "lyrics", title: "Lyrics", feed: "media", wants: ["media"], size: { w: 36, h: 12 }, big: { w: 46, h: 30 },
    words: { none: "NO LYRICS" },
    compact: C([F("lyrics")], { pad: 2 }),
    strip: L("{lyric|upper}", { slot: 1, scroll: "always", w: 168 }),
    rail: L("", { align: "center" })
};

// ── Phase 4 kinds, as templates ──────────────────────────────────────
all.sign = {
    name: "sign", title: "Sign", feed: "panel", size: { w: 40, h: 6 },
    compact: B("{@text|upper}", { slot: "@" }),
    strip: L("{@text|upper}", { slot: "@" }),
    rail: L("{@text|upper}", { slot: "@" })
};
all.note = {
    name: "note", title: "Note", feed: "panel", size: { w: 30, h: 20 },
    compact: L("{@text}", { wrap: true, slot: "@", pad: 2 }),
    strip: L("{@text|upper}", { scroll: true, w: 140, slot: "@" }),
    rail: L("", { align: "center", slot: "@" })
};
all.image = {
    name: "image", title: "Image", feed: "panel", size: { w: 30, h: 20 },
    compact: F("image", { src: "@source" }),
    strip: F("image", { src: "@source", w: 20 }),
    rail: F("image", { src: "@source", h: 13 })
};
all.mpris = {
    name: "mpris", title: "Player", feed: "media", wants: ["media"], size: { w: 36, h: 12 },
    compact: R([F("art", { src: "art", w: "square", dots: true, dither: true, when: "art" }), C([SPACE, L("{title=~none|upper}"), L("{artist|upper}", { slot: 1 }), SPACE], { pad: 2 })], { gap: 2 }),
    words: { none: "NOTHING PLAYING" },
    strip: L("{title|upper}", { scroll: true, w: 112 }),
    rail: L("", { align: "center" })
};
all.media = Object.assign({}, all.nowplaying, { name: "media" });
all.pixels = {
    name: "pixels", title: "Pixels", feed: "panel", size: { w: 30, h: 15 }, click: "none",
    compact: F("pixels"),
    strip: F("pixels", { w: 30 }),
    rail: F("pixels", { h: 13 })
};
// A layout pushed with the panel itself (`dot spawn board --layout '{...}'`).
all.board = {
    name: "board", title: "Board", feed: "", size: { w: 30, h: 12 },
    compact: L("{@id|upper}: NO LAYOUT", { slot: "dim" })
};

// The 15-panel home set, in the order `dot home --reset` lays it out.
var homeSet = ["nowplaying", "clock", "workspaces", "system", "battery", "messages", "capture", "caffeine", "tray", "downloads", "files", "clipboard", "todo", "screenshots", "dock"];
var names = Object.keys(all);

function get(name) {
    return all[name] || null;
}

// The layout for a mode, falling back to the nearest one there is.
function layout(t, mode, own) {
    if (own && own[mode])
        return own[mode];
    if (own && own.compact && mode !== "strip" && mode !== "rail")
        return own.compact;
    if (!t)
        return null;
    if (t[mode])
        return t[mode];
    if (mode === "expanded")
        return t.compact;
    return null;
}
