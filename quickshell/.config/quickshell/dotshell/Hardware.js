.pragma library

// The physical device a panel is built as, per era, in screen px: the
// faceplate around the dots, the display window they sit in, and the keys
// (panel design canvas, "Now playing", compact). One table, read by
// Faceplate.qml, WindowGlass.qml, DeviceKeys.qml and MediaReadout.qml, so the
// mini panel on home (MediaDevice.qml) and the full device it grows into
// (Pane.qml with `hardware`, MEDIA on Super M) are the same hardware.
//
//   plate    the faceplate
//     shape    rect | pill (round ends) | skew (a parallelogram, `slant` of
//              the height, the top edge leaning right)
//     radius   corner px, or [tl, tr, br, bl]
//     color    flat fill; `fill` a gradient instead: { dir: v | h | d,
//              stops: [[pos, color], ...] } (four stops at most)
//     inner    { inset, color }: a second plate inset in the first (a
//              gradient rim around a dark face)
//     under    a darker band along the bottom edge (moulded plastic)
//     edge     a lit line along the top edge (brushed metal)
//     strokes  [{ inset, width, color, glow, opacity }]: outlines following
//              the shape (neon tubes, brass rims, a double rule)
//     brackets { len, width, inset, color, glow }: corner brackets only
//     bevel    { light, dark, inner }: a 95-style raised bevel
//     grid     { step, color }: graph paper
//     rivets   { r, inset, color }: one in each corner
//     gloss    a glassy highlight over the top half
//     shadow   { color, y }: a drop shadow under the plate
//     legend   { text, right, x, color }: words cut into the top rule
//   head     a band across the top: { h, inset, fill (stops, left to right
//            unless `dir` v), left, center, right, color, colorC, colorR,
//            size, buttons } — {pos} {len} in its words are the track times
//   bezel    px from the plate's edge to the display window: { l, t, r, b }
//            (t from the head band when there is one)
//   window   the display window
//     radius   corner px, "pill", or [tl, tr, br, bl]; a skew plate's window
//              leans with it
//     shade    how dark the smoked glass falls from the top (0..1)
//     edge     the window's edge line (`edgeW` px)
//     sunken   { dark, light }: a 95-style sunken bevel
//     frame    { pad, color, radius, mark, markColor }: a surround on the
//              plate (a handheld's screen bezel), `mark` printed under it
//     scan     scanlines        gloss     a glassy highlight
//     vignette dark toward the edges (goggles)
//   side     { kind: "tubes", w, gap }: a column left of the window
//   keys     the transport: at "bottom" (a row under the window) or "right"
//            (a block right of it, `w` wide), `h` the key height, `gap`,
//            `align` stretch | start | center | end, `free` (items placed at
//            their own x y in the block). `style` is every key's look,
//            each item's `style` overrides it; an item's `act` is prev |
//            toggle | next | pane | dpad (left half prev, right half next),
//            its size `w` (or `weight` when stretched), `label` a word
//            instead of an icon ([paused, playing] for toggle)
//     style    shape: rect | round | skew | none (just the word) | dpad;
//              radius; fill [top, bottom]; orb [highlight, mid, rim] (a
//              round, lit from the top left); down [top, bottom] pressed;
//              hover; border { w, color }; glow; edge (lit top line); under
//              (a drop under it); bevel { light, dark }; ink (a color, or
//              slot0 .. slot2 for the era's tubes); hollow (the icon
//              outlined); size (label px); caption (printed under it)
//   readout  how MediaReadout.qml draws the track in the dots:
//     art      none | square | round           reticle  a gunsight on it
//     legends  annunciators | a fixed word (small, over the title) | none
//     prefix   before the title                 cursor   a blinking block
//     bar      segments | blocks | lives | line | chevrons | text | box |
//              tube | dim | flap
//     flaps    the title in split-flap tiles    rain     falling code behind
//     time     right (the big time) | none (the tubes show it)
var eras = {
    phosphor: {
        plate: {
            color: "#0c0906",
            strokes: [
                { inset: 6, width: 1, color: "#e68c28", glow: "#e68c28" },
                { inset: 9, width: 1, color: "#e68c28", glow: "#e68c28" }
            ],
            legend: { text: "┤ mpv · now playing ├", right: "TTY1", x: 22, color: "#e68c28" }
        },
        bezel: { l: 16, t: 18, r: 16, b: 14 },
        window: { radius: 0, scan: true },
        keys: {
            at: "bottom", h: 16, gap: 12, align: "start",
            style: { shape: "none", ink: "#ffb347", glow: "#e68c28", size: 15 },
            items: [
                { act: "prev", label: "[|<]" },
                { act: "toggle", label: ["[>]", "[||]"], style: { ink: "#ffd68c" } },
                { act: "next", label: "[>|]" }
            ]
        },
        readout: { art: "square", legends: "none", prefix: "> ", cursor: true, bar: "text" }
    },
    tokyo: {
        plate: {
            shape: "pill", color: "#08071a",
            strokes: [
                { inset: 1, width: 3, color: "#ff3cac", glow: "#ff3cac" },
                { inset: 9, width: 2, color: "#2de2e6", glow: "#2de2e6", opacity: 0.8 }
            ]
        },
        bezel: { l: 16, t: 16, r: 14, b: 16 },
        window: { radius: "pill" },
        keys: {
            at: "right", w: 118, h: 36, gap: 8, align: "center",
            style: { shape: "round", border: { w: 2, color: "#ff3cac" }, glow: "#ff3cac", ink: "#ff3cac" },
            items: [
                { act: "prev", w: 28, h: 28 },
                { act: "toggle", w: 36, h: 36, style: { border: { w: 2, color: "#2de2e6" }, glow: "#2de2e6", ink: "#2de2e6" } },
                { act: "next", w: 28, h: 28 }
            ]
        },
        readout: { art: "round", legends: "none", bar: "line" }
    },
    nineties: {
        plate: {
            shape: "skew", slant: 0.176,
            fill: { dir: "d", stops: [[0, "#ffe600"], [0.4, "#ff2e97"], [1, "#1fa8ff"]] },
            inner: { inset: 3, color: "#0a0514" }
        },
        bezel: { l: 16, t: 12, r: 18, b: 10 },
        window: { radius: 0 },
        keys: {
            at: "bottom", h: 22, gap: 6, align: "start",
            style: { shape: "skew", slant: 0.176, fill: ["#ffffff", "#a3157f"], down: ["#a3157f", "#ffffff"], ink: "#0a0514" },
            items: [
                { act: "prev", w: 34 },
                { act: "toggle", w: 46, style: { fill: ["#ffffff", "#ff2e97"], down: ["#ff2e97", "#ffffff"] } },
                { act: "next", w: 34 }
            ]
        },
        readout: { art: "square", legends: "none", bar: "chevrons" }
    },
    matrix: {
        plate: {
            color: "#020805",
            brackets: { len: 16, width: 2, inset: 4, color: "#00ff41", glow: "#00ff41" }
        },
        bezel: { l: 12, t: 10, r: 12, b: 10 },
        window: { radius: 0 },
        keys: {
            at: "bottom", h: 16, gap: 14, align: "start",
            style: { shape: "none", ink: "#00ff41", glow: "#00aa28", size: 15 },
            items: [
                { act: "prev", label: "<<" },
                { act: "toggle", label: [">", "||"], style: { ink: "#b4ffc8" } },
                { act: "next", label: ">>" }
            ]
        },
        readout: { art: "square", legends: "//SIGNAL.LOCKED", bar: "blocks", rain: true }
    },
    vfd: {
        plate: {
            radius: 10, edge: "#5a6064",
            fill: { dir: "v", stops: [[0, "#3a3f42"], [1, "#1b1e20"]] }
        },
        bezel: { l: 8, t: 8, r: 8, b: 8 },
        window: { radius: 4, shade: 0.8, edge: "#000000" },
        keys: {
            at: "bottom", h: 30, gap: 6, align: "stretch",
            style: {
                shape: "rect", radius: 4, fill: ["#4a5054", "#2a2e31"], hover: "#555c60",
                down: ["#2a2e31", "#23272a"], edge: "#6a7176", ink: "#cfd6d9"
            },
            items: [
                { act: "prev", weight: 1 },
                { act: "toggle", weight: 1.4, style: { ink: "slot0" } },
                { act: "next", weight: 1 }
            ]
        },
        readout: { art: "none", legends: "annunciators", bar: "segments" }
    },
    aero: {
        plate: {
            radius: 40,
            fill: { dir: "v", stops: [[0, "#ffffff"], [0.48, "#d7f0ff"], [0.52, "#9fd8f5"], [1, "#e8f6fd"]] },
            strokes: [{ inset: 0.5, width: 1, color: "#ffffff" }],
            gloss: true,
            shadow: { color: "#590b3f80", y: 6 }
        },
        bezel: { l: 16, t: 14, r: 12, b: 14 },
        window: { radius: 22, edge: "#9fd8f5", gloss: true },
        keys: {
            at: "right", w: 128, h: 38, gap: 8, align: "center",
            style: { shape: "round", orb: ["#ffffff", "#62c3ee", "#1f7fd1"], ink: "#0b3f80", under: "#400b3f80" },
            items: [
                { act: "prev", w: 28, h: 28 },
                { act: "toggle", w: 38, h: 38, style: { orb: ["#ffffff", "#8fe07a", "#23963c"] } },
                { act: "next", w: 28, h: 28 }
            ]
        },
        readout: { art: "square", legends: "none", bar: "box" }
    },
    gameboy: {
        plate: { radius: [10, 10, 40, 10], color: "#c9c5c0", under: "#a19c96" },
        bezel: { l: 26, t: 22, r: 22, b: 30 },
        window: {
            radius: 0, edge: "#306230", edgeW: 2,
            frame: { pad: 12, padB: 20, color: "#55565f", radius: [8, 8, 24, 8], mark: "DOT MATRIX · STEREO", markColor: "#c9c5c0" }
        },
        keys: {
            at: "right", w: 116, h: 74, gap: 0, free: true,
            style: { shape: "round", fill: ["#8b2d5a", "#8b2d5a"], down: ["#5a1a3a", "#5a1a3a"], under: "#5a1a3a", ink: "#c9c5c0", caption: "#3a3a8a" },
            items: [
                { act: "dpad", x: 0, y: 12, w: 54, h: 54, style: { shape: "dpad", fill: ["#2b2b30", "#2b2b30"], ink: "#6a6a72", under: "" } },
                { act: "pane", x: 62, y: 32, w: 24, h: 24, label: "", style: { caption: "#3a3a8a" }, caption: "B" },
                { act: "toggle", x: 90, y: 16, w: 24, h: 24, label: "", caption: "A" }
            ]
        },
        readout: { art: "square", legends: "none", bar: "box" }
    },
    nixie: {
        plate: {
            radius: 6,
            fill: { dir: "h", stops: [[0, "#3a1d0e"], [0.3, "#5a2e16"], [0.6, "#3e1f0f"], [1, "#5a2e16"]] },
            strokes: [
                { inset: 1, width: 2, color: "#b8863b" },
                { inset: 3, width: 2, color: "#3a1d0e" }
            ]
        },
        bezel: { l: 12, t: 12, r: 12, b: 10 },
        side: { kind: "tubes", w: 150, gap: 10 },
        window: { radius: 4, edge: "#b8863b" },
        keys: {
            at: "bottom", h: 28, gap: 10, align: "start",
            style: { shape: "round", orb: ["#f3d18a", "#c9a050", "#8a5a1e"], ink: "#3a1d0e" },
            items: [
                { act: "prev", w: 22, h: 22 },
                { act: "toggle", w: 28, h: 28 },
                { act: "next", w: 22, h: 22 }
            ]
        },
        readout: { art: "none", legends: "none", bar: "tube", time: "none" }
    },
    flap: {
        plate: {
            color: "#141414",
            strokes: [{ inset: 1, width: 2, color: "#2a2a2a" }],
            rivets: { r: 3, inset: 5, color: "#3a3a3a" }
        },
        head: { h: 12, inset: 12, left: "NOW PLAYING", right: "● ON AIR", color: "#6e6e64", colorR: "#ffd400", size: 9 },
        bezel: { l: 12, t: 6, r: 12, b: 10 },
        window: { radius: 0 },
        keys: {
            at: "bottom", h: 22, gap: 4, align: "end",
            style: { shape: "rect", radius: 1, fill: ["#262626", "#262626"], down: ["#1e1e1e", "#1e1e1e"], hover: "#303030", under: "#0b0b0b", ink: "#f2f2e6" },
            items: [
                { act: "prev", w: 28 },
                { act: "toggle", w: 28, style: { fill: ["#ffd400", "#ffd400"], hover: "#ffe14d", down: ["#a88c00", "#a88c00"], under: "#a88c00", ink: "#0b0b0b" } },
                { act: "next", w: 28 }
            ]
        },
        readout: { art: "none", legends: "none", bar: "flap", flaps: true }
    },
    nightvision: {
        plate: {
            shape: "pill", color: "#040a03",
            strokes: [{ inset: 1, width: 2, color: "#0f3a0c" }]
        },
        bezel: { l: 26, t: 14, r: 26, b: 10 },
        window: { radius: "pill", vignette: true },
        keys: {
            at: "bottom", h: 16, gap: 16, align: "center",
            style: { shape: "none", ink: "#7dff6a", glow: "#2fae2a", size: 13 },
            items: [
                { act: "prev", label: "◁◁" },
                { act: "toggle", label: ["▷", "❚❚"], style: { ink: "#d6ffc9" } },
                { act: "next", label: "▷▷" }
            ]
        },
        readout: { art: "round", reticle: true, legends: "TGT ACQ · CH 02", bar: "line" }
    },
    vapor: {
        plate: { color: "#c9b8e8", bevel: { light: "#ffffff", dark: "#3d1d63", inner: "#8a6fb8" } },
        head: {
            h: 22, inset: 4, fill: [[0, "#b967ff"], [0.6, "#ff71ce"], [1, "#01cdfe"]],
            left: "♪ now_playing.exe", color: "#ffffff", size: 13, buttons: ["_", "□", "×"]
        },
        bezel: { l: 10, t: 8, r: 10, b: 8 },
        window: { radius: 0, sunken: { dark: "#3d1d63", light: "#ffffff" } },
        keys: {
            at: "bottom", h: 22, gap: 4, align: "start",
            style: { shape: "rect", radius: 0, fill: ["#c9b8e8", "#c9b8e8"], down: ["#b9a8d8", "#b9a8d8"], hover: "#d6c8f0", bevel: { light: "#ffffff", dark: "#3d1d63" }, ink: "#130a24" },
            items: [
                { act: "prev", w: 32 },
                { act: "toggle", w: 32 },
                { act: "next", w: 32 }
            ]
        },
        readout: { art: "square", legends: "none", bar: "blocks" }
    },
    arcade: {
        plate: { color: "#000000", strokes: [{ inset: 1.5, width: 3, color: "#2040ff" }] },
        head: {
            h: 24, inset: 3, dir: "v", fill: [[0, "#ff2020"], [1, "#a00000"]],
            left: "1UP {pos}", center: "NOW PLAYING", right: "HI {len}", color: "#ffff33", colorC: "#ffffff", size: 11
        },
        bezel: { l: 10, t: 6, r: 10, b: 10 },
        window: { radius: 0, scan: true },
        keys: {
            at: "right", w: 104, h: 28, gap: 6, align: "center",
            style: { shape: "round", ink: "transparent", under: "#500000" },
            items: [
                { act: "prev", w: 26, h: 26, style: { orb: ["#ff8080", "#ff2020", "#800000"], under: "#500000" } },
                { act: "toggle", w: 26, h: 26, style: { orb: ["#ffff99", "#ffff33", "#808000"], under: "#505000" } },
                { act: "next", w: 26, h: 26, style: { orb: ["#99ff99", "#33ff33", "#008000"], under: "#005000" } }
            ]
        },
        readout: { art: "square", legends: "none", bar: "lives" }
    },
    blueprint: {
        plate: {
            color: "#0b3a75",
            grid: { step: 12, color: "#24a9cdfa" },
            strokes: [{ inset: 0.5, width: 1, color: "#a9cdfa" }]
        },
        head: { h: 12, inset: 10, left: "FIG. 1 — NOW PLAYING", right: "SCALE 1:1", color: "#a9cdfa", size: 10 },
        bezel: { l: 14, t: 6, r: 14, b: 12 },
        window: { radius: 0, edge: "#a9cdfa" },
        keys: {
            at: "bottom", h: 26, gap: 8, align: "start",
            style: { shape: "round", border: { w: 1, color: "#e8f1ff" }, ink: "#e8f1ff", hover: "#1a4f8f", hollow: true },
            items: [
                { act: "prev", w: 26, h: 26 },
                { act: "toggle", w: 26, h: 26, style: { border: { w: 1.5, color: "#ffffff" }, ink: "#ffffff" } },
                { act: "next", w: 26, h: 26 }
            ]
        },
        readout: { art: "square", legends: "none", bar: "dim" }
    }
};

