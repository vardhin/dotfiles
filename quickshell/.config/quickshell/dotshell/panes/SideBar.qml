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
// It holds only what the strip does not: the launcher and file manager at the
// top, CPU / memory / temperature meters and the media transport in the
// middle, and the era switcher, wallpapers and session menu at the bottom.
// Settings: Super T, DISPLAY page (SIDE BAR), or `dot display --side auto`.
Variants {
    model: Tokens.side === "off" ? [] : Quickshell.screens

    PanelWindow {
        id: bar

        required property ShellScreen modelData
        screen: modelData

        readonly property bool auto: Tokens.side === "auto"
        // About the strip's 11 dot rows, turned on end; 13 so the 11-dot
        // Nerd Font icons keep a dot of room either side.
        readonly property int cols: 13
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

        DotSurface {
            id: surface
            x: bar.width - bar.full * bar.reveal
            visible: bar.reveal > 0
            cols: bar.cols
            rows: Math.floor(bar.height / Tokens.pitch)

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

            // ── Middle: system meters, then the media transport ─────
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // CPU, memory, temperature: three 3-dot columns, left to
                // right. Digits are 7 dots wide, so no numbers fit here.
                Row {
                    x: 2
                    spacing: 1
                    RailMeter {
                        value: Sys.cpu
                    }
                    RailMeter {
                        value: Sys.mem
                    }
                    RailMeter {
                        visible: Sys.temp >= 0
                        value: Sys.tempFraction
                    }
                }

                Column {
                    visible: Media.active
                    spacing: 2

                    RailButton {
                        glyph: ""
                        onClicked: Media.previous()
                    }
                    RailButton {
                        glyph: Media.isPlaying ? "" : ""
                        color: Tokens.slot2
                        onClicked: Media.toggle()
                    }
                    RailButton {
                        glyph: ""
                        onClicked: Media.next()
                    }
                    RailButton {
                        glyph: ""
                        active: Ui.pane === "media"
                        onClicked: Ui.toggle("media", bar.screen)
                    }
                }
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
