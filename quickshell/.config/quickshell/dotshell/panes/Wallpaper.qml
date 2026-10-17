import QtQuick
import QtMultimedia
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
// workspace, slower than the world layer's panels (panes/World.qml). The home
// workspace (Tokens.home) shows the whole wallpaper unshifted, and plays the
// `homeWall` token's animated wallpaper (gif, webp or video) when set.
// The `screen` token's look (glass, led, board) is drawn here, over the
// wallpaper only (shaders/wall.frag); windows are left alone.
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

        // Fraction of the screen width the image moves per workspace, over the
        // first `span` workspaces (later ones stay at the far end).
        readonly property real step: 0.08
        readonly property int span: 6
        readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
        property int wsId: 1
        readonly property int liveWs: monitor?.activeWorkspace?.id ?? 1
        onLiveWsChanged: if (liveWs > 0)
            wsId = liveWs
        // Parallax offset, 0 .. 1 of the screen width, eased.
        readonly property bool atHome: wsId === Tokens.home
        // Home: no shift at all. Elsewhere a step per workspace from home.
        property real slide: atHome ? 0 : win.step * Math.min(win.span - 1, Math.abs(win.wsId - Tokens.home))
        Behavior on slide {
            NumberAnimation {
                duration: 380
                easing.type: Easing.OutCubic
            }
        }

        readonly property string source: Tokens.wallpaper ? "file://" + Tokens.wallpaper : ""

        readonly property real dpr: win.devicePixelRatio ?? 1

        // Everything the wallpaper draws, as one layer the screen look runs over.
        Item {
            id: content
            anchors.fill: parent
            layer.enabled: Tokens.screen !== "off"
            layer.effect: ShaderEffect {
                readonly property var era: Tokens.current
                property size size: Qt.size(width * win.dpr, height * win.dpr)
                property real pitch: Math.max(2, Tokens.pitch * win.dpr)
                property real dotSize: Tokens.dotSize
                property real shape: era.shape === "square" ? 1 : era.shape === "bubble" ? 2 : 0
                property real mode: Tokens.screen === "glass" ? 0 : 1
                property real detail: Tokens.screen === "board" ? 0 : 1
                property real depth: Tokens.depthBits
                property real glow: era.glow ?? 0.5
                property color tint: era.slots[0]
                property color glassColor: era.glass
                property color unlitColor: era.unlit
                property color ramp0: era.ramp[0]
                property color ramp1: era.ramp[1]
                property color ramp2: era.ramp[2]
                property color ramp3: era.ramp[3]
                // Cascade: the same wave as the DotSurfaces (Tokens.flip).
                readonly property var was: Tokens.previous
                property real flip: Tokens.flip
                property real oldShape: was.shape === "square" ? 1 : was.shape === "bubble" ? 2 : 0
                property real oldGlow: was.glow ?? 0.5
                property color oldTint: was.slots[0]
                property color oldGlass: was.glass
                property color oldUnlit: was.unlit
                property color oldRamp0: was.ramp[0]
                property color oldRamp1: was.ramp[1]
                property color oldRamp2: was.ramp[2]
                property color oldRamp3: was.ramp[3]
                fragmentShader: Qt.resolvedUrl("../shaders/wall.frag.qsb")
            }

            Rectangle {
                anchors.fill: parent
                color: Tokens.glass
            }

            // ── image: the photo itself ──────────────────────────────────
            Image {
                id: image
                visible: Tokens.wall === "image"
                // Home: the whole picture fits the screen; elsewhere it is wider and slides.
                width: win.atHome ? win.width : win.width * (1 + win.step * (win.span - 1))
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

            // ── home's animated wallpaper ────────────────────────────────
            readonly property string anim: Tokens.homeWall
            readonly property bool animVideo: /\.(mp4|webm|mkv|mov)$/i.test(anim)
            AnimatedImage {
                anchors.fill: parent
                visible: win.atHome && content.anim !== "" && !content.animVideo
                source: visible ? "file://" + content.anim : ""
                fillMode: Image.PreserveAspectCrop
                playing: visible
                asynchronous: true
            }
            MediaPlayer {
                id: homeVideo
                source: win.atHome && content.animVideo ? "file://" + content.anim : ""
                videoOutput: homeOut
                loops: MediaPlayer.Infinite
                onSourceChanged: if (source != "") play()
            }
            VideoOutput {
                id: homeOut
                anchors.fill: parent
                visible: win.atHome && content.animVideo
                fillMode: VideoOutput.PreserveAspectCrop
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
                    width: win.atHome ? board.cols : board.cols * (1 + win.step * (win.span - 1))
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
}
