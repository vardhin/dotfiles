import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.services

// The world layer: desktop panels on a strip of workspaces laid side by side,
// behind windows and above the wallpaper. Switching workspace slides the
// whole strip, so panels scroll away with their workspace.
//
// Panels come from services/Panels.qml; make them with the `dot` CLI.
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
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "dotshell-world"

        readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
        // Normal workspaces only; specials (negative ids) leave the world where it is.
        property int wsId: 1
        readonly property int liveWs: monitor?.activeWorkspace?.id ?? 1
        onLiveWsChanged: if (liveWs > 0)
            wsId = liveWs

        // This layer takes every click on the empty desktop (the panels sit on
        // top of this). Such a click moves no focus, so tell the dropdown.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: mouse => {
                DropTerm.clickedAway();
                mouse.accepted = false;
            }
        }

        Item {
            id: world
            width: win.width
            height: win.height
            x: -(win.wsId - 1) * win.width

            Behavior on x {
                NumberAnimation {
                    duration: 380
                    easing.type: Easing.OutCubic
                }
            }

            Repeater {
                model: Panels.panels

                DeskPanel {
                    required property var modelData
                    panel: modelData
                    originX: (modelData.workspace - 1) * win.width
                }
            }
        }
    }
}
