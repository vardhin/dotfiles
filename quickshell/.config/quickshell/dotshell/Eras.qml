pragma Singleton

import QtQuick
import Quickshell

// Era presets: moods, not palette clones. The first four come from the Dot
// Shell prototype; Phase 5 adds 90s Nights, Frutiger Aero and Game Boy.
//
//   slots   one color per panel "tube": [0] primary, [1] secondary, [2] accent
//   unlit   a panel dot that is off
//   glass   the gap between dots (and the screen behind everything)
//   ramp    4 levels, dark -> bright; images are mapped onto it in "era" depth
//   shape   "round" | "square" | "bubble"
//   glow    0 .. 1 halo around lit dots
//   light   light glass with dark ink (exports pick light app themes)
//   mono    one hue only; the wallpaper tint (Tokens.tint) rotates the ANSI
//           colors too, so the terminal stays mono
//   ansi    terminal colors 0-7 (black red green yellow blue magenta cyan
//           white) for the app export (services/Export.qml); 8-15 are derived
//
// Order here is the order of the era switcher and of `cycleEra`.
Singleton {
    readonly property var all: ({
        phosphor: {
            name: "Phosphor",
            blurb: "AMBER CRT",
            slots: ["#ffb347", "#ffd68c", "#e68c28"],
            unlit: "#2a2015",
            glass: "#0c0906",
            ramp: ["#2e200d", "#6b4b1e", "#b88133", "#ffb347"],
            glow: 0.55,
            shape: "round",
            light: false,
            mono: true,
            ansi: ["#1a130b", "#c96a2a", "#d9a441", "#ffcf70", "#a8742c", "#e08a3c", "#f2b75c", "#ffd68c"]
        },
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
            slots: ["#0f380f", "#306230", "#0f380f"],
            unlit: "#8bac0f",
            glass: "#9bbc0f",
            ramp: ["#0f380f", "#306230", "#8bac0f", "#9bbc0f"],
            glow: 0,
            shape: "square",
            light: true,
            mono: true,
            ansi: ["#0f380f", "#306230", "#306230", "#306230", "#0f380f", "#306230", "#306230", "#8bac0f"]
        }
    })

    readonly property var ids: Object.keys(all)

    function get(id: string): var {
        return all[id] ?? all.phosphor;
    }
}
