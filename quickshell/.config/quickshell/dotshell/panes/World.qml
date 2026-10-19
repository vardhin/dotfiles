import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.services

// The world layer: every workspace's desktop panels, behind windows and
// above the wallpaper. Workspaces lie side by side and switching slides the
// strip, so a workspace's panels scroll away when you leave it. Windows
// cover panels like any desktop; home (Tokens.home) keeps no windows.
//
// For 3 s after a dock it draws the outline of the spot the panel left
// (click it, or press Ctrl Z, to undo). The drag feedback (snap grid,
// landing outline) is DragLayer.qml's, above the windows.
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
        // The keyboard only while a panel is expanded or typed in (Esc folds).
        WlrLayershell.keyboardFocus: Panels.expanded !== "" || Panels.typing ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
        // Normal workspaces only; specials (negative ids) leave the world where it is.
        property int wsId: 1
        readonly property int liveWs: monitor?.activeWorkspace?.id ?? 1
        onLiveWsChanged: {
            if (liveWs > 0)
                wsId = liveWs;
            Panels.fold();
        }
        // Home on the focused screen only.
        readonly property bool homeScreen: screen === Ui.focusedScreen() || Quickshell.screens.length === 1

        // A click on the empty desktop: folds the expanded panel, tells the
        // dropdown, and moves no focus.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: mouse => {
                DropTerm.clickedAway();
                if (Panels.expanded !== "" || Panels.typing) {
                    Panels.fold();
                    Panels.typing = false;
                }
                mouse.accepted = false;
            }
        }

        Item {
            id: keys
            focus: true
            Keys.onEscapePressed: {
                Panels.fold();
                Panels.typing = false;
            }
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Z && (event.modifiers & Qt.ControlModifier)) {
                    Panels.undoLast();
                    event.accepted = true;
                }
            }
        }

        // ── Undo: the spot a docked panel left, for 3 s ─────────────
        Rectangle {
            readonly property var u: Panels.undo
            visible: u !== null && u.before.place === "home" && (u.before.ws > 0 ? u.before.ws : Tokens.home) === win.wsId
            readonly property var p: u ? Panels.find(u.id) : null
            x: (u?.before.x ?? 0) * Panels.unit
            y: (u?.before.y ?? 0) * Panels.unit
            width: (p?.w ?? 0) * Panels.unit
            height: (p?.h ?? 0) * Panels.unit
            color: "transparent"
            border.width: 1
            border.color: Tokens.slot1
            opacity: 0.6
            DotText {
                x: 6
                y: 4
                text: "CLICK OR CTRL Z TO UNDO"
                color: Tokens.slot1
            }
            MouseArea {
                anchors.fill: parent
                onClicked: Panels.undoLast()
            }
        }

        Item {
            id: world
            width: win.width
            height: win.height
            x: -Tokens.wsStep(win.wsId) * win.width
            visible: win.homeScreen

            Behavior on x {
                NumberAnimation {
                    duration: 380
                    easing.type: Easing.OutCubic
                }
            }

            Repeater {
                model: Panels.home

                DeskPanel {
                    required property var modelData
                    panel: modelData
                    originX: Tokens.wsStep(Panels.wsOf(modelData)) * win.width
                    screenW: win.width
                    screenH: win.height
                    // Its own workspace, and while sliding past it.
                    visible: Math.abs(world.x + originX) < win.width
                }
            }
        }
    }
}
