import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs

// Package manager (Super I): pacman + yay (AUR).
//   Tab / Shift Tab   mode: SEARCH INSTALLED EXPLICIT ORPHANS UPDATES
//   type              search (repos + AUR) or filter the list
//   Up / Down, Enter  pick; Enter installs (SEARCH, UPDATES) or removes
//   Ctrl U            UPDATES: upgrade everything; ORPHANS: remove them all
// Anything that changes the system runs in a Ghostty window (dotshell.pkg):
// pacman wants sudo and shows its own prompts, and you should see them.
Pane {
    id: pane

    name: "packages"

    readonly property int slots: 10
    readonly property int inner: Math.min(64, Math.floor((maxCols - 8) / Tokens.charDots)) * Tokens.charDots
    cols: inner + 8
    rows: 4 + Tokens.lineDots * (slots + 4) + 9

    readonly property var modes: ["search", "installed", "explicit", "orphans", "updates"]
    property string mode: "installed"
    property string query: ""
    property var all: []            // [{ name, version, repo, desc, installed }]
    property var results: []
    property int selected: 0
    property int top: 0             // first visible row
    property bool busy: false

    readonly property int nameChars: 30
    readonly property int verChars: 24

    onOpened: {
        input.text = "";
        load();
        input.forceActiveFocus();
    }
    onModeChanged: {
        input.text = "";
        load();
    }
    onQueryChanged: {
        if (mode === "search")
            searchDelay.restart();
        else
            filter();
    }

    function pad(s: string, n: int): string {
        s = String(s ?? "");
        return s.length > n ? s.slice(0, n - 1) + "." : s + " ".repeat(n - s.length);
    }

    // ── Loading ─────────────────────────────────────────────────────
    function load(): void {
        all = [];
        results = [];
        selected = 0;
        top = 0;
        if (mode === "search") {
            if (query.trim().length >= 2)
                run(["yay", "-Ss", "--color", "never", "--topdown", ...query.trim().split(/\s+/)]);
            return;
        }
        const cmds = {
            installed: ["pacman", "-Q"],
            explicit: ["pacman", "-Qe"],
            orphans: ["pacman", "-Qdt"],
            // Repo updates (checkupdates uses a temp db, no root), then AUR.
            updates: ["sh", "-c", "checkupdates 2>/dev/null; yay -Qua --color never 2>/dev/null"]
        };
        run(cmds[mode]);
    }

    function run(cmd: var): void {
        proc.running = false;
        proc.command = cmd;
        busy = true;
        proc.running = true;
    }

    function parse(text: string): var {
        const lines = text.split("\n").filter(l => l !== "");
        const out = [];
        if (mode === "search") {
            for (let i = 0; i < lines.length; i++) {
                const m = lines[i].match(/^(\S+)\/(\S+) (\S+)(.*)$/);
                if (!m)
                    continue;
                const next = lines[i + 1] ?? "";
                const desc = next.startsWith(" ") ? next.trim() : "";
                out.push({ name: m[2], version: m[3], repo: m[1], desc: desc, installed: /\[Installed/.test(m[4]) });
            }
        } else if (mode === "updates") {
            for (const l of lines) {
                const m = l.match(/^(\S+) (\S+) -> (\S+)/);
                if (m)
                    out.push({ name: m[1], version: m[2] + " > " + m[3], repo: "", desc: "", installed: true });
            }
        } else {
            for (const l of lines) {
                const [n, v] = l.split(" ");
                out.push({ name: n, version: v ?? "", repo: "", desc: "", installed: true });
            }
        }
        return out;
    }

    function filter(): void {
        const q = query.trim().toLowerCase();
        results = mode === "search" || !q ? all : all.filter(p => p.name.toLowerCase().includes(q));
        selected = 0;
        top = 0;
    }

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                pane.all = pane.parse(text);
                pane.busy = false;
                pane.filter();
            }
        }
    }

    Timer {
        id: searchDelay
        interval: 450
        onTriggered: pane.load()
    }

    // ── Actions ─────────────────────────────────────────────────────
    function terminal(title: string, script: string): void {
        Ui.close();
        // The title goes in as $1, never into the script text. A notification says
        // how it ended, so the window can sit behind others while it runs.
        const end = "; s=$?; if [ $s -eq 0 ]; then notify-send --app-name packages --urgency low \"$1\" Done; else notify-send --app-name packages \"$1\" \"Failed (exit $s)\"; fi; echo; read -n1 -rsp 'Done. Press a key to close.'";
        Quickshell.execDetached(["ghostty", "--gtk-single-instance=false", "--class=dotshell.pkg", "--title=" + title, "-e", "bash", "-c", script + end, "dotshell-pkg", title]);
    }

    function act(i: int): void {
        const p = results[i];
        // Package names are [a-z0-9@._+-]; refuse anything else before it reaches a shell.
        if (!p || !/^[A-Za-z0-9@._+-]+$/.test(p.name))
            return;
        if (mode === "search" || mode === "updates")
            terminal("Install " + p.name, "yay -S --needed --noconfirm " + p.name);
        else
            terminal("Remove " + p.name, "yay -Rns " + p.name);
    }

    function bulk(): void {
        if (mode === "updates")
            terminal("System update", "yay -Syu");
        else if (mode === "orphans" && all.length > 0)
            terminal("Remove orphans", "yay -Rns $(pacman -Qdtq)");
    }

    function move(d: int): void {
        const n = results.length;
        if (!n)
            return;
        selected = Math.max(0, Math.min(n - 1, selected + d));
        if (selected < top)
            top = selected;
        else if (selected >= top + slots)
            top = selected - slots + 1;
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

            Row {
                height: parent.height
                spacing: 2

                Repeater {
                    model: pane.modes

                    DotButton {
                        required property string modelData
                        text: modelData.toUpperCase()
                        active: pane.mode === modelData
                        onClicked: pane.mode = modelData
                    }
                }
            }
            DotText {
                anchors.right: parent.right
                text: pane.busy ? "WORKING" : pane.results.length + (pane.results.length === pane.all.length ? "" : "/" + pane.all.length)
                color: Tokens.slot1
            }
        }

        DotText {
            height: Tokens.lineDots
            text: pane.pad("PACKAGE", pane.nameChars) + " " + pane.pad("VERSION", pane.verChars) + " REPO"
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
                readonly property int at: pane.top + index
                readonly property var pkg: pane.results[at] ?? null
                readonly property bool picked: at === pane.selected && pkg !== null
                width: pane.inner
                height: Tokens.lineDots

                Frame {
                    anchors.fill: parent
                    visible: row.picked
                }
                DotText {
                    x: 2
                    text: row.pkg ? pane.pad(row.pkg.name, pane.nameChars) : ""
                    color: Tokens.slot0
                }
                DotText {
                    x: 2 + (pane.nameChars + 1) * Tokens.charDots
                    text: row.pkg ? pane.pad(row.pkg.version, pane.verChars) : ""
                    color: Tokens.slot1
                }
                DotText {
                    x: 2 + (pane.nameChars + pane.verChars + 2) * Tokens.charDots
                    text: row.pkg ? (row.pkg.repo + (pane.mode === "search" && row.pkg.installed ? " *" : "")).toUpperCase() : ""
                    color: row.pkg?.repo === "aur" ? Tokens.slot2 : Tokens.slot1
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: row.pkg !== null
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: pane.selected = row.at
                    onClicked: pane.act(row.at)
                }
            }
        }

        Item {
            width: 1
            height: 2
        }
        Rule {}

        // Description of the picked package (search results carry one).
        DotText {
            width: parent.width
            height: Tokens.lineDots
            text: (pane.results[pane.selected]?.desc ?? "").toUpperCase()
            color: Tokens.slot1
            elide: Text.ElideRight
        }

        Item {
            width: parent.width
            height: Tokens.lineDots

            DotText {
                id: prompt
                text: pane.mode === "search" ? "FIND>" : "FILTER>"
                color: Tokens.slot2
            }
            DotInput {
                id: input
                x: prompt.width + Tokens.charDots
                width: parent.width - x - hint.width - Tokens.charDots
                onTextChanged: pane.query = text
                onAccepted: pane.act(pane.selected)

                Keys.onPressed: event => {
                    const ctrl = event.modifiers & Qt.ControlModifier;
                    const i = pane.modes.indexOf(pane.mode);
                    if (event.key === Qt.Key_Down) {
                        pane.move(1);
                    } else if (event.key === Qt.Key_Up) {
                        pane.move(-1);
                    } else if (event.key === Qt.Key_PageDown) {
                        pane.move(pane.slots);
                    } else if (event.key === Qt.Key_PageUp) {
                        pane.move(-pane.slots);
                    } else if (event.key === Qt.Key_Tab) {
                        pane.mode = pane.modes[(i + 1) % pane.modes.length];
                    } else if (event.key === Qt.Key_Backtab) {
                        pane.mode = pane.modes[(i + pane.modes.length - 1) % pane.modes.length];
                    } else if (ctrl && event.key === Qt.Key_U) {
                        pane.bulk();
                    } else {
                        return;
                    }
                    event.accepted = true;
                }
            }
            DotText {
                id: hint
                anchors.right: parent.right
                text: {
                    const verb = pane.mode === "search" || pane.mode === "updates" ? "INSTALL" : "REMOVE";
                    const bulk = pane.mode === "updates" ? "   CTRL U UPDATE ALL" : pane.mode === "orphans" ? "   CTRL U REMOVE ALL" : "";
                    return "ENTER " + verb + bulk + "   TAB MODE";
                }
                color: Tokens.slot1
                opacity: 0.5
            }
        }
    }
}
