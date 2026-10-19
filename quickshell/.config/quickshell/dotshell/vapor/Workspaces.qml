import QtQuick
import qs
import qs.services
import qs.aero as A
import qs.tokyo as T

// Workspaces, Vaporwave: pager.exe. Each workspace a little dark dot
// screen with its windows drawn where they sit, as lilac windows with a
// pink title bar, and its name under it in VT323 ("⌂ Home", "1 Code"); the
// one you are on framed in hot pink. A click goes there. Expanded, the
// overview: a screen per workspace in use (its windows named in dots), the
// next free one, and under each its name and window count in dots (the
// one you are on on pink).
T.Face {
    id: root

    readonly property var list: ctx.list ?? []
    // A short name per workspace, from what is open on it.
    readonly property var kinds: [[/code|codium|zed|nvim|jetbrains/i, "Code"], [/firefox|chrom|browser|librewolf|zen/i, "Web"], [/mpv|vlc|dottv|celluloid/i, "TV"], [/kitty|ghostty|alacritty|foot|term/i, "Term"], [/telegram|discord|vesktop|signal/i, "Chat"], [/spotify|rmpc|music/i, "Music"], [/nautilus|thunar|nemo|files/i, "Files"], [/steam|game/i, "Game"], [/gimp|krita|inkscape|blender/i, "Art"]]
    function kind(cls: string): string {
        for (const [re, w] of kinds)
            if (re.test(cls))
                return w;
        const w = cls.split(/[.\-_ ]/).pop().slice(0, 6).toLowerCase();
        return w.charAt(0).toUpperCase() + w.slice(1);
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
    A.Geo {
        id: geo
    }

    Win {
        id: win
        anchors.fill: parent
        icon: "▦"
        title: "pager.exe"
        big: root.big
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : pager
    }

    // A workspace's windows, drawn where they sit (fractions of it).
    component Desk: Item {
        id: d
        property var wins: []
        property color bar: Ink.pink
        Repeater {
            model: d.wins
            Item {
                required property var modelData
                x: modelData.x * d.width
                y: modelData.y * d.height
                width: Math.max(4, modelData.w * d.width - 3)
                height: Math.max(4, modelData.h * d.height - 3)
                Rectangle {
                    anchors.fill: parent
                    color: Ink.face
                }
                Rectangle {
                    width: parent.width
                    height: Math.max(2, Math.min(4, parent.height * 0.08))
                    color: d.bar
                }
                Bevel {
                    anchors.fill: parent
                }
            }
        }
    }

    // ── Compact: the pager ──────────────────────────────────────────
    Component {
        id: pager
        Item {
            id: c
            readonly property real topY: win.bodyY + 6
            readonly property real labelH: 20
            readonly property real gap: 8
            readonly property var shown: root.list.slice(0, Math.max(1, Math.floor((width - 16 + gap) / (40 + gap))))
            readonly property real tileW: (width - 20 - gap * (shown.length - 1)) / Math.max(1, shown.length)
            readonly property real tileH: height - topY - labelH - 8

            Row {
                x: 10
                y: c.topY
                spacing: c.gap
                Repeater {
                    model: c.shown
                    Item {
                        id: tile
                        required property var modelData
                        width: c.tileW
                        height: c.tileH + c.labelH
                        Rectangle {
                            visible: !!tile.modelData.focused
                            x: -3
                            y: -3
                            width: c.tileW + 6
                            height: c.tileH + 6
                            color: "transparent"
                            border.width: 2
                            border.color: Ink.pink
                        }
                        Crt {
                            id: glass
                            width: c.tileW
                            height: c.tileH
                        }
                        Desk {
                            x: 3
                            y: 3
                            width: c.tileW - 6
                            height: c.tileH - 6
                            wins: geo.geo[tile.modelData.id] ?? []
                        }
                        Pen {
                            y: c.tileH + 2
                            width: c.tileW
                            height: c.labelH
                            horizontalAlignment: Text.AlignHCenter
                            text: (tile.modelData.home ? "⌂" : tile.modelData.id) + " " + root.nameOf(tile.modelData)
                            size: 17
                        }
                        T.Hit {
                            anchors.fill: parent
                            action: "ws " + tile.modelData.id
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
            readonly property real wellY: win.bodyY + 8
            readonly property real wellH: height - wellY - 10
            readonly property real padX: 22
            readonly property real gap: 12
            readonly property real tileW: (width - padX * 2 - gap * 2) / 3
            readonly property int rowsN: Math.ceil(tiles.length / 3)
            readonly property real footH: 24
            readonly property real cellH: (wellH - 20 - footH - gap * (rowsN - 1)) / rowsN
            readonly property real boxH: cellH - 26
            function tileX(i: int): real {
                return padX + i % 3 * (tileW + gap);
            }
            function tileY(i: int): real {
                return wellY + 10 + Math.floor(i / 3) * (cellH + gap);
            }

            Well {
                x: 10
                y: u.wellY
                width: parent.width - 20
                height: u.wellH
            }
            Repeater {
                model: u.tiles
                Item {
                    id: tile
                    required property var modelData
                    required property int index
                    x: u.tileX(index)
                    y: u.tileY(index)
                    width: u.tileW
                    height: u.boxH
                    Rectangle {
                        visible: !!tile.modelData.focused
                        x: -3
                        y: -3
                        width: parent.width + 6
                        height: parent.height + 6
                        color: "transparent"
                        border.width: 2
                        border.color: Ink.pink
                    }
                    Crt {
                        anchors.fill: parent
                    }
                    Desk {
                        x: parent.width * 0.06
                        y: parent.height * 0.08
                        width: parent.width * 0.88
                        height: parent.height * 0.84
                        bar: Ink.violet
                        wins: tile.modelData.next ? [] : (geo.geo[tile.modelData.id] ?? [])
                    }
                    T.Hit {
                        anchors.fill: parent
                        action: "ws " + tile.modelData.id
                    }
                }
            }

            Dots {
                anchors.fill: parent
                Repeater {
                    model: u.tiles
                    Item {
                        id: cell
                        required property var modelData
                        required property int index
                        readonly property var wins: cell.modelData.next ? [] : (geo.geo[cell.modelData.id] ?? [])
                        readonly property real inX: u.tileX(index) + u.tileW * 0.06
                        readonly property real inY: u.tileY(index) + u.boxH * 0.08
                        readonly property real inW: u.tileW * 0.88
                        readonly property real inH: u.boxH * 0.84
                        // Empty: what it is kept for.
                        MatrixText {
                            visible: !!(cell.modelData.next || cell.modelData.home) && !cell.wins.length
                            x: Math.round((u.tileX(cell.index) + u.tileW / 2) / u.p - width / 2)
                            y: Math.round((u.tileY(cell.index) + u.boxH / 2) / u.p) - 2
                            width: implicitWidth
                            height: 5
                            font: "3x5"
                            text: cell.modelData.next ? "+ next free" : "kept clear"
                            color: Ink.violet
                        }
                        // Each window's name at its top left.
                        Repeater {
                            model: cell.wins
                            MatrixText {
                                required property var modelData
                                x: Math.round((cell.inX + modelData.x * cell.inW) / u.p) + 2
                                y: Math.round((cell.inY + modelData.y * cell.inH) / u.p) + 3
                                width: Math.max(0, Math.round(modelData.w * cell.inW / u.p) - 4)
                                height: 5
                                visible: width >= 8 && modelData.h * cell.inH >= 8 * u.p
                                font: "3x5"
                                text: String(modelData.cls).split(".").pop()
                                color: Ink.ink
                            }
                        }
                        // 2 Web                  3 win
                        Item {
                            x: Math.round(u.tileX(cell.index) / u.p)
                            y: Math.round((u.tileY(cell.index) + u.boxH + 8) / u.p)
                            width: Math.floor(u.tileW / u.p)
                            height: 7
                            Rectangle {
                                visible: !!cell.modelData.focused
                                anchors.fill: parent
                                color: Ink.pink
                                opacity: 0.6
                            }
                            MatrixText {
                                x: 1
                                y: 1
                                width: parent.width - count.implicitWidth - 3
                                height: 5
                                font: "3x5"
                                text: cell.modelData.next ? cell.modelData.id + " +" : cell.modelData.home ? "⌂ Home" : cell.modelData.id + " " + root.nameOf(cell.modelData)
                                color: Ink.ink
                            }
                            MatrixText {
                                id: count
                                anchors.right: parent.right
                                anchors.rightMargin: 1
                                y: 1
                                width: implicitWidth
                                height: 5
                                font: "3x5"
                                text: cell.modelData.windows ? cell.modelData.windows + " win" : ""
                                color: Ink.ink
                            }
                        }
                    }
                }
                MatrixText {
                    x: Math.ceil(u.padX / u.p)
                    y: Math.floor((u.wellY + u.wellH - 10) / u.p) - 5
                    width: Math.floor((u.width - u.padX * 2) / u.p)
                    height: 5
                    font: "3x5"
                    scroll: true
                    text: "Tip: click a desktop to go there."
                    color: Ink.label
                }
            }
        }
    }
}
