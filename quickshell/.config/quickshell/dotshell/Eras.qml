pragma Singleton

import QtQuick
import Quickshell

// Era presets: moods, not palette clones. The first three come from the Dot
// Shell prototype; Phase 5 adds 90s Nights, Frutiger Aero and Game Boy; Phase 9
// Nixie, Split-Flap, Night Vision, Vaporwave, Arcade and Blueprint. Each era
// also has a scene (panes/Scenes.js), played while you are away.
//
//   slots   one color per panel "tube": [0] primary, [1] secondary, [2] accent
//   unlit   a panel dot that is off
//   glass   the gap between dots (and the screen behind everything)
//   ramp    4 levels, dark -> bright; images are mapped onto it in "era" depth
//   shape   "round" | "square" | "bubble"
//   glow    0 .. 1 halo around lit dots
//   light   light glass with dark ink (exports pick light app themes): the
//           era's own tone. Every era also has the other tone, designed in
//           Palettes.js (the `tone` token)
//   mono    one hue only; the wallpaper tint (Tokens.tint) rotates the ANSI
//           colors too, so the terminal stays mono
//   ansi    terminal colors 0-7 (black red green yellow blue magenta cyan
//           white) for the app export (services/Export.qml); 8-15 are derived
//
// Order here is the order of the era switcher and of `cycleEra`.
Singleton {
    readonly property var all: ({
        tokyo: {
            name: "Tokyo Night",
            blurb: "NEON ALLEY",
            slots: ["#ff3cac", "#2de2e6", "#b388ff"],
            unlit: "#211c46",
            glass: "#08071a",
            ramp: ["#3c146e", "#b428aa", "#ff3cac", "#2de2e6"],
            glow: 0.8,
            shape: "round",
            light: false,
            mono: false,
            ansi: ["#1a1638", "#ff3c6e", "#3cffa0", "#ffe14d", "#6e7bff", "#ff3cac", "#2de2e6", "#e6e1ff"]
        },
        nineties: {
            name: "90s Nights",
            blurb: "STRIP MALL TUBES",
            slots: ["#ff2e97", "#1fa8ff", "#ffe600"],
            unlit: "#22123a",
            glass: "#0a0514",
            ramp: ["#3b0d5c", "#a3157f", "#ff2e97", "#ffe600"],
            glow: 0.9,
            shape: "round",
            light: false,
            mono: false,
            ansi: ["#1c0f30", "#ff3355", "#39ff6a", "#ffe600", "#1fa8ff", "#ff2e97", "#29fff1", "#ffe9f6"]
        },
        matrix: {
            name: "Matrix",
            blurb: "GREEN RAIN",
            slots: ["#00ff41", "#b4ffc8", "#00aa28"],
            unlit: "#0a2414",
            glass: "#020805",
            ramp: ["#002e0c", "#006b1b", "#00b82f", "#00ff41"],
            glow: 0.5,
            shape: "square",
            light: false,
            mono: true,
            ansi: ["#04140a", "#2fa84f", "#00ff41", "#8cff9e", "#00aa28", "#3fd468", "#6dff8f", "#b4ffc8"]
        },
        vfd: {
            name: "VFD",
            blurb: "CAR STEREO",
            slots: ["#6fffe9", "#ff9f1c", "#9dffb0"],
            unlit: "#0e201c",
            glass: "#030706",
            ramp: ["#0a3c37", "#289682", "#6fffe9", "#ff9f1c"],
            glow: 0.65,
            shape: "round",
            light: false,
            mono: false,
            ansi: ["#0b1a17", "#ff5e3a", "#9dffb0", "#ff9f1c", "#3cb4ff", "#d38cff", "#6fffe9", "#e6fff9"]
        },
        aero: {
            name: "Frutiger Aero",
            blurb: "SKY GLASS",
            slots: ["#0a64c8", "#23963c", "#0096b4"],
            unlit: "#c2e3f5",
            glass: "#e8f6fd",
            ramp: ["#0b3f80", "#1f7fd1", "#62c3ee", "#cdf0ff"],
            glow: 0.3,
            shape: "bubble",
            light: true,
            mono: false,
            ansi: ["#123a5c", "#c8323c", "#23963c", "#b48200", "#0a64c8", "#a03cb4", "#0096b4", "#d7ecf7"]
        },
        gameboy: {
            name: "Game Boy",
            blurb: "DMG-01 LCD",
            // The BGB emulator's greens: the DMG's four shades, minty
            // rather than pea soup.
            slots: ["#081820", "#346856", "#081820"],
            unlit: "#cbe8bb",
            glass: "#e0f8d0",
            ramp: ["#081820", "#346856", "#88c070", "#e0f8d0"],
            glow: 0,
            shape: "square",
            light: true,
            mono: true,
            ansi: ["#081820", "#346856", "#346856", "#346856", "#081820", "#346856", "#346856", "#cbe8bb"]
        },
        nixie: {
            name: "Nixie",
            blurb: "COLD CATHODE",
            slots: ["#ff7a1a", "#ffb366", "#c2410c"],
            unlit: "#2b130a",
            glass: "#0a0503",
            ramp: ["#3a1606", "#8a3510", "#ff7a1a", "#ffc285"],
            glow: 0.85,
            shape: "round",
            light: false,
            mono: true,
            ansi: ["#1f0c05", "#e0501a", "#ff8f3a", "#ffb366", "#c2410c", "#ff6a2a", "#ffa04d", "#ffd9b3"]
        },
        flap: {
            name: "Split-Flap",
            blurb: "DEPARTURE BOARD",
            slots: ["#f2f2e6", "#ffd400", "#ff8c00"],
            unlit: "#1e1e1e",
            glass: "#0b0b0b",
            ramp: ["#262626", "#6e6e64", "#bdbdb0", "#f2f2e6"],
            glow: 0.1,
            shape: "square",
            light: false,
            mono: false,
            ansi: ["#141414", "#ff5a36", "#9ee06b", "#ffd400", "#5aa9ff", "#d48cff", "#5ae0d6", "#f2f2e6"]
        },
        nightvision: {
            name: "Night Vision",
            blurb: "GEN III P43",
            slots: ["#7dff6a", "#d6ffc9", "#2fae2a"],
            unlit: "#0d260b",
            glass: "#040a03",
            ramp: ["#0f3a0c", "#2b8a22", "#62e04f", "#c9ffb8"],
            glow: 0.6,
            shape: "round",
            light: false,
            mono: true,
            ansi: ["#071506", "#3fbf34", "#7dff6a", "#b4ff9e", "#2fae2a", "#58d649", "#9dff8a", "#d6ffc9"]
        },
        vapor: {
            name: "Vaporwave",
            blurb: "A E S T H E T I C",
            slots: ["#ff71ce", "#01cdfe", "#b967ff"],
            unlit: "#2d1b4e",
            glass: "#130a24",
            ramp: ["#3d1d63", "#b967ff", "#ff71ce", "#fffb96"],
            glow: 0.7,
            shape: "round",
            light: false,
            mono: false,
            ansi: ["#21123d", "#ff6b9d", "#05ffa1", "#fffb96", "#01cdfe", "#ff71ce", "#7af7ff", "#f4e9ff"]
        },
        arcade: {
            name: "Arcade",
            blurb: "RGB332 CABINET",
            slots: ["#33ff33", "#ff3333", "#ffff33"],
            unlit: "#181818",
            glass: "#000000",
            ramp: ["#202040", "#2040ff", "#ff2020", "#ffffff"],
            glow: 0.45,
            shape: "square",
            light: false,
            mono: false,
            ansi: ["#101010", "#ff3333", "#33ff33", "#ffff33", "#3366ff", "#ff33ff", "#33ffff", "#f0f0f0"]
        },
        blueprint: {
            name: "Blueprint",
            blurb: "DRAFTING TABLE",
            slots: ["#e8f1ff", "#a9cdfa", "#ffffff"],
            unlit: "#1a4f8f",
            glass: "#0b3a75",
            ramp: ["#123f7a", "#3d72b8", "#a9cdfa", "#f2f7ff"],
            glow: 0.2,
            shape: "round",
            light: false,
            mono: true,
            ansi: ["#0a2f60", "#ff9b8a", "#b8f0c8", "#ffe7a3", "#a9cdfa", "#d9c2ff", "#bfeaff", "#e8f1ff"]
        }
    })

    readonly property var ids: Object.keys(all)

    function get(id: string): var {
        return all[id] ?? all.tokyo;
    }
}
