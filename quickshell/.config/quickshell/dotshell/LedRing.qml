import QtQuick
import qs.services

// An animated one-dot LED border for a DotSurface canvas (1 px = 1 dot):
// drop it in at the canvas size, in place of a Frame. The animation is
// LedFx's (the `ledfx` token); with it off, the ring is still, in `color`.
//   LedRing { width: surface.cols; height: surface.rows; gain: 0.6 }
ShaderEffect {
    id: root

    // The still ring's color.
    property color color: Tokens.slot0
    // 0 .. 1: how bright the animation runs (a focused window 1, the rest less).
    property real gain: 1
    // Sets this ring out of step with the others, 0 .. 1.
    property real offset: 0

    readonly property vector2d grid: Qt.vector2d(width, height)
    readonly property real mode: LedFx.mode
    readonly property real time: LedFx.time
    readonly property real phase: LedFx.phase
    readonly property real dir: LedFx.dir
    readonly property real level: LedFx.level
    readonly property real bass: LedFx.bass
    readonly property real treble: LedFx.treble
    readonly property real beat: LedFx.beat
    readonly property real kick: LedFx.kick
    readonly property vector4d bandsA: LedFx.bands[0]
    readonly property vector4d bandsB: LedFx.bands[1]
    readonly property vector4d bandsC: LedFx.bands[2]
    readonly property vector4d bandsD: LedFx.bands[3]
    readonly property color c0: Tokens.slot0
    readonly property color c1: Tokens.slot1
    readonly property color c2: Tokens.slot2
    readonly property color still: color
    readonly property color unlit: Tokens.unlit

    blending: true
    fragmentShader: Qt.resolvedUrl("shaders/ledring.frag.qsb")
}
