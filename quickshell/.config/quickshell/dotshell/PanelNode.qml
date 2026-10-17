import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import "Bind.js" as Bind
import "Skins.js" as Skins

// One node of a panel layout (Templates.js), drawn on a DotSurface canvas
// (1 px = 1 dot). Rows and columns lay their children out with Qt Layouts;
// each child is another PanelNode, loaded by URL (a type cannot contain
// itself directly). Leaves are the field types listed in Templates.js.
//
//   PanelNode { node: layout; ctx: feed; sink: panel; width: cols; height: rows }
// `sink.run(action)` takes every click with an action (Actions.qml).
Item {
    id: root

    property var node: ({})
    property var ctx: ({})
    // Whoever runs actions (DeskPanel: run(action) and fold/expand).
    property var sink: null
    // The panel's own tube; fields with no slot draw in it.
    property color tube: Tokens.slot0
    property string era: Tokens.era

    readonly property string kind: node?.row ? "row" : node?.col ? "col" : (node?.field ?? "space")
    readonly property bool shown: Bind.truth(ctx, node?.when)
    readonly property bool horizontal: kind === "row"
    readonly property var kids: node?.row ?? node?.col ?? []
    readonly property var skin: Skins.get(era)

    visible: shown
    implicitWidth: body.item ? body.item.implicitWidth + pad * 2 : 0
    implicitHeight: body.item ? body.item.implicitHeight + pad * 2 : 0
    readonly property int pad: Number(node?.pad ?? 0)

    // ── Shared helpers ──────────────────────────────────────────────
    function txt(s: var): string {
        return Bind.text(ctx, s);
    }
    // A slot: 0 1 2, "dim" (secondary at half), "@" (the panel's), or bound.
    function colorOf(s: var): color {
        if (s === undefined || s === null || s === "" || s === "@")
            return tube;
        if (typeof s === "string" && s.indexOf("{") >= 0)
            s = Bind.text(ctx, s);
        if (s === "dim")
            return Tokens.slot1;
        if (s === "@")
            return tube;
        const n = Number(s);
        return n === 1 ? Tokens.slot1 : n === 2 ? Tokens.slot2 : n === 0 ? Tokens.slot0 : tube;
    }
    function dimOf(s: var): real {
        if (typeof s === "string" && s.indexOf("{") >= 0)
            s = Bind.text(ctx, s);
        return s === "dim" ? 0.5 : 1;
    }
    function opacityOf(v: var): real {
        if (v === undefined || v === null || v === "")
            return 1;
        const n = Number(typeof v === "string" ? Bind.text(ctx, v) : v);
        return isNaN(n) ? 1 : Math.max(0, Math.min(1, n));
    }
    function run(action: string): void {
        if (action && sink)
            sink.run(action);
    }
    readonly property string action: node?.action ? txt(node.action) : ""

    // Default sizing of a child inside a row or column.
    function fills(spec: var, alongRow: bool): bool {
        const t = spec?.row ? "row" : spec?.col ? "col" : (spec?.field ?? "space");
        const key = alongRow ? spec?.w : spec?.h;
        if (key === "fill")
            return true;
        if (key !== undefined || (!alongRow && spec?.lines))
            return false;
        if (alongRow)
            return !["label", "status", "glyph", "big", "row", "col", "tray", "rule"].includes(t) || (t === "list" && spec.dir !== "row");
        return ["list", "art", "spectrum", "spark", "notebar", "lyrics", "video", "image", "pixels", "space", "big"].includes(t) && !(t === "list" && spec.dir === "row");
    }

    Loader {
        id: body
        anchors.fill: parent
        anchors.margins: root.pad
        active: root.shown
        sourceComponent: {
            switch (root.kind) {
            case "row":
            case "col":
                return container;
            case "label":
            case "glyph":
                return label;
            case "status":
                return status;
            case "big":
                return big;
            case "meter":
                return meter;
            case "vmeter":
                return vmeter;
            case "progress":
                return progress;
            case "spark":
                return spark;
            case "list":
                return list;
            case "art":
            case "thumb":
                return art;
            case "image":
                return image;
            case "pixels":
                return pixels;
            case "marquee":
                return marquee;
            case "spectrum":
                return spectrum;
            case "notebar":
                return notebar;
            case "lyrics":
                return lyrics;
            case "video":
                return video;
            case "tray":
                return tray;
            case "input":
                return input;
            case "rule":
                return rule;
            default:
                return space;
            }
        }
    }

    // A click anywhere on a node with an action (inputs and seek bars take
    // their own clicks).
    MouseArea {
        id: hit
        anchors.fill: parent
        enabled: root.action !== "" && root.kind !== "input" && root.kind !== "progress"
        hoverEnabled: enabled
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.run(root.action)
    }

    // ── Containers ──────────────────────────────────────────────────
    Component {
        id: container

        GridLayout {
            id: grid
            flow: root.horizontal ? GridLayout.LeftToRight : GridLayout.TopToBottom
            rows: root.horizontal ? 1 : -1
            columns: root.horizontal ? -1 : 1
            readonly property int gap: Number(root.node.gap ?? (root.horizontal ? 4 : 1))
            columnSpacing: gap
            rowSpacing: gap

            Repeater {
                model: root.kids

                Loader {
                    id: child
                    required property var modelData
                    readonly property var spec: modelData ?? ({})
                    source: "PanelNode.qml"
                    visible: item ? item.shown : false

                    readonly property bool fillW: root.horizontal ? root.fills(spec, true) : spec.w === undefined || spec.w === "fill"
                    readonly property bool fillH: root.horizontal ? (spec.h === undefined || spec.h === "fill") : root.fills(spec, false)
                    readonly property int fixedW: typeof spec.w === "number" ? spec.w : spec.w === "square" ? Math.round(spec.h ?? grid.height) : -1
                    readonly property int fixedH: typeof spec.h === "number" ? spec.h : spec.lines ? spec.lines * Tokens.lineDots : -1

                    Layout.fillWidth: fixedW < 0 && fillW
                    Layout.fillHeight: fixedH < 0 && fillH
                    Layout.preferredWidth: fixedW >= 0 ? fixedW : (item ? item.implicitWidth : 0)
                    Layout.preferredHeight: fixedH >= 0 ? fixedH : (item ? item.implicitHeight : 0)
                    Layout.maximumWidth: fixedW >= 0 ? fixedW : Number.POSITIVE_INFINITY
                    Layout.maximumHeight: fixedH >= 0 ? fixedH : Number.POSITIVE_INFINITY
                    Layout.minimumWidth: 0
                    Layout.minimumHeight: 0

                    onLoaded: {
                        item.node = Qt.binding(() => child.spec);
                        item.ctx = Qt.binding(() => root.ctx);
                        item.sink = Qt.binding(() => root.sink);
                        item.tube = Qt.binding(() => root.tube);
                        item.era = Qt.binding(() => root.era);
                    }
                }
            }
        }
    }

    // ── Text ────────────────────────────────────────────────────────
    Component {
        id: label

        Item {
            id: lab
            readonly property string text: root.txt(root.node.text)
            readonly property int size: Math.max(1, Number(root.node.size ?? 1))
            readonly property bool wrap: !!root.node.wrap
            // Too long: elided, and runs like a sign while hovered (or
            // always, with scroll: "always").
            readonly property bool scrolls: !!root.node.scroll && one.implicitWidth > width && (root.node.scroll === "always" || hov.hovered)
            readonly property color ink: root.colorOf(root.node.slot)
            implicitWidth: wrap ? 40 : one.implicitWidth
            implicitHeight: wrap ? Math.max(Tokens.lineDots, note.implicitHeight) : Tokens.fontPx * size + 2
            opacity: root.dimOf(root.node.slot) * root.opacityOf(root.node.opacity)
            clip: true

            HoverHandler {
                id: hov
                enabled: !!root.node.scroll
            }
            DotText {
                id: one
                visible: !lab.wrap && !lab.scrolls
                width: parent.width
                size: lab.size
                text: lab.text
                color: lab.ink
                elide: Text.ElideRight
                horizontalAlignment: root.node.align === "center" ? Text.AlignHCenter : root.node.align === "right" ? Text.AlignRight : Text.AlignLeft
            }
            Scroller {
                visible: lab.scrolls
                width: parent.width
                height: parent.height
                text: lab.text
                color: lab.ink
            }
            DotLabel {
                id: note
                visible: lab.wrap
                width: parent.width
                wrapMode: Text.Wrap
                maximumLineCount: Math.max(1, Math.floor(parent.height / Tokens.lineDots))
                text: lab.text
                color: lab.ink
            }
            // Hover: a one-dot underline, like the strip's words.
            Rectangle {
                visible: hit.containsMouse
                y: parent.height - 1
                width: Math.min(parent.width, one.implicitWidth)
                height: 1
                color: lab.ink
            }
            // Underline on a bound condition (the focused workspace).
            Rectangle {
                visible: !!root.node.underline && Bind.truth(root.ctx, root.node.underline)
                y: parent.height - 1
                width: Math.min(parent.width, one.implicitWidth)
                height: 1
                color: lab.ink
            }
        }
    }

    Component {
        id: status

        Item {
            readonly property string level: root.txt(root.node.level) || "ok"
            implicitWidth: word.implicitWidth
            implicitHeight: Tokens.lineDots
            DotText {
                id: word
                width: parent.width
                text: root.txt(root.node.text)
                color: parent.level === "bad" ? Tokens.slot2 : parent.level === "warn" ? Tokens.slot1 : root.colorOf(root.node.slot)
                opacity: parent.level === "bad" && blink.lit ? 0.45 : 1
            }
            Timer {
                id: blink
                property bool lit: false
                running: parent.level === "bad" && root.visible
                interval: 600
                repeat: true
                onTriggered: lit = !lit
            }
        }
    }

    Component {
        id: big

        Item {
            id: bg
            readonly property string text: root.txt(root.node.text)
            readonly property int chars: Math.max(1, text.length)
            readonly property int size: root.node.size ? Number(root.node.size) : Math.max(1, Math.min(Math.floor(width / (chars * Tokens.charDots)), Math.floor(height / Tokens.fontPx)))
            implicitWidth: chars * Tokens.charDots * 2
            implicitHeight: Tokens.fontPx * 2
            DotText {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: Tokens.fontPx * bg.size
                size: bg.size
                text: bg.text
                color: root.colorOf(root.node.slot)
                opacity: root.dimOf(root.node.slot)
                horizontalAlignment: root.node.align === "left" ? Text.AlignLeft : root.node.align === "right" ? Text.AlignRight : Text.AlignHCenter
            }
        }
    }

    Component {
        id: marquee

        Marquee {
            implicitWidth: 80
            implicitHeight: Tokens.lineDots
            passes: 1000000
            stepMs: 40
            text: root.txt(root.node.text)
            color: root.colorOf(root.node.slot)
            onTextChanged: run()
            Component.onCompleted: run()
        }
    }

    // ── Bars ────────────────────────────────────────────────────────
    Component {
        id: meter
        DotBar {
            blocks: ["vfd", "gameboy", "arcade", "nixie"].includes(root.era)
            implicitWidth: 40
            implicitHeight: 3
            value: Bind.num(root.ctx, root.node.value)
            ink: value >= Number(root.node.warn ?? 0.85) ? Tokens.slot2 : root.colorOf(root.node.slot)
        }
    }

    Component {
        id: vmeter
        DotBar {
            blocks: ["vfd", "gameboy", "arcade", "nixie"].includes(root.era)
            implicitWidth: 3
            implicitHeight: 20
            vertical: true
            value: Bind.num(root.ctx, root.node.value)
            ink: value >= Number(root.node.warn ?? 0.85) ? Tokens.slot2 : root.colorOf(root.node.slot)
        }
    }

    Component {
        id: progress

        Item {
            id: pg
            readonly property real total: root.node.total !== undefined ? Bind.num(root.ctx, root.node.total, 0) : 1
            readonly property real fraction: total > 0 ? Math.max(0, Math.min(1, Bind.num(root.ctx, root.node.value) / total)) : 0
            readonly property int lit: Math.round(fraction * width)
            implicitWidth: 40
            implicitHeight: 3
            Rectangle {
                y: Math.floor(parent.height / 2)
                width: parent.width
                height: 1
                color: Tokens.slot1
                opacity: 0.4
            }
            Rectangle {
                y: Math.floor(parent.height / 2)
                width: pg.lit
                height: 1
                color: root.colorOf(root.node.slot)
            }
            // The head: a brighter dot standing out of the line.
            Rectangle {
                visible: pg.fraction > 0
                x: Math.max(0, pg.lit - 1)
                width: 1
                height: parent.height
                color: Tokens.slot2
            }
            MouseArea {
                anchors.fill: parent
                enabled: root.action !== ""
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: mouse => root.run(root.action + " " + (mouse.x / width).toFixed(4))
            }
        }
    }

    Component {
        id: spark

        Item {
            id: sp
            readonly property var all: Bind.list(root.ctx, root.node.values)
            readonly property int n: Math.max(1, Math.floor((width + 1) / 2))
            readonly property var shown: all.slice(-n)
            implicitWidth: 40
            implicitHeight: 8
            Row {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                spacing: 1
                Repeater {
                    model: sp.shown
                    Rectangle {
                        required property var modelData
                        width: 1
                        height: Math.max(1, Math.round(Math.max(0, Math.min(1, Number(modelData) || 0)) * sp.height))
                        anchors.bottom: parent.bottom
                        color: Number(modelData) >= 0.85 ? Tokens.slot2 : root.colorOf(root.node.slot)
                    }
                }
            }
        }
    }

    // ── Lists ───────────────────────────────────────────────────────
    Component {
        id: list

        Item {
            id: ls
            readonly property bool across: root.node.dir === "row"
            readonly property var items: Bind.list(root.ctx, root.node.items).slice(0, Number(root.node.max ?? 50))
            readonly property int gap: Number(root.node.gap ?? (across ? 4 : 0))
            readonly property bool split: across && root.node.item?.w === "fill"
            clip: true
            implicitWidth: across ? flow.implicitWidth : 40
            implicitHeight: across ? Tokens.lineDots : (items.length === 0 ? Tokens.lineDots : col.implicitHeight)

            DotText {
                visible: ls.items.length === 0 && !!root.node.empty
                width: parent.width
                height: Tokens.lineDots
                text: root.txt(root.node.empty)
                color: Tokens.slot1
                opacity: 0.5
            }

            // Only whole rows: as many as fit the list's height.
            readonly property int rowH: Math.max(1, col.children.length > 0 && col.children[0].height > 0 ? col.children[0].height : Tokens.lineDots)
            readonly property int fit: height > 0 ? Math.max(1, Math.floor((height + gap) / (rowH + gap))) : items.length
            Column {
                id: col
                visible: !ls.across
                width: parent.width
                spacing: ls.gap
                Repeater {
                    model: ls.across ? [] : ls.items.slice(0, ls.fit)
                    Loader {
                        id: row
                        required property var modelData
                        required property int index
                        width: col.width
                        height: item ? item.implicitHeight : 0
                        source: "PanelNode.qml"
                        onLoaded: {
                            item.node = Qt.binding(() => root.node.item);
                            item.ctx = Qt.binding(() => Bind.item(root.ctx, row.modelData, row.index));
                            item.sink = Qt.binding(() => root.sink);
                            item.tube = Qt.binding(() => root.tube);
                            item.era = Qt.binding(() => root.era);
                        }
                        // Split-flap: a dark seam through each row.
                        Rectangle {
                            visible: root.skin.flaps === true && parent.height > 6
                            y: Math.floor(parent.height / 2)
                            width: parent.width
                            height: 1
                            color: Tokens.glass
                            opacity: 0.8
                        }
                    }
                }
            }

            Row {
                id: flow
                visible: ls.across
                height: parent.height
                spacing: ls.gap
                Repeater {
                    model: ls.across ? ls.items : []
                    Loader {
                        id: cell
                        required property var modelData
                        required property int index
                        height: flow.height
                        width: ls.split ? Math.floor((ls.width - ls.gap * (ls.items.length - 1)) / Math.max(1, ls.items.length)) : (typeof root.node.item?.w === "number" ? root.node.item.w : (item ? item.implicitWidth : 0))
                        source: "PanelNode.qml"
                        onLoaded: {
                            item.node = Qt.binding(() => root.node.item);
                            item.ctx = Qt.binding(() => Bind.item(root.ctx, cell.modelData, cell.index));
                            item.sink = Qt.binding(() => root.sink);
                            item.tube = Qt.binding(() => root.tube);
                            item.era = Qt.binding(() => root.era);
                        }
                    }
                }
            }
        }
    }

    // ── Pictures ────────────────────────────────────────────────────
    function srcOf(v: var): string {
        let s = typeof v === "string" && v.startsWith("@") ? Bind.get(ctx, v) : Bind.get(ctx, v);
        s = String(s ?? "");
        if (!s)
            return "";
        if (/^[a-z]+:/.test(s))
            return s;
        return "file://" + s.replace(/^~(?=\/)/, Quickshell.env("HOME"));
    }

    Component {
        id: art

        Item {
            readonly property string src: root.srcOf(root.node.src)
            implicitWidth: 24
            implicitHeight: 24
            // Plain: sharp, over the dots. Dots: the picture as LEDs.
            PlainArt {
                anchors.fill: parent
                visible: !root.node.dots
                source: visible ? parent.src : ""
            }
            Image {
                anchors.fill: parent
                visible: !!root.node.dots
                source: visible ? parent.src : ""
                sourceSize: Qt.size(width, height)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
            }
        }
    }

    Component {
        id: image
        Item {
            implicitWidth: 24
            implicitHeight: 24
            Image {
                anchors.fill: parent
                source: root.srcOf(root.node.src)
                sourceSize: Qt.size(width, height)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
            }
        }
    }

    Component {
        id: pixels
        Item {
            implicitWidth: 24
            implicitHeight: 24
            Image {
                readonly property var frame: Panels.frames[root.ctx?.["@"]?.id ?? ""] ?? null
                anchors.fill: parent
                source: frame ? "data:image/x-portable-pixmap;base64," + frame.data : ""
                smooth: false
                cache: false
            }
        }
    }

    // ── Media ───────────────────────────────────────────────────────
    Component {
        id: spectrum
        Spectrum {
            implicitWidth: 48
            implicitHeight: 12
            bars: Math.max(4, Math.min(32, Math.floor((width + 1) / 3)))
        }
    }

    Component {
        id: notebar
        NoteBar {
            implicitWidth: 72
            implicitHeight: 10
        }
    }

    Component {
        id: lyrics
        LyricsView {
            implicitWidth: 80
            implicitHeight: Tokens.lineDots * 3
            tube: root.tube
        }
    }

    Component {
        id: video
        MatchVideo {
            implicitWidth: 64
            implicitHeight: 36
        }
    }

    Component {
        id: tray
        TrayIcons {
            vertical: !!root.node.vertical
            only: root.node.only ? root.txt(root.node.only) : ""
        }
    }

    // ── Input ───────────────────────────────────────────────────────
    Component {
        id: input

        Item {
            implicitWidth: 60
            implicitHeight: Tokens.lineDots
            DotInput {
                id: field
                anchors.fill: parent
                onAccepted: {
                    const v = text.trim();
                    if (v !== "" && root.node.action)
                        root.run(Bind.text(Object.assign({}, root.ctx, { value: v }), root.node.action).replace("{value}", v));
                    text = "";
                }
                Keys.onEscapePressed: {
                    field.text = "";
                    if (root.sink)
                        root.sink.run("panel fold");
                }
            }
            DotText {
                visible: field.text === "" && !field.activeFocus
                width: parent.width
                text: root.txt(root.node.hint)
                color: Tokens.slot1
                opacity: 0.5
            }
            MouseArea {
                anchors.fill: parent
                visible: !field.activeFocus
                cursorShape: Qt.IBeamCursor
                onClicked: {
                    if (root.sink)
                        root.sink.run("panel keys");
                    field.forceActiveFocus();
                }
            }
        }
    }

    Component {
        id: rule
        Rectangle {
            implicitWidth: 1
            implicitHeight: 1
            color: Tokens.slot1
            opacity: 0.35
        }
    }

    Component {
        id: space
        Item {
            implicitWidth: 0
            implicitHeight: 0
        }
    }
}