// One era's device with every field filled in (null: the era has none).
function get(era) {
    const e = eras[era];
    if (!e)
        return null;
    const plate = Object.assign({
        shape: "rect", slant: 0, radius: 0, color: "#000000", fill: null, inner: null, under: "", edge: "",
        strokes: [], brackets: null, bevel: null, grid: null, rivets: null, gloss: false, shadow: null, legend: null
    }, e.plate);
    const window = Object.assign({
        radius: 0, shade: 0, edge: "", edgeW: 1, sunken: null, frame: null, scan: false, gloss: false, vignette: false
    }, e.window);
    const keys = Object.assign({ at: "bottom", w: 0, h: 30, gap: 6, align: "stretch", free: false, style: {}, items: [] }, e.keys);
    keys.style = Object.assign({
        shape: "rect", radius: 0, fill: null, orb: null, down: null, hover: "", border: null, glow: "", edge: "",
        under: "", bevel: null, ink: "#ffffff", size: 13, slant: 0, caption: "", hollow: false
    }, keys.style);
    keys.items = keys.items.map(i => Object.assign({}, i, { style: Object.assign({}, keys.style, i.style || {}) }));
    const head = e.head ? Object.assign({
        h: 0, inset: 0, dir: "h", fill: null, left: "", center: "", right: "", color: "#ffffff", colorC: "", colorR: "", size: 11, buttons: []
    }, e.head) : null;
    return {
        era: era,
        plate: plate,
        head: head,
        bezel: Object.assign({ l: 8, t: 8, r: 8, b: 8 }, e.bezel),
        window: window,
        side: e.side ? Object.assign({ kind: "", w: 0, gap: 0 }, e.side) : null,
        keys: keys,
        readout: Object.assign({
            art: "none", reticle: false, legends: "none", prefix: "", cursor: false, bar: "segments", flaps: false, rain: false, time: "right"
        }, e.readout)
    };
}

