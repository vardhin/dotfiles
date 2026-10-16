import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs

// Wallpaper layer (replaces awww), on every screen. Three modes, the `wall` token:
//   dots   the wallpaper drawn by the matrix: one dot per cell, era ramp or
//          the chosen color depth, so the whole screen reads as one LED board
//   image  the plain image, cropped to fill; only the dot panels stay LED
//   off    unlit glass: every dot dark
// Set them with:
//   dotshell ipc call tokens set wall dots
//   dotshell ipc call tokens set wallpaper ~/wallpaper/some.jpg
// Parallax: the image is a little wider than the screen and slides a step per
// workspace, slower than the world layer's panels (panes/World.qml).
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property ShellScreen modelData
        screen: modelData

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: Tokens.glass

        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "dotshell-wallpaper"

        // Fraction of the screen width the image moves per workspace, over 10.
        readonly property real step: 0.02
        readonly property int span: 10
        readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
        property int wsId: 1
        readonly property int liveWs: monitor?.activeWorkspace?.id ?? 1
        onLiveWsChanged: if (liveWs > 0)
            wsId = liveWs
        // Parallax offset, 0 .. 1 of the screen width, eased.
        property real slide: win.step * (Math.min(win.span, Math.max(1, win.wsId)) - 1)
        Behavior on slide {
            NumberAnimation {
                duration: 380
                easing.type: Easing.OutCubic
            }
        }

        readonly property string source: Tokens.wallpaper ? "file://" + Tokens.wallpaper : ""

        // ── image: the photo itself ──────────────────────────────────
        Image {
            id: image
            visible: Tokens.wall === "image"
            width: win.width * (1 + win.step * (win.span - 1))
            height: win.height
            x: -win.width * win.slide
            source: visible ? win.source : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(width, height)
            asynchronous: true
            smooth: true
            opacity: status === Image.Ready ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 400
                }
            }
        }

        // ── dots / off: the screen is one dot surface ────────────────
        // Whole dots only; the leftover sliver at the right and bottom edge
        // stays glass, like the edge of a real panel.
        DotSurface {
            id: board
            visible: Tokens.wall !== "image"
            cols: Math.floor(win.width / Tokens.pitch)
            rows: Math.floor(win.height / Tokens.pitch)
            x: Math.floor((win.width - cols * Tokens.pitch) / 2)
            y: Math.floor((win.height - rows * Tokens.pitch) / 2)
            imageMode: true
            // A background, not a pane: lit at about half, like the prototype.
            gain: 0.55

            // Decoded at about one pixel per dot: the decoder averages each
            // cell, so every dot is the mean of what it covers.
            Image {
                visible: Tokens.wall === "dots"
                width: board.cols * (1 + win.step * (win.span - 1))
                height: board.rows
                x: -board.cols * win.slide
                source: visible ? win.source : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(Math.ceil(width), Math.ceil(height))
                asynchronous: true
                smooth: true
            }
        }
    }
}
