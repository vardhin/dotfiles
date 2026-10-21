import QtQuick
import qs.services
import qs.tokyo as Tk
import qs.vfd as Vfd
import qs.aero as Aero
import qs.blueprint as Bp
import qs.vapor as Vw
import qs.flap as Fl
import qs.nixie as Nx
import qs.nineties as Ni
import qs.nightvision as Nv

// The workspaces docked in the strip or the rail, every era: one cell per
// workspace (the house for home), the one you are on marked the era's way,
// a dot per window under each, and + for an empty one. In dots, on the
// bar's canvas; 11 dots tall in the strip, `Tokens.railDots` wide in the
// rail. Cells touch, so every click lands on a workspace; a hold or a drag
// still lifts the item (DockItem.actions.grip).
//   DockWs { rail: false; ctx: feed; sink: dockItem.actions }
Item {
    id: root

    property bool rail: false
    property var ctx: ({})
    property var sink: null

    readonly property bool shown: true
    readonly property int railW: Tokens.railDots
    readonly property var list: ctx.list ?? []
    // The house: Material Design Icons' "home" (Apache 2.0) on a 7 x 7 dot
    // grid, as [x, y, run] spans.
    readonly property var house: {
        const rows = ["...#...", "..###..", ".#####.", "#######", ".#####.", ".##.##.", ".##.##."];
        const o = [];
        rows.forEach((r, y) => {
            let x = 0;
            while (x < r.length) {
                const end = r.indexOf(".", x) < 0 ? r.length : r.indexOf(".", x);
                if (end > x)
                    o.push([x, y, end - x]);
                x = end + 1;
            }
        });
        return o;
    }

    // How each era marks the one you are on, and its inks:
    //   on    the current number     idle  numbers with windows
    //   mark  the mark round it      pip   the window dots
    //   frame drawn round every cell (tile, tube, key), or none
    readonly property var look: ({
            tokyo: { kind: "neon", on: Tk.Ink.cyan, idle: Tk.Ink.violet, mark: Tk.Ink.cyan, pip: Tk.Ink.pink, alarm: Tk.Ink.red },
            vfd: { kind: "invert", on: Vfd.Ink.glass, idle: Vfd.Ink.cyan, mark: Vfd.Ink.amber, pip: Vfd.Ink.amber, alarm: Vfd.Ink.red },
            aero: { kind: "bubble", on: Aero.Ink.ice, idle: Aero.Ink.navy, mark: Aero.Ink.blue, pip: Aero.Ink.lime, alarm: Aero.Ink.red },
            blueprint: { kind: "corners", on: Bp.Ink.white, idle: Bp.Ink.line, mark: Bp.Ink.white, pip: Bp.Ink.line, alarm: Bp.Ink.warn },
            vapor: { kind: "key", on: Vw.Ink.pink, idle: Vw.Ink.ink, mark: Vw.Ink.shade, pip: Vw.Ink.pink, alarm: Vw.Ink.red, hi: Vw.Ink.hi },
            flap: { kind: "tile", on: Fl.Ink.yellow, idle: Fl.Ink.white, mark: Fl.Ink.card, pip: Fl.Ink.orange, alarm: Fl.Ink.red, seam: Fl.Ink.seam },
            nixie: { kind: "tube", on: Nx.Ink.digit, idle: Nx.Ink.amber, mark: Nx.Ink.tubeRim, pip: Nx.Ink.orange, alarm: Nx.Ink.red, ghost: Nx.Ink.ghost },
            nineties: { kind: "slant", on: Ni.Ink.yellow, idle: Ni.Ink.sky, mark: Ni.Ink.magenta, pip: Ni.Ink.pink, alarm: Ni.Ink.red, rim: Ni.Ink.pink },
            nightvision: { kind: "corners", on: Nv.Ink.bright, idle: Nv.Ink.lit, mark: Nv.Ink.bright, pip: Nv.Ink.dim, alarm: Nv.Ink.red }
        })
    readonly property var ink: look[Tokens.era] ?? { kind: "neon", on: Tokens.slot0, idle: Tokens.slot1, mark: Tokens.slot0, pip: Tokens.slot2, alarm: Tokens.slot2 }
    // Every cell has its frame in these; the others mark only the current one.
    readonly property bool framed: ["key", "tile", "tube"].includes(ink.kind)
    readonly property int slantBy: ink.kind === "slant" ? 2 : 0

    implicitWidth: rail ? railW : row.implicitWidth
    implicitHeight: rail ? col.implicitHeight : 11

    Row {
        id: row
        visible: !root.rail
        spacing: 1
        Repeater {
            model: root.rail ? [] : root.list
            Cell {
                required property var modelData
                ws: modelData
            }
        }
        Cell {
            ws: ({ id: "empty", add: true })
        }
    }
    Column {
        id: col
        visible: root.rail
        spacing: 1
        Repeater {
            model: root.rail ? root.list : []
            Cell {
                required property var modelData
                ws: modelData
            }
        }
        Cell {
            ws: ({ id: "empty", add: true })
        }
    }

    // One workspace: the frame or mark in rows 0..8, the number on rows
    // 1..7, its windows as dots on row 10.
    component Cell: Item {
        id: cell

        property var ws: ({})
        readonly property bool add: !!ws.add
        readonly property bool on: !!ws.focused
        readonly property int wins: Math.min(3, ws.windows ?? 0)
        readonly property bool used: on || wins > 0 || !!ws.home
        readonly property bool home: !add && !!ws.home
        readonly property int glyphW: home ? 7 : glyph.implicitWidth
        readonly property int boxW: Math.max(9, glyphW + 4) + root.slantBy
        readonly property int boxX: root.rail ? Math.floor((root.railW - boxW) / 2) : 0
        readonly property color glyphInk: add ? root.ink.idle : ws.urgent ? root.ink.alarm : on ? root.ink.on : root.ink.kind === "tube" && !used ? root.ink.ghost : root.ink.idle

        width: root.rail ? root.railW : boxW
        height: 11

        // ── The frame or the mark ──────────────────────────────────
        Item {
            x: cell.boxX
            width: cell.boxW
            height: 9
            opacity: cell.add ? 0.5 : 1

            // neon: a rounded tube round the current one.
            Repeater {
                model: root.ink.kind === "neon" && cell.on ? [[1, 0, cell.boxW - 2, 1], [1, 8, cell.boxW - 2, 1], [0, 1, 1, 7], [cell.boxW - 1, 1, 1, 7]] : []
                Rectangle {
                    required property var modelData
                    x: modelData[0]
                    y: modelData[1]
                    width: modelData[2]
                    height: modelData[3]
                    color: root.ink.mark
                }
            }
            // invert / bubble: the current one lit solid, its number cut out
            // (bubble rounds the corners).
            Rectangle {
                visible: (root.ink.kind === "invert" || root.ink.kind === "bubble") && cell.on
                y: root.ink.kind === "bubble" ? 1 : 0
                width: cell.boxW
                height: root.ink.kind === "bubble" ? 7 : 9
                color: root.ink.mark
            }
            Rectangle {
                visible: root.ink.kind === "bubble" && cell.on
                x: 1
                width: cell.boxW - 2
                height: 9
                color: root.ink.mark
            }
            // corners: brackets at the four corners of the current one.
            Repeater {
                model: root.ink.kind === "corners" && cell.on ? [[0, 0, 2, 1], [0, 0, 1, 2], [cell.boxW - 2, 0, 2, 1], [cell.boxW - 1, 0, 1, 2], [0, 8, 2, 1], [0, 7, 1, 2], [cell.boxW - 2, 8, 2, 1], [cell.boxW - 1, 7, 1, 2]] : []
                Rectangle {
                    required property var modelData
                    x: modelData[0]
                    y: modelData[1]
                    width: modelData[2]
                    height: modelData[3]
                    color: root.ink.mark
                }
            }
            // key: a Windows 95 push button each, the current one pushed in.
            Repeater {
                model: root.ink.kind === "key" ? [[0, 0, cell.boxW, 1, true], [0, 0, 1, 9, true], [0, 8, cell.boxW, 1, false], [cell.boxW - 1, 0, 1, 9, false]] : []
                Rectangle {
                    required property var modelData
                    x: modelData[0]
                    y: modelData[1]
                    width: modelData[2]
                    height: modelData[3]
                    color: modelData[4] !== cell.on ? root.ink.hi : root.ink.mark
                }
            }
            // tile: a flap card each, the split showing at its edges.
            Rectangle {
                visible: root.ink.kind === "tile"
                width: cell.boxW
                height: 9
                color: root.ink.mark
                Repeater {
                    model: [0, cell.boxW - 2]
                    Rectangle {
                        required property int modelData
                        x: modelData
                        y: 4
                        width: 2
                        height: 1
                        color: root.ink.seam
                    }
                }
            }
            // tube: a glass envelope each, domed at the top.
            Repeater {
                model: root.ink.kind === "tube" ? [[2, 0, cell.boxW - 4, 1], [1, 1, 1, 1], [cell.boxW - 2, 1, 1, 1], [0, 2, 1, 7], [cell.boxW - 1, 2, 1, 7], [1, 8, cell.boxW - 2, 1]] : []
                Rectangle {
                    required property var modelData
                    x: modelData[0]
                    y: modelData[1]
                    width: modelData[2]
                    height: modelData[3]
                    color: cell.on ? root.ink.on : root.ink.mark
                    opacity: cell.on ? 0.55 : 1
                }
            }
            // slant: the current one on a leaning sunset chip.
            Repeater {
                model: root.ink.kind === "slant" && cell.on ? 9 : 0
                Rectangle {
                    required property int index
                    x: Math.floor((8 - index) / 4)
                    y: index
                    width: cell.boxW - 2
                    height: 1
                    color: index === 0 || index === 8 ? root.ink.rim : root.ink.mark
                }
            }
        }

        MatrixText {
            id: glyph
            visible: !cell.home
            x: cell.boxX + Math.floor((cell.boxW - root.slantBy - implicitWidth) / 2) + (root.slantBy ? 1 : 0)
            y: 1
            width: implicitWidth
            height: 7
            text: cell.add ? "+" : cell.home ? "" : String(cell.ws.id)
            color: cell.glyphInk
            opacity: cell.add ? 0.5 : cell.used || root.ink.kind === "tube" ? 1 : 0.45
        }
        // Home: the house, 7 x 7 dots.
        Repeater {
            model: cell.home ? root.house : []
            Rectangle {
                required property var modelData
                x: cell.boxX + Math.floor((cell.boxW - root.slantBy - 7) / 2) + (root.slantBy ? 1 : 0) + modelData[0]
                y: 1 + modelData[1]
                width: modelData[2]
                height: 1
                color: cell.glyphInk
            }
        }

        // A dot per window (up to three).
        Row {
            x: cell.boxX + Math.floor((cell.boxW - width) / 2)
            y: 10
            spacing: 1
            Repeater {
                model: cell.add ? 0 : cell.wins
                Rectangle {
                    width: 1
                    height: 1
                    color: cell.on && (root.ink.kind === "invert" || root.ink.kind === "bubble") ? root.ink.mark : root.ink.pip
                }
            }
        }

        // The whole cell is the key: a click goes there, a hold or a drag
        // lifts the item.
        MouseArea {
            anchors.fill: parent
            anchors.rightMargin: root.rail ? 0 : -1
            anchors.bottomMargin: root.rail ? -1 : 0
            property bool dragged: false
            cursorShape: Qt.PointingHandCursor
            function grip(kind: string, m: var): bool {
                const p = mapToItem(null, m?.x ?? 0, m?.y ?? 0);
                return root.sink ? root.sink.grip(kind, p.x, p.y) : false;
            }
            onPressed: m => {
                dragged = false;
                grip("press", m);
            }
            onPositionChanged: m => {
                if (pressed)
                    grip("move", m);
            }
            onReleased: m => dragged = grip("release", m)
            onCanceled: grip("cancel", null)
            onClicked: {
                if (!dragged && root.sink)
                    root.sink.run("ws " + cell.ws.id);
            }
        }
    }
}
