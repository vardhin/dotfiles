import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services

// CLIP (Super V): the clipboard history (services/Clip.qml), and on Tab the
// SYMBOLS page (Super Period): emoji, arrows, math and currency from
// data/symbols.tsv. Type to filter. Enter pastes into the window you came
// from, Ctrl Enter only copies; on CLIP, Ctrl D forgets the entry.
//
// Emoji are not dot art: their glyphs are drawn crisp in the overlay, over
// cells laid out in dots like everything else.
Pane {
    id: pane

    name: "clip"

    readonly property var pages: ["clip", "symbols"]
    readonly property string page: pages.includes(Ui.page) ? Ui.page : "clip"

    readonly property int inner: cols - 8
    readonly property int slots: 10
    // A screen-wide pane spills past the left edge; keep a margin.
    cols: Math.min(maxCols - 16, 90 * Tokens.charDots + 8)
    rows: 4 + Tokens.lineDots * (slots + 4) + 6

    property string query: ""
    property int selected: 0

    // ── CLIP ────────────────────────────────────────────────────────
    readonly property var clips: {
        const q = query.trim().toLowerCase();
        return Clip.items.filter(x => !q || x.t.toLowerCase().includes(q));
    }
    readonly property int textChars: Math.floor(inner / Tokens.charDots) - 4
    function oneLine(t: string): string {
        const s = t.replace(/\s*\n\s*/g, " | ").replace(/\t/g, " ").trim();
        return s.length > textChars ? s.slice(0, textChars - 1) + "." : s;
    }

    // ── SYMBOLS ─────────────────────────────────────────────────────
    property var symbols: []
    readonly property int cell: 15
    readonly property int gridCols: Math.floor(inner / cell)
    readonly property int gridRows: Math.floor((Tokens.lineDots * slots) / cell)
    readonly property var found: {
        const words = query.trim().toLowerCase().split(/\s+/).filter(w => w);
        return symbols.filter(s => words.every(w => s.n.includes(w)));
    }
    // First row shown, so the selection stays in view.
    property int top: 0
    onSelectedChanged: {
        if (page !== "symbols")
            return;
        const r = Math.floor(selected / gridCols);
        if (r < top)
            top = r;
        else if (r >= top + gridRows)
            top = r - gridRows + 1;
    }

    FileView {
        path: Quickshell.shellPath("data/symbols.tsv")
        onLoaded: pane.symbols = text().split("\n").filter(l => l).map(l => {
            const i = l.indexOf("\t");
            return { c: l.slice(0, i), n: l.slice(i + 1) };
        })
    }

    readonly property int count: page === "clip" ? clips.length : found.length

    function choose(i: int, paste: bool): void {
        if (page === "clip") {
            if (clips[i])
                Clip.use(clips[i].t, paste);
        } else if (found[i]) {
            Clip.use(found[i].c, paste);
        }
    }

    onOpened: {
        input.text = "";
        selected = 0;
        top = 0;
        input.forceActiveFocus();
    }
    onPageChanged: {
        input.text = "";
        selected = 0;
        top = 0;
    }
    onQueryChanged: {
        selected = 0;
        top = 0;
    }

    // ── Header ──────────────────────────────────────────────────────
    Item {
        x: 4
        y: 4
        width: pane.inner
        height: Tokens.lineDots

        Row {
            spacing: Tokens.charDots
            DotButton {
                text: "CLIP"
                active: pane.page === "clip"
                onClicked: Ui.page = "clip"
            }
            DotButton {
                text: "SYMBOLS"
                active: pane.page === "symbols"
                onClicked: Ui.page = "symbols"
            }
        }
        DotText {
            anchors.right: parent.right
            text: pane.page === "clip" ? `${pane.clips.length} OF ${Clip.items.length}` : `${pane.found.length} FOUND`
            color: Tokens.slot1
        }
    }

    Rule {
        x: 4
        y: 6 + Tokens.lineDots
        width: pane.inner
    }

    // ── CLIP rows ───────────────────────────────────────────────────
    Column {
        x: 4
        y: 9 + Tokens.lineDots
        width: pane.inner
        visible: pane.page === "clip"

        Repeater {
            model: pane.page === "clip" ? pane.slots : 0

            Item {
                id: row
                required property int index
                // Scrolls with the selection.
                readonly property int at: Math.max(0, pane.selected - pane.slots + 1) + index
                readonly property var entry: pane.clips[at] ?? null
                readonly property bool picked: at === pane.selected && entry !== null
                width: pane.inner
                height: Tokens.lineDots

                Frame {
                    anchors.fill: parent
                    visible: row.picked
                }
                DotText {
                    x: 2
                    text: row.entry ? String(row.at + 1).padStart(3, " ") : ""
                    color: Tokens.slot2
                }
                DotText {
                    x: 2 + 4 * Tokens.charDots
                    text: row.entry ? pane.oneLine(row.entry.t) : ""
                    color: row.picked ? Tokens.slot0 : Tokens.slot1
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: row.entry !== null
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: pane.selected = row.at
                    onClicked: pane.choose(row.at, true)
                }
            }
        }

        DotText {
            visible: Clip.items.length === 0
            height: Tokens.lineDots
            text: "NOTHING COPIED YET"
            color: Tokens.slot1
            opacity: 0.5
        }
    }

    // ── SYMBOLS grid (cells in dots; glyphs in the overlay) ────────
    Item {
        id: grid
        x: 4 + Math.floor((pane.inner - pane.gridCols * pane.cell) / 2)
        y: 9 + Tokens.lineDots
        width: pane.gridCols * pane.cell
        height: pane.gridRows * pane.cell
        visible: pane.page === "symbols"

        Frame {
            readonly property int r: Math.floor(pane.selected / pane.gridCols) - pane.top
            visible: pane.found.length > 0 && r >= 0 && r < pane.gridRows
            x: (pane.selected % pane.gridCols) * pane.cell
            y: r * pane.cell
            width: pane.cell
            height: pane.cell
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            function at(mx: real, my: real): int {
                return (pane.top + Math.floor(my / pane.cell)) * pane.gridCols + Math.floor(mx / pane.cell);
            }
            onPositionChanged: mouse => {
                const i = at(mouse.x, mouse.y);
                if (i < pane.found.length)
                    pane.selected = i;
            }
            onClicked: mouse => pane.choose(at(mouse.x, mouse.y), true)
            onWheel: wheel => {
                const last = Math.max(0, Math.ceil(pane.found.length / pane.gridCols) - pane.gridRows);
                pane.top = Math.max(0, Math.min(last, pane.top + (wheel.angleDelta.y > 0 ? -1 : 1)));
            }
        }
    }

    overlay: Item {
        id: glyphs
        readonly property point at: {
            void (pane.page, Tokens.pitch, grid.x, grid.y);
            return grid.mapToItem(pane.surface, 0, 0);
        }
        readonly property real px: pane.cell * Tokens.pitch
        x: at.x
        y: at.y
        width: grid.width * Tokens.pitch
        height: grid.height * Tokens.pitch
        visible: pane.shown && pane.page === "symbols"

        Repeater {
            model: pane.page === "symbols" ? pane.found.slice(pane.top * pane.gridCols, (pane.top + pane.gridRows) * pane.gridCols) : []

            Text {
                required property var modelData
                required property int index
                x: (index % pane.gridCols) * glyphs.px
                y: Math.floor(index / pane.gridCols) * glyphs.px
                width: glyphs.px
                height: glyphs.px
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: modelData.c
                color: Tokens.slot0
                font.family: "Noto Color Emoji, " + Tokens.font
                font.pixelSize: Math.round(glyphs.px * 0.62)
            }
        }
    }

    // ── Footer: the picked symbol's name, then the query ───────────
    Column {
        x: 4
        y: pane.rows - 4 - Tokens.lineDots * 2 - 3
        width: pane.inner
        spacing: 0

        DotText {
            width: parent.width
            height: Tokens.lineDots
            text: pane.page === "symbols" ? (pane.found[pane.selected]?.n ?? "").toUpperCase() : ""
            color: Tokens.slot1
            elide: Text.ElideRight
        }
        Rule {}
        Item {
            width: 1
            height: 2
        }
        Item {
            width: parent.width
            height: Tokens.lineDots

            DotText {
                id: prompt
                text: ">"
                color: Tokens.slot2
            }
            DotInput {
                id: input
                x: prompt.width + Tokens.charDots
                width: parent.width - x - hint.width - Tokens.charDots
                onTextChanged: pane.query = text
                onAccepted: pane.choose(pane.selected, true)

                Keys.onPressed: event => {
                    const ctrl = event.modifiers & Qt.ControlModifier;
                    const n = pane.count;
                    const step = pane.page === "symbols" ? pane.gridCols : 1;
                    const move = d => {
                        if (n)
                            pane.selected = Math.max(0, Math.min(n - 1, pane.selected + d));
                        event.accepted = true;
                    };
                    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                        Ui.page = pane.page === "clip" ? "symbols" : "clip";
                        event.accepted = true;
                    } else if (ctrl && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                        pane.choose(pane.selected, false);
                        event.accepted = true;
                    } else if (ctrl && event.key === Qt.Key_D && pane.page === "clip") {
                        if (pane.clips[pane.selected])
                            Clip.remove(pane.clips[pane.selected].t);
                        pane.selected = Math.min(pane.selected, Math.max(0, pane.clips.length - 1));
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Down || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N)))
                        move(step);
                    else if (event.key === Qt.Key_Up || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P)))
                        move(-step);
                    else if (pane.page === "symbols" && event.key === Qt.Key_Right && input.text.length === 0)
                        move(1);
                    else if (pane.page === "symbols" && event.key === Qt.Key_Left && input.text.length === 0)
                        move(-1);
                    else if (event.key === Qt.Key_PageDown)
                        move(step * pane.slots);
                    else if (event.key === Qt.Key_PageUp)
                        move(-step * pane.slots);
                }
            }
            DotText {
                id: hint
                anchors.right: parent.right
                text: pane.page === "clip" ? "ENTER PASTE  CTRL+ENTER COPY  CTRL+D DEL" : "ENTER PASTE  CTRL+ENTER COPY"
                color: Tokens.slot1
                opacity: 0.5
            }
        }
    }
}