// The device in its full size (MEDIA, a whole pane) rather than a panel:
// round ends and a lean would be absurd that tall, so it stands square
// with rounded corners, and the keys go in a row under the window.
function big(hw) {
    if (!hw)
        return null;
    const plate = Object.assign({}, hw.plate);
    if (plate.shape === "pill") {
        plate.shape = "rect";
        plate.radius = 36;
    } else if (plate.shape === "skew") {
        plate.shape = "rect";
        plate.radius = 4;
    }
    const window = Object.assign({}, hw.window);
    if (window.radius === "pill")
        window.radius = 24;
    const keys = Object.assign({}, hw.keys, { at: "bottom", free: false, align: hw.keys.align === "stretch" ? "stretch" : "end" });
    keys.h = Math.min(hw.keys.h, Math.max(30, ...hw.keys.items.map(i => i.h || 0)));
    keys.items = hw.keys.items.map(i => Object.assign({}, i, i.act === "dpad" ? { w: 44, h: 30, style: Object.assign({}, i.style, { shape: "dpad" }) } : {}));
    return Object.assign({}, hw, { plate: plate, window: window, keys: keys, side: null, big: true });
}

// Where everything goes on a w x h px device: { head, side, window, keys }
// as { x, y, w, h } in px. The window gets what the rest leaves.
function layout(hw, w, h) {
    const b = hw.bezel, k = hw.keys;
    const head = hw.head ? { x: hw.head.inset, y: hw.head.inset, w: w - hw.head.inset * 2, h: hw.head.h } : null;
    const top = head ? head.y + head.h + b.t : b.t;
    const right = k.at === "right" ? k.w + k.gap : 0;
    const bottom = k.at === "bottom" ? k.h + k.gap : 0;
    const side = hw.side ? { x: b.l, y: top, w: hw.side.w, h: h - top - b.b } : null;
    const left = b.l + (side ? side.w + hw.side.gap : 0);
    const win = { x: left, y: top, w: Math.max(1, w - left - b.r - right), h: Math.max(1, h - top - b.b - bottom) };
    const keys = k.at === "right" ? { x: win.x + win.w + k.gap, y: top, w: k.w, h: win.h } : { x: left, y: win.y + win.h + k.gap, w: win.w, h: k.h };
    return { head: head, side: side, window: win, keys: keys };
}

