pragma Singleton

import QtQuick
import Quickshell
import qs

// Tokyo Night, Rain City: folke/tokyonight.nvim's night palette (its day
// palette is the other tone). Indigo-grey glass, steel-blue tubes glowing
// softly as through a wet window, cyan readings, lavender small print, and
// one warm paper-lantern orange. The role names are the boards' (pink was
// the main tube, cyan the readings, violet the small print); the colors are
// Tokyo Night's. Tilt Neon is the sign face (fonts/, OFL).
Singleton {
    // A color in the era's own tone and in its other one (the `tone` token,
    // Palettes.js): every color here, and every literal in the panels, is
    // a pair, the second authored for the other glass.
    function c(own: var, other: var): color {
        return Tokens.flipped ? (other === undefined ? Tokens.ink(own) : other) : own;
    }
    // Halos: off when the era is drawn light.
    readonly property bool neon: Tokens.neon

    // The main tube, titles and marks: Tokyo Night blue.
    readonly property color pink: c("#7aa2f7", "#2e7de9")
    readonly property color cyan: c("#7dcfff", "#007197")
    readonly property color violet: c("#bb9af7", "#7847bd")
    // The lantern: one warm sign among the blue.
    readonly property color orange: c("#ff9e64", "#b15c00")
    // Rules, tracks and the outlines of things that are off.
    readonly property color deep: c("#3b4261", "#c4c8da")
    readonly property color red: c("#f7768e", "#f52a65")
    readonly property color unlit: c("#292e42", "#d0d3e0")
    readonly property color glass: c("#16161e", "#e1e2e7")
    // The signs' corner: the media sign's pill, half its 168 px height.
    // Rectangle and Glass clamp it, so a shorter sign is a pill too.
    readonly property real curve: 84

    readonly property string family: neon.status === FontLoader.Ready ? neon.name : "sans-serif"

    FontLoader {
        id: neon
        source: Qt.resolvedUrl("../fonts/TiltNeon.ttf")
    }
}
