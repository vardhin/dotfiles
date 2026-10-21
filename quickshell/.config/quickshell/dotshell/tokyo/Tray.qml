import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs
import qs.services

// Tray, Tokyo Night: each tray icon in its own neon tile, its name under
// it; one that wants attention is rimmed cyan with a pink dot. Expanded,
// the tiles stand in a column and the picked one's menu opens beside them.
Face {
    id: root

    readonly property var items: SystemTray.items.values
    function nameOf(i: var): string {
        return String(i.tooltipTitle || i.title || i.id).replace(/[-_].*$/, "").toUpperCase();
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : sign
    }

    // ── Compact: the tiles ──────────────────────────────────────────
    Component {
        id: sign
        Item {
            id: s
            readonly property bool roomy: height >= 110
            readonly property real tile: Math.round(Math.min(roomy ? height * 0.36 : height * 0.62, 44))
            readonly property real gap: Math.round(tile * 0.32)
            readonly property int fit: Math.max(1, Math.floor((width - 28 + gap) / (tile + gap)))
            readonly property var shown: root.items.slice(0, fit)
            readonly property real rowW: shown.length * (tile + gap) - gap
            readonly property real x0: Math.round((width - rowW) / 2)
            readonly property real y0: roomy ? Math.round(height * 0.16) : Math.round((height - tile) / 2)

            Glass {
                id: glass
                radius: 26
                // The icons, as dots in the tiles.
                Repeater {
                    model: s.shown
                    TrayIcons {
                        required property var modelData
                        required property int index
                        only: modelData.id
                        size: Math.round(s.tile * 0.5 / root.pitch)
                        x: root.d(s.x0 + index * (s.tile + s.gap) + s.tile / 2) - Math.round(width / 2)
                        y: root.d(s.y0 + s.tile / 2) - Math.round(height / 2)
                    }
                }
                Repeater {
                    model: s.roomy ? s.shown : []
                    MatrixText {
                        required property var modelData
                        required property int index
                        readonly property int w: root.d(s.tile + s.gap)
                        x: root.d(s.x0 + index * (s.tile + s.gap) + s.tile / 2) - Math.round(w / 2)
                        y: root.d(s.y0 + s.tile) + 2
                        width: w
                        height: 5
                        font: "3x5"
                        align: "center"
                        text: root.nameOf(modelData).slice(0, Math.max(1, Math.floor((w + 1) / 4)))
                        color: Ink.violet
                    }
                }
                Words {
                    visible: s.roomy
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    small: true
                    text: "トレイ · TRAY"
                    color: Ink.violet
                }
                Words {
                    visible: root.items.length === 0
                    anchors.centerIn: parent
                    text: "NO TRAY ICONS"
                    color: Ink.deep
                }
            }
            Repeater {
                model: s.shown
                Item {
                    required property var modelData
                    required property int index
                    readonly property bool loud: modelData.status === Status.NeedsAttention
                    x: s.x0 + index * (s.tile + s.gap)
                    y: s.y0
                    width: s.tile
                    height: s.tile
                    Tube {
                        anchors.fill: parent
                        radius: Math.round(s.tile * 0.26)
                        line: parent.loud ? 2 : 1.5
                        tint: parent.loud ? Ink.cyan : Ink.deep
                        glow: parent.loud ? 0.8 : 0
                    }
                    Tube {
                        visible: parent.loud
                        x: parent.width - width * 0.6
                        y: -height * 0.4
                        width: Math.round(s.tile * 0.3)
                        height: width
                        radius: width / 2
                        line: 0
                        fill: Ink.pink
                        tint: Ink.pink
                        glow: 0.8
                    }
                }
            }
            Sign {
                radius: 26
            }
        }
    }

    // ── Expanded: a menu open ───────────────────────────────────────
    Component {
        id: board
        Item {
            id: b
            property int picked: 0
            readonly property var item: root.items[Math.min(picked, root.items.length - 1)] ?? null
            readonly property real tile: 34
            readonly property real colX: 20
            readonly property real menuX: colX + tile + 16

            QsMenuOpener {
                id: opener
                menu: b.item?.menu ?? null
            }
            readonly property var entries: opener.children?.values ?? []

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: 28
                color: Ink.glass
            }
            Glass {
                id: glass
                radius: 26
                // The column of icons.
                Repeater {
                    model: root.items.slice(0, Math.floor((b.height - 24) / (b.tile + 8)))
                    TrayIcons {
                        required property var modelData
                        required property int index
                        only: modelData.id
                        size: Math.round(b.tile * 0.5 / root.pitch)
                        x: root.d(b.colX + b.tile / 2) - Math.round(width / 2)
                        y: root.d(16 + index * (b.tile + 8) + b.tile / 2) - Math.round(height / 2)
                    }
                }
                // The menu.
                Item {
                    id: menu
                    x: root.d(b.menuX) + 5
                    y: root.d(16) + 4
                    width: glass.cols - x - root.d(18) - 5
                    height: glass.rows - y - root.d(16) - 4
                    Words {
                        width: parent.width
                        room: parent.width
                        text: b.item ? root.nameOf(b.item) : "NO TRAY ICONS"
                        color: Ink.pink
                    }
                    Column {
                        y: 14
                        width: parent.width
                        Repeater {
                            model: b.entries
                            Item {
                                required property var modelData
                                width: menu.width
                                height: modelData.isSeparator ? 4 : 8
                                MatrixText {
                                    visible: !parent.modelData.isSeparator
                                    x: 3
                                    y: 1
                                    width: parent.width - 6
                                    height: 5
                                    font: "3x5"
                                    text: String(parent.modelData.text ?? "").replace(/_/g, "") + (parent.modelData.hasChildren ? "  ▸" : "")
                                    color: parent.modelData.enabled ? Ink.pink : Ink.deep
                                }
                            }
                        }
                    }
                }
            }
            // Crisp: the tiles (the picked one lit), the menu's rim, rows.
            Repeater {
                model: root.items.slice(0, Math.floor((b.height - 24) / (b.tile + 8)))
                Item {
                    required property var modelData
                    required property int index
                    x: b.colX
                    y: 16 + index * (b.tile + 8)
                    width: b.tile
                    height: b.tile
                    Tube {
                        anchors.fill: parent
                        radius: 9
                        line: index === b.picked ? 2 : 1.5
                        tint: index === b.picked ? Ink.cyan : Ink.deep
                        glow: index === b.picked ? 0.8 : 0
                    }
                    Hit {
                        anchors.fill: parent
                        onTap: b.picked = index
                    }
                }
            }
            Tube {
                id: rim
                x: b.menuX
                y: 16
                width: b.width - b.menuX - 18
                height: b.height - 32
                radius: 18
                line: 2
                tint: Ink.cyan
                glow: 0.8
            }
            Column {
                x: glass.x + menu.x * root.pitch
                y: glass.y + (menu.y + 14) * root.pitch
                width: menu.width * root.pitch
                Repeater {
                    model: b.entries
                    Item {
                        id: entry
                        required property var modelData
                        width: parent.width
                        height: (modelData.isSeparator ? 4 : 8) * root.pitch
                        Rectangle {
                            visible: !!entry.modelData.isSeparator
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 1
                            color: Ink.deep
                        }
                        Rectangle {
                            visible: !entry.modelData.isSeparator && hit.containsMouse
                            anchors.fill: parent
                            radius: height / 2
                            color: Ink.c(Qt.rgba(125 / 255, 207 / 255, 1, 0.14), Qt.rgba(0, 113 / 255, 151 / 255, 0.12))
                        }
                        Hit {
                            id: hit
                            anchors.fill: parent
                            enabled: !entry.modelData.isSeparator && !!entry.modelData.enabled
                            onTap: {
                                if (entry.modelData.hasChildren && b.item) {
                                    const p = entry.mapToItem(null, entry.width, 0);
                                    b.item.display(QsWindow.window, p.x, p.y);
                                } else {
                                    entry.modelData.triggered();
                                }
                            }
                        }
                    }
                }
            }
            Sign {
                radius: 28
            }
        }
    }
}
