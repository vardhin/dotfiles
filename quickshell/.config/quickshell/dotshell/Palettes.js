.pragma library

// Every era's other tone, designed, not derived. An era's own palette lives
// in Eras.qml (Frutiger Aero is light, the rest dark); this is
// its counterpart, built the way paired themes are: each role (glass, ink,
// rules, accents, alarms) given its own value for the other glass rather than
// a color flipped. Dark counterparts use tinted near-blacks, lift raised
// surfaces by lightness and keep gloss to a faint sheen; light ones get deeper,
// more saturated accents (text at 4.5:1 on the glass) and no neon glow. Each
// light tone has a real-world identity of its own:
//
//   tokyo        Tokyo Night Day (folke/tokyonight.nvim's day palette)
//   nineties     lilac paper: off-white, deep orchid, rose, olive
//   vfd          a daylight LCD head unit: reflective segments, aluminium
//   flap         an ivory Solari board, black letters on white flaps
//   nixie        brass and ivory instrument panel
//   nightvision  a daylight scope: sand, olive drab, coyote
//   vapor        pastel vaporwave
//   blueprint    a whiteprint (diazo): cream paper, blue-violet lines
// and the dark one:
//   aero         Aero night glass: deep navy glass, sky ink, black shadows
//
// Per era:
//   slots unlit glass ramp glow ansi blurb   as in Eras.qml, for this tone
//   map    era colors (Hardware.js, NotifLook.js, a few shared QML literals)
//          -> this tone's; colors not listed match the nearest listed one
//          within a few steps, else stay as they are
//   hw nl  patches over the mapped Hardware.js / NotifLook.js tables, where
//          one color plays two roles

