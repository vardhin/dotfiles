import QtQuick
import qs
import qs.services
import qs.tokyo as T

// Workspaces, Frutiger Aero: a row of little sky-blue desks on the glass,
// one per workspace, their windows drawn on them where they sit, each
// named under it in Varela Round; the one you are on ringed in grass green.
// A click goes there. Expanded, an overview: a bigger desk per workspace
// in use (each window named in dots), the next free one, and their names
// and window counts in bubble dots.
T.Face {
    id: root

    readonly property var list: ctx.list ?? []
    // A short name per workspace, from what is open on it.
    readonly property var kinds: [[/code|codium|zed|nvim|jetbrains/i, "Code"], [/firefox|chrom|browser|librewolf|zen/i, "Web"], [/mpv|vlc|dottv|celluloid/i, "TV"], [/kitty|ghostty|alacritty|foot|term/i, "Term"], [/telegram|discord|vesktop|signal/i, "Chat"], [/spotify|rmpc|music/i, "Music"], [/nautilus|thunar|nemo|files/i, "Files"], [/steam|game/i, "Game"], [/gimp|krita|inkscape|blender/i, "Art"]]
    function kind(cls: string): string {
        for (const [re, w] of kinds)
            if (re.test(cls))
                return w;
        const s = cls.split(/[.\-_ ]/).pop();
        return s.charAt(0).toUpperCase() + s.slice(1, 6);
    }
    function nameOf(ws: var): string {
        if (!ws)
            return "";
        if (ws.home)
            return "Home";
        const w = Feeds.windows.find(x => x.ws === ws.id && x.cls);
        return w ? kind(w.cls) : "New";
    }

    onListChanged: geo.poke()
    Geo {
        id: geo
    }

    Sky {
        anchors.fill: parent
        radius: root.big ? 28 : Math.min(30, height * 0.2)
        glossInset: 20
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : row
    }

    // ── Compact: the desks ──────────────────────────────────────────
    Component {
        id: row
        Item {
            id: c
            readonly property real padX: 18
            readonly property real padY: Math.min(16, height * 0.12)
            readonly property real gap: 10
            readonly property real labelH: height >= 70 ? 18 : 0
            readonly property var shown: root.list.slice(0, Math.max(1, Math.floor((width - padX * 2 + gap) / (40 + gap))))

            Row {
                x: c.padX
                y: c.padY
                spacing: c.gap
                Repeater {
                    model: c.shown
                    Item {
                        id: cell
                        required property var modelData
                        width: (c.width - c.padX * 2 - c.gap * (c.shown.length - 1)) / Math.max(1, c.shown.length)
                        height: c.height - c.padY * 2
                        Desk {
                            width: parent.width
                            height: parent.height - c.labelH
                            wins: geo.geo[cell.modelData.id] ?? []
                            on: !!cell.modelData.focused
                        }
                        Text {
                            visible: c.labelH > 0
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            text: root.nameOf(cell.modelData)
                            color: cell.modelData.focused ? Ink.navy : Ink.blue
                            font.family: Ink.family
                            font.pixelSize: 12
                        }
                        T.Hit {
                            anchors.fill: parent
                            action: "ws " + cell.modelData.id
                        }
                    }
                }
            }
        }
    }

    // ── Expanded: the overview ──────────────────────────────────────
    Component {
        id: board
        Item {
            id: u
            readonly property var tiles: {
                const t = root.list.filter(w => w.home || w.focused || w.windows > 0).slice(0, 5);
                const next = root.list.find(w => !w.home && w.windows === 0 && !w.focused);
                return t.concat([{ id: next ? next.id : root.list.length + 1, next: true, windows: 0 }]);
            }
            readonly property int p: Tokens.pitch
            readonly property int cols: Math.floor(width / p)
            readonly property int rows: Math.floor(height / p)
            readonly property int padX: 6
            readonly property int gap: 5
            readonly property int tileW: Math.floor((cols - padX * 2 - gap * 2) / 3)
            readonly property int rowsN: Math.ceil(tiles.length / 3)
            readonly property int cellH: Math.floor((rows - 6 - 14 - gap * (rowsN - 1)) / rowsN)
            readonly property int boxH: cellH - 9
            function tileX(i: int): int {
                return padX + i % 3 * (tileW + gap);
            }
            function tileY(i: int): int {
                return 6 + Math.floor(i / 3) * (cellH + gap);
            }

            Repeater {
                model: u.tiles
                Desk {
                    required property var modelData
                    required property int index
                    x: u.tileX(index) * u.p
                    y: u.tileY(index) * u.p
                    width: u.tileW * u.p
                    height: u.boxH * u.p
                    radius: 14
                    pad: 3 * u.p
                    wins: modelData.next ? [] : (geo.geo[modelData.id] ?? [])
                    on: !!modelData.focused
                    T.Hit {
                        anchors.fill: parent
                        action: "ws " + parent.modelData.id
                    }
                }
            }

            Dots {
                anchors.fill: parent
                Repeater {
                    model: u.tiles
                    Item {
                        id: tile
                        required property var modelData
                        required property int index
                        readonly property var wins: tile.modelData.next ? [] : (geo.geo[tile.modelData.id] ?? [])
                        x: u.tileX(index)
                        y: u.tileY(index)
                        width: u.tileW
                        height: u.cellH
                        // Empty: what it is kept for.
                        MatrixText {
                            visible: !!(tile.modelData.next || tile.modelData.home) && !tile.wins.length
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: Math.round((u.boxH - height) / 2)
                            width: implicitWidth
                            height: implicitHeight
                            font: "3x5"
                            text: tile.modelData.next ? "+ NEXT FREE" : "KEPT CLEAR"
                            color: "white"
                        }
                        // Each window's name at its top left.
                        Repeater {
                            model: tile.wins
                            MatrixText {
                                required property var modelData
                                x: Math.round(3 + modelData.x * (u.tileW - 6)) + 2
                                y: Math.round(3 + modelData.y * (u.boxH - 6)) + 2
                                width: Math.max(0, Math.round(modelData.w * (u.tileW - 6)) - 4)
                                height: implicitHeight
                                visible: width >= 8 && modelData.h * (u.boxH - 6) >= 8
                                font: "3x5"
                                text: String(modelData.cls).split(".").pop()
                                color: Ink.navy
                            }
                        }
                        // 2 Web                  3 win
                        MatrixText {
                            y: u.boxH + 3
                            width: parent.width - count.implicitWidth - 3
                            height: implicitHeight
                            font: "3x5"
                            text: tile.modelData.next ? tile.modelData.id + " NEW" : tile.modelData.home ? "⌂ HOME" : tile.modelData.id + " " + root.nameOf(tile.modelData)
                            color: tile.modelData.focused ? Ink.navy : Ink.blue
                        }
                        MatrixText {
                            id: count
                            anchors.right: parent.right
                            y: u.boxH + 3
                            width: implicitWidth
                            height: implicitHeight
                            font: "3x5"
                            text: tile.modelData.windows ? tile.modelData.windows + " WIN" : ""
                            color: tile.modelData.focused ? Ink.navy : Ink.blue
                        }
                    }
                }
                MatrixText {
                    x: u.padX
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 5
                    width: u.cols - u.padX * 2
                    height: implicitHeight
                    font: "3x5"
                    scroll: true
                    text: "CLICK A DESKTOP TO GO THERE · HOME STAYS EMPTY"
                    color: Ink.blue
                }
            }
        }
    }
}
