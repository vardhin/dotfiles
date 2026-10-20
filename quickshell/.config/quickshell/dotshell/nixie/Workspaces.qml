import QtQuick
import qs
import qs.services
import qs.aero as A
import qs.tokyo as T

// Workspaces, Nixie: a lift's floor dial in an arched walnut case. The
// floors sit round a brass arc as small tubes (the one you are on glowing,
// the rest dim, an urgent one red), a brass needle on its pivot points at
// it; beside the dial FLOOR in brass, the floor's number and name glowing
// big and its windows in orange. A click on a tube goes there. Expanded,
// OVERVIEW: the case's dot screen with an arched card per floor in use, its
// windows drawn where they sit in glowing orange frames and named in dots,
// the next free one, the one you are on ringed bright; its name and window
// count under each.
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
        return w ? kind(w.cls) : "New";
    }
    function windowsOf(ws: var): string {
        if (!ws)
            return "";
        const ws_ = Feeds.windows.filter(x => x.ws === ws.id && x.cls).map(x => String(x.cls).split(".").pop().toLowerCase());
        return ws_.length ? ws_.join(" · ") : ws.home ? "kept clear" : "no windows";
    }
    onListChanged: geo.poke()
    A.Geo {
        id: geo
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : dial
    }

    // ── Compact: the floor dial ─────────────────────────────────────
    Component {
        id: dial
        Item {
            id: c
            readonly property var floors: root.list.slice(0, 9)
            readonly property int n: Math.max(1, floors.length)
            readonly property int focusAt: Math.max(0, floors.findIndex(w => w.focused))
            // The dial: a half circle on the case's floor.
            readonly property real r: Math.min((width * 0.55 - 30) / 2, height - 46)
            readonly property real cx: 16 + r + 14
            readonly property real cy: height - 22
            readonly property real tubeW: Math.max(18, Math.min(30, r * 0.32))
            readonly property real tubeH: tubeW * 1.0
            function angle(i: int): real {
                return Math.PI * (1 - (n === 1 ? 0.5 : i / (n - 1)));
            }

            Wood {
                anchors.fill: parent
                dome: Math.min(height * 0.62, width * 0.25)
            }
            // The arc, a dark band inside it.
            Canvas {
                anchors.fill: parent
                readonly property string sig: [c.cx, c.cy, c.r, Ink.brass, Ink.woodA].join("|")
                onSigChanged: requestPaint()
                onPaint: {
                    const g = getContext("2d");
                    g.reset();
                    g.lineWidth = Math.max(6, c.r * 0.12);
                    g.strokeStyle = String(Ink.c("rgba(58,29,14,0.55)", "rgba(122,70,30,0.15)"));
                    g.beginPath();
                    g.arc(c.cx, c.cy, c.r * 0.86, Math.PI, 0, false);
                    g.stroke();
                    g.lineWidth = 2;
                    g.strokeStyle = String(Ink.brass);
                    g.beginPath();
                    g.arc(c.cx, c.cy, c.r, Math.PI, 0, false);
                    g.stroke();
                }
            }
            // The needle and its pivot.
            Rectangle {
                id: needle
                x: c.cx - 1.5
                y: c.cy - c.r * 0.72
                width: 3
                height: c.r * 0.72
                color: Ink.c("#ffd29a", "#8a5a1e")
                transformOrigin: Item.Bottom
                rotation: 90 - c.angle(c.focusAt) * 180 / Math.PI
                Behavior on rotation {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutBack
                    }
                }
            }
            Rectangle {
                x: c.cx - 8
                y: c.cy - 8
                width: 16
                height: 16
                radius: 8
                color: Ink.brass
            }
            // The floors, small tubes round the arc.
            Repeater {
                model: c.floors
                Item {
                    id: fl
                    required property var modelData
                    required property int index
                    readonly property real a: c.angle(index)
                    x: c.cx + Math.cos(a) * c.r - c.tubeW / 2
                    y: c.cy - Math.sin(a) * c.r - c.tubeH / 2 - 4
                    width: c.tubeW
                    height: c.tubeH
                    Tube {
                        anchors.fill: parent
                        mesh: false
                        ghost: false
                        dome: width / 2
                        text: fl.modelData.home ? "⌂" : String(fl.modelData.id)
                        lit: true
                        ink: fl.modelData.urgent ? Ink.red : fl.modelData.focused ? Ink.digit : Ink.deep
                    }
                    T.Hit {
                        anchors.fill: parent
                        action: "ws " + fl.modelData.id
                    }
                }
            }
            // FLOOR / 2 · Web / its windows.
            Column {
                x: c.cx + c.r + 30
                width: c.width - x - 20
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 6
                spacing: 2
                Print {
                    text: "FLOOR"
                    size: 8
                    spacing: 3
                }
                Dots {
                    width: parent.width
                    height: Math.round(Math.min(c.height * 0.36, 60) / Tokens.pitch) * Tokens.pitch
                    Word {
                        width: parent.cols
                        height: parent.rows
                        dots: height
                        serifAt: 18
                        text: root.cur ? (root.cur.home ? "⌂" : root.cur.id) + " · " + root.nameOf(root.cur) : "--"
                    }
                }
                Pen {
                    width: parent.width
                    text: root.windowsOf(root.cur)
                    size: 14
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
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
            readonly property real padX: 24
            readonly property real gap: 14
            readonly property real tileW: (width - padX * 2 - gap * 2) / 3
            readonly property int rowsN: Math.ceil(tiles.length / 3)
            readonly property real footH: 5 * p + 16
            readonly property real labelH: 7 * p + 8
            readonly property real cellH: (height - 24 - 12 - footH - gap * (rowsN - 1)) / rowsN
            readonly property real boxH: cellH - labelH
            function tileX(i: int): real {
                return padX + i % 3 * (tileW + gap);
            }
            function tileY(i: int): real {
                return 24 + Math.floor(i / 3) * (cellH + gap);
            }
            function dx(px: real): int {
                return Math.round((px - box.sx - box.screen.surface.x) / p);
            }
            function dy(px: real): int {
                return Math.round((px - box.sy - box.screen.surface.y) / p);
            }

            Case {
                id: box
                anchors.fill: parent
                Repeater {
                    model: u.tiles
                    Item {
                        id: cell
                        required property var modelData
                        required property int index
                        readonly property var wins: cell.modelData.next ? [] : (geo.geo[cell.modelData.id] ?? [])
                        readonly property real inX: u.tileX(index) + u.tileW * 0.07
                        readonly property real inY: u.tileY(index) + u.boxH * 0.1
                        readonly property real inW: u.tileW * 0.86
                        readonly property real inH: u.boxH * 0.82
                        readonly property color tone: cell.modelData.focused ? Ink.digit : Ink.orange
                        // Empty: what it is kept for.
                        MatrixText {
                            visible: !!(cell.modelData.next || cell.modelData.home) && !cell.wins.length
                            x: Math.round(u.dx(u.tileX(cell.index) + u.tileW / 2) - width / 2)
                            y: u.dy(u.tileY(cell.index) + u.boxH / 2) - 2
                            width: implicitWidth
                            height: 5
                            font: "3x5"
                            text: cell.modelData.next ? "+ NEXT FREE" : "KEPT CLEAR"
                            color: Ink.deep
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
                                color: Ink.digit
                            }
                        }
                        // 2 Web                  3 win
                        MatrixText {
                            x: u.dx(u.tileX(cell.index))
                            y: u.dy(u.tileY(cell.index) + u.boxH + 6)
                            width: Math.floor(u.tileW / u.p) - count.implicitWidth - 2
                            height: 7
                            text: cell.modelData.next ? cell.modelData.id + " New" : cell.modelData.home ? "⌂ Home" : cell.modelData.id + " " + root.nameOf(cell.modelData)
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
                    y: box.screen.rows - Math.ceil(10 / u.p) - 5
                    width: u.dx(u.width - u.padX) - x
                    height: 5
                    font: "3x5"
                    scroll: true
                    text: "CLICK A FLOOR TO GO THERE · HOME STAYS CLEAR"
                    color: Ink.brass
                }
            }
            // The floors' arched cards and their windows' frames.
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
                    topLeftRadius: Math.min(width, height) * 0.3
                    topRightRadius: Math.min(width, height) * 0.3
                    Item {
                        x: parent.width * 0.07
                        y: parent.height * 0.1
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
                                radius: 6
                                color: Ink.c(Qt.rgba(1, 122 / 255, 26 / 255, 0.06), Qt.rgba(180 / 255, 70 / 255, 15 / 255, 0.06))
                                border.width: 1.5
                                border.color: Ink.orange
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