const alts = {
    tokyo: {
        blurb: "OVERCAST",
        slots: ["#2e7de9", "#007197", "#7847bd"],
        unlit: "#d0d3e0",
        glass: "#e1e2e7",
        ramp: ["#2b3368", "#3760bf", "#2e7de9", "#d5d8ea"],
        glow: 0.08,
        ansi: ["#343b6a", "#f52a65", "#587539", "#8c6c3e", "#2e7de9", "#9854f1", "#007197", "#c4c8da"],
        map: {
            "#16161e": "#e1e2e7", "#7aa2f7": "#2e7de9", "#7dcfff": "#007197", "#bb9af7": "#7847bd",
            "#3b4261": "#c4c8da", "#292e42": "#d0d3e0", "#f7768e": "#f52a65", "#ff9e64": "#b15c00",
            "#c0caf5": "#3760bf", "#a9b1d6": "#6172b0", "#565f89": "#848cb5"
        }
    },
    nineties: {
        blurb: "LILAC PAPER",
        slots: ["#8a3f88", "#b8466f", "#5f6e2a"],
        unlit: "#e6ddd2",
        glass: "#f4ede4",
        ramp: ["#2a1f30", "#b8466f", "#8a3f88", "#f4ede4"],
        glow: 0.06,
        ansi: ["#2a1f30", "#b5523f", "#4f7a3a", "#8a6a2a", "#3f6a9a", "#8a5a8c", "#2f7f76", "#e6ddd2"],
        map: {
            "#c776c4": "#8a3f88", "#e57ba9": "#b8466f", "#dff57e": "#5f6e2a", "#120d17": "#f4ede4",
            "#f6ead8": "#2a1f30", "#3a2a42": "#d9cfd6", "#2a1f30": "#e6ddd2", "#ff7a6b": "#b5523f",
            "#e8b4e4": "#a0609e", "#8a4a8a": "#e3cfe0"
        },
        hw: { plate: { inner: { color: "#f4ede4" } } }
    },
    vfd: {
        blurb: "DAYLIGHT LCD",
        slots: ["#0f4f47", "#b35c00", "#2f6e3e"],
        unlit: "#bccdc6",
        glass: "#c9d8d2",
        ramp: ["#0f2a26", "#2f6e63", "#7fa89c", "#d6e3de"],
        glow: 0.04,
        ansi: ["#1d2f2b", "#c0391b", "#2f6e3e", "#9a5a00", "#1f5f9e", "#7a3f9a", "#0f6b62", "#c9d8d2"],
        map: {
            "#6fffe9": "#0f4f47", "#ff9f1c": "#b35c00", "#9dffb0": "#2f6e3e", "#ff5e3a": "#c0391b",
            "#289682": "#4f7d74", "#0a3c37": "#a9c4bd", "#030706": "#c9d8d2", "#123a33": "#b9cbc4",
            "#3a3f42": "#e4e7e9", "#1b1e20": "#bfc4c8", "#5a6064": "#f7f9fa", "#4a5054": "#f1f3f4",
            "#2a2e31": "#cfd4d7", "#6a7176": "#ffffff", "#cfd6d9": "#2c3236", "#8a9296": "#6d767b",
            "#555c60": "#f6f8f9", "#23272a": "#c3c8cb", "#000000": "#8d9a95"
        }
    },
    aero: {
        blurb: "NIGHT GLASS",
        slots: ["#5cb6ff", "#4fd06a", "#3fd0e0"],
        unlit: "#14263a",
        glass: "#0b1828",
        ramp: ["#06101c", "#123a63", "#2f7fc8", "#8fd4ff"],
        glow: 0.45,
        ansi: ["#0b1828", "#ff5a64", "#4fd06a", "#f0c040", "#5cb6ff", "#c77dff", "#3fd0e0", "#d6e8f5"],
        map: {
            "#ffffff": "#2b5580", "#d7f0ff": "#132a45", "#9fd8f5": "#1d4a73", "#e8f6fd": "#0d1e33",
            "#62c3ee": "#3d9be0", "#1f7fd1": "#5cb6ff", "#0b3f80": "#dceeff", "#8fe07a": "#5fd06a",
            "#23963c": "#2f9e48", "#cdeaf8": "#1d3550", "#62a8d0": "#7f9fb8", "#c8323c": "#ff5a64"
        },
        hw: { plate: { shadow: { color: "#a6000000", y: 6 } } },
        nl: { fill: "#132a45", rim: "#1d3550", keyFill: "#1d3a5c", keyRim: "#2b5580", text: "#dceeff", head: "#dceeff" }
    },
    nixie: {
        blurb: "BRASS & IVORY",
        slots: ["#b4460f", "#8a5a2b", "#7a2e0a"],
        unlit: "#e6d9c6",
        glass: "#f4ece0",
        ramp: ["#3a1d0e", "#8a3510", "#d98a4f", "#f4ece0"],
        glow: 0.05,
        ansi: ["#3a1d0e", "#b4460f", "#9a5a1a", "#8a6a2a", "#7a2e0a", "#a8501f", "#8a5a2b", "#e6d9c6"],
        map: { "#3a1d0e": "#4a2a14", "#5a2e16": "#e8cfa6", "#3e1f0f": "#dcbf94", "#b8863b": "#9a6a24" },
        hw: { plate: { fill: { dir: "h", stops: [[0, "#d9b98c"], [0.3, "#e8cfa6"], [0.6, "#dcbf94"], [1, "#e8cfa6"]] } } }
    },
    flap: {
        blurb: "IVORY BOARD",
        slots: ["#1c1b18", "#b07d00", "#c25a00"],
        unlit: "#e4dfd2",
        glass: "#f1ede3",
        ramp: ["#1c1b18", "#5a574f", "#a39d8e", "#f1ede3"],
        glow: 0,
        ansi: ["#1c1b18", "#c4321a", "#4f7a28", "#9a6a00", "#2a5d9e", "#8a3f8a", "#1f7a73", "#e8e3d6"],
        map: {
            "#141414": "#e8e3d6", "#2a2a2a": "#c9c2b2", "#3a3a3a": "#b5ae9e", "#6e6e64": "#8a8475",
            "#ffd400": "#b07d00", "#262626": "#fbf9f3", "#1e1e1e": "#efebe1", "#303030": "#ffffff",
            "#0b0b0b": "#2a2418", "#f2f2e6": "#1c1b18", "#ffe14d": "#c99400", "#a88c00": "#7a5600",
            "#212121": "#f5f2ea", "#bdbdb0": "#5a574f", "#ff5a36": "#c4321a"
        },
        nl: { keyInk: "#fbf9f3" }
    },
    nightvision: {
        blurb: "DAYLIGHT SCOPE",
        slots: ["#3f5a1a", "#5c6b2e", "#6b4e1a"],
        unlit: "#d8d2ba",
        glass: "#e9e4d0",
        ramp: ["#262b14", "#4f5a28", "#9a9a6a", "#e9e4d0"],
        glow: 0,
        ansi: ["#2c3314", "#8a3a1a", "#3f5a1a", "#7a6420", "#4f5a28", "#6b4e1a", "#556b3a", "#d8d2ba"],
        map: { "#040a03": "#e9e4d0", "#0f3a0c": "#a8a27e", "#7dff6a": "#3f5a1a", "#2fae2a": "#5c6b2e", "#d6ffc9": "#262b14", "#2b8a22": "#7a7a4a" }
    },
    vapor: {
        blurb: "PASTEL DUSK",
        slots: ["#d63fa3", "#0096c7", "#8b3fd9"],
        unlit: "#ece2f8",
        glass: "#fbf7ff",
        ramp: ["#3d2466", "#8b3fd9", "#e58ccc", "#fbf7ff"],
        glow: 0.1,
        ansi: ["#2a1840", "#d61f5f", "#0f9a6e", "#a8730a", "#0083b8", "#c2399a", "#0f8f9e", "#efe6fb"],
        map: {
            "#c9b8e8": "#f3ecfb", "#ffffff": "#ffffff", "#3d1d63": "#9a86bd", "#8a6fb8": "#c8b6e6",
            "#b967ff": "#a35ee8", "#ff71ce": "#e55aae", "#01cdfe": "#1aa9d6", "#b9a8d8": "#e3d6f5",
            "#d6c8f0": "#faf6ff", "#130a24": "#2a1840", "#ff3d7f": "#d61f5f"
        }
    },
    blueprint: {
        blurb: "WHITEPRINT",
        slots: ["#1c2f6e", "#3a5fb0", "#0f1f55"],
        unlit: "#e3dfd0",
        glass: "#f3efe2",
        ramp: ["#1c2f6e", "#4a6bb5", "#a9b6d8", "#f3efe2"],
        glow: 0,
        ansi: ["#1c2f6e", "#b8372a", "#3d7a46", "#9a6a12", "#2f57b0", "#6a3fa0", "#2a7a8a", "#e6e1d1"],
        map: {
            "#0b3a75": "#f3efe2", "#a9cdfa": "#3a5fb0", "#e8f1ff": "#1c2f6e", "#1a4f8f": "#e6e1d1",
            "#ffffff": "#0f1f55", "#ff9b8a": "#b8372a"
        }
    }
};

