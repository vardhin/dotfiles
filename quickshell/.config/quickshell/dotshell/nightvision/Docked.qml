import QtQuick
import QtQuick.Effects
import qs
import qs.services
import qs.tokyo as T

// A panel docked in the top strip or the side rail, Night Vision: its strip
// or rail form as the NIGHT VISION boards draw it, in phosphor dots on the
// bar's green dot glass (its own DotSurface): the readings bright, the
// small print dim, marks and titles lit, alarms bright, dim tracks deep
// green, little pictograms (the cup, the dashed frame, the cell, the
// window pips) in dots. No casing of its own. 11 dots tall in the strip,
// `Tokens.railDots` wide in the rail. DockItem.qml loads it for the
// templates in `forms`. A click where a form has no key of its own runs
// its `action`; a hold or a drag still lifts it.
//   Docked { template: "system"; rail: false; ctx: …; sink: …; panel: …; words: … }
T.Face {
    id: root

    property string template: ""
    property bool rail: false
    // The templates drawn here.
    readonly property var forms: ["media", "clock", "workspaces", "system", "battery", "messages", "capture", "caffeine", "clipboard", "todo"]
    readonly property bool shown: form.item ? form.item.shown !== false : false
    readonly property int railW: Tokens.railDots

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
    readonly property var cup: ["0020000", "0002000", "1111110", "1111101", "1111110", "0111100", "3333330"]
    readonly property var frame: ["1101011", "1000001", "0000000", "1000001", "1101011"]
    readonly property var ringDash: ["0010100", "0100010", "0000000", "1000001", "0000000", "0100010", "0010100"]
    readonly property var ring: ["0011100", "0100010", "1000001", "1000001", "1000001", "0100010", "0011100"]
    readonly property var disc: ["0011100", "0111110", "1111111", "1111111", "1111111", "0111110", "0011100"]
    readonly property var sheets: ["1111000", "1001000", "1011110", "1010010", "1110010", "0010010", "0011110"]
    readonly property var vinyl: ["001111100", "011111110", "111111111", "111020111", "111222111", "111020111", "111111111", "011111110", "001111100"]
    readonly property var keyRing: ["00011111000", "00100000100", "01000000010", "10000000001", "10000000001", "10000000001", "10000000001", "10000000001", "01000000010", "00100000100", "00011111000"]
    readonly property var keyPause: ["00011111000", "00100000100", "01000000010", "10002020001", "10002020001", "10002020001", "10002020001", "10002020001", "01000000010", "00100000100", "00011111000"]
    readonly property var keyPlay: ["00011111000", "00100000100", "01000000010", "10002000001", "10002200001", "10002220001", "10002200001", "10002000001", "01000000010", "00100000100", "00011111000"]
    readonly property var keyNext: ["00011111000", "00100000100", "01000000010", "10020002001", "10022002001", "10022202001", "10022002001", "10020002001", "01000000010", "00100000100", "00011111000"]
    readonly property var keyPrev: ["00011111000", "00100000100", "01000000010", "10020002001", "10020022001", "10020222001", "10020022001", "10020002001", "01000000010", "00100000100", "00011111000"]

    // ── Parts ───────────────────────────────────────────────────────
    // A pictogram in dots.
    component Pix: Item {
        id: pix
        property var pattern: []
        property var inks: [Ink.pink]
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
                color: pix.inks[modelData.n - 1] ?? Ink.pink
            }
        }
    }
    // 5x7 sits on rows 2..8 of the strip, 3x5 on rows 4..8: one baseline.
    component Big: MatrixText {
        y: 2
        width: implicitWidth
        height: 7
        color: Ink.ink
    }
    component Small: MatrixText {
        y: 4
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
    // A level as rising steps (the strip's little signal wedge): `n`
    // columns, lit cyan up to the value, the rest unlit violet.
    component Wedge: Row {
        id: wedge
        property real value: 0
        property color color: Ink.ink
        property int n: 6
        spacing: 1
        height: 5
        Repeater {
            model: wedge.n
            Rectangle {
                required property int index
                readonly property int h: 1 + Math.round(index * 4 / Math.max(1, wedge.n - 1))
                y: 5 - h
                width: 1
                height: h
                color: index < Math.round(Math.max(0, Math.min(1, wedge.value)) * wedge.n) ? wedge.color : Ink.mid
            }
        }
    }
    // A battery: a cyan outline, its charge in pink blocks, the nub on its
    // right (or on top, standing).
    component Cell: Item {
        id: bat
        property real value: 0
        property color color: Ink.ink
        property color fill: Ink.pink
        property bool standing: false
        readonly property real v: Math.max(0, Math.min(1, value))
        width: standing ? 7 : 14
        height: standing ? 16 : 7
        Rectangle {
            y: bat.standing ? 1 : 0
            width: bat.standing ? 7 : 13
            height: bat.standing ? 15 : 7
            color: "transparent"
            border.width: 1
            border.color: bat.color
        }
        Rectangle {
            x: bat.standing ? 2 : 13
            y: bat.standing ? 0 : 2
            width: bat.standing ? 3 : 1
            height: bat.standing ? 1 : 3
            color: bat.color
        }
        // Blocks of two with a dark dot between, like the board's cells.
        Repeater {
            model: bat.standing ? 4 : 3
            Rectangle {
                required property int index
                readonly property bool lit: index < Math.ceil(bat.v * (bat.standing ? 4 : 3) - 0.15)
                x: bat.standing ? 2 : 2 + index * 3
                y: bat.standing ? 13 - index * 3 - 1 : 2
                width: bat.standing ? 3 : 2
                height: bat.standing ? 2 : 3
                color: lit ? bat.fill : Ink.mid
            }
        }
    }
    // Album art as a disc of dots, the pink vinyl when there is none.
    component Art: Item {
        id: art
        property int size: 9
        width: size
        height: size
        Pix {
            visible: !img.ready
            x: Math.floor((art.size - 9) / 2)
            y: x
            pattern: root.vinyl
            inks: [Ink.pink, Ink.face]
        }
        Image {
            id: img
            readonly property bool ready: status === Image.Ready && source != ""
            anchors.fill: parent
            visible: false
            source: root.ctx.active ? (root.ctx.art ?? "") : ""
            sourceSize: Qt.size(art.size * 2, art.size * 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
        }
        Rectangle {
            id: mask
            anchors.fill: parent
            radius: width / 2
            visible: false
            layer.enabled: true
        }
        MultiEffect {
            visible: img.ready
            anchors.fill: parent
            source: img
            maskEnabled: true
            maskSource: mask
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
    // Media: the art disc (a click plays / pauses), title · artist in cyan
    // on a seek line of dots, the time in pink.
    Component {
        id: stripMedia
        Run {
            readonly property bool on: !!root.ctx.active
            Art {
                y: 1
                Click {
                    action: "media toggle"
                }
            }
            Item {
                visible: parent.on
                width: 112
                height: 11
                Big {
                    y: 1
                    width: 112
                    text: String((root.ctx.title ?? "") + (root.ctx.artist ? " · " + root.ctx.artist : "")).toUpperCase()
                    scroll: true
                }
                Row {
                    y: 10
                    spacing: 1
                    Repeater {
                        model: 56
                        Rectangle {
                            required property int index
                            width: 1
                            height: 1
                            color: index / 56 < Math.max(0, Math.min(1, root.ctx.progress ?? 0)) ? Ink.ink : Ink.mid
                        }
                    }
                }
                Click {
                    action: "pane media"
                }
            }
            Big {
                visible: parent.on && (root.ctx.len ?? 0) > 0
                y: 1
                text: Media.clock(root.ctx.pos ?? 0)
                color: Ink.pink
            }
            Item {
                visible: !parent.on
                width: idle.width
                height: 11
                Big {
                    id: idle
                    text: "NO SIGNAL"
                    color: Ink.label
                }
                Click {
                    action: "pane media"
                }
            }
        }
    }

    // Clock: the time in cyan, the day in pink.
    Component {
        id: stripClock
        Run {
            spacing: 5
            Big {
                text: root.ctx.time ?? ""
            }
            Big {
                text: String(root.ctx.dateShort ?? "").toUpperCase()
                color: Ink.pink
            }
            readonly property string action: "pane calendar"
        }
    }

    // Workspaces: the numbers, the one you are on cyan, a pink pip per
    // window after each; + opens an empty one.
    Component {
        id: stripWs
        Run {
            spacing: 4
            Repeater {
                model: root.ctx.list ?? []
                Row {
                    id: ws
                    required property var modelData
                    height: 11
                    spacing: 2
                    readonly property int wins: Math.min(3, modelData.windows ?? 0)
                    Big {
                        text: ws.modelData.home ? "⌂" : String(ws.modelData.id)
                        color: ws.modelData.urgent ? Ink.red : ws.modelData.focused ? Ink.ink : Ink.label
                        opacity: ws.modelData.focused || ws.wins > 0 ? 1 : 0.5
                        T.Hit {
                            anchors.fill: parent
                            anchors.topMargin: -2
                            anchors.bottomMargin: -2
                            anchors.rightMargin: -ws.wins * 3 - 1
                            action: "ws " + ws.modelData.id
                        }
                    }
                    Row {
                        y: 5
                        spacing: 1
                        Repeater {
                            model: ws.wins
                            Rectangle {
                                width: 2
                                height: 2
                                color: Ink.pink
                            }
                        }
                    }
                }
            }
            Big {
                text: "+"
                color: Ink.label
                opacity: 0.6
                T.Hit {
                    anchors.fill: parent
                    anchors.margins: -2
                    action: "ws empty"
                }
            }
        }
    }

    // System: CPU, MEM, TEMP, each its violet label, a rising wedge and
    // the reading in cyan; a hot one turns pink.
    Component {
        id: stripSys
        Run {
            spacing: 6
            Repeater {
                model: [
                    {
                        k: "CPU",
                        v: root.ctx.cpu ?? 0,
                        t: root.pct(root.ctx.cpu ?? 0),
                        w: 23,
                        on: true
                    },
                    {
                        k: "MEM",
                        v: root.ctx.mem ?? 0,
                        t: Number(root.ctx.memGb ?? 0).toFixed(1) + "G",
                        w: 29,
                        on: true
                    },
                    {
                        k: "TEMP",
                        v: root.ctx.tempF ?? 0,
                        t: Math.round(root.ctx.temp ?? 0) + "°",
                        w: 17,
                        on: !!root.ctx.hasTemp
                    }
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
                    Wedge {
                        y: 4
                        value: rd.modelData.v
                        color: root.hot(rd.modelData.v) ? Ink.pink : Ink.ink
                    }
                    Big {
                        width: rd.modelData.w
                        align: "right"
                        text: rd.modelData.t
                        color: root.hot(rd.modelData.v) ? Ink.pink : Ink.ink
                    }
                }
            }
        }
    }

    // Battery: the cell, then the percent; red and ! when low, + while
    // charging.
    Component {
        id: stripBat
        Run {
            readonly property bool shown: !!root.ctx.present
            readonly property bool low: root.ctx.level === "bad"
            Cell {
                y: 2
                value: root.ctx.fraction ?? 0
                color: parent.low ? Ink.red : Ink.ink
                fill: parent.low ? Ink.red : root.ctx.charging ? Ink.ink : Ink.pink
            }
            Big {
                text: (root.ctx.pct ?? 0) + "%"
                color: parent.low ? Ink.red : Ink.ink
            }
            Big {
                visible: parent.low || !!root.ctx.charging
                text: parent.low ? "!" : "+"
                color: parent.low ? Ink.red : Ink.pink
            }
            readonly property string action: "pane battery"
        }
    }

    // Messages: MSG and the count in cyan, the newest after it in pink. Do
    // not disturb: DND and how many are held, switched off.
    Component {
        id: stripMsg
        Run {
            readonly property int live: root.ctx.live ?? 0
            readonly property bool dnd: !!root.ctx.dnd
            readonly property var last: (root.ctx.items ?? [])[0] ?? null
            Big {
                text: parent.dnd ? "DND" : "MSG"
                color: parent.dnd ? Ink.label : Ink.ink
                opacity: parent.dnd ? 0.45 : 1
            }
            Big {
                text: String(parent.live)
                color: parent.dnd ? Ink.label : parent.live > 0 ? Ink.ink : Ink.label
                opacity: parent.dnd ? 0.45 : 1
            }
            Big {
                visible: parent.dnd || (parent.live > 0 && parent.last !== null)
                width: parent.dnd ? implicitWidth : 100
                scroll: true
                text: parent.dnd ? "HELD" : String((parent.last?.app ?? "") + " · " + (parent.last?.summary ?? "")).toUpperCase()
                color: parent.dnd ? Ink.label : Ink.pink
                opacity: parent.dnd ? 0.45 : 1
            }
            readonly property string action: "pane notifs"
        }
    }

    // Capture: a dashed pink frame and CAPTURE; recording, a red lamp and
    // the time (a click stops it).
    Component {
        id: stripCap
        Run {
            readonly property bool rec: !!root.ctx.recording
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
                color: parent.rec ? Ink.red : Ink.ink
            }
            readonly property string action: rec ? "capture stop" : "pane capture"
        }
    }

    // Caffeine: the cup steaming and the time left in cyan; asleep, the cup
    // unlit and OFF.
    Component {
        id: stripCaf
        Run {
            readonly property bool on: !!root.ctx.on
            Pix {
                y: 2
                pattern: root.cup
                inks: parent.on ? [Ink.ink, Ink.pink, Ink.ink] : [Ink.mid, "transparent", Ink.mid]
            }
            Big {
                text: parent.on ? (root.ctx.left || "ON") : "OFF"
                color: parent.on ? Ink.ink : Ink.label
                opacity: parent.on ? 1 : 0.5
            }
            readonly property string action: "caffeine toggle"
        }
    }

    // Clipboard: the sheets in violet (the list), the last copy after it
    // in pink (a click pastes it).
    Component {
        id: stripClip
        Run {
            spacing: 4
            Pix {
                y: 2
                pattern: root.sheets
                inks: [Ink.label]
                T.Hit {
                    anchors.fill: parent
                    anchors.margins: -2
                    action: "pane clip"
                }
            }
            Big {
                visible: (root.ctx.count ?? 0) > 0
                width: 84
                scroll: true
                text: String(root.ctx.lastPreview ?? "").toUpperCase()
                color: Ink.pink
                T.Hit {
                    anchors.fill: parent
                    action: "paste 0"
                }
            }
        }
    }

    // Todo: the dashed ring, how many are left in violet, the next one in
    // pink.
    Component {
        id: stripTodo
        Run {
            spacing: 3
            Pix {
                y: 2
                pattern: root.ctx.next ? root.ringDash : root.disc
                inks: [root.ctx.next ? Ink.pink : Ink.ink]
            }
            Small {
                text: (root.ctx.left ?? 0) + " LEFT ·"
            }
            Big {
                width: 112
                scroll: true
                text: String(root.ctx.next || root.words.empty || "ALL DONE").toUpperCase()
                color: root.ctx.next ? Ink.pink : Ink.label
            }
        }
    }

    // ── Rail ────────────────────────────────────────────────────────
    // Media: the art disc, the seek bar standing in dots, play / pause in
    // a cyan ring, next in a pink one.
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
                    x: Math.floor(root.railW / 2)
                    spacing: 1
                    Repeater {
                        model: 10
                        Rectangle {
                            required property int index
                            width: 1
                            height: 1
                            color: (index + 1) / 10 <= Math.max(0, Math.min(1, root.ctx.progress ?? 0)) + 0.05 ? Ink.ink : Ink.mid
                        }
                    }
                }
            }
            Repeater {
                model: parent.on ? ["prev", "toggle", "next"] : []
                Mid {
                    id: key
                    required property string modelData
                    height: 11
                    Pix {
                        x: Math.floor((root.railW - 11) / 2)
                        pattern: key.modelData === "prev" ? root.keyPrev : key.modelData === "next" ? root.keyNext : root.ctx.playing ? root.keyPause : root.keyPlay
                        inks: key.modelData === "toggle" ? [Ink.ink, Ink.ink] : [Ink.pink, Ink.pink]
                    }
                    T.Hit {
                        anchors.fill: parent
                        action: key.modelData === "prev" ? "media previous" : key.modelData === "next" ? "media next" : "media toggle"
                    }
                }
            }
        }
    }

    // Clock: the hours over the minutes in cyan, the day and date in pink.
    Component {
        id: railClock
        Stack {
            Repeater {
                model: [root.ctx.hh ?? "", root.ctx.mm ?? ""]
                MatrixText {
                    required property string modelData
                    text: modelData
                    width: root.railW
                    height: 7
                    align: "center"
                    color: Ink.ink
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
                    color: Ink.pink
                }
            }
            readonly property string action: "pane calendar"
        }
    }

    // Workspaces: the numbers stacked, a pink pip per window under each.
    Component {
        id: railWs
        Stack {
            spacing: 3
            Repeater {
                model: (root.ctx.list ?? []).slice(0, 6)
                Mid {
                    id: ws
                    required property var modelData
                    readonly property int wins: Math.min(3, modelData.windows ?? 0)
                    height: wins > 0 ? 10 : 7
                    MatrixText {
                        text: ws.modelData.home ? "⌂" : String(ws.modelData.id)
                        width: root.railW
                        height: 7
                        align: "center"
                        color: ws.modelData.urgent ? Ink.red : ws.modelData.focused ? Ink.ink : Ink.label
                        opacity: ws.modelData.focused || ws.wins > 0 ? 1 : 0.5
                    }
                    Row {
                        x: Math.floor((root.railW - width) / 2)
                        y: 8
                        spacing: 1
                        Repeater {
                            model: ws.wins
                            Rectangle {
                                width: 2
                                height: 2
                                color: Ink.pink
                            }
                        }
                    }
                    T.Hit {
                        anchors.fill: parent
                        action: "ws " + ws.modelData.id
                    }
                }
            }
        }
    }

    // System: three columns rising in cyan on unlit violet, C M T under.
    Component {
        id: railSys
        Stack {
            Mid {
                Row {
                    x: Math.floor((root.railW - width) / 2)
                    spacing: 2
                    Repeater {
                        model: [
                            {
                                k: "C",
                                v: root.ctx.cpu ?? 0,
                                on: true
                            },
                            {
                                k: "M",
                                v: root.ctx.mem ?? 0,
                                on: true
                            },
                            {
                                k: "T",
                                v: root.ctx.tempF ?? 0,
                                on: !!root.ctx.hasTemp
                            }
                        ]
                        Column {
                            id: col
                            required property var modelData
                            visible: modelData.on
                            spacing: 2
                            Item {
                                width: 3
                                height: 30
                                Rectangle {
                                    anchors.fill: parent
                                    color: Ink.mid
                                }
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: 3
                                    height: Math.round(30 * Math.max(0, Math.min(1, col.modelData.v)))
                                    color: root.hot(col.modelData.v) ? Ink.pink : Ink.ink
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
            Mid {
                Cell {
                    x: Math.floor((root.railW - width) / 2)
                    standing: true
                    value: root.ctx.fraction ?? 0
                    color: parent.parent.low ? Ink.red : Ink.ink
                    fill: parent.parent.low ? Ink.red : root.ctx.charging ? Ink.ink : Ink.pink
                }
            }
            MatrixText {
                readonly property string t: String(root.ctx.pct ?? 0)
                font: t.length > 2 ? "3x5" : "5x7"
                text: t
                width: root.railW
                height: t.length > 2 ? 5 : 7
                align: "center"
                color: parent.low ? Ink.red : Ink.ink
            }
            readonly property string action: "pane battery"
        }
    }

    // Messages: MSG in pink small print, the count big in cyan.
    Component {
        id: railMsg
        Stack {
            readonly property int live: root.ctx.live ?? 0
            readonly property bool dnd: !!root.ctx.dnd
            Line {
                text: parent.dnd ? "DND" : "MSG"
                color: parent.dnd ? Ink.label : Ink.pink
                opacity: parent.dnd ? 0.45 : 1
            }
            MatrixText {
                text: String(Math.min(99, parent.live))
                width: root.railW
                height: 7
                align: "center"
                color: parent.live > 0 && !parent.dnd ? Ink.ink : Ink.label
                opacity: parent.dnd ? 0.45 : 1
            }
            readonly property string action: "pane notifs"
        }
    }

    // Capture: the dashed frame and CAP; recording, the red lamp and REC.
    Component {
        id: railCap
        Stack {
            readonly property bool rec: !!root.ctx.recording
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
                color: parent.rec ? Ink.red : Ink.ink
            }
            readonly property string action: rec ? "capture stop" : "pane capture"
        }
    }

    // Caffeine: the cup, the time left (or OFF) under it.
    Component {
        id: railCaf
        Stack {
            readonly property bool on: !!root.ctx.on
            Mid {
                height: 7
                Pix {
                    x: Math.floor((root.railW - 7) / 2)
                    pattern: root.cup
                    inks: parent.parent.on ? [Ink.ink, Ink.pink, Ink.ink] : [Ink.mid, "transparent", Ink.mid]
                }
            }
            Line {
                text: parent.on ? (String(root.ctx.left ?? "").split(" ").pop() || "ON") : "OFF"
                color: parent.on ? Ink.ink : Ink.label
                opacity: parent.on ? 1 : 0.5
            }
            readonly property string action: "caffeine toggle"
        }
    }

    // Clipboard: the sheets, then the last four copies as numbered slots,
    // the newest boxed in cyan (a click pastes that one).
    Component {
        id: railClip
        Stack {
            spacing: 3
            Mid {
                height: 7
                Pix {
                    x: Math.floor((root.railW - 7) / 2)
                    pattern: root.sheets
                    inks: [Ink.label]
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
                    height: 9
                    Rectangle {
                        x: Math.floor((root.railW - 11) / 2)
                        width: 11
                        height: 9
                        color: "transparent"
                        border.width: 1
                        border.color: slot.index === 0 ? Ink.ink : Ink.mid
                    }
                    MatrixText {
                        y: 2
                        font: "3x5"
                        text: String(slot.index + 1)
                        width: root.railW
                        height: 5
                        align: "center"
                        color: slot.index === 0 ? Ink.ink : Ink.label
                    }
                    T.Hit {
                        anchors.fill: parent
                        action: "paste " + slot.index
                    }
                }
            }
        }
    }

    // Todo: a ring per task today (done: a cyan disc; the next: solid
    // pink; the rest dashed), how many are left under.
    Component {
        id: railTodo
        Stack {
            spacing: 3
            Repeater {
                model: (root.ctx.today ?? []).slice(0, 5)
                Mid {
                    required property var modelData
                    height: 7
                    Pix {
                        x: Math.floor((root.railW - 7) / 2)
                        pattern: parent.modelData.done ? root.disc : parent.modelData.next ? root.ring : root.ringDash
                        inks: [parent.modelData.done ? Ink.ink : Ink.pink]
                    }
                }
            }
            Line {
                text: String(root.ctx.left ?? 0)
            }
        }
    }
}
