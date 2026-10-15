import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// Wallpaper layer (replaces awww): the `wallpaper` token, cropped to fill,
// on every screen. Set it with:
//   dotshell ipc call tokens set wallpaper ~/wallpaper/some.jpg
// Phase 4/5 add the dots mode, parallax and per-workspace scrolling.
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

        Image {
            id: image
            anchors.fill: parent
            source: Tokens.wallpaper ? "file://" + Tokens.wallpaper : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(win.width, win.height)
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
