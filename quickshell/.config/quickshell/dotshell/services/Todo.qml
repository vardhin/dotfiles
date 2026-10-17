pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import "../Skins.js" as Skins
import "../Templates.js" as Templates

// The Todo panel's tasks: a todo.txt file, ~/Documents/todo.txt (the
// TODO_FILE environment variable overrides it). Edit it anywhere; it is
// re-read live.
//   x 2026-10-18 done task          (A) high priority          +list
//   due:2026-10-23
// Quick-add takes `+list due:fri !high`: weekday and `today` / `tomorrow`
// dues become dates, !high / !med / !low become (A) / (B) / (C).
Singleton {
    id: root

    readonly property string path: Quickshell.env("TODO_FILE") || Quickshell.env("HOME") + "/Documents/todo.txt"
    property var lines: []

    FileView {
        id: file
        path: root.path
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.lines = text().split("\n").filter(l => l.trim() !== "")
        onLoadFailed: root.lines = []
    }

    function save(list: var): void {
        lines = list;
        file.setText(list.join("\n") + (list.length ? "\n" : ""));
    }

    function iso(d: var): string {
        return Qt.formatDate(d, "yyyy-MM-dd");
    }

    function parse(line: string, n: int): var {
        let s = line.trim();
        const done = /^x\s/.test(s);
        if (done)
            s = s.replace(/^x\s+(\d{4}-\d{2}-\d{2}\s+)?/, "");
        let prio = "";
        const pm = s.match(/^\(([A-Z])\)\s+/);
        if (pm) {
            prio = pm[1];
            s = s.slice(pm[0].length);
        }
        s = s.replace(/^\d{4}-\d{2}-\d{2}\s+/, "");
        const lists = (s.match(/(^|\s)\+(\S+)/g) ?? []).map(x => x.trim().slice(1));
        const dm = s.match(/(^|\s)due:(\S+)/);
        const due = dm ? dm[2] : "";
        const text = s.replace(/(^|\s)(\+|@)\S+/g, "").replace(/(^|\s)due:\S+/g, "").replace(/\s+/g, " ").trim();
        return { n: n, line: line, done: done, prio: prio, lists: lists, due: due, text: text };
    }

    // "2026-10-23" -> "FRI", today -> "TODAY", past -> "LATE".
    function dueWord(due: string): string {
        if (!/^\d{4}-\d{2}-\d{2}$/.test(due))
            return due;
        const today = iso(new Date());
        if (due === today)
            return "today";
        if (due < today)
            return "late";
        const d = new Date(due + "T12:00:00");
        const days = Math.round((d - new Date(today + "T12:00:00")) / 86400000);
        return days < 7 ? Qt.formatDate(d, "ddd") : Qt.formatDate(d, "dd MMM");
    }

    readonly property var tasks: lines.map((l, i) => parse(l, i))

    readonly property var feed: {
        const words = Skins.words(Tokens.era, Templates.get("todo"));
        const today = iso(new Date());
        const rank = t => (t.done ? 1e6 : 0) + (t.prio ? t.prio.charCodeAt(0) - 65 : 30) * 100 + (t.due && /^\d{4}/.test(t.due) ? Math.min(99, Math.max(0, Math.round((new Date(t.due) - new Date(today)) / 86400000))) : 60);
        const sorted = [...tasks].sort((a, b) => rank(a) - rank(b));
        const open = sorted.filter(t => !t.done);
        const next = open[0] ?? null;
        const shape = t => ({
            n: t.n,
            text: t.text,
            done: t.done,
            due: t.due ? dueWord(t.due) : "",
            prio: t.prio ? (t.prio === "A" ? "!" : t.prio === "B" ? ":" : ".") : "",
            mark: t.done ? words.on : words.off,
            markSlot: t.done ? "dim" : t === next ? 2 : 0,
            textSlot: t.done ? "dim" : t === next ? 2 : 0,
            opacity: t.done ? 0.6 : 1
        });
        const counts = {};
        for (const t of open)
            for (const l of t.lists)
                counts[l] = (counts[l] ?? 0) + 1;
        const todayTasks = sorted.filter(t => !t.done || (t.done && /^x\s+\d{4}-\d{2}-\d{2}/.test(t.line) && t.line.slice(2, 12) === today));
        return {
            left: open.length,
            done: tasks.length - open.length,
            total: tasks.length,
            next: next?.text ?? "",
            today: todayTasks.slice(0, 12).map(shape),
            items: sorted.map(shape),
            lists: Object.keys(counts).map(k => ({ name: k, count: counts[k] }))
        };
    }

    // ── Changes ─────────────────────────────────────────────────────
    function nextWeekday(name: string): string {
        const names = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];
        const want = names.indexOf(name.slice(0, 3).toLowerCase());
        const d = new Date();
        if (name === "today")
            return iso(d);
        if (name === "tomorrow" || name === "tmr") {
            d.setDate(d.getDate() + 1);
            return iso(d);
        }
        if (want < 0)
            return name;
        let add = (want - d.getDay() + 7) % 7;
        if (add === 0)
            add = 7;
        d.setDate(d.getDate() + add);
        return iso(d);
    }

    function add(text: string): void {
        let s = text.trim();
        if (!s)
            return;
        let prio = "";
        s = s.replace(/(^|\s)!(high|hi|h|a|med|m|b|low|lo|l|c)\b/i, (m, sp, p) => {
            p = p.toLowerCase();
            prio = /^(high|hi|h|a)$/.test(p) ? "A" : /^(med|m|b)$/.test(p) ? "B" : "C";
            return "";
        });
        s = s.replace(/(^|\s)due:(\S+)/, (m, sp, d) => sp + "due:" + (/^\d{4}-\d{2}-\d{2}$/.test(d) ? d : nextWeekday(d)));
        s = s.replace(/\s+/g, " ").trim();
        save([...lines, (prio ? "(" + prio + ") " : "") + iso(new Date()) + " " + s]);
    }

    function toggle(n: int): void {
        const l = lines[n];
        if (l === undefined)
            return;
        const out = [...lines];
        out[n] = /^x\s/.test(l) ? l.replace(/^x\s+(\d{4}-\d{2}-\d{2}\s+)?/, "") : "x " + iso(new Date()) + " " + l.replace(/^\([A-Z]\)\s+/, "");
        save(out);
    }

    function remove(n: int): void {
        if (lines[n] === undefined)
            return;
        save(lines.filter((l, i) => i !== n));
    }
}
