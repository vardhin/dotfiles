import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.services
import "../Templates.js" as Templates

// Above the windows, taking no input: while a panel is dragged toward a
// desktop, the 24 px snap grid and the outline it will land in (the drag
// keeps the pointer on the window it started in; the strip and the rail
// draw their own slots and ghosts); and the name of the docked item under
// the pointer (Panels.hint, from DockItem.qml).
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property ShellScreen modelData
        screen: modelData

        readonly property var d: Panels.drag
        readonly property bool toDesk: d !== null && d.target === "home"
        readonly property var p: d ? Panels.find(d.id) : null

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        readonly property bool shown: toDesk && modelData === Ui.focusedScreen()
        readonly property var h: Panels.hint
        readonly property var hp: h && Panels.drag === null && Ui.pane !== "peek" ? Panels.find(h.id) : null
        visible: (shown || hp !== null) && modelData === Ui.focusedScreen()
        mask: Region {}

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "dotshell-drag"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // ── The snap grid ───────────────────────────────────────────
        Item {
            anchors.fill: parent
            opacity: 0.45
            Repeater {
                model: win.shown ? Math.ceil(win.height / 24) : 0
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

        // ── The hovered item's name: under a strip item, left of a rail one.
        DotSurface {
            id: tip
            visible: win.hp !== null
            readonly property string title: (Templates.get(win.hp?.template ?? "")?.title ?? "").toUpperCase()
            readonly property string how: "CLICK · DRAG TO MOVE"
            cols: Math.max(title.length, how.length) * Tokens.charDots + 8
            rows: Tokens.lineDots * 2 + 5
            readonly property real pw: cols * Tokens.pitch
            readonly property real ph: rows * Tokens.pitch
            x: !win.h ? 0 : win.h.place === "rail" ? win.h.x - pw - 8 : Math.max(4, Math.min(win.h.x + win.h.w / 2 - pw / 2, win.width - pw - 4))
            y: !win.h ? 0 : win.h.place === "rail" ? Math.max(4, Math.min(win.h.y + win.h.h / 2 - ph / 2, win.height - ph - 4)) : win.h.y + win.h.h + 6

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: 1
                border.color: Tokens.slot1
            }
            DotText {
                x: 4
                y: 2
                height: Tokens.lineDots
                text: tip.title
                color: Tokens.slot2
            }
            DotText {
                x: 4
                y: 2 + Tokens.lineDots
                height: Tokens.lineDots
                text: tip.how
                color: Tokens.slot1
            }
        }

        // ── Where it lands: a docked item lands with its corner at the
        // cursor; a desktop panel moves by the drag (DeskPanel draws it).
        Rectangle {
            visible: win.p !== null && win.d.from !== "home"
            x: win.d ? Math.round(win.d.x / 24) * 24 : 0
            y: win.d ? Math.max(Tokens.pitch * 11, Math.round(win.d.y / 24) * 24) : 0
            width: (win.p?.w ?? 0) * Panels.unit
            height: (win.p?.h ?? 0) * Panels.unit
            color: Qt.rgba(Tokens.glass.r, Tokens.glass.g, Tokens.glass.b, 0.55)
            border.width: 2
            border.color: Tokens.slot0
            DotText {
                x: 8
                y: 8
                height: Tokens.lineDots
                text: (Templates.get(win.p?.template ?? "")?.title ?? "").toUpperCase()
                color: Tokens.slot2
            }
            DotText {
                x: 8
                y: parent.height - Tokens.lineDots - 8
                height: Tokens.lineDots
                text: "RELEASE: DESKTOP " + (Hyprland.focusedWorkspace?.id ?? "")
                color: Tokens.slot1
            }
        }
    }
}
