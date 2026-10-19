.pragma library

// Every era's other tone, designed, not derived. An era's own palette lives
// in Eras.qml (Frutiger Aero and Game Boy are light, the rest dark); this is
// its counterpart, built the way paired themes are: each role (glass, ink,
// rules, accents, alarms) given its own value for the other glass rather than
// a color flipped. Dark counterparts use tinted near-blacks, lift raised
// surfaces by lightness and keep gloss to a faint sheen; light ones get deeper,
// more saturated accents (text at 4.5:1 on the glass) and no neon glow. Each
// light tone has a real-world identity of its own:
//
//   tokyo        Tokyo Night Day (folke/tokyonight.nvim's day palette)
//   nineties     Memphis: off-white, hot pink, blue, sun yellow
//   matrix       green-bar printout paper
//   vfd          a daylight LCD head unit: reflective segments, aluminium
//   flap         an ivory Solari board, black letters on white flaps
//   nixie        brass and ivory instrument panel
//   nightvision  a daylight scope: sand, olive drab, coyote
//   vapor        pastel vaporwave
//   arcade       cabinet side art: white card, primaries
//   blueprint    a whiteprint (diazo): cream paper, blue-violet lines
// and the dark ones:
//   aero         Aero night glass: deep navy glass, sky ink, black shadows
//   gameboy      the Kirokaze palette (lospec): violet night, lime pixels
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
        blurb: "NEON BY DAY",
        slots: ["#c92c7f", "#007197", "#7847bd"],
        unlit: "#d0d3e0",
        glass: "#e1e2e7",
        ramp: ["#2b3368", "#7847bd", "#c92c7f", "#d5d8ea"],
        glow: 0.12,
        ansi: ["#343b6a", "#e0285c", "#587539", "#8c6c3e", "#2e7de9", "#9854f1", "#007197", "#c4c8da"],
        map: {
            "#08071a": "#e1e2e7", "#ff3cac": "#c92c7f", "#2de2e6": "#007197", "#b388ff": "#7847bd",
            "#3c146e": "#c4c8da", "#211c46": "#d0d3e0", "#ff2a4a": "#e0285c"
        }
    },
    nineties: {
        blurb: "MEMPHIS DAYTIME",
        slots: ["#e6177d", "#0a84d6", "#d99a00"],
        unlit: "#efe6d6",
        glass: "#fff6e5",
        ramp: ["#2b1b4a", "#a3157f", "#ff6fb0", "#fff6e5"],
        glow: 0.08,
        ansi: ["#2b1b4a", "#d9234a", "#1f9a5a", "#c48a00", "#0a84d6", "#e6177d", "#00a3a3", "#f1e6d2"],
        map: {
            "#ffe600": "#f5c400", "#ff2e97": "#e6177d", "#1fa8ff": "#0a84d6", "#0a0514": "#2b1b4a",
            "#ffffff": "#ffffff", "#a3157f": "#f7b6d6"
        },
        hw: { plate: { inner: { color: "#fff6e5" } } }
    },
    matrix: {
        blurb: "GREEN BAR PAPER",
        slots: ["#0b6b2a", "#3c8f52", "#14501f"],
        unlit: "#d9ead6",
        glass: "#eef6ec",
        ramp: ["#0b2e14", "#1f6b35", "#7fbf8c", "#eef6ec"],
        glow: 0,
        ansi: ["#0f3d1c", "#2f7a3f", "#0b6b2a", "#4f8f3a", "#14501f", "#3c8f52", "#2a7f5a", "#d9ead6"],
        map: { "#020805": "#eef6ec", "#00ff41": "#0b6b2a", "#00aa28": "#3c8f52", "#b4ffc8": "#14501f" }
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
    gameboy: {
        blurb: "KIROKAZE NIGHT",
        slots: ["#94e344", "#e2f3e4", "#46878f"],
        unlit: "#3b3560",
        glass: "#332c50",
        ramp: ["#332c50", "#46878f", "#94e344", "#e2f3e4"],
        glow: 0.25,
        ansi: ["#2a2442", "#46878f", "#94e344", "#94e344", "#46878f", "#94e344", "#46878f", "#e2f3e4"],
        map: {
            "#c9c5c0": "#4a4266", "#a19c96": "#372f52", "#346856": "#46878f", "#55565f": "#221d36",
            "#3a3a8a": "#a9a3d6", "#2b2b30": "#1b1730", "#6a6a72": "#8a85a8"
        },
        hw: { keys: { style: { ink: "#e2f3e4" } }, window: { frame: { markColor: "#a9a3d6" } } }
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
        map: { "#040a03": "#e9e4d0", "#0f3a0c": "#a8a27e", "#7dff6a": "#3f5a1a", "#2fae2a": "#5c6b2e", "#d6ffc9": "#262b14" }
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
    arcade: {
        blurb: "CABINET ART",
        slots: ["#13873a", "#d42020", "#c99400"],
        unlit: "#e3e1d8",
        glass: "#f5f4ef",
        ramp: ["#14143a", "#1d3fd8", "#d42020", "#f5f4ef"],
        glow: 0.05,
        ansi: ["#1a1a1a", "#d42020", "#13873a", "#b88400", "#1d3fd8", "#b0209c", "#0f8a96", "#e3e1d8"],
        // The buttons are real plastic: they keep their colors.
        map: {
            "#000000": "#f5f4ef", "#2040ff": "#1d3fd8", "#ff2020": "#d42020", "#a00000": "#8a0f0f",
            "#ff8080": "#ff8080", "#800000": "#800000", "#ffff99": "#ffff99", "#808000": "#808000",
            "#99ff99": "#99ff99", "#33ff33": "#33ff33", "#008000": "#008000", "#500000": "#500000",
            "#505000": "#505000", "#005000": "#005000", "#ffff33": "#ffff33", "#ffffff": "#ffffff"
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

// The era's other tone is light: every era's own tone is dark but these two.
function isLight(era) {
    return era !== "aero" && era !== "gameboy";
}