// ── Outlines, as SVG paths ──────────────────────────────────────────

// A w x h rectangle at (x, y) with corner radii r ([tl, tr, br, bl]).
function rounded(x, y, w, h, r) {
    const m = Math.max(0, Math.min(w, h) / 2);
    const [a, b, c, d] = (Array.isArray(r) ? r : [r, r, r, r]).map(v => Math.max(0, Math.min(m, v)));
    return `M ${x + a} ${y} L ${x + w - b} ${y} ` + (b ? `A ${b} ${b} 0 0 1 ${x + w} ${y + b} ` : "") + `L ${x + w} ${y + h - c} ` + (c ? `A ${c} ${c} 0 0 1 ${x + w - c} ${y + h} ` : "") + `L ${x + d} ${y + h} ` + (d ? `A ${d} ${d} 0 0 1 ${x} ${y + h - d} ` : "") + `L ${x} ${y + a} ` + (a ? `A ${a} ${a} 0 0 1 ${x + a} ${y} ` : "") + "Z";
}

// A parallelogram leaning right by `k` of its height, inset by i.
function skewed(w, h, k, i) {
    const s = k * h, d = i * Math.sqrt(1 + k * k);
    const lx = y => s * (1 - y / h) + d, rx = y => w - s * y / h - d;
    return `M ${lx(i)} ${i} L ${rx(i)} ${i} L ${rx(h - i)} ${h - i} L ${lx(h - i)} ${h - i} Z`;
}

