pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Desktop panels: small LED boards that live on the world layer (panes/World.qml)
// behind windows, one set per workspace. Persisted to
//   ${XDG_STATE_HOME:-~/.local/state}/dotshell/panels.json
// and driven from the `dot` CLI over services/DotBus.qml.
//
// A panel:
//   { id, kind, shape, x, y, w, h, workspace, slot, dot, source, text }
//   kind      clock | sign | note | image | mpris | pixels
//   shape     rect | circle | hex | diamond | strip | <svg path in a 0..100 box>
//   x y w h   grid units (Panels.unit px each), so a panel keeps its place and
//             size at any dot pitch; only its dots get finer or coarser
//   workspace Hyprland workspace id it sits on
//   slot      era color tube: 0 primary, 1 secondary, 2 accent
//   dot       false renders the panel raw (crisp image, art) clipped to its shape
//   source    image: a file path; mpris: a player name ("" = the first player)
//   text      sign / note text
// `pixels` panels show the last frame pushed with `dot pixels <id>`; frames are
// not persisted (they are live data).
Singleton {
    id: root

    // One grid unit in logical px. 12 is the coarsest pitch, so every pitch
    // divides a unit evenly except 5 and 8, which round to whole dots.
    readonly property int unit: 12
    readonly property var kinds: ["clock", "sign", "note", "image", "mpris", "pixels"]

    readonly property var panels: store.panels
    // id -> { w, h, data: base64 PPM (P6) } for pixels panels; not saved.
    property var frames: ({})

    FileView {
        id: file
        path: Tokens.dirReady ? Tokens.dir + "/panels.json" : ""
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: store
            property var panels: []
        }
    }

    function find(id: string): var {
        return store.panels.find(p => p.id === id) ?? null;
    }

    function freeId(kind: string): string {
        if (!find(kind))
            return kind;
        let n = 2;
        while (find(kind + n))
            n++;
        return kind + n;
    }

    function commit(list: var): void {
        store.panels = list;
    }

    function spawn(kind: string, opts: var): var {
        if (!kinds.includes(kind))
            return { error: "unknown kind; one of: " + kinds.join(", ") };
        opts = opts ?? {};
        const id = opts.id ? String(opts.id) : freeId(kind);
        if (!/^[A-Za-z0-9_-]+$/.test(id))
            return { error: "id must be letters, digits, - or _" };
        if (find(id))
            return { error: "a panel called " + id + " exists" };
        const p = {
            id: id,
            kind: kind,
            shape: opts.shape ?? "rect",
            x: Math.round(Number(opts.x ?? 4)),
            y: Math.round(Number(opts.y ?? 6)),
            w: Math.max(2, Math.round(Number(opts.w ?? 24))),
            h: Math.max(1, Math.round(Number(opts.h ?? 6))),
            workspace: Math.round(Number(opts.workspace ?? 1)),
            slot: Math.max(0, Math.min(2, Number(opts.slot ?? 0))),
            dot: opts.dot ?? true,
            source: String(opts.source ?? ""),
            text: String(opts.text ?? "")
        };
        commit([...store.panels, p]);
        return p;
    }

    function remove(id: string): var {
        if (!find(id))
            return { error: "no panel " + id };
        commit(store.panels.filter(p => p.id !== id));
        const f = Object.assign({}, frames);
        delete f[id];
        frames = f;
        return { ok: true };
    }

    // Change fields of one panel. Numbers are coerced; unknown keys refused.
    function set(id: string, fields: var): var {
        const old = find(id);
        if (!old)
            return { error: "no panel " + id };
        const allowed = ["kind", "shape", "x", "y", "w", "h", "workspace", "slot", "dot", "source", "text"];
        const p = Object.assign({}, old);
        for (const k in fields) {
            if (!allowed.includes(k))
                return { error: "unknown field " + k + "; one of: " + allowed.join(", ") };
            let v = fields[k];
            if (["x", "y", "w", "h", "workspace", "slot"].includes(k))
                v = Math.round(Number(v));
            else if (k === "dot")
                v = v === true || v === "true" || v === "on" || v === "1";
            else
                v = String(v);
            if (k === "kind" && !kinds.includes(v))
                return { error: "unknown kind" };
            p[k] = v;
        }
        p.w = Math.max(2, p.w);
        p.h = Math.max(1, p.h);
        p.slot = Math.max(0, Math.min(2, p.slot));
        commit(store.panels.map(q => q.id === id ? p : q));
        return p;
    }

    function move(id: string, x: int, y: int): var {
        return set(id, { x: x, y: y });
    }

    function pixels(id: string, w: int, h: int, data: string): var {
        const p = find(id);
        if (!p)
            return { error: "no panel " + id };
        if (p.kind !== "pixels")
            return { error: id + " is a " + p.kind + " panel, not pixels" };
        const f = Object.assign({}, frames);
        f[id] = { w: w, h: h, data: data };
        frames = f;
        return { ok: true };
    }
}
