import QtQuick
import qs
import qs.services
import qs.aero as A
import qs.tokyo as T

// Workspaces, Split-Flap: PLAT · WORKSPACE · WINDOWS. A row of flap tiles
// per workspace (its number in yellow, what it is for, how many windows
// or CLEAR / FREE, and NOW in orange on the one you are on); a click goes
// there. Too short for every row: a flap tile per workspace instead, the
// one you are on yellow, and its name under them. Expanded, PLATFORMS: a
// card per workspace in use with its windows drawn where they sit and
// named in dots, the next free one, the one you are on ruled yellow;
// under each its name and window count.
T.Face {
    id: root

    readonly property var list: ctx.list ?? []
    readonly property var cur: list.find(w => w.focused) ?? null
    // A short name per workspace, from what is open on it.
    readonly property var kinds: [[/code|codium|zed|nvim|jetbrains/i, "CODE"], [/firefox|chrom|browser|librewolf|zen/i, "WEB"], [/mpv|vlc|dottv|celluloid/i, "TV"], [/kitty|ghostty|alacritty|foot|term/i, "TERM"], [/telegram|discord|vesktop|signal/i, "CHAT"], [/spotify|rmpc|music/i, "MUSIC"], [/nautilus|thunar|nemo|files/i, "FILES"], [/steam|game/i, "GAME"], [/gimp|krita|inkscape|blender/i, "ART"]]
    function kind(cls: string): string {
        for (const [re, w] of kinds)
            if (re.test(cls))
                return w;
        return cls.split(/[.\-_ ]/).pop().slice(0, 5).toUpperCase();
    }
    function nameOf(ws: var): string {
        if (!ws)
            return "";
        if (ws.home)
            return "HOME";
        const w = Feeds.windows.find(x => x.ws === ws.id && x.cls);
        return w ? kind(w.cls) : "+";
    }
    function pad(s: string, n: int): string {
        return String(s).slice(0, n).padEnd(n, " ");
    }
    onListChanged: geo.poke()
    A.Geo {
        id: geo
    }

    Housing {
        id: box
        anchors.fill: parent
        label: root.big ? "PLATFORMS" : "PLAT · WORKSPACE · WINDOWS"
        status: root.cur ? "NOW AT " + (root.cur.home ? "⌂" : root.cur.id) : ""
        statusInk: root.big ? Ink.label : Ink.yellow
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : platforms
    }

    // ── Compact ─────────────────────────────────────────────────────
    Component {
        id: platforms
        Item {
            id: c
            readonly property int p: Tokens.pitch
            readonly property real room: height - box.bodyY - 10
            // Every workspace a row, when they all fit in 3x5 tiles.
            readonly property bool rows: root.list.length * 7 * p + (root.list.length - 1) * 3 <= room
            Rows {
                visible: c.rows
                x: 14
                y: box.bodyY + 2
                width: c.width - 28
                height: c.room
                gap: 3
                lines: root.list.map(w => ({
                            spans: [[root.pad(w.home ? "⌂" : w.id, 2), Ink.yellow], [root.pad(root.nameOf(w), 5), w.focused ? Ink.yellow : Ink.white], [root.pad(w.home ? (w.windows ? w.windows + " WIN" : "CLEAR") : w.windows ? w.windows + " WIN" : "FREE", 6), Ink.white], [w.focused ? "NOW" : "", Ink.orange]],
                            action: "ws " + w.id
                        }))
            }
            // Else a tile per workspace, the one you are on yellow, and
            // what it is under them.
            readonly property string tileFont: 9 * p * 2 + 6 <= room ? "5x7" : "3x5"
            Row {
                id: tiles
                visible: !c.rows
                x: 14
                y: box.bodyY + 2
                spacing: 3 * c.p
                Repeater {
                    model: root.list
                    Flaps {
                        required property var modelData
                        cells: 1
                        font: c.tileFont
                        text: modelData.home ? "⌂" : String(modelData.id)
                        color: Ink.dim
                        lit: modelData.focused ? [0] : []
                        T.Hit {
                            anchors.fill: parent
                            anchors.margins: -3
                            action: "ws " + parent.modelData.id
                        }
                    }
                }
            }
            Flaps {
                visible: !c.rows
                x: 14
                y: tiles.y + tiles.height + 6
                width: c.width - 28
                font: c.tileFont
                spans: root.cur ? [[(root.cur.home ? "⌂" : root.cur.id) + " ", Ink.yellow], [root.nameOf(root.cur) + " ", Ink.white], [root.cur.windows ? "· " + root.cur.windows + " WIN" : "· CLEAR", Ink.dim]] : []
            }
        }
    }

    // ── Expanded: the platforms ─────────────────────────────────────
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
            readonly property real padX: 14
            readonly property real gap: 16
            readonly property real tileW: (width - padX * 2 - gap * 2) / 3
            readonly property int rowsN: Math.ceil(tiles.length / 3)
            readonly property real footH: 5 * p + 20
            readonly property real labelH: 5 * p + 8
            readonly property real cellH: (height - box.bodyY - 4 - footH - gap * (rowsN - 1)) / rowsN
            readonly property real boxH: cellH - labelH
            function tileX(i: int): real {
                return padX + i % 3 * (tileW + gap);
            }
            function tileY(i: int): real {
                return box.bodyY + 4 + Math.floor(i / 3) * (cellH + gap);
            }

            Repeater {
                model: u.tiles
                Card {
                    id: tile
                    required property var modelData
                    required property int index
                    x: u.tileX(index)
                    y: u.tileY(index)
                    width: u.tileW
                    height: u.boxH
                    on: !!modelData.focused
                    color: Ink.lower
                    // The windows, as flap-dark slabs with a rule under their top.
                    Item {
                        x: parent.width * 0.06
                        y: parent.height * 0.08
                        width: parent.width * 0.88
                        height: parent.height * 0.84
                        Repeater {
                            model: tile.modelData.next ? [] : (geo.geo[tile.modelData.id] ?? [])
                            Item {
                                required property var modelData
                                x: modelData.x * parent.width
                                y: modelData.y * parent.height
                                width: Math.max(4, modelData.w * parent.width - 4)
                                height: Math.max(4, modelData.h * parent.height - 4)
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 2
                                    color: Ink.rim
                                }
                                Rectangle {
                                    y: Math.min(parent.height - 2, Math.max(8, 7 * u.p + 4))
                                    width: parent.width
                                    height: 2
                                    color: Ink.seam
                                }
                            }
                        }
                    }
                    T.Hit {
                        anchors.fill: parent
                        action: "ws " + tile.modelData.id
                    }
                }
            }

            Dots {
                id: ink
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
                        readonly property color tone: cell.modelData.focused ? Ink.yellow : Ink.dim
                        // Empty: what it is kept for.
                        MatrixText {
                            visible: !!(cell.modelData.next || cell.modelData.home) && !cell.wins.length
                            x: Math.round((u.tileX(cell.index) + u.tileW / 2) / u.p - width / 2)
                            y: Math.round((u.tileY(cell.index) + u.boxH / 2) / u.p) - 2
                            width: implicitWidth
                            height: 5
                            font: "3x5"
                            text: cell.modelData.next ? "+ NEXT FREE" : "KEPT CLEAR"
                            color: Ink.label
                        }
                        // Each window's name at its top left.
                        Repeater {
                            model: cell.wins
                            MatrixText {
                                required property var modelData
                                x: Math.round((cell.inX + modelData.x * cell.inW) / u.p) + 1
                                y: Math.round((cell.inY + modelData.y * cell.inH) / u.p) + 1
                                width: Math.max(0, Math.round(modelData.w * cell.inW / u.p) - 3)
                                height: 5
                                visible: width >= 8 && modelData.h * cell.inH >= 8 * u.p
                                font: "3x5"
                                text: String(modelData.cls).split(".").pop()
                                color: Ink.white
                            }
                        }
                        // 2 WEB                  3 WIN
                        MatrixText {
                            x: Math.round(u.tileX(cell.index) / u.p)
                            y: Math.round((u.tileY(cell.index) + u.boxH + 6) / u.p)
                            width: Math.floor(u.tileW / u.p) - count.implicitWidth - 2
                            height: 5
                            font: "3x5"
                            text: cell.modelData.next ? cell.modelData.id + " +" : cell.modelData.home ? "⌂ HOME" : cell.modelData.id + " " + root.nameOf(cell.modelData)
                            color: cell.tone
                        }
                        MatrixText {
                            id: count
                            x: Math.round((u.tileX(cell.index) + u.tileW) / u.p) - width
                            y: Math.round((u.tileY(cell.index) + u.boxH + 6) / u.p)
                            width: implicitWidth
                            height: 5
                            font: "3x5"
                            text: cell.modelData.windows ? cell.modelData.windows + " WIN" : ""
                            color: cell.tone
                        }
                    }
                }
                MatrixText {
                    x: Math.ceil(u.padX / u.p)
                    y: ink.rows - Math.ceil(12 / u.p) - 5
                    width: ink.cols - x * 2
                    height: 5
                    font: "3x5"
                    scroll: true
                    text: "CLICK A PLATFORM TO GO THERE · HOME STAYS CLEAR"
                    color: Ink.label
                }
            }
        }
    }
}
