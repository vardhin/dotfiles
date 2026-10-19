pragma Singleton

import QtQuick
import Quickshell

// The car stereo's display and its gunmetal, from the panel design canvas
// (dot-shell-panels.html, the VFD boards): cyan phosphor, the amber of the
// alarms and the picked row, the teal of the small print, and the plate,
// keys and rules round the glass.
Singleton {
    readonly property color cyan: "#6fffe9"
    readonly property color amber: "#ff9f1c"
    readonly property color green: "#9dffb0"
    // Alarms: the battery low.
    readonly property color red: "#ff5e3a"
    // Small print and legends.
    readonly property color teal: "#289682"
    // Rules on the glass: card outlines, empty tracks.
    readonly property color deep: "#0a3c37"
    readonly property color glass: "#030706"
    // The segments that are off, still showing through the smoked glass:
    // a step up from the unlit grid so they read as cells.
    readonly property color ghost: "#123a33"

    // The plate: brushed gunmetal, lit along its top edge.
    readonly property color plateTop: "#3a3f42"
    readonly property color plateBottom: "#1b1e20"
    readonly property color plateEdge: "#5a6064"
    // Hard keys.
    readonly property color keyTop: "#4a5054"
    readonly property color keyBottom: "#2a2e31"
    readonly property color keyEdge: "#6a7176"
    readonly property color keyInk: "#cfd6d9"
    readonly property color keyDim: "#8a9296"
}
