import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets

// Top LED strip: workspaces | clock | tray glyphs, on one row of dots.
// Everything inside the DotSurface is measured in dots, not pixels.
PanelWindow {
    id: strip

    required property ShellScreen modelData
    screen: modelData

    readonly property int rows: 11
    readonly property int cols: Math.floor(width / Tokens.pitch)
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: rows * Tokens.pitch
    color: Tokens.glass

    WlrLayershell.namespace: "dotshell-strip"
    WlrLayershell.layer: WlrLayer.Top

    DotSurface {
        id: surface
        anchors.horizontalCenter: parent.horizontalCenter
        cols: strip.cols
        rows: strip.rows

        // ── Left: workspaces ────────────────────────────────────────
        Row {
            id: workspaces
            x: 2
            height: strip.rows
            spacing: 3

            // Always show 1..5, plus any higher workspace that exists.
            readonly property var live: Hyprland.workspaces.values.filter(w => w.id > 0)
            readonly property int count: Math.max(5, ...live.map(w => w.id))

            Repeater {
                model: workspaces.count

                Item {
                    id: cell
                    required property int index
                    readonly property int wsId: index + 1
                    readonly property var ws: workspaces.live.find(w => w.id === wsId) ?? null
                    readonly property bool focused: ws !== null && ws.id === Hyprland.focusedWorkspace?.id
                    readonly property bool shown: ws !== null && ws.active && ws.monitor === strip.monitor

                    width: label.implicitWidth
                    height: strip.rows

                    DotText {
                        id: label
                        text: cell.wsId
                        color: cell.ws?.urgent ? Tokens.slot2 : cell.focused || cell.shown ? Tokens.slot0 : Tokens.slot1
                        // Empty workspaces sit at the dim brightness level.
                        opacity: cell.ws === null ? 0.5 : 1
                    }

                    // Focus underline: one dot row under the digit.
                    Rectangle {
                        visible: cell.focused
                        y: strip.rows - 1
                        width: parent.width
                        height: 1
                        color: Tokens.slot0
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: Hyprland.dispatch("workspace " + cell.wsId)
                    }
                }
            }
        }

        // ── Center: clock ───────────────────────────────────────────
        SystemClock {
            id: clock
            precision: SystemClock.Seconds
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            height: strip.rows
            spacing: 4

            DotText {
                text: Qt.formatDateTime(clock.date, "ddd dd MMM").toUpperCase()
                color: Tokens.slot2
            }
            DotText {
                // Blinking colon, like a real LED clock.
                text: Qt.formatDateTime(clock.date, clock.seconds % 2 ? "hh mm" : "hh:mm")
                color: Tokens.slot0
            }
        }

        // ── Right: tray glyphs ──────────────────────────────────────
        Row {
            id: tray
            anchors.right: parent.right
            anchors.rightMargin: 2
            height: strip.rows
            spacing: 3

            Repeater {
                model: SystemTray.items

                Item {
                    id: glyph
                    required property SystemTrayItem modelData
                    readonly property int size: 9

                    width: size
                    height: strip.rows

                    // The icon only supplies a silhouette; the dots take an era color.
                    IconImage {
                        id: icon
                        anchors.centerIn: parent
                        implicitSize: glyph.size
                        source: glyph.modelData.icon
                        layer.enabled: true
                        visible: false
                    }
                    Rectangle {
                        anchors.fill: icon
                        color: glyph.modelData.status === Status.NeedsAttention ? Tokens.slot2 : Tokens.slot1
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: icon
                            maskThresholdMin: 0.4
                            maskSpreadAtMin: 0
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: mouse => {
                            const item = glyph.modelData;
                            if (mouse.button === Qt.MiddleButton) {
                                item.secondaryActivate();
                            } else if (mouse.button === Qt.RightButton || item.onlyMenu) {
                                if (item.hasMenu) {
                                    const p = glyph.mapToItem(null, 0, glyph.height);
                                    item.display(strip, p.x, p.y);
                                }
                            } else {
                                item.activate();
                            }
                        }
                        onWheel: wheel => glyph.modelData.scroll(wheel.angleDelta.y / 120, false)
                    }
                }
            }
        }
    }
}
