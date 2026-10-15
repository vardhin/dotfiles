pragma Singleton

import QtQuick
import Quickshell

// Era presets: moods, not palette clones. Values come from the Dot Shell prototype.
// Phase 5 adds the rest (90s Nights, Frutiger Aero, Game Boy, ...) and the era switcher.
//
//   slots   one color per panel "tube": [0] primary, [1] secondary, [2] accent
//   unlit   a panel dot that is off
//   glass   the gap between dots
//   ramp    4 levels, dark -> bright; images are mapped onto it in "era" depth
//   shape   "round" | "square" | "bubble"
Singleton {
    readonly property var all: ({
        phosphor: {
            name: "Phosphor",
            slots: ["#ffb347", "#ffd68c", "#e68c28"],
            unlit: "#2a2015",
            glass: "#0c0906",
            ramp: ["#2e200d", "#6b4b1e", "#b88133", "#ffb347"],
            glow: 0.55,
            shape: "round"
        },
        tokyo: {
            name: "Tokyo Night",
            slots: ["#ff3cac", "#2de2e6", "#b388ff"],
            unlit: "#211c46",
            glass: "#08071a",
            ramp: ["#3c146e", "#b428aa", "#ff3cac", "#2de2e6"],
            glow: 0.8,
            shape: "round"
        },
        matrix: {
            name: "Matrix",
            slots: ["#00ff41", "#b4ffc8", "#00aa28"],
            unlit: "#0a2414",
            glass: "#020805",
            ramp: ["#002e0c", "#006b1b", "#00b82f", "#00ff41"],
            glow: 0.5,
            shape: "square"
        },
        vfd: {
            name: "VFD",
            slots: ["#6fffe9", "#ff9f1c", "#9dffb0"],
            unlit: "#0e201c",
            glass: "#030706",
            ramp: ["#0a3c37", "#289682", "#6fffe9", "#ff9f1c"],
            glow: 0.65,
            shape: "round"
        }
    })

    readonly property var ids: Object.keys(all)

    function get(id: string): var {
        return all[id] ?? all.phosphor;
    }
}
