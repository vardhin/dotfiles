import QtQuick
import qs

// Era switcher and display settings (Super T). Two pages, Tab switches.
//
// ERAS: every era is a card drawn in its own colors: its glass, its three
// tubes and its ramp. Arrows (or hjkl) move, Enter applies, 1-9 apply
// directly; the screen then flips over to the new era (the `cascade` token).
// DISPLAY: dot pitch, dot size, color depth, wallpaper mode, hue source and
// the cascade, the screen shader, window effects. Up/Down pick a row, Left/Right change it.
// Every choice is a token, so it persists and applies live.
//
// The pane is sized in dots, so it grows with the pitch. At coarse pitches it
// narrows to the screen (cards drop the blurb and ramp, settings show only the
// current value as < VALUE >) and both lists scroll with the cursor, so it
// always fits under the strip.
Pane {
    id: pane

    name: "eras"
    anchors {
        top: true
        right: true
    }

    // 40 characters, or the screen's width in dots at coarse pitches.
    readonly property int full: 40 * Tokens.charDots
    readonly property int inner: Math.min(full, Math.floor((screen?.width ?? 1600) / Tokens.pitch) - 10)
    readonly property bool wide: inner >= full
    cols: inner + 8
    rows: body.height + 8

    property string page: "eras"
    property int cursor: 0      // era card
    property int row: 0         // display setting

    // Dot rows free under the strip at this pitch.
    readonly property int avail: Math.floor(((screen?.height ?? 1000) - 40) / Tokens.pitch) - 2
    readonly property int step: Tokens.lineDots + 3

    readonly property int n: Eras.ids.length
    // Tabs, hint line, rule and padding; one card is 15 dots + 2 gap.
    readonly property int fixedRows: step * 2 + 12
    readonly property int shownCards: Math.max(1, Math.min(n, Math.floor((avail - fixedRows) / 17)))
    property int firstCard: 0
    onCursorChanged: {
        if (cursor < firstCard)
            firstCard = cursor;
        else if (cursor >= firstCard + shownCards)
            firstCard = cursor - shownCards + 1;
    }
    onShownCardsChanged: firstCard = Math.max(0, Math.min(Math.max(firstCard, cursor - shownCards + 1), n - shownCards))

    readonly property var settings: [
        { token: "pitch", label: "PITCH", options: [[3, "FINE"], [5, "MED"], [8, "COARSE"], [12, "CHUNKY"]] },
        { token: "dotSize", label: "DOT SIZE", options: [[60, "60"], [70, "70"], [80, "80"], [90, "90"], [100, "100"]] },
        { token: "depth", label: "DEPTH", options: [["era", "ERA"], ["8", "8 BIT"], ["16", "16"], ["24", "24"]] },
        { token: "wall", label: "WALL", options: [["dots", "DOTS"], ["image", "IMAGE"], ["off", "OFF"]] },
        { token: "hue", label: "HUE", options: [["era", "ERA"], ["wallpaper", "WALLPAPER"]] },
        { token: "cascade", label: "CASCADE", options: [["true", "FLIP"], ["false", "CUT"]] },
        { token: "screen", label: "SCREEN", options: [["glass", "GLASS"], ["led", "LED"], ["off", "OFF"]] },
        { token: "winfx", label: "WINDOWS", options: [["true", "DOTS"], ["false", "PLAIN"]] }
    ]
    // Settings rows that fit; the window follows `row`.
    readonly property int shownRows: Math.max(1, Math.min(settings.length, Math.floor((avail - fixedRows) / step)))
    property int first: 0
    onRowChanged: {
        if (row < first)
            first = row;
        else if (row >= first + shownRows)
            first = row - shownRows + 1;
    }
    onShownRowsChanged: first = Math.max(0, Math.min(first, settings.length - shownRows))

    function currentOf(token: string): string {
        const t = Tokens.snapshot();
        return String(t[token]);
    }

    function nudge(i: int, dir: int): void {
        const s = settings[i];
        const cur = s.options.findIndex(o => String(o[0]) === currentOf(s.token));
        const next = s.options[(Math.max(0, cur) + dir + s.options.length) % s.options.length];
        Tokens.set(s.token, String(next[0]));
    }

    function apply(i: int): void {
        cursor = i;
        Tokens.set("era", Eras.ids[i]);
    }

    onOpened: {
        page = "eras";
        cursor = Math.max(0, Eras.ids.indexOf(Tokens.era));
    }
    onKeyPressed: event => {
        const k = event.key;
        if (k === Qt.Key_Tab || k === Qt.Key_Backtab) {
            page = page === "eras" ? "display" : "eras";
        } else if (page === "eras") {
            if (k === Qt.Key_Down || k === Qt.Key_J)
                cursor = (cursor + 1) % n;
            else if (k === Qt.Key_Up || k === Qt.Key_K)
                cursor = (cursor + n - 1) % n;
            else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space)
                apply(cursor);
            else if (k >= Qt.Key_1 && k <= Qt.Key_9 && k - Qt.Key_1 < n)
                apply(k - Qt.Key_1);
            else
                return;
        } else {
            if (k === Qt.Key_Down || k === Qt.Key_J)
                row = (row + 1) % settings.length;
            else if (k === Qt.Key_Up || k === Qt.Key_K)
                row = (row + settings.length - 1) % settings.length;
            else if (k === Qt.Key_Right || k === Qt.Key_L || k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space)
                nudge(row, 1);
            else if (k === Qt.Key_Left || k === Qt.Key_H)
                nudge(row, -1);
            else
                return;
        }
        event.accepted = true;
    }

    // One era, previewed in its own colors.
    component EraCard: Item {
        id: card
        required property string eraId
        property int at: 0
        // As it would look applied: with the wallpaper hue when hue = wallpaper.
        readonly property var era: Tokens.effective(eraId, Tokens.hue, Tokens.wallHue)
        readonly property bool applied: Tokens.era === eraId
        readonly property bool focused: pane.cursor === at
        readonly property bool wide: pane.wide

        width: pane.inner
        height: Tokens.lineDots + 2

        // The applied era: a bar in the accent tube, left of the card.
        Rectangle {
            visible: card.applied
            width: 2
            height: parent.height
            color: Tokens.slot2
        }

        Rectangle {
            id: glass
            x: 4
            width: parent.width - 4
            height: parent.height
            color: card.era.glass

            DotText {
                x: 3
                y: 1
                width: card.wide ? 16 * Tokens.charDots : swatch.x - 5
                height: Tokens.lineDots
                text: (card.at + 1) + " " + card.era.name.toUpperCase()
                elide: Text.ElideRight
                color: card.era.slots[0]
            }
            DotText {
                visible: card.wide
                x: 3 + 17 * Tokens.charDots
                y: 1
                width: 16 * Tokens.charDots
                height: Tokens.lineDots
                text: card.era.blurb ?? ""
                color: card.era.slots[1]
            }

            // Tubes, then (wide cards) the ramp dark -> bright.
            Row {
                id: swatch
                anchors.right: parent.right
                anchors.rightMargin: 3
                y: 3
                spacing: 1

                Repeater {
                    model: card.era.slots
                    Rectangle {
                        required property string modelData
                        width: card.wide ? 4 : 2
                        height: 9
                        color: modelData
                    }
                }
                Item {
                    visible: card.wide
                    width: 2
                    height: 1
                }
                Repeater {
                    model: card.wide ? card.era.ramp : []
                    Rectangle {
                        required property string modelData
                        width: 2
                        height: 9
                        color: modelData
                    }
                }
            }
        }

        // Keyboard cursor: a lit frame in the current era's primary tube.
        Frame {
            visible: card.focused && pane.page === "eras"
            x: 3
            y: -1
            width: parent.width - 2
            height: parent.height + 2
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: pane.cursor = card.at
            onClicked: pane.apply(card.at)
        }
    }

    Column {
        id: body
        x: 4
        y: 4
        width: pane.inner
        spacing: 3

        // Page tabs, and where the hue comes from.
        Item {
            width: pane.inner
            height: Tokens.lineDots

            Row {
                spacing: 2
                DotButton {
                    text: "ERAS"
                    color: Tokens.slot2
                    active: pane.page === "eras"
                    onClicked: pane.page = "eras"
                }
                DotButton {
                    text: "DISPLAY"
                    color: Tokens.slot2
                    active: pane.page === "display"
                    onClicked: pane.page = "display"
                }
            }
            DotText {
                visible: pane.wide
                anchors.right: parent.right
                text: Tokens.hue !== "wallpaper" ? "" : Tokens.wallHue >= 0 ? "HUE: WALLPAPER" : "HUE: NO MATUGEN"
                color: Tokens.slot1
            }
        }

        // ── ERAS ────────────────────────────────────────────────────
        Column {
            visible: pane.page === "eras"
            spacing: 2
            topPadding: 1
            bottomPadding: 1

            Repeater {
                model: pane.page === "eras" ? Eras.ids.slice(pane.firstCard, pane.firstCard + pane.shownCards) : []

                EraCard {
                    required property string modelData
                    required property int index
                    eraId: modelData
                    at: pane.firstCard + index
                }
            }
        }

        // ── DISPLAY ─────────────────────────────────────────────────
        Repeater {
            model: pane.page === "display" ? pane.settings.slice(pane.first, pane.first + pane.shownRows) : []

            Line {
                id: line
                required property var modelData
                required property int index
                readonly property int at: pane.first + index
                label: (at === pane.row ? "> " : "  ") + modelData.label
                labelColor: at === pane.row ? Tokens.slot2 : Tokens.slot0

                // Wide: every option. Narrow: just the current one, < VALUE >.
                Repeater {
                    model: pane.wide ? line.modelData.options : []

                    DotButton {
                        required property var modelData
                        text: modelData[1]
                        active: pane.currentOf(line.modelData.token) === String(modelData[0])
                        onClicked: {
                            pane.row = line.at;
                            Tokens.set(line.modelData.token, String(modelData[0]));
                        }
                    }
                }
                DotButton {
                    visible: !pane.wide
                    active: true
                    text: "<" + (line.modelData.options.find(o => String(o[0]) === pane.currentOf(line.modelData.token))?.[1] ?? "?") + ">"
                    onClicked: {
                        pane.row = line.at;
                        pane.nudge(line.at, 1);
                    }
                }
            }
        }

        Rule {}

        DotText {
            width: pane.inner
            height: Tokens.lineDots
            elide: Text.ElideRight
            text: !pane.wide ? "TAB PAGE  ENTER" : pane.page === "eras" ? "TAB DISPLAY  ENTER APPLY  1-" + pane.n + " PICK" : "TAB ERAS  LEFT RIGHT CHANGE" + (pane.shownRows < pane.settings.length ? "  UP DOWN MORE" : "")
            color: Tokens.slot1
        }
    }
}
