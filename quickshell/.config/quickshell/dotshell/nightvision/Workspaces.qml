import QtQuick
import qs
import qs.services
import qs.aero as A
import qs.tokyo as T

// Workspaces, Night Vision: SECTORS. Dim small print says where the
// cursor is, then a box per workspace ruled in green (the one you are on
// in white with a green haze): a lit contact for each window on it, its
// number and name at the foot. A click on a box goes there. Expanded,
// OVERVIEW on the CRT: a box per sector in use with its windows drawn
// where they sit as lit frames named in bright dots, the next free one,
// HOME kept clear; its number, name and window count under each.
T.Face {
    id: root

    readonly property var list: ctx.list ?? []
    readonly property var cur: list.find(w => w.focused) ?? null
    // A short name per workspace, from what is open on it.
    readonly property var kinds: [[/code|codium|zed|nvim|jetbrains/i, "code"], [/firefox|chrom|browser|librewolf|zen/i, "web"], [/mpv|vlc|dottv|celluloid/i, "tv"], [/kitty|ghostty|alacritty|foot|term/i, "term"], [/telegram|discord|vesktop|signal/i, "chat"], [/spotify|rmpc|music/i, "music"], [/nautilus|thunar|nemo|files/i, "files"], [/steam|game/i, "game"], [/gimp|krita|inkscape|blender/i, "art"]]
    function kind(cls: string): string {
        for (const [re, w] of kinds)
            if (re.test(cls))
                return w;
        return cls.split(/[.\-_ ]/).pop().toLowerCase().slice(0, 6);
    }
    function nameOf(ws: var): string {
        if (!ws)
            return "";
        if (ws.home)
            return "home";
        const w = Feeds.windows.find(x => x.ws === ws.id && x.cls);
        return w ? kind(w.cls) : "new";
    }
    function label(ws: var): string {
        return ws.home ? "⌂ HOME" : ws.id + " " + nameOf(ws).toUpperCase();
    }
    onListChanged: geo.poke()
    A.Geo {
        id: geo
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : sectors
    }

    // ── Compact: the sectors ────────────────────────────────────────
    Component {
        id: sectors
        Scope {
            id: s
            readonly property var tiles: root.list.slice(0, 6)
            readonly property real padX: (Math.max(18, rx * 0.5) + 8)
            readonly property int t: (Math.max(2, Math.round(rows * 0.13)) + 2)
            readonly property bool tall: rows >= 28
            readonly property real gap: 8
            readonly property real tileY: py(tall ? t + 8 : t)
            readonly property real tileH: s.height - tileY - Math.max(8, height * 0.13) - 4
            readonly property real tileW: Math.max(10, (s.width - padX * 2 - gap * (tiles.length - 1)) / Math.max(1, tiles.length))
            readonly property bool named: tileW / Tokens.pitch >= 22

            MatrixText {
                visible: s.tall
                x: s.dx(s.padX)
                y: s.t
                width: s.dx(s.width - s.padX) - x
                height: 5
                font: "3x5"
                text: "SECTORS · CURSOR IN " + (root.cur ? (root.cur.home ? "HOME" : root.cur.id) : "--")
                color: Ink.dim
            }
            // Each sector's number and name at its foot.
            Repeater {
                model: s.tiles
                MatrixText {
                    required property var modelData
                    required property int index
                    x: s.dx(s.padX + index * (s.tileW + s.gap) + 5)
                    y: s.dy(s.tileY + s.tileH - 5) - 5
                    width: Math.floor((s.tileW - 10) / Tokens.pitch)
                    height: 5
                    font: "3x5"
                    text: s.named ? root.label(modelData) : (modelData.home ? "⌂" : String(modelData.id))
                    color: modelData.focused ? Ink.bright : Ink.lit
                }
            }
            Repeater {
                parent: s.over
                model: s.tiles
                Item {
                    id: tile
                    required property var modelData
                    required property int index
                    x: s.padX + index * (s.tileW + s.gap)
                    y: s.tileY
                    width: s.tileW
                    height: s.tileH
                    readonly property int n: Math.min(4, modelData.windows ?? 0)
                    readonly property real disc: Math.max(5, Math.min(12, height * 0.16, width * 0.14))
                    Box {
                        anchors.fill: parent
                        tone: tile.modelData.focused ? "bright" : ""
                        bloom: !!tile.modelData.focused
                    }
                    // A lit contact per window.
                    Repeater {
                        model: tile.n
                        Rectangle {
                            required property int index
                            readonly property real span: tile.width * 0.6
                            x: tile.width * 0.2 + (tile.n === 1 ? span / 2 : index * span / (tile.n - 1)) - width / 2
                            y: tile.height * (s.named ? 0.36 : 0.42) - height / 2 + (index % 2 === 1 && tile.n > 2 ? tile.disc * 0.9 : 0)
                            width: tile.disc
                            height: tile.disc
                            radius: width / 2
                            color: tile.modelData.focused ? Ink.bright : Ink.lit
                            antialiasing: true
                        }
                    }
                    T.Hit {
                        anchors.fill: parent
                        action: "ws " + tile.modelData.id
                    }
                }
            }
        }
    }

    // ── Expanded: the overview ──────────────────────────────────────
    Component {
        id: board
        Scope {
            id: u
            crt: true
            readonly property var tiles: {
                const t = root.list.filter(w => w.home || w.focused || w.windows > 0).slice(0, 5);
                const next = root.list.find(w => !w.home && w.windows === 0 && !w.focused);
                return t.concat([{ id: next ? next.id : root.list.length + 1, next: true, windows: 0 }]);
            }
            readonly property int p: Tokens.pitch
            readonly property real padX: (Math.max(16, rx * 0.36) + 10)
            readonly property real padY: (Math.max(12, ry * 0.6) + 8)
            readonly property real gap: 12
            readonly property real tileW: (width - padX * 2 - gap * 2) / 3
            readonly property int rowsN: Math.ceil(tiles.length / 3)
            readonly property real footH: 5 * p + 10
            readonly property real labelH: 7 * p + 8
            readonly property real cellH: (height - padY * 2 - footH - gap * (rowsN - 1)) / rowsN
            readonly property real boxH: cellH - labelH
            function tileX(i: int): real {
                return padX + i % 3 * (tileW + gap);
            }
            function tileY(i: int): real {
                return padY + Math.floor(i / 3) * (cellH + gap);
            }

            Repeater {
                model: u.tiles
                Item {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property var wins: cell.modelData.next ? [] : (geo.geo[cell.modelData.id] ?? [])
                    readonly property real inX: u.tileX(index) + u.tileW * 0.07
                    readonly property real inY: u.tileY(index) + u.boxH * 0.09
                    readonly property real inW: u.tileW * 0.86
                    readonly property real inH: u.boxH * 0.82
                    readonly property color tone: cell.modelData.focused ? Ink.bright : Ink.lit
                    // Empty: what it is kept for.
                    MatrixText {
                        visible: !!(cell.modelData.next || cell.modelData.home) && !cell.wins.length
                        x: Math.round(u.dx(u.tileX(cell.index) + u.tileW / 2) - width / 2)
                        y: u.dy(u.tileY(cell.index) + u.boxH / 2) - 2
                        width: implicitWidth
                        height: 5
                        font: "3x5"
                        text: cell.modelData.next ? "+ NEXT FREE" : "KEPT CLEAR"
                        color: Ink.dim
                    }
                    // Each window's name at its top left.
                    Repeater {
                        model: cell.wins
                        MatrixText {
                            required property var modelData
                            x: u.dx(cell.inX + modelData.x * cell.inW) + 2
                            y: u.dy(cell.inY + modelData.y * cell.inH) + 2
                            width: Math.max(0, Math.round(modelData.w * cell.inW / u.p) - 4)
                            height: 5
                            visible: width >= 8 && modelData.h * cell.inH >= 9 * u.p
                            font: "3x5"
                            text: String(modelData.cls).split(".").pop().toLowerCase()
                            color: Ink.bright
                        }
                    }
                    // 2 WEB                  3 win
                    MatrixText {
                        x: u.dx(u.tileX(cell.index))
                        y: u.dy(u.tileY(cell.index) + u.boxH + 6)
                        width: Math.floor(u.tileW / u.p) - count.implicitWidth - 2
                        font: u.tileW / u.p >= 52 ? "5x7" : "3x5"
                        height: font === "5x7" ? 7 : 5
                        text: cell.modelData.next ? cell.modelData.id + " +" : root.label(cell.modelData)
                        color: cell.tone
                    }
                    MatrixText {
                        id: count
                        x: u.dx(u.tileX(cell.index) + u.tileW) - width
                        y: u.dy(u.tileY(cell.index) + u.boxH + 6) + 1
                        width: implicitWidth
                        height: 5
                        font: "3x5"
                        text: cell.modelData.windows ? cell.modelData.windows + " WIN" : ""
                        color: cell.tone
                    }
                }
            }
            MatrixText {
                x: u.dx(u.padX)
                y: u.dy(u.height - u.padY) - 5
                width: u.dx(u.width - u.padX) - x
                height: 5
                font: "3x5"
                scroll: true
                text: "CLICK A SECTOR TO MOVE IN · HOME STAYS CLEAR"
                color: Ink.dim
            }
            // The boxes and their windows.
            Repeater {
                parent: u.over
                model: u.tiles
                Item {
                    id: tile
                    required property var modelData
                    required property int index
                    x: u.tileX(index)
                    y: u.tileY(index)
                    width: u.tileW
                    height: u.boxH
                    Box {
                        anchors.fill: parent
                        tone: tile.modelData.focused ? "bright" : ""
                        bloom: !!tile.modelData.focused
                        line: tile.modelData.focused ? 2 : 1
                    }
                    Item {
                        x: parent.width * 0.07
                        y: parent.height * 0.09
                        width: parent.width * 0.86
                        height: parent.height * 0.82
                        Repeater {
                            model: tile.modelData.next ? [] : (geo.geo[tile.modelData.id] ?? [])
                            Rectangle {
                                required property var modelData
                                x: modelData.x * parent.width
                                y: modelData.y * parent.height
                                width: Math.max(4, modelData.w * parent.width - 4)
                                height: Math.max(4, modelData.h * parent.height - 4)
                                color: "transparent"
                                border.width: 1.5
                                border.color: Ink.lit
                            }
                        }
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
