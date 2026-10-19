import QtQuick
import qs
import qs.services
import qs.tokyo as T

// A panel docked in the top strip or the side rail, Split-Flap: its strip
// or rail form as the SPLIT-FLAP boards draw it, in square dots straight
// on the bar's housing (Rack.qml, a bare DotSurface over it). Readings
// sit on little flap tiles drawn in dots (a dark top half, the hinge, a
// darker bottom half) in off-white, marks and counts in yellow, warnings
// orange, alarms red, small print grey. No casing of its own. 11 dots
// tall in the strip, `Tokens.railDots` wide in the rail. DockItem.qml
// loads it for the templates in `forms`. A click where a form has no key
// of its own runs its `action`; a hold or a drag still lifts it.
//   Docked { template: "system"; rail: false; ctx: …; sink: …; panel: …; words: … }
T.Face {
    id: root

    property string template: ""
    property bool rail: false
    // The templates drawn here.
    readonly property var forms: ["media", "clock", "workspaces", "system", "battery", "messages", "capture", "caffeine", "clipboard", "todo"]
    readonly property bool shown: form.item ? form.item.shown !== false : false
    readonly property int railW: Tokens.railDots

    // The tiles' halves, a step above the housing so they read as dots.
    readonly property color tileUp: Ink.c("#2e2e2e", "#f7f4ec")
    readonly property color tileLow: Ink.c("#242424", "#ebe6da")
    // A picked tile: deep amber halves under a yellow letter (dark ink on
    // yellow dots would vanish into the gaps between them).
    readonly property color litUp: Ink.c("#5c4b00", "#f3dc8a")
    readonly property color litLow: Ink.c("#4a3c00", "#e8cc6a")

    implicitWidth: rail ? railW : (form.item?.implicitWidth ?? 0)
    implicitHeight: rail ? (form.item?.implicitHeight ?? 0) : 11

    // The form's own click (its `action`), under any keys it has.
    T.Hit {
        anchors.fill: form
        enabled: action !== ""
        action: form.item?.action ?? ""
    }
    Loader {
        id: form
        width: root.rail ? root.railW : implicitWidth
        sourceComponent: {
            const s = root.rail ? railForms : stripForms;
            return s[root.template] ?? null;
        }
    }
    readonly property var stripForms: ({
            media: stripMedia,
            clock: stripClock,
            workspaces: stripWs,
            system: stripSys,
            battery: stripBat,
            messages: stripMsg,
            capture: stripCap,
            caffeine: stripCaf,
            clipboard: stripClip,
            todo: stripTodo
        })
    readonly property var railForms: ({
            media: railMedia,
            clock: railClock,
            workspaces: railWs,
            system: railSys,
            battery: railBat,
            messages: railMsg,
            capture: railCap,
            caffeine: railCaf,
            clipboard: railClip,
            todo: railTodo
        })

    // ── Pictograms, a row of digits per dot row (0 = off, n = inks[n-1]) ─
    readonly property var frame: ["1101011", "1000001", "0000000", "1000001", "1101011"]
    readonly property var disc: ["0011100", "0111110", "1111111", "1111111", "1111111", "0111110", "0011100"]
    readonly property var keyPause: ["11111111111", "11122122111", "11122122111", "11122122111", "11122122111", "11122122111", "11111111111"]
    readonly property var keyPlay: ["11111111111", "11112111111", "11112211111", "11112221111", "11112211111", "11112111111", "11111111111"]
    readonly property var keyNext: ["11111111111", "11121112111", "11122112111", "11122212111", "11122112111", "11121112111", "11111111111"]
    readonly property var keyPrev: ["11111111111", "11121112111", "11121122111", "11121222111", "11121122111", "11121112111", "11111111111"]

    // ── Parts ───────────────────────────────────────────────────────
    // A pictogram in dots.
    component Pix: Item {
        id: pix
        property var pattern: []
        property var inks: [Ink.white]
        width: pattern.length ? pattern[0].length : 0
        height: pattern.length
        Repeater {
            model: {
                const o = [];
                pix.pattern.forEach((r, y) => {
                    for (let x = 0; x < r.length; x++)
                        if (r[x] !== "0")
                            o.push({
                                x: x,
                                y: y,
                                n: Number(r[x])
                            });
                });
                return o;
            }
            Rectangle {
                required property var modelData
                x: modelData.x
                y: modelData.y
                width: 1
                height: 1
                color: pix.inks[modelData.n - 1] ?? Ink.white
            }
        }
    }
    // Characters on flap tiles drawn in dots: a tile per character (5x7
    // on a 7 x `tall` tile, the hinge row left dark), `lit` tiles amber
    // with yellow letters. `cells` tiles (0: one per character); a longer
    // line pages through with `page`.
    component Tiles: Item {
        id: tiles
        property string text: ""
        property color color: Ink.white
        property int cells: 0
        property var lit: []
        property bool page: false
        property int tall: 11
        readonly property string up: String(text).toUpperCase()
        readonly property int count: cells > 0 ? cells : up.length
        property int at: 0
        readonly property int pages: page && count > 0 ? Math.max(1, Math.ceil(up.length / count)) : 1
        onPagesChanged: at = 0
        Timer {
            interval: 3600
            repeat: true
            running: tiles.pages > 1 && tiles.visible
            onTriggered: tiles.at = (tiles.at + 1) % tiles.pages
        }
        readonly property string shown: up.slice(at * count, at * count + count)
        readonly property int seam: Math.floor(tall / 2)
        width: count * 8 - 1
        height: tall
        Repeater {
            model: tiles.count
            Item {
                id: cell
                required property int index
                readonly property bool on: tiles.lit.includes(index)
                x: index * 8
                width: 7
                height: tiles.tall
                Rectangle {
                    width: 7
                    height: tiles.seam
                    color: cell.on ? root.litUp : root.tileUp
                }
                Rectangle {
                    y: tiles.seam + 1
                    width: 7
                    height: tiles.tall - tiles.seam - 1
                    color: cell.on ? root.litLow : root.tileLow
                }
                MatrixText {
                    x: 1
                    y: Math.floor((tiles.tall - 7) / 2)
                    width: 5
                    height: 7
                    text: tiles.shown[cell.index] ?? ""
                    color: cell.on ? Ink.yellow : tiles.color
                }
            }
        }
    }
    // Words with no tiles under them: 5x7 on rows 2..8, 3x5 on rows 3..7.
    component Big: MatrixText {
        y: 2
        width: implicitWidth
        height: 7
        color: Ink.white
    }
    component Small: MatrixText {
        y: 3
        font: "3x5"
        width: implicitWidth
        height: 5
        color: Ink.label
    }
    // A run of parts side by side, 11 dots tall.
    component Run: Row {
        height: 11
        spacing: 4
    }
    // A run of parts stacked, centred across the rail.
    component Stack: Column {
        width: root.railW
        spacing: 2
    }
    component Mid: Item {
        width: root.railW
        height: childrenRect.height
    }
    component Line: MatrixText {
        font: "3x5"
        width: root.railW
        height: 5
        align: "center"
        color: Ink.label
    }
    // A level as a row of blocks (the strip's little meter): `n` columns
    // two dots wide, lit off-white up to the value, the rest dark.
    component Blocks: Row {
        id: blocks
        property real value: 0
        property color color: Ink.white
        property int n: 5
        spacing: 1
        height: 5
        Repeater {
            model: blocks.n
            Rectangle {
                required property int index
                y: index === blocks.n - 1 ? 3 : 0
                width: 2
                height: index === blocks.n - 1 ? 2 : 5
                color: index < Math.round(Math.max(0, Math.min(1, blocks.value)) * blocks.n) ? blocks.color : root.tileUp
            }
        }
    }
    // A battery: a dashed grey outline, its charge in blocks, the nub on
    // its right (or on top, standing).
    component Cell: Item {
        id: bat
        property real value: 0
        property color fill: Ink.white
        property bool standing: false
        readonly property real v: Math.max(0, Math.min(1, value))
        width: standing ? 7 : 15
        height: standing ? 16 : 7
        Repeater {
            // The outline, every other dot.
            model: {
                const o = [], w = bat.standing ? 7 : 13, h = bat.standing ? 15 : 7, y0 = bat.standing ? 1 : 0;
                for (let x = 0; x < w; x += 2) {
                    o.push([x, y0]);
                    o.push([x, y0 + h - 1]);
                }
                for (let y = y0 + 2; y < y0 + h - 1; y += 2) {
                    o.push([0, y]);
                    o.push([w - 1, y]);
                }
                return o;
            }
            Rectangle {
                required property var modelData
                x: modelData[0]
                y: modelData[1]
                width: 1
                height: 1
                color: Ink.label
            }
        }
        Rectangle {
            x: bat.standing ? 2 : 14
            y: bat.standing ? 0 : 2
            width: bat.standing ? 3 : 1
            height: bat.standing ? 1 : 3
            color: Ink.label
        }
        Repeater {
            model: bat.standing ? 5 : 4
            Rectangle {
                required property int index
                readonly property bool lit: index < Math.ceil(bat.v * (bat.standing ? 5 : 4) - 0.15)
                visible: lit
                x: bat.standing ? 2 : 2 + index * 2.5
                y: bat.standing ? 13 - index * 2.5 : 2
                width: bat.standing ? 3 : 2
                height: bat.standing ? 2 : 3
                color: bat.fill
            }
        }
    }
    // Album art, square, in true colour dots; a seam of tiles when none.
    component Art: Item {
        id: art
        property int size: 9
        width: size
        height: size
        Rectangle {
            visible: !img.ready
            anchors.fill: parent
            color: root.tileUp
        }
        Rectangle {
            visible: !img.ready
            y: Math.floor(art.size / 2)
            width: art.size
            height: 1
            color: Ink.housing
        }
        Image {
            id: img
            readonly property bool ready: status === Image.Ready && source != ""
            anchors.fill: parent
            source: root.ctx.active ? (root.ctx.art ?? "") : ""
            sourceSize: Qt.size(art.size * 2, art.size * 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
        }
    }
    component Click: T.Hit {
        anchors.fill: parent
    }

    function pct(v: real): string {
        return Math.round(Math.max(0, Math.min(1, v)) * 100) + "%";
    }
    function hot(v: real): bool {
        return v >= 0.85;
    }

    // ── Strip ───────────────────────────────────────────────────────
    // Media: the title on flap tiles (a long one pages), the time on
    // yellow ones; a click opens MEDIA.
    Component {
        id: stripMedia
        Run {
            spacing: 3
            readonly property bool on: !!root.ctx.active
            readonly property string action: "pane media"
            Tiles {
                cells: 12
                page: true
                text: parent.on ? String(root.ctx.title ?? "") : "NO SIGNAL"
                color: parent.on ? Ink.white : Ink.label
            }
            Tiles {
                visible: parent.on && (root.ctx.len ?? 0) > 0
                text: Media.clock(root.ctx.pos ?? 0)
                color: Ink.yellow
            }
        }
    }

    // Clock: the time on flap tiles, the day and date in yellow.
    Component {
        id: stripClock
        Run {
            spacing: 5
            readonly property string action: "pane calendar"
            Tiles {
                text: root.ctx.time ?? ""
            }
            Small {
                text: String(root.ctx.dateShort ?? "").toUpperCase()
                color: Ink.yellow
            }
        }
    }

    // Workspaces: a flap tile per workspace, the one you are on yellow,
    // urgent ones red, empty ones faint; + opens an empty one.
    Component {
        id: stripWs
        Run {
            spacing: 2
            Repeater {
                model: root.ctx.list ?? []
                Tiles {
                    required property var modelData
                    text: modelData.home ? "⌂" : String(modelData.id)
                    color: modelData.urgent ? Ink.red : Ink.dim
                    lit: modelData.focused ? [0] : []
                    opacity: modelData.focused || (modelData.windows ?? 0) > 0 || modelData.home ? 1 : 0.55
                    T.Hit {
                        anchors.fill: parent
                        anchors.margins: -1
                        action: "ws " + parent.modelData.id
                    }
                }
            }
            Big {
                text: "+"
                color: Ink.label
                T.Hit {
                    anchors.fill: parent
                    anchors.margins: -2
                    action: "ws empty"
                }
            }
        }
    }

    // System: CPU, MEM, TEMP, each its grey label, a row of blocks and the
    // reading in off-white; a hot one turns orange.
    Component {
        id: stripSys
        Run {
            spacing: 6
            Repeater {
                model: [
                    { k: "CPU", v: root.ctx.cpu ?? 0, t: root.pct(root.ctx.cpu ?? 0), w: 23, on: true },
                    { k: "MEM", v: root.ctx.mem ?? 0, t: Number(root.ctx.memGb ?? 0).toFixed(1) + "G", w: 29, on: true },
                    { k: "TEMP", v: root.ctx.tempF ?? 0, t: Math.round(root.ctx.temp ?? 0) + "°", w: 17, on: !!root.ctx.hasTemp }
                ]
                Row {
                    id: rd
                    required property var modelData
                    visible: modelData.on
                    height: 11
                    spacing: 2
                    Small {
                        text: rd.modelData.k
                    }
                    Blocks {
                        y: 3
                        value: rd.modelData.v
                        color: root.hot(rd.modelData.v) ? Ink.orange : Ink.white
                    }
                    Big {
                        width: rd.modelData.w
                        align: "right"
                        text: rd.modelData.t
                        color: root.hot(rd.modelData.v) ? Ink.orange : Ink.white
                    }
                }
            }
        }
    }

    // Battery: the dashed cell, its charge white (yellow charging, red
    // low), the percent; ! when low, + while charging.
    Component {
        id: stripBat
        Run {
            readonly property bool shown: !!root.ctx.present
            readonly property bool low: root.ctx.level === "bad"
            readonly property string action: "pane battery"
            Cell {
                y: 2
                value: root.ctx.fraction ?? 0
                fill: parent.low ? Ink.red : root.ctx.charging ? Ink.yellow : Ink.white
            }
            Big {
                text: (root.ctx.pct ?? 0) + "%"
                color: parent.low ? Ink.red : Ink.white
            }
            Big {
                visible: parent.low || !!root.ctx.charging
                text: parent.low ? "!" : "+"
                color: parent.low ? Ink.red : Ink.white
            }
        }
    }

    // Messages: MSG and the count on yellow tiles, the newest after it in
    // off-white. Do not disturb: DND on dark tiles and how many are held.
    Component {
        id: stripMsg
        Run {
            readonly property int live: root.ctx.live ?? 0
            readonly property bool dnd: !!root.ctx.dnd
            readonly property var last: (root.ctx.items ?? [])[0] ?? null
            readonly property string action: "pane notifs"
            Tiles {
                readonly property string word: (parent.dnd ? "DND " : "MSG ") + Math.min(99, parent.live)
                text: word
                color: Ink.label
                lit: parent.dnd ? [] : [0, 1, 2, 3, 4, 5]
                opacity: parent.dnd ? 0.6 : 1
            }
            Big {
                visible: parent.dnd || (parent.live > 0 && parent.last !== null)
                width: parent.dnd ? implicitWidth : 110
                scroll: true
                text: parent.dnd ? "HELD" : String((parent.last?.app ?? "") + " · " + (parent.last?.summary ?? ""))
                color: parent.dnd ? Ink.label : Ink.white
            }
        }
    }

    // Capture: the dashed frame and CAPTURE; recording, a red lamp and the
    // time in red (a click stops it).
    Component {
        id: stripCap
        Run {
            readonly property bool rec: !!root.ctx.recording
            readonly property string action: rec ? "capture stop" : "pane capture"
            Item {
                width: 7
                height: 11
                Pix {
                    visible: !parent.parent.rec
                    y: 3
                    pattern: root.frame
                }
                Pix {
                    visible: parent.parent.rec
                    y: 2
                    pattern: root.disc
                    inks: [Ink.red]
                    opacity: root.ctx.blink ?? 1
                }
            }
            Big {
                text: parent.rec ? "REC " + (root.ctx.elapsed ?? "") : "CAPTURE"
                color: parent.rec ? Ink.red : Ink.white
            }
        }
    }

    // Caffeine: AWAKE and the time left in yellow; asleep, AWAKE OFF in
    // grey.
    Component {
        id: stripCaf
        Run {
            readonly property bool on: !!root.ctx.on
            readonly property string action: "caffeine toggle"
            Big {
                text: "AWAKE"
                color: parent.on ? Ink.yellow : Ink.label
            }
            Big {
                text: parent.on ? (String(root.ctx.left || "ON")) : "OFF"
                color: parent.on ? Ink.yellow : Ink.label
            }
        }
    }

    // Clipboard: CL in yellow (the list), the last copy after it in
    // off-white (a click pastes it).
    Component {
        id: stripClip
        Run {
            spacing: 4
            Big {
                text: "CL"
                color: Ink.yellow
                T.Hit {
                    anchors.fill: parent
                    anchors.margins: -2
                    action: "pane clip"
                }
            }
            Big {
                visible: (root.ctx.count ?? 0) > 0
                width: 90
                scroll: true
                text: String(root.ctx.lastPreview ?? "")
                color: Ink.white
                T.Hit {
                    anchors.fill: parent
                    action: "paste 0"
                }
            }
        }
    }

    // Todo: DUE in yellow small print, how many are left in orange, the
    // next one in off-white.
    Component {
        id: stripTodo
        Run {
            spacing: 4
            Small {
                text: root.ctx.next ? "DUE" : "DONE"
                color: root.ctx.next ? Ink.yellow : Ink.label
            }
            Big {
                text: (root.ctx.left ?? 0) + " LEFT ·"
                color: Ink.orange
            }
            Big {
                width: 112
                scroll: true
                text: String(root.ctx.next || root.words.empty || "ALL DONE")
                color: root.ctx.next ? Ink.white : Ink.label
            }
        }
    }

    // ── Rail ────────────────────────────────────────────────────────
    // Media: the art, the seek line standing in dots, play / pause on a
    // yellow key, next on a dark one.
    Component {
        id: railMedia
        Stack {
            readonly property bool on: !!root.ctx.active
            spacing: 3
            Mid {
                height: 11
                Art {
                    x: Math.floor((root.railW - size) / 2)
                    size: 11
                }
                Click {
                    action: "pane media"
                }
            }
            Mid {
                visible: parent.on
                height: 20
                Column {
                    x: Math.floor(root.railW / 2) - 1
                    spacing: 1
                    Repeater {
                        model: 10
                        Rectangle {
                            required property int index
                            width: 3
                            height: 1
                            color: (10 - index) / 10 <= Math.max(0, Math.min(1, root.ctx.progress ?? 0)) + 0.05 ? Ink.yellow : root.tileUp
                        }
                    }
                }
            }
            Repeater {
                model: parent.on ? ["toggle", "next"] : []
                Mid {
                    id: key
                    required property string modelData
                    height: 7
                    Pix {
                        x: Math.floor((root.railW - 11) / 2)
                        pattern: key.modelData === "next" ? root.keyNext : root.ctx.playing ? root.keyPause : root.keyPlay
                        inks: key.modelData === "toggle" ? [Ink.yellow, Ink.housing] : [root.tileUp, Ink.white]
                    }
                    T.Hit {
                        anchors.fill: parent
                        action: key.modelData === "next" ? "media next" : "media toggle"
                    }
                }
            }
        }
    }

    // Clock: the hours over the minutes on flap tiles, the day and date in
    // yellow.
    Component {
        id: railClock
        Stack {
            spacing: 2
            readonly property string action: "pane calendar"
            Repeater {
                model: [root.ctx.hh ?? "", root.ctx.mm ?? ""]
                Mid {
                    required property string modelData
                    height: 11
                    Tiles {
                        x: Math.floor((root.railW - width) / 2)
                        text: parent.modelData
                    }
                }
            }
            Item {
                width: 1
                height: 1
            }
            Repeater {
                model: [String(root.ctx.date ?? "").slice(0, 3).toUpperCase(), root.ctx.dd ?? ""]
                Line {
                    required property string modelData
                    text: modelData
                    color: Ink.yellow
                }
            }
        }
    }

    // Workspaces: a flap tile each, stacked, the one you are on yellow.
    Component {
        id: railWs
        Stack {
            spacing: 2
            Repeater {
                model: (root.ctx.list ?? []).slice(0, 6)
                Mid {
                    id: ws
                    required property var modelData
                    height: 11
                    Tiles {
                        x: Math.floor((root.railW - width) / 2)
                        text: ws.modelData.home ? "⌂" : String(ws.modelData.id)
                        color: ws.modelData.urgent ? Ink.red : Ink.dim
                        lit: ws.modelData.focused ? [0] : []
                        opacity: ws.modelData.focused || (ws.modelData.windows ?? 0) > 0 || ws.modelData.home ? 1 : 0.55
                    }
                    T.Hit {
                        anchors.fill: parent
                        action: "ws " + ws.modelData.id
                    }
                }
            }
        }
    }

    // System: three columns rising in off-white on dark tracks, C M T
    // under.
    Component {
        id: railSys
        Stack {
            Mid {
                Row {
                    x: Math.floor((root.railW - width) / 2)
                    spacing: 1
                    Repeater {
                        model: [
                            { k: "C", v: root.ctx.cpu ?? 0, on: true },
                            { k: "M", v: root.ctx.mem ?? 0, on: true },
                            { k: "T", v: root.ctx.tempF ?? 0, on: !!root.ctx.hasTemp }
                        ]
                        Column {
                            id: col
                            required property var modelData
                            visible: modelData.on
                            spacing: 2
                            Item {
                                width: 3
                                height: 30
                                // Blocks of two with a dark row between.
                                Repeater {
                                    model: 10
                                    Rectangle {
                                        required property int index
                                        y: 30 - (index + 1) * 3
                                        width: 3
                                        height: 2
                                        color: index < Math.round(10 * Math.max(0, Math.min(1, col.modelData.v))) ? (root.hot(col.modelData.v) ? Ink.orange : Ink.white) : root.tileUp
                                    }
                                }
                            }
                            MatrixText {
                                font: "3x5"
                                text: col.modelData.k
                                width: 3
                                height: 5
                                color: Ink.label
                            }
                        }
                    }
                }
            }
        }
    }

    // Battery: the cell standing, the percent under it.
    Component {
        id: railBat
        Stack {
            readonly property bool shown: !!root.ctx.present
            readonly property bool low: root.ctx.level === "bad"
            readonly property string action: "pane battery"
            Mid {
                Cell {
                    x: Math.floor((root.railW - width) / 2)
                    standing: true
                    value: root.ctx.fraction ?? 0
                    fill: parent.parent.low ? Ink.red : root.ctx.charging ? Ink.yellow : Ink.white
                }
            }
            MatrixText {
                readonly property string t: String(root.ctx.pct ?? 0)
                font: t.length > 2 ? "3x5" : "5x7"
                text: t
                width: root.railW
                height: t.length > 2 ? 5 : 7
                align: "center"
                color: parent.low ? Ink.red : Ink.white
            }
        }
    }

    // Messages: MSG in grey small print, the count big in yellow.
    Component {
        id: railMsg
        Stack {
            readonly property int live: root.ctx.live ?? 0
            readonly property bool dnd: !!root.ctx.dnd
            readonly property string action: "pane notifs"
            Line {
                text: parent.dnd ? "DND" : "MSG"
                opacity: parent.dnd ? 0.6 : 1
            }
            MatrixText {
                text: String(Math.min(99, parent.live))
                width: root.railW
                height: 7
                align: "center"
                color: parent.live > 0 && !parent.dnd ? Ink.yellow : Ink.label
            }
        }
    }

    // Capture: the dashed frame and CAP; recording, the red lamp and REC.
    Component {
        id: railCap
        Stack {
            readonly property bool rec: !!root.ctx.recording
            readonly property string action: rec ? "capture stop" : "pane capture"
            Mid {
                height: 7
                Pix {
                    visible: !parent.parent.rec
                    x: Math.floor((root.railW - 7) / 2)
                    y: 1
                    pattern: root.frame
                }
                Pix {
                    visible: parent.parent.rec
                    x: Math.floor((root.railW - 7) / 2)
                    pattern: root.disc
                    inks: [Ink.red]
                    opacity: root.ctx.blink ?? 1
                }
            }
            Line {
                text: parent.rec ? "REC" : "CAP"
                color: parent.rec ? Ink.red : Ink.white
            }
        }
    }

    // Caffeine: WAKE in small yellow print, the time left (or OFF) under.
    Component {
        id: railCaf
        Stack {
            readonly property bool on: !!root.ctx.on
            readonly property string action: "caffeine toggle"
            Line {
                text: "WAKE"
                color: parent.on ? Ink.yellow : Ink.label
            }
            Line {
                text: parent.on ? (String(root.ctx.left ?? "").split(" ").pop() || "ON") : "OFF"
                color: parent.on ? Ink.yellow : Ink.label
            }
        }
    }

    // Clipboard: CL in yellow, then the last four copies as numbered flap
    // tiles, the newest yellow (a click pastes that one).
    Component {
        id: railClip
        Stack {
            spacing: 2
            Mid {
                height: 7
                MatrixText {
                    text: "CL"
                    width: root.railW
                    height: 7
                    align: "center"
                    color: Ink.yellow
                }
                T.Hit {
                    anchors.fill: parent
                    action: "pane clip"
                }
            }
            Repeater {
                model: Math.min(4, root.ctx.count ?? 0)
                Mid {
                    id: slot
                    required property int index
                    height: 11
                    Tiles {
                        x: Math.floor((root.railW - width) / 2)
                        text: String(slot.index + 1)
                        color: Ink.dim
                        lit: slot.index === 0 ? [0] : []
                    }
                    T.Hit {
                        anchors.fill: parent
                        action: "paste " + slot.index
                    }
                }
            }
        }
    }

    // Todo: DONE or DUE per task today (DUE yellow), how many are left in
    // orange under.
    Component {
        id: railTodo
        Stack {
            spacing: 2
            Repeater {
                model: (root.ctx.today ?? []).slice(0, 5)
                Line {
                    required property var modelData
                    text: modelData.done ? "DONE" : "DUE"
                    color: modelData.done ? Ink.label : Ink.yellow
                }
            }
            MatrixText {
                text: String(root.ctx.left ?? 0)
                width: root.railW
                height: 7
                align: "center"
                color: Ink.orange
            }
        }
    }
}
