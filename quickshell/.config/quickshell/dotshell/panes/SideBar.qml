import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.services

// The side bar: a tall LED board on the right edge (the `side` token).
//   on    always there; windows make room for it
//   auto  hidden; touch the right edge of the screen and it slides out over
//         the windows, then hides again shortly after the pointer leaves
//   off   gone
// Top to bottom: a big clock and the date, workspaces (click to go, + for a
// new one), now playing (dithered art, title, transport, spectrum), and
// meters for CPU, memory, temperature, volume, brightness and battery.
// Settings: Super T, DISPLAY page (SIDE BAR), or `dot display --side auto`.
Variants {
    model: Tokens.side === "off" ? [] : Quickshell.screens

    PanelWindow {
        id: bar

        required property ShellScreen modelData
        screen: modelData

        readonly property bool auto: Tokens.side === "auto"
        // About 240 px wide at any pitch, never under 20 dots.
        readonly property int cols: Math.max(20, Math.floor(240 / Tokens.pitch))
        readonly property int inner: cols - 4
        readonly property int full: cols * Tokens.pitch
        readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)

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
        // How far out the board is, 0 .. 1.
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

            // LED border.
            Frame {
                visible: Tokens.borders
                width: surface.cols
                height: surface.rows
                border.color: Tokens.slot1
                opacity: 0.6
            }

            Column {
                x: 2
                y: 3
                width: bar.inner
                spacing: 3

                // ── Clock ───────────────────────────────────────────
                SystemClock {
                    id: clock
                    precision: SystemClock.Seconds
                }
                Item {
                    width: bar.inner
                    height: Tokens.fontPx * 3
                    readonly property int size: bar.inner >= 5 * Tokens.charDots * 3 ? 3 : bar.inner >= 5 * Tokens.charDots * 2 ? 2 : 1
                    DotText {
                        width: parent.width
                        size: parent.size
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.formatDateTime(clock.date, clock.seconds % 2 ? "hh mm" : "hh:mm")
                        color: Tokens.slot0
                    }
                }
                DotText {
                    width: bar.inner
                    height: Tokens.lineDots
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.formatDateTime(clock.date, "ddd dd MMM").toUpperCase()
                    color: Tokens.slot2
                }
                // Seconds run along one dot row.
                Rectangle {
                    width: Math.round(bar.inner * clock.seconds / 59)
                    height: 1
                    color: Tokens.slot1
                }

                Rule {}

                // ── Workspaces ──────────────────────────────────────
                Flow {
                    id: wsFlow
                    width: bar.inner
                    spacing: 2
                    readonly property var live: Hyprland.workspaces.values.filter(w => w.id > 0)
                    readonly property int count: Math.max(5, ...live.map(w => w.id))

                    Repeater {
                        model: wsFlow.count

                        Item {
                            id: cell
                            required property int index
                            readonly property int wsId: index + 1
                            readonly property var ws: wsFlow.live.find(w => w.id === wsId) ?? null
                            readonly property bool focused: ws !== null && ws.id === Hyprland.focusedWorkspace?.id
                            readonly property int windows: ws?.toplevels?.values?.length ?? 0
                            width: Tokens.charDots * 2 + 2
                            height: Tokens.lineDots + 3

                            Frame {
                                anchors.fill: parent
                                visible: cell.focused
                            }
                            DotText {
                                x: 1
                                width: parent.width - 2
                                height: Tokens.lineDots
                                horizontalAlignment: Text.AlignHCenter
                                text: cell.wsId
                                color: cell.ws?.urgent ? Tokens.slot2 : cell.focused ? Tokens.slot0 : Tokens.slot1
                                opacity: cell.ws === null ? 0.5 : 1
                            }
                            // One dot per window, up to the cell's width.
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: Tokens.lineDots
                                spacing: 1
                                Repeater {
                                    model: Math.min(cell.windows, 5)
                                    Rectangle {
                                        width: 1
                                        height: 1
                                        color: Tokens.slot0
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Hyprland.dispatch("workspace " + cell.wsId)
                            }
                        }
                    }
                    DotButton {
                        text: "+"
                        color: Tokens.slot2
                        height: Tokens.lineDots + 3
                        onClicked: Hyprland.dispatch("workspace empty")
                    }
                }

                Rule {}

                // ── Now playing ─────────────────────────────────────
                Column {
                    visible: Media.active
                    width: bar.inner
                    spacing: 2

                    Item {
                        width: bar.inner
                        height: art.visible ? bar.inner : 0
                        DitherArt {
                            id: art
                            visible: Media.art !== "" && bar.inner >= 24
                            width: bar.inner
                            height: bar.inner
                            source: visible ? Media.art : ""
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Ui.toggle("media", bar.screen)
                        }
                    }
                    Scroller {
                        width: bar.inner
                        height: Tokens.lineDots
                        text: (Media.title || "NOTHING PLAYING").toUpperCase()
                    }
                    DotText {
                        width: bar.inner
                        height: Tokens.lineDots
                        elide: Text.ElideRight
                        text: Media.artist.toUpperCase()
                        color: Tokens.slot1
                    }
                    Item {
                        width: bar.inner
                        height: 2
                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Tokens.slot1
                            opacity: 0.5
                        }
                        Rectangle {
                            width: Math.round(parent.width * Media.progress)
                            height: 1
                            color: Tokens.slot0
                        }
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 2
                        DotButton {
                            text: ""
                            onClicked: Media.previous()
                        }
                        DotButton {
                            text: Media.isPlaying ? "" : ""
                            color: Tokens.slot2
                            onClicked: Media.toggle()
                        }
                        DotButton {
                            text: ""
                            onClicked: Media.next()
                        }
                    }
                    Spectrum {
                        width: bar.inner
                        height: 14
                        bars: Math.max(4, Math.min(24, Math.floor(bar.inner / 3)))
                        visible: bar.reveal > 0 && Media.isPlaying
                    }
                    Item {
                        width: 1
                        height: 1
                    }
                    Rule {}
                }

                // ── Meters ──────────────────────────────────────────
                Repeater {
                    model: [
                        { label: "CPU", value: Sys.cpu, text: Math.round(Sys.cpu * 100) + "%" },
                        { label: "MEM", value: Sys.mem, text: Sys.memGb.toFixed(1) + "G" },
                        { label: "TMP", value: Sys.tempFraction, text: Sys.temp < 0 ? "--" : Math.round(Sys.temp) + "C", hide: Sys.temp < 0 },
                        { label: "VOL", value: Audio.muted ? 0 : Audio.volume, text: Audio.muted ? "OFF" : Math.round(Audio.volume * 100) + "%" },
                        { label: "BRT", value: Brightness.value, text: Math.round(Brightness.value * 100) + "%", hide: !Brightness.available },
                        { label: "BAT", value: Power.fraction, text: Power.percent + (Power.charging ? "+" : "%"), hide: !Power.present }
                    ]

                    Item {
                        required property var modelData
                        visible: !modelData.hide
                        width: bar.inner
                        height: Tokens.lineDots

                        DotText {
                            text: modelData.label
                            color: Tokens.slot1
                        }
                        VuBar {
                            x: 3 * Tokens.charDots + 2
                            y: 3
                            segments: Math.max(1, Math.floor((bar.inner - x - 4 * Tokens.charDots - 1) / 3))
                            segWidth: 2
                            segHeight: 5
                            value: modelData.value
                        }
                        DotText {
                            anchors.right: parent.right
                            text: modelData.text
                            color: Tokens.slot0
                        }
                    }
                }
            }
        }
    }
}
