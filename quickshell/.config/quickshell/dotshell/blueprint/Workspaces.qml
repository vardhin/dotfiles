import QtQuick
import qs
import qs.services
import qs.aero as A
import qs.tokyo as T

// Workspaces, Blueprint: PLAN — LEVEL 1. The workspaces as rooms of one
// floor plan in a heavy outline, their windows drawn in each where they
// sit, each room named at its foot; the one you are on shaded and named in
// white. A click goes there. Expanded, SHEET 3, the floor plans: a room
// per workspace in use (its windows hatched and named in dots), the next
// free one, and their names and window counts in dots.
T.Face {
    id: root

    readonly property var list: ctx.list ?? []
    // A short name per workspace, from what is open on it.
    readonly property var kinds: [[/code|codium|zed|nvim|jetbrains/i, "code"], [/firefox|chrom|browser|librewolf|zen/i, "web"], [/mpv|vlc|dottv|celluloid/i, "tv"], [/kitty|ghostty|alacritty|foot|term/i, "term"], [/telegram|discord|vesktop|signal/i, "chat"], [/spotify|rmpc|music/i, "music"], [/nautilus|thunar|nemo|files/i, "files"], [/steam|game/i, "game"], [/gimp|krita|inkscape|blender/i, "art"]]
    function kind(cls: string): string {
        for (const [re, w] of kinds)
            if (re.test(cls))
                return w;
        return cls.split(/[.\-_ ]/).pop().slice(0, 6).toLowerCase();
    }
    function nameOf(ws: var): string {
        if (!ws)
            return "";
        if (ws.home)
            return "home";
        const w = Feeds.windows.find(x => x.ws === ws.id && x.cls);
        return w ? kind(w.cls) : "new";
    }

    onListChanged: geo.poke()
    A.Geo {
        id: geo
    }

    Paper {
        anchors.fill: parent
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : plan
    }

    // A room's windows, drawn where they sit (fractions of the room).
    component Furniture: Item {
        id: f
        property var wins: []
        property bool hatched: false
        Repeater {
            model: f.wins
            Item {
                required property var modelData
                x: modelData.x * f.width
                y: modelData.y * f.height
                width: Math.max(3, modelData.w * f.width - 3)
                height: Math.max(3, modelData.h * f.height - 3)
                Hatch {
                    visible: f.hatched
                    anchors.fill: parent
                    color: Ink.hatchFaint
                }
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 1
                    border.color: f.hatched ? Ink.ink : Ink.line
                }
            }
        }
    }

    // ── Compact: PLAN — LEVEL 1 ─────────────────────────────────────
    Component {
        id: plan
        Item {
            id: c
            readonly property var shown: root.list.slice(0, Math.max(1, Math.floor((width - 32) / 40)))
            readonly property real roomW: (frame.width - 4) / Math.max(1, shown.length)

            Pen {
                x: 16
                y: 10
                width: parent.width - 32
                height: 14
                text: "PLAN — LEVEL 1 · WORKSPACES"
            }
            Rectangle {
                id: frame
                x: 16
                y: 30
                width: parent.width - 32
                height: parent.height - y - 14
                color: "transparent"
                border.width: 2
                border.color: Ink.ink
            }
            Row {
                x: frame.x + 2
                y: frame.y + 2
                Repeater {
                    model: c.shown
                    Item {
                        id: room
                        required property var modelData
                        required property int index
                        width: c.roomW
                        height: frame.height - 4
                        Rectangle {
                            anchors.fill: parent
                            visible: !!room.modelData.focused
                            color: Qt.rgba(232 / 255, 241 / 255, 1, 0.1)
                        }
                        Rectangle {
                            visible: room.index < c.shown.length - 1
                            anchors.right: parent.right
                            width: 1
                            height: parent.height
                            color: Ink.ink
                        }
                        Furniture {
                            x: parent.width * 0.06
                            y: parent.height * 0.08
                            width: parent.width * 0.88
                            height: parent.height * 0.84
                            wins: geo.geo[room.modelData.id] ?? []
                        }
                        Pen {
                            x: 6
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 2
                            width: parent.width - 8
                            height: 14
                            text: (room.modelData.home ? "⌂" : room.modelData.id) + " " + root.nameOf(room.modelData)
                            color: room.modelData.focused ? Ink.white : Ink.line
                        }
                        T.Hit {
                            anchors.fill: parent
                            action: "ws " + room.modelData.id
                        }
                    }
                }
            }
        }
    }

    // ── Expanded: SHEET 3 ───────────────────────────────────────────
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
            readonly property int padX: Math.ceil(16 / p)
            readonly property int topY: Math.ceil(30 / p)
            readonly property int gap: 4
            readonly property int tileW: Math.floor((cols - padX * 2 - gap * 2) / 3)
            readonly property int rowsN: Math.ceil(tiles.length / 3)
            readonly property int cellH: Math.floor((rows - topY - 10 - gap * (rowsN - 1)) / rowsN)
            readonly property int boxH: cellH - 9
            function tileX(i: int): int {
                return padX + i % 3 * (tileW + gap);
            }
            function tileY(i: int): int {
                return topY + Math.floor(i / 3) * (cellH + gap);
            }

            Sheet {
                title: "SHEET 3 — FLOOR PLANS"
            }
            Repeater {
                model: u.tiles
                Item {
                    id: tile
                    required property var modelData
                    required property int index
                    x: u.tileX(index) * u.p
                    y: u.tileY(index) * u.p
                    width: u.tileW * u.p
                    height: u.boxH * u.p
                    Rectangle {
                        anchors.fill: parent
                        color: tile.modelData.focused ? Qt.rgba(232 / 255, 241 / 255, 1, 0.08) : "transparent"
                        border.width: tile.modelData.focused ? 2 : 1.5
                        border.color: tile.modelData.focused ? Ink.white : Ink.line
                    }
                    Furniture {
                        x: parent.width * 0.06
                        y: parent.height * 0.08
                        width: parent.width * 0.88
                        height: parent.height * 0.84
                        hatched: true
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
                        id: tile
                        required property var modelData
                        required property int index
                        readonly property var wins: tile.modelData.next ? [] : (geo.geo[tile.modelData.id] ?? [])
                        readonly property int inX: Math.round(u.tileW * 0.06)
                        readonly property int inY: Math.round(u.boxH * 0.08)
                        readonly property int inW: Math.round(u.tileW * 0.88)
                        readonly property int inH: Math.round(u.boxH * 0.84)
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
                            color: Ink.done
                        }
                        // Each window's name at its top left.
                        Repeater {
                            model: tile.wins
                            MatrixText {
                                required property var modelData
                                x: tile.inX + Math.round(modelData.x * tile.inW) + 2
                                y: tile.inY + Math.round(modelData.y * tile.inH) + 2
                                width: Math.max(0, Math.round(modelData.w * tile.inW) - 4)
                                height: implicitHeight
                                visible: width >= 8 && modelData.h * tile.inH >= 8
                                font: "3x5"
                                text: String(modelData.cls).split(".").pop()
                                color: Ink.ink
                            }
                        }
                        // 2 WEB                  3 win
                        MatrixText {
                            y: u.boxH + 3
                            width: parent.width - count.implicitWidth - 3
                            height: implicitHeight
                            font: "3x5"
                            text: tile.modelData.next ? tile.modelData.id + " +" : tile.modelData.home ? "⌂ HOME" : tile.modelData.id + " " + root.nameOf(tile.modelData)
                            color: tile.modelData.focused ? Ink.white : Ink.line
                        }
                        MatrixText {
                            id: count
                            anchors.right: parent.right
                            y: u.boxH + 3
                            width: implicitWidth
                            height: implicitHeight
                            font: "3x5"
                            text: tile.modelData.windows ? tile.modelData.windows + " WIN" : ""
                            color: tile.modelData.focused ? Ink.white : Ink.line
                        }
                    }
                }
                MatrixText {
                    x: u.padX
                    y: u.rows - 7
                    width: u.cols - u.padX * 2
                    height: implicitHeight
                    font: "3x5"
                    scroll: true
                    text: "NOTE: ROOM 0 (HOME) IS KEPT CLEAR. CLICK A ROOM TO GO THERE."
                    color: Ink.line
                }
            }
        }
    }
}
