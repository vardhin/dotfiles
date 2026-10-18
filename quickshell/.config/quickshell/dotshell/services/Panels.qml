pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import "../Templates.js" as Templates

// Desktop panels: one template (Templates.js) plus one feed (Feeds.qml) each,
// drawn by DeskPanel.qml. A panel lives in one of three places:
//   home    on the home workspace (Tokens.home), at x y in grid units;
//           compact, or expanded after a click
//   strip   docked in the top strip, in a zone (l left, c center, r before
//           the settings words, e after them) at an order
//   rail    docked in the side rail, at an order
// Panels never sit on any other workspace. Persisted to
//   ${XDG_STATE_HOME:-~/.local/state}/dotshell/panels.json
// and driven from the `dot` CLI over services/DotBus.qml.
//
// A panel:
//   { id, template, feed, layout, place, x, y, w, h, zone, order, slot, dot,
//     shape, source, text }
//   template  a name from Templates.js (nowplaying clock workspaces system
//             battery messages capture caffeine tray downloads files
//             clipboard todo screenshots dock tv, the popped vis and lyrics
//             boards, and the Phase 4 kinds: sign note image mpris media
//             pixels board)
//   feed      the feed it binds ("" = the template's own)
//   layout    a layout of its own ({ compact, expanded, strip, rail }), for
//             `board` panels a script made
//   shape     rect | circle | hex | diamond | strip | <svg path in 0..100>
//   slot      the panel's tube: 0 primary, 1 secondary, 2 accent
//   dot       false: images and art crisp, drawn content flat
//   source    image: a file path      text  sign / note text
Singleton {
    id: root

    // One grid unit in logical px; panels keep their size at any dot pitch.
    readonly property int unit: 12
    readonly property var kinds: Templates.names
    readonly property var places: ["home", "strip", "rail"]
    readonly property var zones: ["l", "c", "r", "e"]

    readonly property var panels: store.panels
    readonly property var pinned: store.pinned
    // id -> { w, h, data: base64 PPM (P6) } for pixels panels; not saved.
    property var frames: ({})

    // ── Runtime state (not saved) ───────────────────────────────────
    // The one expanded panel on home ("" = none).
    property string expanded: ""
    onExpandedChanged: if (expanded === "") typing = false
    // A panel's text field has the keyboard (the world layer takes it then).
    property bool typing: false
    // A panel being dragged: { id, from, x, y (screen px), target, zone,
    // order } — the strip and the rail draw their armed and hover slots from it.
    property var drag: null
    // The last dock or undock, for 3 s: { id, before, until }.
    property var undo: null
    // Where docked items sit on screen, published by the strip and the rail:
    // { id: { place, zone, order, x, y, w, h } } in screen px.
    property var slots: ({})

    readonly property var home: panels.filter(p => p.place === "home")
    readonly property var strip: panels.filter(p => p.place === "strip").sort((a, b) => zones.indexOf(a.zone) - zones.indexOf(b.zone) || a.order - b.order)
    readonly property var rail: panels.filter(p => p.place === "rail").sort((a, b) => a.order - b.order)
    function inStrip(zone: string): var {
        return strip.filter(p => p.zone === zone);
    }
    // A template docked in the strip? (The strip hides its own copy otherwise.)
    function docked(template: string): bool {
        return strip.some(p => p.template === template);
    }

    FileView {
        id: file
        path: Tokens.dirReady ? Tokens.dir + "/panels.json" : ""
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoaded: root.migrate()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                root.migrate();
        }

        JsonAdapter {
            id: store
            property var panels: []
            property var pinned: []
            property int version: 0
        }
    }

    // Phase 4 panels (kind, workspace) become templates on home; the first
    // time, the 16-panel set is added: the old strip items docked where they
    // were, System in the rail, the rest on home.
    function migrate(): void {
        if (store.version >= 3)
            return;
        // v3: Dot TV joins the set, on the free right half of home.
        if (store.version === 2) {
            if (!store.panels.some(p => p.template === "tv"))
                store.panels = [...store.panels, Object.assign(base("tv"), { id: freeId("tv"), x: 82, y: 6 })];
            store.version = 3;
            return;
        }
        const out = store.panels.map(p => {
            const q = Object.assign({}, p);
            if (!q.template)
                q.template = q.kind && Templates.get(q.kind) ? q.kind : "note";
            delete q.kind;
            delete q.workspace;
            q.place = q.place ?? "home";
            q.feed = q.feed ?? "";
            q.zone = q.zone ?? "";
            q.order = q.order ?? 0;
            return q;
        });
        store.panels = [...out, ...seed(out)];
        if (!store.pinned.length)
            store.pinned = ["firefox", "com.mitchellh.ghostty", "org.gnome.Nautilus", "code"].filter(id => DesktopEntries.byId(id));
        store.version = 3;
    }

    function seed(existing: var): var {
        const taken = existing.map(p => p.id);
        const id = t => {
            if (!taken.includes(t)) {
                taken.push(t);
                return t;
            }
            let n = 2;
            while (taken.includes(t + n))
                n++;
            taken.push(t + n);
            return t + n;
        };
        const mk = (t, f) => Object.assign(base(t), { id: id(t) }, f);
        return [
            mk("workspaces", { place: "strip", zone: "l", order: 0 }),
            mk("clock", { place: "strip", zone: "c", order: 0 }),
            mk("nowplaying", { place: "strip", zone: "r", order: 0 }),
            mk("capture", { place: "strip", zone: "r", order: 1 }),
            mk("messages", { place: "strip", zone: "r", order: 2 }),
            mk("caffeine", { place: "strip", zone: "r", order: 3 }),
            mk("battery", { place: "strip", zone: "e", order: 0 }),
            mk("tray", { place: "strip", zone: "e", order: 1 }),
            mk("system", { place: "rail", order: 0 }),
            mk("dock", { place: "home", x: 1, y: 6 }),
            mk("downloads", { place: "home", x: 8, y: 6 }),
            mk("files", { place: "home", x: 8, y: 20 }),
            mk("clipboard", { place: "home", x: 8, y: 36 }),
            mk("todo", { place: "home", x: 42, y: 6 }),
            mk("screenshots", { place: "home", x: 42, y: 25 }),
            mk("tv", { place: "home", x: 82, y: 6 })
        ];
    }

    function base(template: string): var {
        const t = Templates.get(template);
        return {
            id: "",
            template: template,
            feed: "",
            place: "home",
            shape: "rect",
            x: 4,
            y: 6,
            w: t?.size?.w ?? 24,
            h: t?.size?.h ?? 8,
            zone: "",
            order: 0,
            slot: 0,
            dot: true,
            source: "",
            text: ""
        };
    }

    function find(id: string): var {
        return store.panels.find(p => p.id === id) ?? null;
    }

    function freeId(name: string): string {
        if (!find(name))
            return name;
        let n = 2;
        while (find(name + n))
            n++;
        return name + n;
    }

    function commit(list: var): void {
        store.panels = list;
    }

    function spawn(template: string, opts: var): var {
        if (!Templates.get(template))
            return { error: "unknown template; one of: " + kinds.join(", ") };
        opts = opts ?? {};
        const id = opts.id ? String(opts.id) : freeId(template);
        if (!/^[A-Za-z0-9_-]+$/.test(id))
            return { error: "id must be letters, digits, - or _" };
        if (find(id))
            return { error: "a panel called " + id + " exists" };
        const p = Object.assign(base(template), { id: id });
        const r = apply(p, opts, true);
        if (r.error)
            return r;
        if (p.place !== "home" && opts.order === undefined)
            p.order = (p.place === "rail" ? rail : inStrip(p.zone)).length;
        commit([...store.panels, p]);
        return p;
    }

    // Copy the allowed fields of `fields` onto p, coerced. `loose` ignores
    // fields that are not panel fields (spawn passes the whole request).
    function apply(p: var, fields: var, loose: bool): var {
        const allowed = ["template", "kind", "feed", "layout", "place", "x", "y", "w", "h", "zone", "order", "shape", "slot", "dot", "source", "text"];
        for (const k in fields) {
            if (!allowed.includes(k)) {
                if (loose)
                    continue;
                return { error: "unknown field " + k + "; one of: " + allowed.join(", ") };
            }
            let v = fields[k];
            if (["x", "y", "w", "h", "slot", "order"].includes(k))
                v = Math.round(Number(v));
            else if (k === "dot")
                v = v === true || v === "true" || v === "on" || v === "1";
            else if (k === "layout") {
                if (typeof v === "string") {
                    try {
                        v = JSON.parse(v);
                    } catch (e) {
                        return { error: "layout is not JSON: " + e.message };
                    }
                }
                if (v && !v.compact && !v.strip && !v.rail && (v.row || v.col || v.field))
                    v = { compact: v };
            } else
                v = String(v);
            if (k === "kind" || k === "template") {
                if (!Templates.get(v))
                    return { error: "unknown template; one of: " + kinds.join(", ") };
                p.template = v;
                continue;
            }
            if (k === "place" && !places.includes(v))
                return { error: "place is one of: " + places.join(", ") };
            if (k === "zone" && v !== "" && !zones.includes(v))
                return { error: "zone is one of: " + zones.join(", ") };
            p[k] = v;
        }
        if (p.place === "strip" && !zones.includes(p.zone))
            p.zone = "r";
        p.w = Math.max(2, p.w);
        p.h = Math.max(1, p.h);
        p.slot = Math.max(0, Math.min(2, p.slot));
        return {};
    }

    function remove(id: string): var {
        if (!find(id))
            return { error: "no panel " + id };
        commit(store.panels.filter(p => p.id !== id));
        const f = Object.assign({}, frames);
        delete f[id];
        frames = f;
        if (expanded === id)
            expanded = "";
        return { ok: true };
    }

    function set(id: string, fields: var): var {
        const old = find(id);
        if (!old)
            return { error: "no panel " + id };
        const p = Object.assign({}, old);
        const r = apply(p, fields, false);
        if (r.error)
            return r;
        commit(store.panels.map(q => q.id === id ? p : q));
        return p;
    }

    function move(id: string, x: int, y: int): var {
        return set(id, { x: x, y: y });
    }

    // Dock, undock or reorder: place a panel at (place, zone, order); the
    // other items in that row shift to make room. Remembered for undo().
    function place(id: string, where: string, zone: string, order: int, x: int, y: int): var {
        const old = find(id);
        if (!old)
            return { error: "no panel " + id };
        if (!places.includes(where))
            return { error: "place is one of: " + places.join(", ") };
        const before = { place: old.place, zone: old.zone, order: old.order, x: old.x, y: old.y };
        const p = Object.assign({}, old, { place: where });
        if (where === "home") {
            p.x = x;
            p.y = y;
        } else {
            p.zone = where === "strip" ? (zones.includes(zone) ? zone : "r") : "";
            p.order = order;
        }
        // Renumber the row the panel lands in: everything at or after
        // `order` moves one along.
        const row = store.panels.filter(q => q.id !== id && q.place === where && (where !== "strip" || q.zone === p.zone)).sort((a, b) => a.order - b.order);
        const renum = {};
        if (where !== "home") {
            let n = 0;
            for (const q of row) {
                if (n === p.order)
                    n++;
                renum[q.id] = n++;
            }
            p.order = Math.min(p.order, row.length);
        }
        commit(store.panels.map(q => q.id === id ? p : renum[q.id] !== undefined ? Object.assign({}, q, { order: renum[q.id] }) : q));
        if (expanded === id)
            expanded = "";
        if (before.place !== where) {
            undo = { id: id, before: before, until: Date.now() + 3000 };
            undoTimer.restart();
        }
        return p;
    }

    function undoLast(): var {
        if (!undo || Date.now() > undo.until)
            return { error: "nothing to undo" };
        const u = undo;
        undo = null;
        const b = u.before;
        return place(u.id, b.place, b.zone, b.order, b.x, b.y);
    }
    Timer {
        id: undoTimer
        interval: 3000
        onTriggered: root.undo = null
    }

    // ── Expand and pop ──────────────────────────────────────────────
    function expand(id: string): void {
        expanded = expanded === id ? "" : id;
    }
    function fold(): void {
        expanded = "";
    }

    // Now playing's VIS and LYR boards: pop one out beside the panel it came
    // from; popping it again (or closing the board) folds it back in.
    function pop(fromId: string, template: string): void {
        const id = fromId + "-" + template;
        if (find(id)) {
            remove(id);
            return;
        }
        const from = find(fromId);
        const t = Templates.get(template);
        const at = from && from.place === "home" ? { x: from.x + from.w + 1, y: from.y } : { x: 30, y: 20 };
        spawn(template, { id: id, place: "home", x: at.x, y: at.y, w: t.size.w, h: t.size.h, slot: from?.slot ?? 0 });
    }

    // Lay the 15-panel set out again (keeps every other panel).
    function reset(): var {
        const keep = store.panels.filter(p => !Templates.homeSet.includes(p.template));
        commit([...keep, ...seed(keep)]);
        return { panels: store.panels.length };
    }

    function pin(id: string, on: bool): void {
        const p = store.pinned.filter(x => x !== id);
        store.pinned = on ? [...p, id] : p;
    }

    function pixels(id: string, w: int, h: int, data: string): var {
        const p = find(id);
        if (!p)
            return { error: "no panel " + id };
        if (p.template !== "pixels")
            return { error: id + " is a " + p.template + " panel, not pixels" };
        const f = Object.assign({}, frames);
        f[id] = { w: w, h: h, data: data };
        frames = f;
        return { ok: true };
    }
}
