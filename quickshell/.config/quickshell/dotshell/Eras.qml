pragma Singleton

import QtQuick
import Quickshell

// Era presets: moods, not palette clones. Tokyo Night and VFD come from the Dot
// Shell prototype; Phase 5 adds 90s Nights and Frutiger Aero; Phase 9
// Nixie, Split-Flap, Night Vision, Vaporwave and Blueprint. Each era
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
            blurb: "RAIN CITY",
            slots: ["#7aa2f7", "#7dcfff", "#bb9af7"],
            unlit: "#292e42",
            glass: "#16161e",
            ramp: ["#24283b", "#3d59a1", "#7aa2f7", "#c0caf5"],
            glow: 0.35,
            shape: "round",
            light: false,
            mono: false,
            ansi: ["#15161e", "#f7768e", "#9ece6a", "#e0af68", "#7aa2f7", "#bb9af7", "#7dcfff", "#a9b1d6"]
        },
        nineties: {
            name: "90s Nights",
            blurb: "QUIET STORM",
            slots: ["#c776c4", "#e57ba9", "#dff57e"],
            unlit: "#2a1f30",
            glass: "#120d17",
            ramp: ["#2a1f30", "#6a3f72", "#c776c4", "#dff57e"],
            glow: 0.35,
            shape: "round",
            light: false,
            mono: false,
            ansi: ["#1a1220", "#ff7a6b", "#a6e07a", "#f2c86a", "#6fa0ff", "#c776c4", "#36c9b8", "#f6ead8"]
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
