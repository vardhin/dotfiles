import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs

// Departure-board launcher (Alt Space) on the bottom edge.
// Type to filter; Up/Down (or Ctrl J/K, Tab) to pick; Enter to board.
// Rows flap into place like a split-flap board when results change.
// Apps you launch often rise to the top: counts live in
// ${XDG_STATE_HOME:-~/.local/state}/dotshell/launcher.json.
Pane {
    id: pane

    name: "launcher"
    anchors {
        bottom: true
        left: true
        right: true
    }

    readonly property int slots: 8
    readonly property int inner: maxCols - 8
    cols: maxCols
    rows: 4 + Tokens.lineDots * (slots + 3) + 10

    property string query: ""
    property int selected: 0
    property var results: []

    // Column widths in characters.
    readonly property int gateChars: 4
    readonly property int classChars: 14
    readonly property int statusChars: 9
    readonly property int nameChars: Math.max(10, Math.floor(inner / Tokens.charDots) - gateChars - classChars - statusChars - 3)

    onOpened: {
        input.text = "";
        refresh();
        input.forceActiveFocus();
    }
    onQueryChanged: refresh()

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            if (pane.shown)
                pane.refresh();
        }
    }

    // ── Matching ────────────────────────────────────────────────────
    function score(entry: var, q: string): real {
        const name = (entry.name || "").toLowerCase();
        if (!q)
            return 1;
        let s = 0;
        if (name === q)
            s = 100;
        else if (name.startsWith(q))
            s = 80;
        else if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q)))
            s = 60;
        else if (name.includes(q))
            s = 40;
        else {
            const extra = [entry.genericName, ...(entry.keywords ?? []), entry.id, (entry.command ?? [])[0]].join(" ").toLowerCase();
            if (extra.includes(q))
                s = 25;
            else {
                // Subsequence: all letters in order.
                let i = 0;
                for (const c of name)
                    if (c === q[i])
                        i++;
                s = i === q.length ? 10 : 0;
            }
        }
        return s;
    }

    function refresh(): void {
        const q = query.trim().toLowerCase();
        const counts = usage.counts ?? {};
        const scored = [];
        for (const e of DesktopEntries.applications.values) {
            if (e.noDisplay)
                continue;
            const s = score(e, q);
            if (s > 0)
                scored.push({ e: e, s: s + Math.min(30, Math.log2(1 + (counts[e.id] ?? 0)) * 6) });
        }
        scored.sort((a, b) => b.s - a.s || a.e.name.localeCompare(b.e.name));
        results = scored.slice(0, slots).map(x => x.e);
        selected = 0;
    }

    function launch(i: int): void {
        const e = results[i];
        if (!e)
            return;
        const counts = Object.assign({}, usage.counts ?? {});
        counts[e.id] = (counts[e.id] ?? 0) + 1;
        usage.counts = counts;
        Ui.close();
        e.execute();
    }

    function pad(s: string, n: int): string {
        s = s.toUpperCase();
        return s.length > n ? s.slice(0, n - 1) + "." : s + " ".repeat(n - s.length);
    }

    function category(e: var): string {
        const known = ["Development", "Network", "Graphics", "AudioVideo", "Audio", "Video", "Office", "Game", "System", "Settings", "Utility", "Education", "Science"];
        const c = (e.categories ?? []).find(x => known.includes(x)) ?? (e.categories ?? [])[0] ?? "APP";
        return c === "AudioVideo" ? "MEDIA" : c === "Development" ? "DEV" : c;
    }

    FileView {
        path: Tokens.dirReady ? Tokens.dir + "/launcher.json" : ""
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: usage
            property var counts: ({})
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // ── Board ───────────────────────────────────────────────────────
    Column {
        x: 4
        y: 4
        width: pane.inner
        spacing: 0

        Item {
            width: parent.width
            height: Tokens.lineDots

            DotText {
                text: "DEPARTURES"
                color: Tokens.slot2
            }
            DotText {
                anchors.right: parent.right
                text: `${pane.results.length} SHOWN   ${Qt.formatDateTime(clock.date, "hh:mm")}`
                color: Tokens.slot1
            }
        }

        // Column heads.
        DotText {
            height: Tokens.lineDots
            text: pane.pad("GATE", pane.gateChars) + " " + pane.pad("DESTINATION", pane.nameChars) + " " + pane.pad("CLASS", pane.classChars) + " " + "STATUS"
            color: Tokens.slot1
            opacity: 0.5
        }

        Rule {}
        Item {
            width: 1
            height: 2
        }

        Repeater {
            model: pane.slots

            Item {
                id: row
                required property int index
                readonly property var entry: pane.results[index] ?? null
                readonly property bool picked: index === pane.selected && entry !== null
                width: pane.inner
                height: Tokens.lineDots

                Frame {
                    anchors.fill: parent
                    visible: row.picked
                }

                FlapText {
                    x: 0
                    target: row.entry ? pane.pad(" " + (row.index + 1), pane.gateChars) : ""
                    color: Tokens.slot2
                }
                FlapText {
                    x: (pane.gateChars + 1) * Tokens.charDots
                    target: row.entry ? pane.pad(row.entry.name, pane.nameChars) : ""
                    color: Tokens.slot0
                }
                FlapText {
                    x: (pane.gateChars + pane.nameChars + 2) * Tokens.charDots
                    target: row.entry ? pane.pad(pane.category(row.entry), pane.classChars) : ""
                    color: Tokens.slot1
                }
                DotText {
                    x: (pane.gateChars + pane.nameChars + pane.classChars + 3) * Tokens.charDots
                    text: row.entry ? (row.picked ? "BOARDING" : "ON TIME") : ""
                    color: Tokens.slot1
                    opacity: row.picked ? 1 : 0.5
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: row.entry !== null
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: pane.selected = row.index
                    onClicked: pane.launch(row.index)
                }
            }
        }

        Item {
            width: 1
            height: 2
        }
        Rule {}
        Item {
            width: 1
            height: 2
        }

        // ── Query ───────────────────────────────────────────────────
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
                onAccepted: pane.launch(pane.selected)

                Keys.onPressed: event => {
                    const ctrl = event.modifiers & Qt.ControlModifier;
                    const n = pane.results.length;
                    if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N))) {
                        if (n)
                            pane.selected = (pane.selected + 1) % n;
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P))) {
                        if (n)
                            pane.selected = (pane.selected + n - 1) % n;
                        event.accepted = true;
                    } else if (ctrl && event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                        pane.launch(event.key - Qt.Key_1);
                        event.accepted = true;
                    }
                }
            }
            DotText {
                id: hint
                anchors.right: parent.right
                text: "ENTER BOARD   CTRL 1-8 GATE   ESC CLOSE"
                color: Tokens.slot1
                opacity: 0.5
            }
        }
    }
}
