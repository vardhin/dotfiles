import QtQuick
import qs

// A row of flap tiles, the departure board's line: one character per
// tile, printed in square dots (5x7, or 3x5 with font: "3x5"), the hinge
// drawn across every tile over its letter. `spans` is the line as runs
// of [text, color] laid one after another (or set `text` and `color`);
// `cells` tiles show (0: as many as fit the width), blank ones too. A
// change spins the changed tiles through random letters and settles them
// left to right, like the real board. Longer than the row with `page`:
// it shows a row at a time, flipping on every few seconds.
// `lit` lists tiles drawn yellow (their letters go dark).
//   Flaps { width: 300; spans: [["CPU  ", Ink.dim], ["38%", Ink.yellow]] }
Item {
    id: flaps

    property string text: ""
    property color color: Ink.white
    property var spans: []
    property int cells: 0
    property string font: "5x7"
    property var lit: []
    property bool tiles: true
    property bool spin: true
    property bool page: false
    property int pageMs: 3600

    readonly property int pitch: Tokens.pitch
    readonly property int glyphW: font === "5x7" ? 5 : 3
    readonly property int glyphH: font === "5x7" ? 7 : 5
    // One tile, in dots.
    readonly property int cw: glyphW + 2
    readonly property int ch: glyphH + 2
    readonly property int fit: Math.max(0, Math.floor(width / (cw * pitch)))
    readonly property int count: cells > 0 ? cells : fit

    implicitWidth: count * cw * pitch
    implicitHeight: ch * pitch

    // The whole line and each character's ink.
    readonly property var runs: spans.length ? spans : [[text, color]]
    readonly property string full: runs.map(r => String(r[0] ?? "")).join("").toUpperCase()
    readonly property var inks: {
        const o = [];
        for (const r of runs)
            for (let i = 0; i < String(r[0] ?? "").length; i++)
                o.push(r[1] ?? color);
        return o;
    }
    // Paging through a line longer than the row.
    property int pageAt: 0
    readonly property int pages: page && count > 0 ? Math.max(1, Math.ceil(full.length / count)) : 1
    onPagesChanged: pageAt = 0
    Timer {
        interval: flaps.pageMs
        repeat: true
        running: flaps.pages > 1 && flaps.visible
        onTriggered: flaps.pageAt = (flaps.pageAt + 1) % flaps.pages
    }
    readonly property int from: pageAt * count
    readonly property string target: full.slice(from, from + count).padEnd(count, " ")

    // What the tiles show: the target, or letters still spinning to it.
    property string shown: ""
    property string was: ""
    property int frame: 0
    readonly property int flips: 5
    readonly property string glyphs: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    Component.onCompleted: {
        shown = target;
        was = target;
    }
    onTargetChanged: {
        if (!spin || !visible || was.length !== target.length) {
            spinner.stop();
            shown = target;
            was = target;
            return;
        }
        frame = 0;
        spinner.restart();
    }
    Timer {
        id: spinner
        interval: 34
        repeat: true
        onTriggered: {
            flaps.frame++;
            const t = flaps.target, w = flaps.was;
            let out = "", busy = false, k = 0;
            for (let i = 0; i < t.length; i++) {
                if (t[i] === w[i]) {
                    out += t[i];
                    continue;
                }
                const settled = flaps.frame >= flaps.flips + k++;
                if (!settled)
                    busy = true;
                out += settled ? t[i] : flaps.glyphs[Math.floor(Math.random() * flaps.glyphs.length)];
            }
            flaps.shown = out;
            if (!busy) {
                stop();
                flaps.shown = t;
                flaps.was = t;
            }
        }
    }

    // Same-ink runs of the shown row, for one MatrixText each.
    readonly property var parts: {
        const o = [];
        const s = shown;
        for (let i = 0; i < s.length; i++) {
            const ink = String(lit.includes(i) ? Ink.housing : (inks[from + i] ?? color));
            const last = o[o.length - 1];
            if (last && last.ink === ink)
                last.text += s[i];
            else
                o.push({ at: i, text: s[i], ink: ink });
        }
        return o.filter(p => p.text.trim() !== "");
    }

    Repeater {
        model: flaps.tiles ? flaps.count : 0
        Tile {
            required property int index
            x: index * flaps.cw * flaps.pitch + 1
            width: flaps.cw * flaps.pitch - 2
            height: flaps.ch * flaps.pitch
            lit: flaps.lit.includes(index)
        }
    }
    Dots {
        width: flaps.count * flaps.cw * flaps.pitch
        height: flaps.ch * flaps.pitch
        Repeater {
            model: flaps.parts
            MatrixText {
                required property var modelData
                x: 1 + modelData.at * flaps.cw
                y: 1
                width: implicitWidth
                height: flaps.glyphH
                font: flaps.font
                gap: flaps.cw - flaps.glyphW
                text: modelData.text
                color: modelData.ink
            }
        }
    }
    // The hinge, across every tile and its letter.
    Repeater {
        model: flaps.tiles ? flaps.count : 0
        Rectangle {
            required property int index
            x: index * flaps.cw * flaps.pitch + 1
            y: Math.floor(flaps.ch * flaps.pitch / 2) - (flaps.pitch >= 8 ? 1 : 0)
            width: flaps.cw * flaps.pitch - 2
            height: flaps.pitch >= 8 ? 2 : 1
            color: Ink.seam
            opacity: 0.85
        }
    }
}
