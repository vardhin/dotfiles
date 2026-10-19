import QtQuick
import Quickshell.Io
import qs
import qs.services
import qs.tokyo as T

// Workspaces, VFD: the stereo's presets. The display shows the workspace
// you are on as a preset (P2 WEB, big), the windows on it under that and
// the annunciators over it; under the display a row of hard preset keys,
// one per workspace, each with a lamp (lit: here; teal: has windows; dark:
// empty). Expanded, an overview: a ruled tile per workspace with its
// windows drawn where they sit (the one you are on ruled in cyan).
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
        return cls.split(/[.\-_ ]/).pop().toUpperCase().slice(0, 5);
    }
    function nameOf(ws: var): string {
        if (!ws)
            return "";
        if (ws.home)
            return "HOME";
        const w = Feeds.windows.find(x => x.ws === ws.id && x.cls);
        return w ? kind(w.cls) : ws.windows ? "" : "FREE";
    }
    function apps(ws: var): string {
        if (!ws)
            return "";
        const l = Feeds.windows.filter(x => x.ws === ws.id && x.cls).map(x => String(x.cls).split(".").pop().toUpperCase());
        return l.length ? l.join(" · ") : ws.home ? "KEPT CLEAR" : "NO WINDOWS";
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : presets
    }

    // ── Compact: the presets ────────────────────────────────────────
    Component {
        id: presets
        Unit {
            id: u
            foot: root.height >= 140 ? 40 : 26
            readonly property int padX: 4
            readonly property bool ann: rows >= 22
            readonly property bool sub: rows >= 30
            readonly property int size: Math.max(1, Math.min(4, Math.floor((rows - 3 - (ann ? 7 : 0) - (sub ? 7 : 0)) / 7)))

            // WS  P2  3 WIN  HOME ⌂
            Row {
                visible: u.ann
                x: u.padX
                y: 2
                spacing: 6
                MatrixText {
                    height: 5
                    font: "3x5"
                    text: "WS"
                    color: Ink.cyan
                }
                MatrixText {
                    height: 5
                    font: "3x5"
                    text: root.cur?.home ? "⌂" : "P" + (root.cur?.id ?? "-")
                    color: Ink.amber
                }
                MatrixText {
                    height: 5
                    font: "3x5"
                    text: (root.cur?.windows ?? 0) + " WIN"
                    color: Ink.cyan
                }
                MatrixText {
                    height: 5
                    font: "3x5"
                    text: "HOME ⌂"
                    color: root.cur?.home ? Ink.cyan : Ink.ghost
                }
            }
            // P2  WEB
            Digits {
                x: u.padX
                y: u.ann ? 9 + Math.max(0, Math.floor((u.rows - 9 - (u.sub ? 7 : 0) - height) / 2)) : Math.floor((u.rows - height) / 2)
                width: u.cols - u.padX * 2
                height: implicitHeight
                size: u.size
                ghosts: false
                text: (root.cur?.home ? "" : "P" + (root.cur?.id ?? "-") + " ") + root.nameOf(root.cur)
            }
            // FIREFOX · FIREFOX · TERM
            MatrixText {
                visible: u.sub
                x: u.padX
                y: u.rows - 7
                width: u.cols - u.padX * 2
                height: 5
                font: "3x5"
                scroll: true
                text: root.apps(root.cur)
                color: Ink.cyan
            }

            deck: Row {
                anchors.fill: parent
                spacing: 5
                Repeater {
                    model: root.list
                    Key {
                        required property var modelData
                        width: (parent.width - parent.spacing * (root.list.length - 1)) / Math.max(1, root.list.length)
                        height: parent.height
                        size: u.foot >= 40 ? 11 : 9
                        text: modelData.home ? "⌂" : modelData.id
                        led: modelData.focused ? Ink.cyan : modelData.windows > 0 ? Ink.teal : Ink.plateBottom
                        ledGlow: !!modelData.focused
                        action: "ws " + modelData.id
                    }
                }
            }
        }
    }

    // ── Expanded: the overview ──────────────────────────────────────
    Component {
        id: board
        Unit {
            id: u

            // { ws: [{ x, y, w, h, cls }] } in fractions of the monitor.
            property var geo: ({})
            readonly property var tiles: {
                const t = root.list.filter(w => w.home || w.focused || w.windows > 0).slice(0, 5);
                const next = root.list.find(w => !w.home && w.windows === 0 && !w.focused);
                return t.concat([{ id: next ? next.id : root.list.length + 1, next: true, windows: 0 }]);
            }
            readonly property int padX: 4
            readonly property int gap: 4
            readonly property int tileW: Math.floor((cols - padX * 2 - gap * 2) / 3)
            readonly property int rowsN: Math.ceil(tiles.length / 3)
            readonly property int cellH: Math.floor((rows - 4 - 10 - gap * (rowsN - 1)) / rowsN)
            readonly property int boxH: cellH - 9
            function tileX(i: int): int {
                return padX + i % 3 * (tileW + gap);
            }
            function tileY(i: int): int {
                return 4 + Math.floor(i / 3) * (cellH + gap);
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
                            u.geo = by;
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

            Repeater {
                model: u.tiles
                Item {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property color ink: modelData.focused ? Ink.amber : Ink.teal
                    x: u.tileX(index)
                    y: u.tileY(index)
                    width: u.tileW
                    height: u.cellH

                    // Empty: what it is kept for.
                    MatrixText {
                        visible: !!(tile.modelData.next || tile.modelData.home) && !(u.geo[tile.modelData.id]?.length)
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: Math.round((u.boxH - height) / 2)
                        width: implicitWidth
                        height: implicitHeight
                        font: "3x5"
                        text: tile.modelData.next ? "+ NEXT FREE" : "KEPT CLEAR"
                        color: Ink.deep
                    }
                    // Each window's name at its top left.
                    Repeater {
                        model: tile.modelData.next ? [] : (u.geo[tile.modelData.id] ?? [])
                        MatrixText {
                            required property var modelData
                            x: Math.round(2 + modelData.x * (u.tileW - 4)) + 2
                            y: Math.round(2 + modelData.y * (u.boxH - 4)) + 2
                            width: Math.max(0, Math.round(modelData.w * (u.tileW - 4)) - 4)
                            height: implicitHeight
                            visible: width >= 8 && modelData.h * (u.boxH - 4) >= 8
                            font: "3x5"
                            text: String(modelData.cls).split(".").pop()
                            color: Ink.cyan
                        }
                    }
                    // 2 WEB                  3 WIN
                    MatrixText {
                        y: u.boxH + 3
                        width: parent.width - count.implicitWidth - 3
                        height: implicitHeight
                        font: "3x5"
                        text: tile.modelData.next ? tile.modelData.id + " +" : tile.modelData.home ? "⌂ HOME" : tile.modelData.id + " " + root.nameOf(tile.modelData)
                        color: tile.ink
                    }
                    MatrixText {
                        id: count
                        anchors.right: parent.right
                        y: u.boxH + 3
                        width: implicitWidth
                        height: implicitHeight
                        font: "3x5"
                        text: tile.modelData.windows ? tile.modelData.windows + " WIN" : ""
                        color: tile.ink
                    }
                }
            }

            MatrixText {
                x: u.padX
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3
                width: u.cols - u.padX * 2
                height: implicitHeight
                font: "3x5"
                scroll: true
                text: "CLICK A PRESET TO GO THERE · HOME STAYS EMPTY"
                color: Ink.teal
            }

            // The tiles' rules and the windows, crisp: striped like a
            // window seen through the glass.
            over: Repeater {
                model: u.tiles
                Item {
                    id: box
                    required property var modelData
                    required property int index
                    x: u.px(u.tileX(index))
                    y: u.px(u.tileY(index))
                    width: u.px(u.tileW)
                    height: u.px(u.boxH)

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.width: box.modelData.focused ? 2 : 1
                        border.color: box.modelData.focused ? Ink.cyan : Ink.deep
                    }
                    Repeater {
                        model: box.modelData.next ? [] : (u.geo[box.modelData.id] ?? [])
                        Item {
                            id: win
                            required property var modelData
                            x: u.px(2 + modelData.x * (u.tileW - 4))
                            y: u.px(2 + modelData.y * (u.boxH - 4))
                            width: modelData.w * (u.tileW - 4) * u.pitch
                            height: modelData.h * (u.boxH - 4) * u.pitch
                            clip: true
                            Column {
                                spacing: 2
                                Repeater {
                                    model: Math.ceil(win.height / 4)
                                    Rectangle {
                                        width: win.width
                                        height: 2
                                        color: Qt.rgba(Ink.cyan.r, Ink.cyan.g, Ink.cyan.b, 0.35)
                                    }
                                }
                            }
                        }
                    }
                    T.Hit {
                        anchors.fill: parent
                        action: "ws " + box.modelData.id
                    }
                }
            }
        }
    }
}
