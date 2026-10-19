pragma Singleton

import QtQuick
import Quickshell
import qs

// The car stereo's display and its gunmetal, from the panel design canvas
// (dot-shell-panels.html, the VFD boards): cyan phosphor, the amber of the
// alarms and the picked row, the teal of the small print, and the plate,
// keys and rules round the glass.
Singleton {
    // A color in the era's own tone and in its other one (the `tone` token,
    // Palettes.js): every color here, and every literal in the panels, is
    // a pair, the second authored for the other glass.
    function c(own: var, other: var): color {
        return Tokens.flipped ? (other === undefined ? Tokens.ink(own) : other) : own;
    }
    // Halos: off when the era is drawn light.
    readonly property bool neon: Tokens.neon

    readonly property color cyan: c("#6fffe9", "#0f4f47")
    readonly property color amber: c("#ff9f1c", "#b35c00")
    readonly property color green: c("#9dffb0", "#2f6e3e")
    // Alarms: the battery low.
    readonly property color red: c("#ff5e3a", "#c0391b")
    // Small print and legends.
    readonly property color teal: c("#289682", "#4f7d74")
    // Rules on the glass: card outlines, empty tracks.
    readonly property color deep: c("#0a3c37", "#a9c4bd")
    readonly property color glass: c("#030706", "#c9d8d2")
    // The segments that are off, still showing through the smoked glass:
    // a step up from the unlit grid so they read as cells.
    readonly property color ghost: c("#123a33", "#b9cbc4")

    // The plate: brushed gunmetal, lit along its top edge.
    readonly property color plateTop: c("#3a3f42", "#e4e7e9")
    readonly property color plateBottom: c("#1b1e20", "#bfc4c8")
    readonly property color plateEdge: c("#5a6064", "#f7f9fa")
    // Hard keys.
    readonly property color keyTop: c("#4a5054", "#f1f3f4")
    readonly property color keyBottom: c("#2a2e31", "#cfd4d7")
    readonly property color keyEdge: c("#6a7176", "#ffffff")
    readonly property color keyInk: c("#cfd6d9", "#2c3236")
    readonly property color keyDim: c("#8a9296", "#6d767b")
}
