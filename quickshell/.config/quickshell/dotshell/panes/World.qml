import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.services
import "../Templates.js" as Templates

// The world layer: the home workspace's desktop panels, behind windows and
// above the wallpaper. Workspaces lie side by side and switching slides the
// strip, so home's panels scroll away when you leave home (Tokens.home).
// Panels live only on home; the strip and the rail are their other places.
//
// While a panel is dragged this layer also draws the home snap grid (24 px),
// the landing outline of a panel pulled out of the strip or the rail, and,
// for 3 s after a dock, the outline of the spot it left (click it, or press
// Ctrl Z, to undo).
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
            if (liveWs !== Tokens.home)
                Panels.fold();
        }
        readonly property bool atHome: wsId === Tokens.home
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

        // ── The snap grid, while a panel is over home ───────────────
        Item {
            anchors.fill: parent
            visible: win.atHome && Panels.drag !== null && Panels.drag.target === "home"
            opacity: 0.55
            Repeater {
                model: parent.visible ? Math.ceil(win.height / 24) : 0
                Row {
                    required property int index
                    y: index * 24
                    spacing: 23
                    Repeater {
                        model: Math.ceil(win.width / 24)
                        Rectangle {
                            width: 1
                            height: 1
                            color: Tokens.slot1
                        }
                    }
                }
            }
        }

        // ── Landing outline for a panel pulled out of the strip or rail ─
        Rectangle {
            readonly property var d: Panels.drag
            readonly property var p: d && d.from !== "home" ? Panels.find(d.id) : null
            readonly property var t: p ? Templates.get(p.template) : null
            visible: win.atHome && p !== null && d.target === "home"
            x: d ? Math.round(d.x / 24) * 24 : 0
            y: d ? Math.round(d.y / 24) * 24 : 0
            width: (p?.w ?? 0) * Panels.unit
            height: (p?.h ?? 0) * Panels.unit
            color: "transparent"
            border.width: 1
            border.color: Tokens.slot1
            DotText {
                x: 6
                y: parent.height - Tokens.fontPx - 4
                text: "RELEASE TO PLACE"
                color: Tokens.slot1
            }
        }
        // Off home a pulled panel has nowhere to land: refused, it snaps back.
        DotText {
            visible: !win.atHome && Panels.drag !== null && Panels.drag.from !== "home" && Panels.drag.target === "home"
            x: (Panels.drag?.x ?? 0) + 12
            y: (Panels.drag?.y ?? 0) + 12
            text: "PANELS LIVE ON HOME"
            color: Tokens.slot2
        }

        // ── Undo: the spot a docked panel left, for 3 s ─────────────
        Rectangle {
            readonly property var u: Panels.undo
            visible: win.atHome && u !== null && u.before.place === "home"
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
            x: -(win.wsId - Tokens.home) * win.width
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
                    screenW: win.width
                    screenH: win.height
                    visible: win.atHome || Math.abs(world.x) < win.width
                }
            }
        }
    }
}