function get(era) {
    return alts[era] ?? null;
}

function rgb(c) {
    return [parseInt(c.slice(1, 3), 16), parseInt(c.slice(3, 5), 16), parseInt(c.slice(5, 7), 16)];
}

// One color, "#rrggbb" (or "#aarrggbb", alpha kept), in the era's other tone.
function color(era, c) {
    const a = alts[era];
    if (!a || typeof c !== "string" || !/^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(c))
        return c;
    const alpha = c.length === 9 ? c.slice(1, 3) : "";
    const hex = "#" + c.slice(c.length - 6).toLowerCase();
    let hit = a.map[hex];
    if (hit === undefined) {
        const p = rgb(hex);
        let best = 1e9;
        for (const k in a.map) {
            const q = rgb(k);
            const d = Math.abs(p[0] - q[0]) + Math.abs(p[1] - q[1]) + Math.abs(p[2] - q[2]);
            if (d < best) {
                best = d;
                hit = a.map[k];
            }
        }
        if (best > 12)
            return c;
    }
    return alpha ? "#" + alpha + hit.slice(1) : hit;
}

function merge(base, patch) {
    if (!patch || typeof patch !== "object" || Array.isArray(patch))
        return patch === undefined ? base : patch;
    const out = Object.assign({}, base);
    for (const k in patch)
        out[k] = merge(base ? base[k] : undefined, patch[k]);
    return out;
}

// A Hardware.js / NotifLook.js table in the era's other tone. Light tones
// drop neon glows: on pale glass a halo reads as a smudge.
function table(era, o, kind) {
    const a = alts[era];
    if (!a)
        return o;
    const light = isLight(era);
    const walk = (v, key) => {
        if (key === "glow" && light)
            return "";
        if (typeof v === "string")
            return color(era, v);
        if (Array.isArray(v))
            return v.map(x => walk(x, ""));
        if (v && typeof v === "object") {
            const r = {};
            for (const k in v)
                r[k] = walk(v[k], k);
            return r;
        }
        return v;
    };
    return merge(walk(o, ""), a[kind]);
}

// The era's other tone is light: every era's own tone is dark but aero.
function isLight(era) {
    return era !== "aero";
}