// The plate's outline on a w x h device, inset by i px.
function platePath(hw, w, h, i) {
    const p = hw.plate;
    i = i || 0;
    if (w <= 2 * i || h <= 2 * i)
        return "";
    if (p.shape === "skew")
        return skewed(w, h, p.slant, i);
    const r = p.shape === "pill" ? h / 2 - i : Array.isArray(p.radius) ? p.radius.map(v => Math.max(0, v - i)) : Math.max(0, p.radius - i);
    return rounded(i, i, w - 2 * i, h - 2 * i, r);
}

// The display window's outline, w x h, in px (unit 1) or in dots (unit =
// the pitch: the radius shrinks with it). A skew plate's window leans with
// it, by the plate's slant.
function windowPath(hw, w, h, unit) {
    unit = unit || 1;
    const r = hw.window.radius;
    if (hw.plate.shape === "skew")
        return skewed(w, h, hw.plate.slant, 0);
    const rr = r === "pill" ? h / 2 : Array.isArray(r) ? r.map(v => v / unit) : r / unit;
    if (!Array.isArray(rr) && rr < 0.5)
        return "";
    return rounded(0, 0, w, h, rr);
}

// The color of a key's ink: an era tube by name, or as written.
function ink(c, slots) {
    const m = /^slot([0-2])$/.exec(c || "");
    return m ? slots[Number(m[1])] : c;
}

// The transport icons, on a 16 x 14 box.
var icons = {
    prev: "M0 1 L3 1 L3 13 L0 13 Z M15 1 L4 7 L15 13 Z",
    next: "M1 1 L12 7 L1 13 Z M13 1 L16 1 L16 13 L13 13 Z",
    play: "M3 0 L15 7 L3 14 Z",
    pause: "M2 0 L6 0 L6 14 L2 14 Z M10 0 L14 0 L14 14 L10 14 Z"
};
