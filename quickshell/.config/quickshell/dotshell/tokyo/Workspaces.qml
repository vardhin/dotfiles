import QtQuick
import Quickshell.Io
import qs
import qs.services

// Workspaces, Tokyo Night: a metro line. Each workspace a station on a
// cyan rail, a pink dot over it per window, its name under it (the
// focused one big and cyan, empty ones dark). Expanded, an overview: a
// tile per workspace with its windows drawn where they sit.
Face {
    id: root

    readonly property var list: ctx.list ?? []
    // A short name per workspace, from what is open on it.
    readonly property var kinds: [[/code|codium|zed|nvim|jetbrains/i, "CODE"], [/firefox|chrom|browser|librewolf|zen/i, "WEB"], [/mpv|vlc|dottv|celluloid/i, "TV"], [/kitty|ghostty|alacritty|foot|term/i, "TERM"], [/telegram|discord|vesktop|signal/i, "CHAT"], [/spotify|rmpc|music/i, "MUSIC"], [/nautilus|thunar|nemo|files/i, "FILES"], [/steam|game/i, "GAME"], [/gimp|krita|inkscape|blender/i, "ART"]]
    function kind(cls: string): string {
        for (const [re, w] of kinds)
            if (re.test(cls))
                return w;
        return cls.split(/[.\-_ ]/).pop().toUpperCase().slice(0, 5);
    }
    function nameOf(ws: var): string {
        if (ws.home)
            return "⌂ HOME";
        const w = Feeds.windows.find(x => x.ws === ws.id && x.cls);
        return ws.id + (w ? " " + kind(w.cls) : ws.windows ? "" : " +");
    }
    function tone(ws: var): color {
        return ws.focused ? Ink.cyan : ws.windows > 0 ? Ink.pink : Ink.deep;
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : line
    }

    // ── Compact: the line ───────────────────────────────────────────
    Component {
        id: line
        Item {
            id: sign
            readonly property bool roomy: height >= 130
            readonly property real padX: Math.round(width * 0.06)
            readonly property real railY: roomy ? Math.round(height * 0.5) : Math.round(height * 0.44)
            readonly property int n: root.list.length
            function stationX(i: int): real {
                const span = width - padX * 2 - 20;
                return padX + 10 + (n > 1 ? span * (0.03 + 0.94 * i / (n - 1)) : span / 2);
            }

            Glass {
                id: glass
                radius: 28

                DotText {
                    visible: sign.roomy
                    x: root.d(sign.padX)
                    y: root.d(16)
                    height: Tokens.fontPx
                    text: "DOT LINE · 線"
                    color: Ink.violet
                }

                // The names under the stations: in the 5x7 font when they
                // fit, the small one when not, the bare number at worst.
                Repeater {
                    model: root.list
                    Item {
                        id: name
                        required property var modelData
                        required property int index
                        readonly property string full: root.nameOf(modelData).toUpperCase()
                        readonly property int room: Math.floor((sign.width - sign.padX * 2) / Math.max(1, sign.n) / root.pitch) + 2
                        readonly property int fit: full.length * Tokens.charDots <= room ? 2 : full.length * 4 <= room ? 1 : 0
                        x: root.d(sign.stationX(index))
                        y: root.d(sign.railY + (modelData.focused ? 15 : 12))
                        DotText {
                            visible: name.fit !== 1
                            x: -Math.round(implicitWidth / 2)
                            height: Tokens.fontPx
                            text: name.fit ? name.full : name.modelData.home ? "⌂" : String(name.modelData.id)
                            color: root.tone(name.modelData)
                        }
                        MatrixText {
                            visible: name.fit === 1
                            x: -Math.round(implicitWidth / 2)
                            y: 3
                            height: implicitHeight
                            font: "3x5"
                            text: name.full.replace("⌂ ", "")
                            color: root.tone(name.modelData)
                        }
                    }
                }
            }

            // The rail.
            Tube {
                x: sign.padX
                y: sign.railY - 3
                width: sign.width - sign.padX * 2
                height: 6
                radius: 3
                line: 0
                fill: Ink.cyan
                tint: Ink.cyan
                glow: 0.8
            }

            // Stations, and a dot per window over each.
            Repeater {
                model: root.list
                Item {
                    id: stop
                    required property var modelData
                    required property int index
                    readonly property real size: modelData.focused ? 20 : 15
                    x: sign.stationX(index) - 20
                    width: 40
                    height: sign.height

                    Tube {
                        x: (parent.width - width) / 2
                        y: sign.railY - height / 2
                        width: stop.size
                        height: stop.size
                        radius: width / 2
                        line: 3
                        fill: Ink.glass
                        tint: root.tone(stop.modelData)
                        glow: 0.6
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: sign.railY - stop.size / 2 - 12
                        spacing: 3
                        Repeater {
                            model: Math.min(4, stop.modelData.windows)
                            Tube {
                                width: 7
                                height: 7
                                radius: 3.5
                                line: 0
                                fill: Ink.pink
                                tint: Ink.pink
                                glow: 0.5
                            }
                        }
                    }
                    Hit {
                        anchors.fill: parent
                        action: "ws " + stop.modelData.id
                    }
                }
            }

            Sign {
                radius: 28
            }
        }
    }

    // ── Expanded: the overview ──────────────────────────────────────
    Component {
        id: board
        Item {
            id: over

            // { ws: [{ x, y, w, h, cls }] } in fractions of the monitor.
            property var geo: ({})
            readonly property var tiles: {
                const t = root.list.filter(w => w.home || w.focused || w.windows > 0).slice(0, 5);
                const next = root.list.find(w => !w.home && w.windows === 0 && !w.focused);
                return t.concat([{ id: next ? next.id : root.list.length + 1, next: true, windows: 0 }]);
            }

            Process {
                id: query
                command: ["sh", "-c", "printf '{\"clients\":%s,\"monitors\":%s}' \"$(hyprctl -j clients)\" \"$(hyprctl -j monitors)\""]
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            const d = JSON.parse(text);
                            const mon = {};
                            for (const m of d.monitors ?? [])
                                mon[m.id] = m;
                            const by = {};
                            for (const c of d.clients ?? []) {
                                const ws = c.workspace?.id ?? 0;
                                if (ws <= 0 || !c.mapped)
                                    continue;
                                const m = mon[c.monitor] ?? { x: 0, y: 0, width: 1920, height: 1080 };
                                (by[ws] = by[ws] ?? []).push({ x: (c.at[0] - m.x) / m.width, y: (c.at[1] - m.y) / m.height, w: c.size[0] / m.width, h: c.size[1] / m.height, cls: c.class ?? "" });
                            }
                            over.geo = by;
                        } catch (e) {}
                    }
                }
            }
            // Again whenever windows come, go or move between workspaces.
            Timer {
                id: later
                interval: 250
                onTriggered: query.running = true
            }
            Connections {
                target: root
                function onListChanged() {
                    later.restart();
                }
            }
            Component.onCompleted: query.running = true

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: 30
                color: Ink.glass
            }
            Item {
                id: well
                anchors.fill: parent
                anchors.margins: 12

                Glass {
                    id: glass
                    radius: 20

                    // Laid out in dots: three tiles a row, a name line under each.
                    Item {
                        id: grid
                        x: 5
                        y: 5
                        width: glass.cols - 10
                        height: glass.rows - 10 - 8
                        readonly property int gap: 4
                        readonly property int tileW: Math.floor((width - gap * 2) / 3)
                        readonly property int rowsN: Math.ceil(over.tiles.length / 3)
                        readonly property int cellH: Math.floor((height - gap * (rowsN - 1)) / rowsN)
                        readonly property int boxH: cellH - 9

                        Repeater {
                            model: over.tiles
                            Item {
                                id: tile
                                required property var modelData
                                required property int index
                                x: index % 3 * (grid.tileW + grid.gap)
                                y: Math.floor(index / 3) * (grid.cellH + grid.gap)
                                width: grid.tileW
                                height: grid.cellH

                                // Empty: what it is kept for.
                                MatrixText {
                                    visible: !!(tile.modelData.next || tile.modelData.home) && !(over.geo[tile.modelData.id]?.length)
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: Math.round((grid.boxH - height) / 2)
                                    height: implicitHeight
                                    font: "3x5"
                                    text: tile.modelData.next ? "+ NEXT FREE" : "KEPT CLEAR"
                                    color: Ink.deep
                                }
                                // Each window's name in its outline.
                                Repeater {
                                    model: tile.modelData.next ? [] : (over.geo[tile.modelData.id] ?? [])
                                    MatrixText {
                                        required property var modelData
                                        x: Math.round(2 + modelData.x * (grid.tileW - 4)) + 2
                                        y: Math.round(2 + modelData.y * (grid.boxH - 4)) + 2
                                        width: Math.max(0, Math.round(modelData.w * (grid.tileW - 4)) - 4)
                                        height: implicitHeight
                                        visible: width >= 8 && modelData.h * (grid.boxH - 4) >= 8
                                        font: "3x5"
                                        text: String(modelData.cls).split(".").pop().toLowerCase()
                                        color: Ink.pink
                                    }
                                }
                                // 1 CODE                 2 WIN
                                MatrixText {
                                    y: grid.boxH + 3
                                    height: implicitHeight
                                    width: parent.width - count.implicitWidth - 3
                                    font: "3x5"
                                    text: (tile.modelData.next ? tile.modelData.id + " +" : root.nameOf(tile.modelData)).replace("⌂ ", "")
                                    color: tile.modelData.focused ? Ink.cyan : Ink.violet
                                }
                                MatrixText {
                                    id: count
                                    anchors.right: parent.right
                                    y: grid.boxH + 3
                                    height: implicitHeight
                                    font: "3x5"
                                    text: tile.modelData.windows ? tile.modelData.windows + " WIN" : ""
                                    color: tile.modelData.focused ? Ink.cyan : Ink.violet
                                }
                            }
                        }
                    }

                    MatrixText {
                        x: 5
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 4
                        width: glass.cols - 10
                        height: implicitHeight
                        font: "3x5"
                        scroll: true
                        text: "CLICK A WORKSPACE TO GO THERE · HOME STAYS EMPTY"
                        color: Ink.violet
                    }
                }

                // The tiles and window outlines, crisp over the glass.
                Item {
                    x: glass.x + grid.x * root.pitch
                    y: glass.y + grid.y * root.pitch
                    Repeater {
                        model: over.tiles
                        Item {
                            id: box
                            required property var modelData
                            required property int index
                            x: index % 3 * (grid.tileW + grid.gap) * root.pitch
                            y: Math.floor(index / 3) * (grid.cellH + grid.gap) * root.pitch
                            width: grid.tileW * root.pitch
                            height: grid.boxH * root.pitch

                            Tube {
                                anchors.fill: parent
                                radius: 12
                                line: 2
                                tint: box.modelData.focused ? Ink.cyan : Ink.deep
                                glow: box.modelData.focused ? 0.8 : 0
                            }
                            Repeater {
                                model: box.modelData.next ? [] : (over.geo[box.modelData.id] ?? [])
                                Tube {
                                    required property var modelData
                                    x: (2 + modelData.x * (grid.tileW - 4)) * root.pitch
                                    y: (2 + modelData.y * (grid.boxH - 4)) * root.pitch
                                    width: modelData.w * (grid.tileW - 4) * root.pitch
                                    height: modelData.h * (grid.boxH - 4) * root.pitch
                                    radius: 5
                                    line: 1.5
                                    tint: Ink.pink
                                    glow: 0.4
                                }
                            }
                            Hit {
                                anchors.fill: parent
                                action: "ws " + box.modelData.id
                            }
                        }
                    }
                }
            }
            Sign {
                radius: 30
                inner: true
                innerInset: 12
            }
        }
    }
}
