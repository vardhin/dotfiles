import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services

// The switchboard (Super Tab): every workspace as a small LED screen, its
// windows captured (ScreencopyView of each toplevel, so hidden workspaces
// show too) and drawn through the board's own dots, dithered onto the era
// ramp. The workspace you are on is framed, the cursor is lit.
//
//   arrows / hjkl  move     Enter  go there      Shift Enter  take the window
//   1-9            go       click  go there      Escape       close
//
// Switching goes through WsFx, so it still dissolves.
Pane {
    id: pane

    name: "overview"

    readonly property int tileW: 64
    readonly property int tileH: 36
    readonly property int gap: 4
    readonly property int perRow: Math.max(1, Math.min(5, tiles.length, Math.floor((maxCols - 8 + gap) / (tileW + gap))))
    readonly property int count: tiles.length
    readonly property int rowCount: Math.ceil(count / perRow)
    cols: perRow * (tileW + gap) - gap + 8
    rows: rowCount * (tileH + gap + Tokens.lineDots) + Tokens.lineDots + 8

    surface.imageMode: true
    surface.dither: true

    // [{ id, name, windows: [{ x, y, w, h, address, cls }] }], plus one empty
    // "new" tile at the end.
    property var tiles: []
    property int cursor: 0
    readonly property int current: Hyprland.focusedWorkspace?.id ?? 1

    onOpened: {
        Hyprland.refreshToplevels();
        query.running = true;
    }

    function rebuild(clients: var, monitors: var): void {
        const mon = {};
        for (const m of monitors)
            mon[m.id] = m;
        const by = {};
        for (const c of clients) {
            const ws = c.workspace?.id ?? 0;
            if (ws <= 0)
                continue; // special workspaces stay off the board
            const m = mon[c.monitor] ?? monitors[0] ?? { x: 0, y: 0, width: 1920, height: 1080 };
            (by[ws] = by[ws] ?? { mon: m, windows: [] }).windows.push({
                x: (c.at[0] - m.x) / m.width,
                y: (c.at[1] - m.y) / m.height,
                w: c.size[0] / m.width,
                h: c.size[1] / m.height,
                address: String(c.address).replace(/^0x/, "").toLowerCase(),
                cls: c.class ?? ""
            });
        }
        if (!by[current])
            by[current] = { windows: [] };
        const ids = Object.keys(by).map(Number).sort((a, b) => a - b);
        const next = ids.length ? Math.max(...ids) + 1 : 1;
        tiles = ids.map(id => ({ id: id, name: String(id), windows: by[id].windows })).concat([{ id: next, name: "+", windows: [] }]);
        cursor = Math.max(0, ids.indexOf(current));
    }

    Process {
        id: query
        command: ["sh", "-c", "printf '{\"clients\":%s,\"monitors\":%s}' \"$(hyprctl -j clients)\" \"$(hyprctl -j monitors)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    pane.rebuild(d.clients ?? [], d.monitors ?? []);
                } catch (e) {
                    pane.rebuild([], []);
                }
            }
        }
    }

    // A captured toplevel for an address from `hyprctl -j clients`.
    function toplevel(address: string): var {
        for (const t of Hyprland.toplevels?.values ?? [])
            if (String(t.address).replace(/^0x/, "").toLowerCase() === address)
                return t.wayland ?? null;
        return null;
    }

    function go(i: int, take: bool): void {
        const t = tiles[i];
        if (!t)
            return;
        Ui.close();
        if (take)
            WsFx.move(String(t.id));
        else
            WsFx.go(String(t.id));
    }

    onKeyPressed: event => {
        const k = event.key;
        const n = count;
        if (k === Qt.Key_Right || k === Qt.Key_L || k === Qt.Key_Tab)
            cursor = (cursor + 1) % n;
        else if (k === Qt.Key_Left || k === Qt.Key_H || k === Qt.Key_Backtab)
            cursor = (cursor + n - 1) % n;
        else if (k === Qt.Key_Down || k === Qt.Key_J)
            cursor = Math.min(n - 1, cursor + perRow);
        else if (k === Qt.Key_Up || k === Qt.Key_K)
            cursor = Math.max(0, cursor - perRow);
        else if (k === Qt.Key_Return || k === Qt.Key_Enter)
            go(cursor, (event.modifiers & Qt.ShiftModifier) !== 0);
        else if (k >= Qt.Key_1 && k <= Qt.Key_9) {
            const i = tiles.findIndex(t => t.id === k - Qt.Key_0);
            if (i >= 0)
                go(i, false);
        } else
            return;
        event.accepted = true;
    }

    DotText {
        x: 4
        y: 4
        height: Tokens.lineDots
        text: "SWITCHBOARD"
        color: Tokens.slot1
    }
    DotText {
        anchors.right: parent.right
        anchors.rightMargin: 4
        y: 4
        height: Tokens.lineDots
        text: pane.tiles[pane.cursor] ? (pane.tiles[pane.cursor].name === "+" ? "NEW" : pane.tiles[pane.cursor].windows.length + " WIN") : ""
        color: Tokens.slot2
    }

    Grid {
        x: 4
        y: 4 + Tokens.lineDots
        columns: pane.perRow
        columnSpacing: pane.gap
        rowSpacing: pane.gap
        topPadding: 2

        Repeater {
            model: pane.shown ? pane.tiles : []

            Item {
                id: tile
                required property var modelData
                required property int index
                width: pane.tileW
                height: pane.tileH + Tokens.lineDots
                readonly property bool here: modelData.id === pane.current
                readonly property bool sel: index === pane.cursor

                // The screen: glass, each window a capture in its rect.
                Rectangle {
                    id: screen
                    width: pane.tileW
                    height: pane.tileH
                    color: Tokens.glass
                    clip: true

                    Repeater {
                        model: tile.modelData.windows

                        Item {
                            required property var modelData
                            x: Math.round(modelData.x * screen.width)
                            y: Math.round(modelData.y * screen.height)
                            width: Math.max(2, Math.round(modelData.w * screen.width))
                            height: Math.max(2, Math.round(modelData.h * screen.height))

                            Rectangle {
                                anchors.fill: parent
                                color: Tokens.unlit
                            }
                            ScreencopyView {
                                anchors.fill: parent
                                captureSource: pane.shown ? pane.toplevel(parent.modelData.address) : null
                                live: false
                                paintCursor: false
                            }
                        }
                    }

                    DotText {
                        visible: tile.modelData.name === "+"
                        anchors.centerIn: parent
                        height: Tokens.lineDots
                        text: "+"
                        color: Tokens.slot0
                    }
                }

                // The cursor is lit; the workspace you are on is framed dim.
                // Around the screen, in the gap, so a bright capture never hides it.
                Frame {
                    x: -2
                    y: -2
                    width: pane.tileW + 4
                    height: pane.tileH + 4
                    visible: tile.sel || tile.here
                    border.color: tile.sel ? Tokens.slot0 : Tokens.slot2
                }

                DotText {
                    y: pane.tileH
                    height: Tokens.lineDots
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: tile.modelData.name === "+" ? "NEW" : tile.modelData.name
                    color: tile.sel ? Tokens.slot0 : tile.here ? Tokens.slot2 : Tokens.slot1
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: pane.go(tile.index, false)
                    hoverEnabled: true
                    onEntered: pane.cursor = tile.index
                }
            }
        }
    }
}
