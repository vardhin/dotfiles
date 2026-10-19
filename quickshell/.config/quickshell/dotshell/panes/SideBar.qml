import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// The side bar: a thin LED rail on the right edge, about as wide as the top
// strip is tall (the `side` token).
//   on    always there; windows make room for it
//   auto  hidden; touch the right edge of the screen and it slides out over
//         the windows, then hides again shortly after the pointer leaves
//   off   gone
// It holds the launcher and file manager at the top, docked panels in their
// rail form in the middle (services/Panels.qml; System by default), and the
// era switcher, wallpapers and session menu at the bottom.
// Settings: Super T, DISPLAY page (SIDE BAR), or `dot display --side auto`.
Variants {
    model: Tokens.side === "off" ? [] : Quickshell.screens

    PanelWindow {
        id: bar

        required property ShellScreen modelData
        screen: modelData

        readonly property bool auto: Tokens.side === "auto"
        // Two glyphs wide (Tokens.railDots), so a docked item can show a
        // two-digit number: the hour, a battery percent, a count.
        readonly property int cols: Tokens.railDots
        readonly property int full: cols * Tokens.pitch

        // Auto: out while the pointer is on it, and a moment after.
        property bool out: !auto
        readonly property bool hovered: hover.hovered
        onHoveredChanged: {
            if (hovered) {
                hide.stop();
                out = true;
            } else if (auto) {
                hide.restart();
            }
        }
        onAutoChanged: out = !auto
        Timer {
            id: hide
            interval: 700
            onTriggered: bar.out = false
        }
        // How far out the rail is, 0 .. 1.
        property real reveal: out ? 1 : 0
        Behavior on reveal {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }

        anchors {
            top: true
            bottom: true
            right: true
        }
        // Hidden, only a one-dot edge is left to touch.
        implicitWidth: auto && reveal === 0 ? Math.max(2, Tokens.pitch) : full
        exclusionMode: auto ? ExclusionMode.Normal : ExclusionMode.Auto
        exclusiveZone: auto ? 0 : full
        color: "transparent"

        WlrLayershell.namespace: "dotshell-side"
        WlrLayershell.layer: WlrLayer.Top

        Item {
            anchors.fill: parent
            HoverHandler {
                id: hover
            }
        }

        // Frutiger Aero: the rail is sky glass with only its lit dots on it.
        BarChrome {
            x: surface.x
            width: bar.full
            height: bar.height
            visible: Tokens.era === "aero" && surface.visible
            place: "rail"
        }

        DotSurface {
            id: surface
            x: bar.width - bar.full * bar.reveal
            visible: bar.reveal > 0
            cols: bar.cols
            rows: Math.floor(bar.height / Tokens.pitch)
            bare: Tokens.era === "aero"

            Component.onCompleted: Sys.want("side-" + bar.modelData.name, true)
            Component.onDestruction: Sys.want("side-" + bar.modelData.name, false)
            onVisibleChanged: Sys.want("side-" + bar.modelData.name, visible)

            // ── Top: apps ───────────────────────────────────────────
            Column {
                y: 2
                spacing: 2

                RailButton {
                    glyph: ""
                    active: Ui.pane === "launcher"
                    onClicked: Ui.toggle("launcher", bar.screen)
                }
                RailButton {
                    glyph: ""
                    onClicked: Quickshell.execDetached(["nautilus", "--new-window"])
                }
            }

            // ── Middle: docked panels in their rail form ────────────
            // System by default (CPU, memory, temperature meters); dock Now
            // playing here for the transport. Drag them in and out like the
            // strip's (DockRow.qml).
            DockRow {
                anchors.verticalCenter: parent.verticalCenter
                place: "rail"
                originX: bar.screen.width - bar.width + surface.x * 1
                screenW: bar.screen.width
                screenH: bar.screen.height
            }

            // ── Bottom: look and session ────────────────────────────
            Column {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 2
                spacing: 2

                RailButton {
                    glyph: ""
                    color: Tokens.slot2
                    active: Ui.pane === "eras" && Ui.page !== "walls"
                    onClicked: Ui.togglePage("eras", "eras", bar.screen)
                }
                RailButton {
                    glyph: ""
                    active: Ui.pane === "eras" && Ui.page === "walls"
                    onClicked: Ui.togglePage("eras", "walls", bar.screen)
                }
                RailButton {
                    glyph: ""
                    active: Ui.pane === "session"
                    onClicked: Ui.toggle("session", bar.screen)
                }
            }
        }
    }
}
