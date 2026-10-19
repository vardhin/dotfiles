import QtQuick
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import "../Hardware.js" as Hardware

// MEDIA (Super M, or the strip's now-playing word). Five pages, Tab switches.
//
// NOW: whatever plays on MPRIS (services/Media.qml): dithered art, title,
// artist, a seek bar, transport and a spectrum. Space plays or pauses,
// Left/Right seek 5 s, N/P next and previous, S switches player. With Dot TV
// playing, the video plays right here (TvScreen) over the art, with what is up
// next and M for Endless Mix.
// TV: the Dot TV library (services/Tv.qml, the `dottv` CLI), most played
// first, with the YouTube Music songs (♪) among the videos. Type to filter;
// Ctrl S searches YouTube for the text instead.
// Enter plays, Ctrl Q queues, Ctrl E plays next, Ctrl L adds to or drops from
// the target list, Ctrl D deletes (twice), Ctrl G saves a YouTube result
// without playing it. A YouTube result that is not saved streams and saves.
// ANIME: covers to browse and search, categories, likes, a watchlist and
// downloads, through ani-cli (panes/AnimePage.qml, services/Anime.qml).
// LISTS: playlists, then the YouTube Music stations (♪, read-only). Enter
// plays, Ctrl R shuffles, Ctrl T makes it the target for Ctrl L, Ctrl O makes
// a new list named after the text, Ctrl D drops it. SYNC (or Ctrl Y, here and
// on TV) runs `dottv sync`: new songs and stations from YouTube Music.
// SCREEN: how the video is drawn as dots (Tv.screen: pitch, dot size, shape,
// color mode, glow, dither), with a live preview. Up/Down pick, Left/Right
// change. The Dot TV window (O, Super Ctrl M) follows the same settings.
Pane {
    id: pane

    name: "media"
    skyGlass: true
    title: "now_playing.exe"
    icon: "♪"
    caption: "NOW PLAYING"
    captionStatus: !Media.active ? "OFF AIR" : Media.isPlaying ? "ON AIR" : "PAUSED"
    // One device: with a media panel on home, MEDIA opens out of it (Pane
    // `from`), wherever it sits, as the same hardware (the era's faceplate
    // and keys); with none, it hangs from the top right as before.
    readonly property var home: Panels.mediaHome()
    from: home && screen ? Panels.rectOf(home, screen.width, screen.height) : null
    // The eras whose device is built (VFD, Tokyo); the others keep the plain
    // pane. Full size, the device stands square (Hardware.big).
    hardware: Tokens.era === "vfd" ? Hardware.get("vfd") : Tokens.era === "tokyo" ? Hardware.big(Hardware.get("tokyo")) : null
    // On a device: its readout instead of the plain lines, its keys on the
    // faceplate instead of the buttons.
    readonly property bool hasDevice: !!hardware
    anchors {
        top: true
        left: grows
        right: !grows
    }
    margins {
        left: growX
        top: growY
    }
    keys: Loader {
        active: !!pane.hardware
        width: pane.surface.width
        height: pane.hardware?.keys.h ?? 0
        sourceComponent: DeviceKeys {
            hw: pane.hardware
            row: true
        }
    }

    readonly property int full: 46 * Tokens.charDots
    readonly property int inner: Math.min(full, Math.floor((screen?.width ?? 1600) / Tokens.pitch) - 10)
    readonly property bool wide: inner >= full
    readonly property int chars: Math.floor(inner / Tokens.charDots)
    cols: inner + 8
    // Always the full height under the strip, so no strip of desktop shows
    // below it; what the content does not fill stays as unlit dots.
    // Grown out of its panel: as tall as the page.
    rows: grows ? body.height + 8 : Math.max(body.height + 8, maxRows)

    // Dot rows free under the strip at this pitch.
    readonly property int avail: maxRows - 2
    // The video: 16:9, as wide as the pane unless that would not fit the
    // screen with the page's own rows; then smaller, centered. Shown on NOW
    // and TV while Dot TV plays, and always on SCREEN.
    // Rows each page needs besides the video (lines, rules, spacing, padding).
    readonly property int reserve: {
        const L = Tokens.lineDots;
        if (page === "now")
            return L * 9 + 20 + 30;     // tabs, 4 info, transport, 3 up next, spectrum
        if (page === "tv")
            return L * 7 + 30;          // tabs, query, 3 rows at least, mode, 2 hints
        return L * 12 + 30;             // tabs, 9 settings, 2 hints
    }
    readonly property int screenH: Math.max(0, Math.min(Math.round(inner * 9 / 16), avail - reserve))
    readonly property int screenW: Math.min(inner, Math.round(screenH * 16 / 9))
    readonly property bool tvShown: (page === "screen" || Media.isVideo && (page === "now" || page === "tv")) && screenH >= 18
    readonly property int slots: Math.max(3, Math.min(10, Math.floor((avail - 5 * Tokens.lineDots - 30 - (tvShown ? screenH + 3 : 0)) / Tokens.lineDots)))
    property int screenRow: 0
    // Rows the NOW page has under the tabs and the video, above the rule
    // and the two hint lines (body spacing 3, padding 4 + 4).
    readonly property int nowRoom: maxRows - 8 - (Tokens.lineDots + 3) - (tvShown ? screenH + 3 : 0) - (1 + 3) - 2 * (Tokens.lineDots + 3)
    // SCREEN's rows: how the video is drawn (Tv.screen), then how the note
    // bar hears the music (Notes.settings).
    readonly property var screenRows: Tv.screenOptions.map(o => Object.assign({ src: "tv" }, o)).concat(Notes.options.map(o => Object.assign({ src: "notes" }, o)))
    function valueOf(row: var): var {
        return row.src === "notes" ? Notes.settings[row.key] : Tv.screen[row.key];
    }
    function setRow(row: var, v: var): void {
        if (row.src === "notes")
            Notes.set(row.key, v);
        else
            Tv.setScreen(row.key, v);
    }
    function nudgeRow(row: var, dir: int): void {
        if (row.src === "notes")
            Notes.nudge(row.key, dir);
        else
            Tv.nudgeScreen(row.key, dir);
    }

    property string page: "now"
    readonly property var pages: ["now", "tv", "anime", "lists", "screen"]

    // ── TV page state ───────────────────────────────────────────────
    property string query: ""
    property int pick: 0
    property int first: 0
    property string target: ""
    property string confirm: ""
    // YouTube results stay up while the text is what was searched.
    readonly property bool online: Tv.searched !== "" && Tv.searched === query.trim()
    readonly property var rowsTv: {
        if (online)
            return Tv.results;
        const q = query.trim().toLowerCase();
        if (!q)
            return Tv.library;
        const words = q.split(/\s+/);
        return Tv.library.filter(e => {
            const hay = (e.title + " " + e.channel).toLowerCase();
            return words.every(w => hay.includes(w));
        });
    }

    // ── LISTS page state ────────────────────────────────────────────
    property string listQuery: ""
    property int listPick: 0
    readonly property var rowsLists: {
        const q = listQuery.trim().toLowerCase();
        return Tv.lists.concat(Tv.stations).filter(l => !q || l.name.toLowerCase().includes(q));
    }
    readonly property string targetName: Tv.lists.some(l => l.name === target) ? target : (Tv.lists[0]?.name ?? "")

    readonly property var listed: page === "lists" ? rowsLists : rowsTv
    readonly property int cursor: page === "lists" ? listPick : pick

    function move(by: int): void {
        const n = listed.length;
        if (!n)
            return;
        const at = (cursor + by + n) % n;
        if (page === "lists")
            listPick = at;
        else
            pick = at;
        if (at < first)
            first = at;
        else if (at >= first + slots)
            first = at - slots + 1;
        confirm = "";
    }

    function show(p: string): void {
        page = p;
        if (Ui.pane === "media")
            Ui.page = p;
        first = 0;
        confirm = "";
        nowBox.scroll = 0;
        Tv.watching = shown;
        if (p === "tv")
            tvInput.forceActiveFocus();
        else if (p === "anime" && !Anime.show)
            animePage.focusField();
        else if (p === "lists")
            listInput.forceActiveFocus();
        else
            pane.surface.forceActiveFocus();
    }

    onQueryChanged: {
        pick = 0;
        first = 0;
    }
    onListQueryChanged: {
        listPick = 0;
        first = 0;
    }
    // Opened on a page (Ui.openPage: the media panel's TV ANIME LISTS, the
    // launcher), or on the one it was left on.
    onOpened: {
        Tv.reload();
        show(pages.includes(Ui.page) ? Ui.page : page);
    }
    Connections {
        target: Ui
        function onPageChanged() {
            if (Ui.pane === "media" && pane.pages.includes(Ui.page))
                pane.show(Ui.page);
        }
    }
    onShownChanged: {
        Tv.watching = shown;
    }

    function pad(s: string, n: int): string {
        s = String(s ?? "").toUpperCase();
        return s.length > n ? s.slice(0, Math.max(0, n - 1)) + "." : s + " ".repeat(Math.max(0, n - s.length));
    }

    // Enter, and Ctrl+letter, on the TV and LISTS pages.
    function act(what: string): void {
        if (page === "tv") {
            const e = rowsTv[pick];
            if (!e)
                return;
            if (what === "play")
                Tv.play(e.id, "");
            else if (what === "queue")
                Tv.play(e.id, "queue");
            else if (what === "next")
                Tv.play(e.id, "next");
            else if (what === "save" && online)
                Tv.save(e.id);
            else if (what === "list" && targetName && !online)
                Tv.listToggle(targetName, e.id);
            else if (what === "delete" && !online) {
                if (confirm === e.id) {
                    Tv.remove(e.id);
                    confirm = "";
                } else {
                    confirm = e.id;
                }
            }
        } else if (page === "lists") {
            const l = rowsLists[listPick];
            if (what === "new") {
                const name = listQuery.trim();
                if (name && !Tv.lists.some(x => x.name.toLowerCase() === name.toLowerCase())) {
                    Tv.listNew(name);
                    target = name;
                    listInput.text = "";
                }
                return;
            }
            if (!l)
                return;
            if (what === "play" || what === "shuffle") {
                Tv.listPlay(l.id, what === "shuffle");
                show("now");
            } else if (l.station) {
                // Stations are YouTube Music's: a sync rewrites them.
                return;
            } else if (what === "target") {
                target = l.name;
            } else if (what === "delete") {
                if (confirm === l.id) {
                    Tv.listDrop(l.name);
                    confirm = "";
                } else {
                    confirm = l.id;
                }
            }
        }
    }

    onKeyPressed: event => {
        const k = event.key;
        const ctrl = event.modifiers & Qt.ControlModifier;
        if (k === Qt.Key_Tab || k === Qt.Key_Backtab) {
            const i = pages.indexOf(page);
            show(pages[(i + (k === Qt.Key_Tab ? 1 : pages.length - 1)) % pages.length]);
        } else if (page === "anime") {
            if (!animePage.key(event))
                return;
        } else if (page === "screen") {
            const n = screenRows.length;
            if (k === Qt.Key_Down || k === Qt.Key_J)
                screenRow = (screenRow + 1) % n;
            else if (k === Qt.Key_Up || k === Qt.Key_K)
                screenRow = (screenRow + n - 1) % n;
            else if (k === Qt.Key_Right || k === Qt.Key_L || k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space)
                nudgeRow(screenRows[screenRow], 1);
            else if (k === Qt.Key_Left || k === Qt.Key_H)
                nudgeRow(screenRows[screenRow], -1);
            else
                return;
        } else if (page === "now") {
            if (k === Qt.Key_Space || k === Qt.Key_Return || k === Qt.Key_Enter)
                Media.toggle();
            else if (k === Qt.Key_Left)
                Media.seek(-5);
            else if (k === Qt.Key_Right)
                Media.seek(5);
            else if (k === Qt.Key_N || k === Qt.Key_Down || k === Qt.Key_J)
                Media.next();
            else if (k === Qt.Key_P || k === Qt.Key_Up || k === Qt.Key_K)
                Media.previous();
            else if (k === Qt.Key_S)
                Media.cycle();
            else if (k === Qt.Key_M && Media.isTv)
                Tv.mix(!Tv.status.mix);
            else if (k === Qt.Key_O)
                Tv.open();
            else
                return;
        } else {
            if (k === Qt.Key_Down || ctrl && (k === Qt.Key_J || k === Qt.Key_N))
                move(1);
            else if (k === Qt.Key_Up || ctrl && (k === Qt.Key_K || k === Qt.Key_P))
                move(-1);
            else if (k === Qt.Key_PageDown)
                move(slots);
            else if (k === Qt.Key_PageUp)
                move(-slots);
            else if (ctrl && k === Qt.Key_S && page === "tv")
                Tv.search(query);
            else if (ctrl && k === Qt.Key_Q)
                act("queue");
            else if (ctrl && k === Qt.Key_E)
                act("next");
            else if (ctrl && k === Qt.Key_G)
                act("save");
            else if (ctrl && k === Qt.Key_L)
                act("list");
            else if (ctrl && k === Qt.Key_D)
                act("delete");
            else if (ctrl && k === Qt.Key_R)
                act("shuffle");
            else if (ctrl && k === Qt.Key_T)
                act("target");
            else if (ctrl && k === Qt.Key_O)
                act("new");
            else if (ctrl && k === Qt.Key_M)
                Tv.mix(!Tv.status.mix);
            else if (ctrl && k === Qt.Key_Y)
                Tv.sync();
            else
                return;
        }
        event.accepted = true;
    }

    // The video, laid over screenSlot in screen px.
    overlay: TvScreen {
        readonly property point at: {
            // Depend on what moves the slot.
            void (pane.page, pane.tvShown, screenSlot.y, Tokens.pitch);
            return screenSlot.mapToItem(pane.surface, 0, 0);
        }
        x: at.x + Math.floor((pane.inner - pane.screenW) / 2) * Tokens.pitch
        y: at.y
        width: pane.screenW * Tokens.pitch
        height: pane.screenH * Tokens.pitch
        visible: pane.shown && pane.tvShown
    }

    // dotshell ipc call mediapane open tv   (now | tv | anime | lists | screen)
    IpcHandler {
        target: "mediapane"

        function open(page: string): string {
            if (!pane.pages.includes(page))
                return "one of: " + pane.pages.join(", ");
            if (pane.shown)
                pane.show(page);
            else {
                pane.page = page;
                Ui.open("media", null);
            }
            return page;
        }
    }

    Column {
        id: body
        x: 4
        y: 4
        width: pane.inner
        spacing: 3

        // ── Tabs, and which player ──────────────────────────────────
        Item {
            width: pane.inner
            height: Tokens.lineDots

            Row {
                spacing: 2
                Repeater {
                    model: [["now", "NOW"], ["tv", "TV"], ["anime", "ANIME"], ["lists", "LISTS"], ["screen", "SCREEN"]]
                    DotButton {
                        required property var modelData
                        text: modelData[1]
                        color: Tokens.slot2
                        active: pane.page === modelData[0]
                        onClicked: pane.show(modelData[0])
                    }
                }
            }
            // Where the media panel lives: the top strip, the side rail or
            // the desktop, one click each (the lit one is where it is).
            Row {
                id: places
                readonly property var panel: Panels.media()
                anchors.right: parent.right
                anchors.rightMargin: player.visible ? player.width + 6 : 0
                y: 3
                spacing: 3
                visible: !!panel && pane.page === "now"
                Repeater {
                    model: ["strip", "rail", "home"]
                    Item {
                        id: spot
                        required property string modelData
                        readonly property bool here: places.panel?.place === modelData
                        readonly property color ink: here ? Tokens.slot0 : hit.containsMouse ? Tokens.slot1 : Tokens.slot2
                        width: 11
                        height: 7
                        // A tiny screen: its frame, and the part the panel
                        // would be in lit.
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.width: 1
                            border.color: spot.ink
                            opacity: spot.here ? 1 : 0.6
                        }
                        Rectangle {
                            x: spot.modelData === "rail" ? 8 : spot.modelData === "home" ? 3 : 0
                            y: spot.modelData === "home" ? 2 : 0
                            width: spot.modelData === "rail" ? 3 : spot.modelData === "home" ? 5 : 11
                            height: spot.modelData === "strip" ? 2 : spot.modelData === "home" ? 3 : 7
                            color: spot.ink
                        }
                        MouseArea {
                            id: hit
                            anchors.fill: parent
                            anchors.margins: -2
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Panels.send(places.panel.id, spot.modelData)
                        }
                    }
                }
            }
            DotButton {
                id: player
                anchors.right: parent.right
                visible: pane.page === "now" && Media.players.length > 0
                text: Media.name.slice(0, pane.wide ? 16 : 6) + (Media.players.length > 1 ? " " + (Media.players.indexOf(Media.player) + 1) + "/" + Media.players.length : "")
                color: Tokens.slot1
                onClicked: Media.cycle()
            }
            Row {
                anchors.right: parent.right
                visible: pane.page === "tv" || pane.page === "lists"
                spacing: 2 * Tokens.charDots

                DotText {
                    text: pane.page === "tv" ? (Tv.searching ? "SEARCHING" : pane.online ? "YOUTUBE" : Tv.library.length + " SAVED") : Tv.lists.length + " LISTS" + (Tv.stations.length && pane.wide ? " " + Tv.stations.length + " ♪" : "")
                    color: Tokens.slot1
                }
                // YouTube Music: new songs and stations.
                DotButton {
                    visible: Tv.status.sync?.available ?? false
                    text: Tv.syncing ? "SYNCING" : "SYNC"
                    color: Tokens.slot2
                    active: Tv.syncing
                    onClicked: Tv.sync()
                }
            }
        }

        // Where the video goes; TvScreen in the overlay is laid over it.
        Item {
            id: screenSlot
            visible: pane.tvShown
            width: pane.inner
            height: pane.screenH
        }

        // ── ANIME ───────────────────────────────────────────────────
        // The full height: tabs, then this, then the rule and two hint lines.
        AnimePage {
            id: animePage
            visible: pane.page === "anime"
            active: pane.shown && pane.page === "anime"
            inner: pane.inner
            surface: pane.surface
            height: pane.avail - 4 * Tokens.lineDots - 6
            onSummon: {
                if (pane.shown)
                    pane.show("anime");
                else {
                    pane.page = "anime";
                    Ui.open("media", null);
                }
            }
        }

        // ── NOW ─────────────────────────────────────────────────────
        // Taller than what is left under the video: it scrolls (the wheel,
        // a line a notch), so up next and the lyrics are always in reach.
        Item {
            id: nowBox
            visible: pane.page === "now"
            width: pane.inner
            height: Math.min(nowCol.height, Math.max(Tokens.lineDots * 4, pane.nowRoom))
            clip: true
            readonly property int maxScroll: Math.max(0, nowCol.height - height)
            property real scroll: 0
            onMaxScrollChanged: scroll = Math.min(scroll, maxScroll)

            // Under the page, so the lyrics sheet takes the wheel first.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: wheel => {
                    const notches = wheel.angleDelta.y / 120;
                    nowBox.scroll = Math.max(0, Math.min(nowBox.maxScroll, nowBox.scroll - notches * Tokens.lineDots));
                    wheel.accepted = nowBox.maxScroll > 0;
                }
            }

            Column {
                id: nowCol
                y: -Math.round(nowBox.scroll)
                width: pane.inner
                spacing: 3


                    Item {
                        id: now
                        readonly property int art: Media.isVideo ? 0 : Tokens.lineDots * 4
                        width: pane.inner
                        height: Media.isVideo ? Tokens.lineDots * 4 : art

                        // Unlit until the art loads; a frame marks where it goes.
                        Frame {
                            width: now.art
                            height: now.art
                            visible: now.art > 0 && !artPic.ready
                            border.color: Tokens.slot1
                            opacity: 0.5
                        }
                        PlainArt {
                            id: artPic
                            visible: now.art > 0
                            width: now.art
                            height: now.art
                            source: Media.art
                        }

                        // The era's own readout: the mini panel's display, here at
                        // the top of the device it grew into.
                        VfdReadout {
                            visible: pane.hasDevice && Tokens.era === "vfd"
                            full: true
                            x: now.art > 0 ? now.art + 6 : 0
                            width: pane.inner - x
                            height: now.height
                        }

                        MediaReadout {
                            visible: pane.hasDevice && Tokens.era !== "vfd"
                            hw: pane.hardware ?? Hardware.get("vfd")
                            full: true
                            x: now.art > 0 ? now.art + 6 : 0
                            width: pane.inner - x
                            height: now.height
                        }

                        Column {
                            visible: !pane.hasDevice
                            x: now.art > 0 ? now.art + 6 : 0
                            width: pane.inner - x

                            Scroller {
                                width: parent.width
                                height: Tokens.lineDots
                                text: (Media.title || (Media.active ? "NOTHING PLAYING" : "NO PLAYER")).toUpperCase()
                            }
                            DotText {
                                width: parent.width
                                height: Tokens.lineDots
                                elide: Text.ElideRight
                                text: Media.artist.toUpperCase()
                                color: Tokens.slot1
                            }
                            DotText {
                                width: parent.width
                                height: Tokens.lineDots
                                elide: Text.ElideRight
                                text: Media.album.toUpperCase()
                                color: Tokens.slot1
                                opacity: 0.5
                            }

                            // Seek bar: click or drag along it.
                            Item {
                                width: parent.width
                                height: Tokens.lineDots

                                Rectangle {
                                    y: 5
                                    width: parent.width
                                    height: 2
                                    color: Tokens.slot1
                                    opacity: 0.5
                                }
                                Rectangle {
                                    y: 5
                                    width: Math.round(parent.width * Media.progress)
                                    height: 2
                                    color: Tokens.slot0
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: Media.player?.canSeek ?? false
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: mouse => Media.seekTo(mouse.x / width)
                                    onPositionChanged: mouse => {
                                        if (pressed)
                                            Media.seekTo(mouse.x / width);
                                    }
                                }
                            }
                        }
                    }

                    // The music, two ways (duolightbars' two bars): the spectrum,
                    // and the notes on a keyboard.
                    Spectrum {
                        width: pane.inner
                        height: 24
                        bars: pane.wide ? 48 : 24
                        visible: pane.shown && pane.page === "now"
                    }
                    NoteBar {
                        width: pane.inner
                        height: 22
                        labels: true
                        visible: pane.shown && pane.page === "now"
                    }

                    // Unsynced lyrics: the whole sheet, under the music (synced ones
                    // sing in the readout, under the title).
                    LyricsView {
                        width: pane.inner
                        height: Tokens.lineDots * 5
                        visible: pane.page === "now" && (Lyrics.has && !Lyrics.synced || Lyrics.status === "looking" || !pane.hasDevice && Lyrics.has)
                    }

                    // Transport and time (with a readout: the keys are on the
                    // faceplate, the time in the readout; MIX and SCREEN stay).
                    Item {
                        visible: !pane.hasDevice || Media.isTv || Media.isVideo
                        width: pane.inner
                        height: Tokens.lineDots

                        Row {
                            spacing: 3
                            DotButton {
                                visible: !pane.hasDevice
                                text: ""
                                enabled: Media.player?.canGoPrevious ?? false
                                onClicked: Media.previous()
                            }
                            DotButton {
                                visible: !pane.hasDevice
                                text: Media.isPlaying ? " PAUSE" : " PLAY"
                                color: Tokens.slot2
                                enabled: Media.player?.canTogglePlaying ?? false
                                onClicked: Media.toggle()
                            }
                            DotButton {
                                visible: !pane.hasDevice
                                text: ""
                                enabled: Media.player?.canGoNext ?? false
                                onClicked: Media.next()
                            }
                            Item {
                                visible: !pane.hasDevice
                                width: 4
                                height: 1
                            }
                            DotButton {
                                visible: Media.isTv
                                text: "MIX"
                                active: Tv.status.mix
                                onClicked: Tv.mix(!Tv.status.mix)
                            }
                            DotButton {
                                visible: Media.isVideo
                                text: "SCREEN"
                                onClicked: pane.show("screen")
                            }
                        }
                        DotText {
                            anchors.right: parent.right
                            visible: Media.length > 0 && !pane.hasDevice
                            text: Media.clock(Media.position) + " / " + Media.clock(Media.length)
                            color: Tokens.slot1
                        }
                    }

                    // Dot TV's queue.
                    Repeater {
                        model: Media.isTv ? Tv.status.queue.slice(0, 10) : []

                        DotText {
                            required property var modelData
                            required property int index
                            width: pane.inner
                            height: Tokens.lineDots
                            elide: Text.ElideRight
                            text: (index === 0 ? "NEXT  " : "      ") + modelData.title.toUpperCase()
                            color: index === 0 ? Tokens.slot0 : Tokens.slot1
                        }
                    }
            }

            // More below / above: a dot at the edge.
            Rectangle {
                visible: nowBox.scroll < nowBox.maxScroll
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                width: 3
                height: 1
                color: Tokens.slot2
            }
        }

        // ── TV and LISTS: query line ────────────────────────────────
        Item {
            visible: pane.page === "tv" || pane.page === "lists"
            width: pane.inner
            height: Tokens.lineDots

            DotText {
                id: prompt
                text: pane.page === "tv" && pane.online ? "?" : ">"
                color: Tokens.slot2
            }
            DotInput {
                id: tvInput
                visible: pane.page === "tv"
                x: prompt.width + Tokens.charDots
                width: parent.width - x
                onTextChanged: pane.query = text
                onAccepted: pane.act("play")
            }
            DotInput {
                id: listInput
                visible: pane.page === "lists"
                x: prompt.width + Tokens.charDots
                width: parent.width - x
                onTextChanged: pane.listQuery = text
                onAccepted: pane.act("play")
            }
        }

        // ── TV rows ─────────────────────────────────────────────────
        Column {
            visible: pane.page === "tv"
            width: pane.inner

            Repeater {
                model: pane.page === "tv" ? pane.slots : 0

                Item {
                    id: tvRow
                    required property int index
                    readonly property int at: pane.first + index
                    readonly property var e: pane.rowsTv[at] ?? null
                    readonly property string mark: e?.audio ? "♪ " : ""
                    readonly property bool picked: at === pane.pick && e !== null
                    readonly property int titleChars: pane.chars - 6 - 7 - 2
                    width: pane.inner
                    height: Tokens.lineDots

                    Frame {
                        anchors.fill: parent
                        visible: tvRow.picked
                    }
                    DotText {
                        x: 1
                        text: !tvRow.e ? "" : pane.online ? (tvRow.e.saved ? "  SAVED" : "") : pane.confirm === tvRow.e.id ? "DEL?" : (tvRow.e.plays + "X").padStart(4) + (Tv.inList(pane.targetName, tvRow.e.id) ? "*" : " ")
                        color: pane.confirm === tvRow.e?.id ? Tokens.slot2 : Tokens.slot1
                        visible: !pane.online
                    }
                    DotText {
                        x: pane.online ? 1 : 6 * Tokens.charDots
                        width: (pane.online ? pane.chars - 8 : tvRow.titleChars) * Tokens.charDots
                        elide: Text.ElideRight
                        text: tvRow.e ? (pane.online && tvRow.e.saved ? "* " : tvRow.mark) + tvRow.e.title.toUpperCase() : ""
                        color: Tokens.slot0
                    }
                    DotText {
                        anchors.right: parent.right
                        anchors.rightMargin: 1
                        text: tvRow.e?.duration ?? ""
                        color: Tokens.slot1
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: tvRow.e !== null
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onEntered: pane.pick = tvRow.at
                        onClicked: mouse => {
                            pane.pick = tvRow.at;
                            pane.act(mouse.button === Qt.MiddleButton ? "queue" : "play");
                        }
                    }
                }
            }
            DotText {
                visible: pane.rowsTv.length === 0
                height: Tokens.lineDots
                text: Tv.searching ? "SEARCHING YOUTUBE" : pane.query ? "NOTHING SAVED MATCHES. CTRL S SEARCHES YOUTUBE" : "THE LIBRARY IS EMPTY. TYPE, THEN CTRL S"
                color: Tokens.slot1
            }
        }

        // ── LISTS rows ──────────────────────────────────────────────
        Column {
            visible: pane.page === "lists"
            width: pane.inner

            Repeater {
                model: pane.page === "lists" ? pane.slots : 0

                Item {
                    id: listRow
                    required property int index
                    readonly property int at: pane.first + index
                    readonly property var l: pane.rowsLists[at] ?? null
                    readonly property bool picked: at === pane.listPick && l !== null
                    width: pane.inner
                    height: Tokens.lineDots

                    Frame {
                        anchors.fill: parent
                        visible: listRow.picked
                    }
                    DotText {
                        x: 1
                        width: parent.width - 10 * Tokens.charDots
                        elide: Text.ElideRight
                        text: listRow.l ? (listRow.l.station ? "♪ " : listRow.l.name === pane.targetName ? "* " : "  ") + listRow.l.name.toUpperCase() : ""
                        color: Tokens.slot0
                    }
                    DotText {
                        anchors.right: parent.right
                        anchors.rightMargin: 1
                        text: !listRow.l ? "" : pane.confirm === listRow.l.id ? "DROP?" : (listRow.l.itemIds ?? []).length + (listRow.l.station ? " SONGS" : (listRow.l.itemIds ?? []).length === 1 ? " TRACK" : " TRACKS")
                        color: pane.confirm === listRow.l?.id ? Tokens.slot2 : Tokens.slot1
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: listRow.l !== null
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: pane.listPick = listRow.at
                        onClicked: {
                            pane.listPick = listRow.at;
                            pane.act("play");
                        }
                    }
                }
            }
            DotText {
                visible: pane.rowsLists.length === 0
                height: Tokens.lineDots
                text: pane.listQuery ? "CTRL O MAKES THE LIST " + pane.listQuery.toUpperCase().slice(0, 20) : "NO LISTS. TYPE A NAME, THEN CTRL O"
                color: Tokens.slot1
            }
        }

        // ── SCREEN settings ─────────────────────────────────────────
        Repeater {
            model: pane.page === "screen" ? pane.screenRows : []

            Line {
                id: setting
                required property var modelData
                required property int index
                label: (index === pane.screenRow ? "> " : "  ") + modelData.label
                labelColor: index === pane.screenRow ? Tokens.slot2 : Tokens.slot0

                Repeater {
                    model: pane.wide ? setting.modelData.options : []

                    DotButton {
                        required property var modelData
                        text: modelData[1]
                        active: pane.valueOf(setting.modelData) === modelData[0]
                        onClicked: {
                            pane.screenRow = setting.index;
                            pane.setRow(setting.modelData, modelData[0]);
                        }
                    }
                }
                DotButton {
                    visible: !pane.wide
                    active: true
                    text: "<" + (setting.modelData.options.find(o => o[0] === pane.valueOf(setting.modelData))?.[1] ?? "?") + ">"
                    onClicked: {
                        pane.screenRow = setting.index;
                        pane.nudgeRow(setting.modelData, 1);
                    }
                }
            }
        }

        Rule {}

        // Mode line: Endless Mix and the target list (or how a sync is
        // going), then key hints.
        DotText {
            visible: (pane.page === "tv" || pane.page === "lists") && (pane.wide || Tv.syncing)
            width: pane.inner
            height: Tokens.lineDots
            elide: Text.ElideRight
            text: Tv.syncing ? "SYNC  " + (Tv.status.sync?.line ?? "").toUpperCase() : "MIX " + (Tv.status.mix ? "ON" : "OFF") + "   LIST " + (pane.targetName ? pane.targetName.toUpperCase() : "NONE") + (Tv.status.queue.length ? "   UP NEXT " + Tv.status.queue.length : "")
            color: Tokens.slot2
        }
        // Key hints, two lines at most.
        Repeater {
            model: {
                if (pane.page === "anime")
                    return animePage.hints;
                if (!pane.wide)
                    return ["TAB PAGE  ENTER"];
                if (pane.page === "now")
                    return ["SPACE PLAY  < > SEEK  N P TRACK", "S PLAYER  " + (Media.isTv ? "M MIX  " : "") + "O TV WINDOW  TAB PAGE"];
                if (pane.page === "screen")
                    return ["UP DOWN PICK  LEFT RIGHT CHANGE", "THE TV WINDOW (O) LOOKS THE SAME"];
                if (pane.page === "tv")
                    return pane.online ? ["ENTER PLAY  ^Q QUEUE  ^E NEXT  ^G SAVE"] : ["ENTER PLAY  ^Q QUEUE  ^E NEXT  ^S YOUTUBE", "^L ADD TO LIST  ^D DELETE  ^M ENDLESS MIX"];
                return ["ENTER PLAY  ^R SHUFFLE  ^T TARGET", "^O NEW LIST  ^D DROP  ^Y SYNC"];
            }

            DotText {
                required property string modelData
                width: pane.inner
                height: Tokens.lineDots
                elide: Text.ElideRight
                text: modelData
                color: Tokens.slot1
            }
        }
    }
}
