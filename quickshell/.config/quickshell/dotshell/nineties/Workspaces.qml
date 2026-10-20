import QtQuick
import qs
import qs.services
import qs.aero as A
import qs.tokyo as T

// Workspaces, 90s Nights: the TV's channel selector in the slanted sign.
// CH 02 · WEB big in sunset dots and its window count in blue, then a row
// of leaning channel buttons (⌂ HOME, 1 CODE, …: pink with windows, dim
// when empty, the one you are on white → yellow and glowing). A click on a
// button goes there. Expanded, OVERVIEW: a leaning box per channel in use
// ruled in deep violet, its windows drawn where they sit (pink → blue
// glass under a yellow title bar, named in white dots), the next free
// one, the one you are on ruled yellow and glowing; its number, name and
// window count under each.
T.Face {
    id: root

    readonly property var list: ctx.list ?? []
    readonly property var cur: list.find(w => w.focused) ?? null
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
        return w ? kind(w.cls) : "+";
    }
    function chan(ws: var): string {
        return ws ? (ws.home ? "HOME" : "CH " + String(ws.id).padStart(2, "0") + " · " + nameOf(ws).toUpperCase()) : "--";
    }
    onListChanged: geo.poke()
    A.Geo {
        id: geo
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : selector
    }

    // ── Compact: the channel selector ───────────────────────────────
    Component {
        id: selector
        Item {
            id: c
            readonly property int p: Tokens.pitch
            readonly property real padY: Math.max(10, height * 0.08)
            readonly property real keyH: Math.round(Math.max(30, Math.min(48, height * 0.32)))
            readonly property real keysY: height - padY - keyH
            readonly property real keysX: plate.leftAt(keysY + keyH / 2) + 14
            readonly property real keysW: plate.rightAt(keysY + keyH / 2) - 14 - keysX
            readonly property int n: Math.max(1, Math.min(root.list.length, Math.floor((keysW + 8) / 52)))
            readonly property var shown: {
                // The current channel always in view.
                const l = root.list;
                const at = Math.max(0, l.findIndex(w => w.focused));
                const from = Math.max(0, Math.min(at - n + 1 + Math.floor(n / 2), l.length - n));
                return l.slice(Math.max(0, Math.min(from, at)), Math.max(0, Math.min(from, at)) + n);
            }
            readonly property real tx: plate.leftAt(padY + 12) + 16
            // The title as big as fits: whole-dot 5x7.
            readonly property string title: root.chan(root.cur)
            readonly property string count: root.cur ? root.cur.windows + (root.cur.windows === 1 ? " WINDOW" : " WINDOWS") : ""
            readonly property int room: Math.floor((plate.rightAt(padY) - 16 - tx) / p) - count.length * 4 - 4
            readonly property int k: Math.max(1, Math.min(Math.floor((keysY - padY - 8) / p / 7), Math.floor(room / (title.length * 6))))

            Plate {
                id: plate
                anchors.fill: parent
                Word {
                    id: head
                    x: Math.round((c.tx - plate.rim) / c.p)
                    y: Math.round((c.padY - plate.rim) / c.p)
                    width: implicitWidth
                    height: 7 * c.k
                    dots: 7 * c.k
                    fontAt: 99
                    text: c.title
                    stops: Ink.sunset
                }
                MatrixText {
                    x: Math.round((plate.rightAt(c.padY + 10) - 16 - plate.rim) / c.p) - width
                    y: head.y + head.height - 5
                    visible: x > head.x + head.width + 3
                    width: implicitWidth
                    height: 5
                    font: "3x5"
                    text: c.count
                    color: Ink.blue
                }
            }
            Row {
                x: c.keysX
                y: c.keysY
                spacing: 8
                Repeater {
                    model: c.shown
                    Channel {
                        required property var modelData
                        width: (c.keysW - 8 * (c.shown.length - 1)) / Math.max(1, c.shown.length)
                        height: c.keyH
                        number: modelData.home ? "⌂" : String(modelData.id)
                        name: modelData.home ? "HOME" : root.nameOf(modelData).toUpperCase()
                        on: !!modelData.focused
                        used: !!modelData.home || modelData.windows > 0
                        urgent: !!modelData.urgent
                        action: "ws " + modelData.id
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
            readonly property real padX: 18
            readonly property real gap: 12
            readonly property real tileW: (width - padX * 2 - gap * 2) / 3
            readonly property int rowsN: Math.ceil(tiles.length / 3)
            readonly property real footH: 5 * p + 14
            readonly property real labelH: 7 * p + 8
            readonly property real cellH: (height - 18 - 10 - footH - gap * (rowsN - 1)) / rowsN
            readonly property real boxH: cellH - labelH
            readonly property real t6: Math.tan(6 * Math.PI / 180)
            function tileX(i: int): real {
                return padX + i % 3 * (tileW + gap);
            }
            function tileY(i: int): real {
                return 18 + Math.floor(i / 3) * (cellH + gap);
            }
            function dx(px: real): int {
                return Math.round((px - plate.surface.x) / p);
            }
            function dy(px: real): int {
                return Math.round((px - plate.surface.y) / p);
            }

            Plate {
                id: plate
                anchors.fill: parent
                slant: false
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
                        readonly property color tone: cell.modelData.focused ? Ink.yellow : Ink.blue
                        // Empty: what it is kept for.
                        MatrixText {
                            visible: !!(cell.modelData.next || cell.modelData.home) && !cell.wins.length
                            x: Math.round(u.dx(u.tileX(cell.index) + u.tileW / 2) - width / 2)
                            y: u.dy(u.tileY(cell.index) + u.boxH / 2) - 2
                            width: implicitWidth
                            height: 5
                            font: "3x5"
                            text: cell.modelData.next ? "+ NEXT FREE" : "KEPT CLEAR"
                            color: Ink.magenta
                        }
                        // Each window's name at its top left, leaning with the box.
                        Repeater {
                            model: cell.wins
                            MatrixText {
                                required property var modelData
                                readonly property real py: cell.inY + modelData.y * cell.inH
                                x: u.dx(cell.inX + modelData.x * cell.inW + u.t6 * (u.tileY(cell.index) + u.boxH / 2 - py)) + 2
                                y: u.dy(py) + 2
                                width: Math.max(0, Math.round(modelData.w * cell.inW / u.p) - 4)
                                height: 5
                                visible: width >= 8 && modelData.h * cell.inH >= 9 * u.p
                                font: "3x5"
                                text: String(modelData.cls).split(".").pop().toLowerCase()
                                color: Ink.white
                            }
                        }
                        // 2 WEB                  3 win
                        MatrixText {
                            x: u.dx(u.tileX(cell.index))
                            y: u.dy(u.tileY(cell.index) + u.boxH + 6)
                            width: Math.floor(u.tileW / u.p) - count.implicitWidth - 2
                            font: text.length * 6 <= width ? "5x7" : "3x5"
                            height: font === "5x7" ? 7 : 5
                            text: (cell.modelData.next ? cell.modelData.id + " NEW" : cell.modelData.home ? "⌂ HOME" : cell.modelData.id + " " + root.nameOf(cell.modelData)).toUpperCase()
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
                    y: plate.rows - Math.ceil(10 / u.p) - 5
                    width: u.dx(u.width - u.padX) - x
                    height: 5
                    font: "3x5"
                    scroll: true
                    text: "CLICK A CHANNEL TO TUNE IN · HOME STAYS EMPTY"
                    color: Ink.blue
                }
            }
            // The boxes and their windows.
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
                    antialiasing: true
                    transform: Lean {
                        item: tile
                        deg: 6
                    }
                    Rectangle {
                        antialiasing: true
                        visible: !!tile.modelData.focused && Tokens.neon
                        anchors.fill: parent
                        anchors.margins: -3
                        color: "transparent"
                        border.width: 3
                        border.color: Ink.pink
                        opacity: 0.35
                    }
                    Rectangle {
                        antialiasing: true
                        anchors.fill: parent
                        color: "transparent"
                        border.width: 2
                        border.color: tile.modelData.focused ? Ink.yellow : Ink.deep
                    }
                    Item {
                        x: parent.width * 0.06
                        y: parent.height * 0.08
                        width: parent.width * 0.88
                        height: parent.height * 0.84
                        Repeater {
                            model: tile.modelData.next ? [] : (geo.geo[tile.modelData.id] ?? [])
                            Rectangle {
                                antialiasing: true
                                required property var modelData
                                x: modelData.x * parent.width
                                y: modelData.y * parent.height
                                width: Math.max(4, modelData.w * parent.width - 4)
                                height: Math.max(4, modelData.h * parent.height - 4)
                                gradient: Gradient {
                                    GradientStop {
                                        position: 0
                                        color: Ink.c(Qt.rgba(1, 46 / 255, 151 / 255, 0.5), Qt.rgba(230 / 255, 23 / 255, 125 / 255, 0.35))
                                    }
                                    GradientStop {
                                        position: 1
                                        color: Ink.c(Qt.rgba(31 / 255, 168 / 255, 1, 0.4), Qt.rgba(10 / 255, 132 / 255, 214 / 255, 0.3))
                                    }
                                }
                                Rectangle {
                                    antialiasing: true
                                    width: parent.width
                                    height: 3
                                    color: Ink.yellow
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
        }
    }
}
