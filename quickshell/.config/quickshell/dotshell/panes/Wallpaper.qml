import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs

// Wallpaper layer (replaces awww): the `wallpaper` token, cropped to fill,
// on every screen. Set it with:
//   dotshell ipc call tokens set wallpaper ~/wallpaper/some.jpg
// Parallax: the image is a little wider than the screen and slides a step per
// workspace, slower than the world layer's panels (panes/World.qml).
// Phase 5 adds the dots and off modes.
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

        Image {
            id: image
            width: win.width * (1 + win.step * (win.span - 1))
            height: win.height
            x: -win.width * win.step * (Math.min(win.span, Math.max(1, win.wsId)) - 1)

            Behavior on x {
                NumberAnimation {
                    duration: 380
                    easing.type: Easing.OutCubic
                }
            }
            source: Tokens.wallpaper ? "file://" + Tokens.wallpaper : ""
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
    }
}
