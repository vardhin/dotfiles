import QtQuick
import qs
import qs.services
import qs.tokyo as T

// A panel docked in the top strip or the side rail, VFD: its strip or rail
// form as the stereo's display draws it (the VFD boards' small forms): the
// small print teal, the readings cyan, the alarms and counts amber, levels
// as segment bars with their unlit cells showing. No casing of its own: it
// sits in the bar's one long window (Dash.qml). In dots, on the bar's
// canvas; 11 dots tall in the strip, `Tokens.railDots` wide in the rail.
// DockItem.qml loads it for the templates in `forms`; the rest keep the
// generic forms. A click where a form has no key of its own falls through
// to the item (the peek); a hold or a drag still lifts it.
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

    // ── Parts ───────────────────────────────────────────────────────
    // 5x7 sits on rows 2..8 of the strip, 3x5 on rows 4..8: one baseline.
    component Big: MatrixText {
        y: 2
        width: implicitWidth
        height: 7
        color: Ink.cyan
    }
    component Small: MatrixText {
        y: 4
        font: "3x5"
        width: implicitWidth
        height: 5
        color: Ink.teal
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
    // A battery: rule round a cell of segments, the nub on its right (or
    // on top, standing).
    component Cell: Item {
        id: bat
        property real value: 0
        property color color: Ink.cyan
        property bool standing: false
        width: standing ? 7 : 14
        height: standing ? 16 : 7
        Rectangle {
            x: 0
            y: bat.standing ? 1 : 0
            width: bat.standing ? 7 : 13
            height: bat.standing ? 15 : 7
            color: "transparent"
            border.width: 1
            border.color: bat.color
            opacity: 0.8
        }
        Rectangle {
            x: bat.standing ? 2 : 13
            y: bat.standing ? 0 : 2
            width: bat.standing ? 3 : 1
            height: bat.standing ? 1 : 3
            color: bat.color
            opacity: 0.8
        }
        Bar {
            x: 2
            y: bat.standing ? 3 : 2
            width: bat.standing ? 3 : 10
            height: bat.standing ? 11 : 3
            vertical: bat.standing
            value: bat.value
            color: bat.color
            cell: bat.standing ? 1 : 2
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
    // Media: the title running across the window on a hairline seek bar,
    // the time in amber; play / pause in front. Nothing playing: NO DISC.
    Component {
        id: stripMedia
        Run {
            readonly property bool on: !!root.ctx.active
            Item {
                visible: parent.on
                width: 5
                height: 11
                Rectangle {
                    visible: !!root.ctx.playing
                    x: 0
                    y: 2
                    width: 2
                    height: 7
                    color: Ink.amber
                }
                Rectangle {
                    visible: !!root.ctx.playing
                    x: 3
                    y: 2
                    width: 2
                    height: 7
                    color: Ink.amber
                }
                Big {
                    visible: !root.ctx.playing
                    text: "▸"
                    color: Ink.amber
                }
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
                    text: String(root.ctx.title ?? "").toUpperCase()
                    scroll: true
                }
                Rectangle {
                    y: 9
                    width: 112
                    height: 1
                    color: Ink.ghost
                }
                Rectangle {
                    y: 9
                    width: Math.round(112 * Math.max(0, Math.min(1, root.ctx.progress ?? 0)))
                    height: 1
                    color: Ink.cyan
                }
                Click {
                    action: "pane media"
                }
            }
            Big {
                visible: parent.on && (root.ctx.len ?? 0) > 0
                y: 1
                text: Media.clock(root.ctx.pos ?? 0)
                color: Ink.amber
            }
            Item {
                visible: !parent.on
                width: idle.width
                height: 11
                Big {
                    id: idle
                    text: "NO DISC"
                    color: Ink.teal
                }
                Click {
                    action: "pane media"
                }
            }
        }
    }

    // Clock: the time over its unlit 88:88, the day in amber.
    Component {
        id: stripClock
        Run {
            Digits {
                y: 2
                text: root.ctx.time ?? ""
                mask: "88:88"
                size: 1
            }
            Small {
                text: String(root.ctx.dateShort ?? "").toUpperCase()
                color: Ink.amber
            }
            readonly property string action: "pane calendar"
        }
    }

    // Workspaces: the presets, the one you are on lit, an amber lamp per
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
                        color: ws.modelData.urgent ? Ink.amber : ws.modelData.focused ? Ink.cyan : Ink.teal
                        opacity: ws.modelData.focused || ws.wins > 0 ? 1 : 0.55
                        T.Hit {
                            anchors.fill: parent
                            anchors.topMargin: -2
                            anchors.bottomMargin: -2
                            anchors.rightMargin: -ws.wins * 4 - 1
                            action: "ws " + ws.modelData.id
                        }
                    }
                    Repeater {
                        model: ws.wins
                        Rectangle {
                            y: 4
                            width: 2
                            height: 5
                            color: Ink.amber
                        }
                    }
                }
            }
            Big {
                text: "+"
                color: Ink.teal
                T.Hit {
                    anchors.fill: parent
                    anchors.margins: -2
                    action: "ws empty"
                }
            }
        }
    }

    // System: CPU, MEM, TEMP, each its teal label, a short segment bar and
    // the reading; a hot reading turns amber.
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
                    Bar {
                        y: 4
                        width: 14
                        height: 5
                        value: rd.modelData.v
                        color: root.hot(rd.modelData.v) ? Ink.amber : Ink.cyan
                    }
                    Big {
                        width: rd.modelData.w
                        align: "right"
                        text: rd.modelData.t
                        color: root.hot(rd.modelData.v) ? Ink.amber : Ink.cyan
                    }
                }
            }
        }
    }

    // Battery: the cell drawn, then the percent; red and ! when low, amber
    // and + while charging.
    Component {
        id: stripBat
        Run {
            readonly property bool shown: !!root.ctx.present
            readonly property bool low: root.ctx.level === "bad"
            readonly property color ink: low ? Ink.red : root.ctx.charging ? Ink.amber : Ink.cyan
            Cell {
                y: 2
                value: root.ctx.fraction ?? 0
                color: parent.ink
            }
            Big {
                text: (root.ctx.pct ?? 0) + "%"
                color: parent.low ? Ink.red : Ink.cyan
            }
            Big {
                visible: parent.low || !!root.ctx.charging
                text: parent.low ? "!" : "+"
                color: parent.low ? Ink.red : Ink.cyan
            }
            readonly property string action: "pane battery"
        }
    }

    // Messages: MSG and the count in amber, the newest in small print. Do
    // not disturb: DND unlit and how many are held.
    Component {
        id: stripMsg
        Run {
            readonly property int live: root.ctx.live ?? 0
            readonly property bool dnd: !!root.ctx.dnd
            readonly property var last: (root.ctx.items ?? [])[0] ?? null
            Digits {
                y: 2
                size: 1
                text: parent.dnd ? "DND" : root.words.icon ?? "MSG"
                color: parent.dnd ? Ink.teal : parent.live > 0 ? Ink.amber : Ink.teal
                opacity: parent.dnd ? 0.6 : 1
            }
            Big {
                visible: !parent.dnd
                text: String(parent.live)
                color: parent.live > 0 ? Ink.amber : Ink.teal
            }
            Small {
                visible: parent.dnd || (parent.live > 0 && parent.last !== null)
                width: parent.dnd ? implicitWidth : 100
                scroll: true
                text: parent.dnd ? parent.live + " HELD" : String((parent.last?.app ?? "") + " · " + (parent.last?.summary ?? "")).toUpperCase()
                color: parent.dnd ? Ink.teal : Ink.cyan
            }
            readonly property string action: "pane notifs"
        }
    }

    // Capture: a frame and CAPTURE; recording, a red lamp and the time,
    // blinking (a click stops it).
    Component {
        id: stripCap
        Run {
            readonly property bool rec: !!root.ctx.recording
            Item {
                width: 7
                height: 11
                Rectangle {
                    visible: !parent.parent.rec
                    y: 3
                    width: 7
                    height: 5
                    color: "transparent"
                    border.width: 1
                    border.color: Ink.cyan
                }
                Rectangle {
                    visible: parent.parent.rec
                    x: 1
                    y: 3
                    width: 5
                    height: 5
                    radius: 2.5
                    color: Ink.red
                    opacity: root.ctx.blink ?? 1
                }
            }
            Big {
                text: parent.rec ? "REC " + (root.ctx.elapsed ?? "") : "CAPTURE"
                color: parent.rec ? Ink.red : Ink.cyan
            }
            readonly property string action: rec ? "capture stop" : "pane capture"
        }
    }

    // Caffeine: its word and the time left in amber while on, teal OFF.
    Component {
        id: stripCaf
        Run {
            readonly property bool on: !!root.ctx.on
            Big {
                text: root.words.icon ?? "WARM"
                color: parent.on ? Ink.amber : Ink.teal
            }
            Big {
                text: parent.on ? (root.ctx.left || "ON") : "OFF"
                color: parent.on ? Ink.amber : Ink.teal
                opacity: parent.on ? 1 : 0.6
            }
            readonly property string action: "caffeine toggle"
        }
    }

    // Clipboard: the memory key in amber, the last copy after it (a click
    // pastes it).
    Component {
        id: stripClip
        Run {
            spacing: 6
            Big {
                text: root.words.icon ?? "M1"
                color: Ink.amber
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
                T.Hit {
                    anchors.fill: parent
                    action: "paste 0"
                }
            }
        }
    }

    // Todo: how many are left in amber, the next one after it.
    Component {
        id: stripTodo
        Run {
            spacing: 3
            Big {
                text: String(root.ctx.left ?? 0)
                color: Ink.amber
            }
            Small {
                text: "LEFT"
                color: Ink.amber
            }
            Item {
                width: 1
                height: 11
            }
            Big {
                width: 112
                scroll: true
                text: String(root.ctx.next || root.words.empty || "ALL DONE").toUpperCase()
                color: root.ctx.next ? Ink.cyan : Ink.teal
            }
        }
    }

    // ── Rail ────────────────────────────────────────────────────────
    // Media: the seek bar standing, then previous, play / pause, next.
    Component {
        id: railMedia
        Stack {
            readonly property bool on: !!root.ctx.active
            spacing: 3
            Mid {
                visible: parent.on
                Bar {
                    x: Math.floor((root.railW - 5) / 2)
                    width: 5
                    height: 20
                    vertical: true
                    value: root.ctx.progress ?? 0
                }
            }
            Repeater {
                model: parent.on ? ["prev", "toggle", "next"] : []
                Mid {
                    id: key
                    required property string modelData
                    height: 7
                    Item {
                        x: Math.floor((root.railW - width) / 2)
                        width: 7
                        height: 7
                        Rectangle {
                            visible: key.modelData === "prev"
                            width: 1
                            height: 7
                            color: Ink.cyan
                        }
                        MatrixText {
                            visible: key.modelData === "prev"
                            x: 1
                            text: "◂"
                            width: 5
                            height: 7
                            color: Ink.cyan
                        }
                        MatrixText {
                            visible: key.modelData === "next"
                            x: 1
                            text: "▸"
                            width: 5
                            height: 7
                            color: Ink.cyan
                        }
                        Rectangle {
                            visible: key.modelData === "next"
                            x: 6
                            width: 1
                            height: 7
                            color: Ink.cyan
                        }
                        Rectangle {
                            visible: key.modelData === "toggle" && !!root.ctx.playing
                            x: 1
                            width: 2
                            height: 7
                            color: Ink.amber
                        }
                        Rectangle {
                            visible: key.modelData === "toggle" && !!root.ctx.playing
                            x: 4
                            width: 2
                            height: 7
                            color: Ink.amber
                        }
                        MatrixText {
                            visible: key.modelData === "toggle" && !root.ctx.playing
                            x: 1
                            text: "▸"
                            width: 5
                            height: 7
                            color: Ink.amber
                        }
                    }
                    T.Hit {
                        anchors.fill: parent
                        action: key.modelData === "prev" ? "media previous" : key.modelData === "next" ? "media next" : "media toggle"
                    }
                }
            }
            Mid {
                visible: !parent.on
                height: 12
                Column {
                    x: Math.floor((root.railW - width) / 2)
                    spacing: 2
                    MatrixText {
                        font: "3x5"
                        text: "NO"
                        width: 15
                        height: 5
                        align: "center"
                        color: Ink.teal
                    }
                    MatrixText {
                        font: "3x5"
                        text: "DISC"
                        width: 15
                        height: 5
                        align: "center"
                        color: Ink.teal
                    }
                }
                T.Hit {
                    anchors.fill: parent
                    action: "pane media"
                }
            }
        }
    }

    // Clock: the hours over the minutes, each on its unlit 88, the day
    // and date in amber.
    Component {
        id: railClock
        Stack {
            Repeater {
                model: [root.ctx.hh ?? "", root.ctx.mm ?? ""]
                Mid {
                    required property string modelData
                    Digits {
                        x: Math.floor((root.railW - 11) / 2)
                        text: parent.modelData
                        mask: "88"
                        size: 1
                    }
                }
            }
            Item {
                width: 1
                height: 1
            }
            Repeater {
                model: [String(root.ctx.date ?? "").slice(0, 3).toUpperCase(), root.ctx.dd ?? ""]
                MatrixText {
                    required property string modelData
                    font: "3x5"
                    text: modelData
                    width: root.railW
                    height: 5
                    align: "center"
                    color: Ink.amber
                }
            }
            readonly property string action: "pane calendar"
        }
    }

    // Workspaces: the presets stacked, an amber lamp per window under each.
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
                    height: wins > 0 ? 11 : 7
                    MatrixText {
                        text: ws.modelData.home ? "⌂" : String(ws.modelData.id)
                        width: root.railW
                        height: 7
                        align: "center"
                        color: ws.modelData.urgent ? Ink.amber : ws.modelData.focused ? Ink.cyan : Ink.teal
                        opacity: ws.modelData.focused || ws.wins > 0 ? 1 : 0.55
                    }
                    Row {
                        x: Math.floor((root.railW - width) / 2)
                        y: 9
                        spacing: 1
                        Repeater {
                            model: ws.wins
                            Rectangle {
                                width: 2
                                height: 2
                                color: Ink.amber
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

    // System: three segment columns, C M T under them.
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
                            Bar {
                                width: 3
                                height: 30
                                vertical: true
                                cell: 1
                                value: col.modelData.v
                                color: root.hot(col.modelData.v) ? Ink.amber : Ink.cyan
                            }
                            MatrixText {
                                font: "3x5"
                                text: col.modelData.k
                                width: 3
                                height: 5
                                color: Ink.teal
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
                    color: parent.parent.low ? Ink.red : root.ctx.charging ? Ink.amber : Ink.cyan
                }
            }
            MatrixText {
                readonly property string t: String(root.ctx.pct ?? 0)
                font: t.length > 2 ? "3x5" : "5x7"
                text: t
                width: root.railW
                height: t.length > 2 ? 5 : 7
                align: "center"
                color: parent.low ? Ink.red : Ink.cyan
            }
            readonly property string action: "pane battery"
        }
    }

    // Messages: MSG in small print, the count big in amber.
    Component {
        id: railMsg
        Stack {
            readonly property int live: root.ctx.live ?? 0
            readonly property bool dnd: !!root.ctx.dnd
            MatrixText {
                font: "3x5"
                text: parent.dnd ? "DND" : root.words.icon ?? "MSG"
                width: root.railW
                height: 5
                align: "center"
                color: Ink.teal
                opacity: parent.dnd ? 0.6 : 1
            }
            MatrixText {
                text: String(Math.min(99, parent.live))
                width: root.railW
                height: 7
                align: "center"
                color: parent.live > 0 && !parent.dnd ? Ink.amber : Ink.teal
            }
            readonly property string action: "pane notifs"
        }
    }

    // Capture: the frame and CAP; recording, the red lamp and REC.
    Component {
        id: railCap
        Stack {
            readonly property bool rec: !!root.ctx.recording
            Mid {
                height: 7
                Rectangle {
                    visible: !parent.parent.rec
                    x: Math.floor((root.railW - 9) / 2)
                    width: 9
                    height: 7
                    color: "transparent"
                    border.width: 1
                    border.color: Ink.cyan
                }
                Rectangle {
                    visible: parent.parent.rec
                    x: Math.floor((root.railW - 7) / 2)
                    width: 7
                    height: 7
                    radius: 3.5
                    color: Ink.red
                    opacity: root.ctx.blink ?? 1
                }
            }
            MatrixText {
                font: "3x5"
                text: parent.rec ? "REC" : "CAP"
                width: root.railW
                height: 5
                align: "center"
                color: parent.rec ? Ink.red : Ink.teal
            }
            readonly property string action: rec ? "capture stop" : "pane capture"
        }
    }

    // Caffeine: its word, and the time left (or OFF) under it.
    Component {
        id: railCaf
        Stack {
            readonly property bool on: !!root.ctx.on
            MatrixText {
                font: "3x5"
                text: root.words.icon ?? "WARM"
                width: root.railW
                height: 5
                align: "center"
                color: parent.on ? Ink.amber : Ink.teal
            }
            MatrixText {
                font: "3x5"
                text: parent.on ? (String(root.ctx.left ?? "").split(" ").pop() || "ON") : "OFF"
                width: root.railW
                height: 5
                align: "center"
                color: parent.on ? Ink.amber : Ink.teal
                opacity: parent.on ? 1 : 0.6
            }
            readonly property string action: "caffeine toggle"
        }
    }

    // Clipboard: the memory key in amber, how many are kept under it.
    Component {
        id: railClip
        Stack {
            MatrixText {
                font: "3x5"
                text: root.words.icon ?? "M1"
                width: root.railW
                height: 5
                align: "center"
                color: Ink.amber
            }
            MatrixText {
                text: String(Math.min(99, root.ctx.count ?? 0))
                width: root.railW
                height: 7
                align: "center"
                color: Ink.cyan
            }
            readonly property string action: "pane clip"
        }
    }

    // Todo: a lamp per task today (lit: done), how many are left under.
    Component {
        id: railTodo
        Stack {
            Repeater {
                model: (root.ctx.today ?? []).slice(0, 5)
                Mid {
                    required property var modelData
                    height: 5
                    Rectangle {
                        x: Math.floor((root.railW - 5) / 2)
                        width: 5
                        height: 5
                        radius: 2.5
                        color: parent.modelData.done ? Ink.cyan : "transparent"
                        border.width: 1
                        border.color: parent.modelData.done ? Ink.cyan : parent.modelData.next ? Ink.amber : Ink.teal
                    }
                }
            }
            MatrixText {
                font: "3x5"
                text: String(root.ctx.left ?? 0)
                width: root.railW
                height: 5
                align: "center"
                color: Ink.amber
            }
        }
    }
}
