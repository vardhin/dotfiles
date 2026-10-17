import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import qs.services
import "Shapes.js" as Shapes
import "Skins.js" as Skins
import "Templates.js" as Templates

// One panel on the home workspace (see services/Panels.qml): its template's
// layout (Templates.js) bound to its feed (Feeds.qml), drawn by PanelNode on
// a DotSurface inside the era's frame (Skins.js).
//   click            expand (or the template's own click); click outside folds
//   hold 200 ms, or drag     lift it: the strip and the rail arm their slots;
//                    drop near the top to dock it in the strip, near the right
//                    edge for the rail, anywhere else to move it (24 px grid)
Item {
    id: root

    required property var panel
    // The screen size, for the dock zones and keeping expanded panels on it.
    property int screenW: 1920
    property int screenH: 1080

    readonly property int unit: Panels.unit
    readonly property var template: Templates.get(panel.template)
    readonly property bool expanded: Panels.expanded === panel.id
    readonly property string mode: expanded ? "expanded" : "compact"
    readonly property var layout: Templates.layout(template, mode, panel.layout)
    readonly property string feedId: panel.feed || template?.feed || ""
    readonly property var skin: Skins.get(Tokens.era)
    readonly property var words: Skins.words(Tokens.era, template)

    // The size in px: compact is the panel's own; expanded the template's
    // big size (never smaller), kept on screen.
    readonly property int pxW: (expanded ? Math.max(panel.w, template?.big?.w ?? panel.w) : panel.w) * unit
    readonly property int pxH: (expanded ? Math.max(panel.h, template?.big?.h ?? panel.h) : panel.h) * unit
    readonly property int homeX: Math.max(0, Math.min(panel.x * unit, screenW - pxW))
    readonly property int homeY: Math.max(0, Math.min(panel.y * unit, screenH - pxH))

    readonly property int cols: Math.max(1, Math.floor(pxW / Tokens.pitch))
    readonly property int rows: Math.max(1, Math.floor(pxH / Tokens.pitch))
    readonly property color tube: [Tokens.slot0, Tokens.slot1, Tokens.slot2][panel.slot] ?? Tokens.slot0
    readonly property bool raw: panel.dot === false
    readonly property bool photo: panel.template === "image"
    readonly property bool rect: panel.shape === "rect" || panel.shape === ""

    // Frame insets in dots: the ring, and the title band when the era has one.
    readonly property bool header: skin.header === true && rows >= 30 && !["sign", "image", "pixels", "dock"].includes(panel.template)
    readonly property int edge: raw ? 0 : skin.frame === "bezel" ? 4 : skin.frame === "double" ? 4 : 2
    readonly property int topInset: edge + (header ? Tokens.lineDots + 1 : 0)
    readonly property int inset: rect ? 0 : Math.round(Math.min(cols, rows) * 0.14)

    // ── Feed ────────────────────────────────────────────────────────
    readonly property var ctx: Object.assign({ "~": words, "@": panel }, Feeds.get(feedId))
    Component.onCompleted: want(true)
    Component.onDestruction: want(false)
    onVisibleChanged: want(visible)
    onExpandedChanged: Sys.want("top-" + panel.id, expanded && panel.template === "system")
    function want(on: bool): void {
        if (feedId)
            Feeds.want(feedId, panel.id, on);
        for (const w of template?.wants ?? [])
            Feeds.want(w, panel.id, on);
    }

    // Actions from the layout: panel verbs here, the rest to Actions.qml.
    QtObject {
        id: sink
        function run(a: string): void {
            const w = a.split(/\s+/);
            if (w[0] === "panel") {
                if (w[1] === "expand")
                    Panels.expand(root.panel.id);
                else if (w[1] === "fold")
                    Panels.fold();
                else if (w[1] === "pop")
                    Panels.pop(root.panel.id, w[2]);
                else if (w[1] === "keys")
                    Panels.typing = true;
                return;
            }
            Actions.run(a);
        }
    }

    // ── Placement and drag ──────────────────────────────────────────
    property point drag: Qt.point(0, 0)
    property bool lifted: false
    readonly property string target: lifted ? (Panels.drag?.target ?? "home") : "home"
    readonly property bool overDock: lifted && target !== "home"

    x: homeX + drag.x
    y: homeY + drag.y
    width: pxW
    height: pxH
    z: lifted ? 3 : expanded ? 2 : 0
    // Over a dock slot the board shrinks toward the cursor and fades: the
    // slot shows its strip or rail form as a live ghost instead.
    scale: overDock ? 0.42 : lifted ? 0.97 : 1
    opacity: overDock ? 0.3 : 1
    rotation: lifted && !overDock ? -1.5 : 0
    transformOrigin: Item.TopLeft
    Behavior on scale {
        NumberAnimation {
            duration: 140
            easing.type: Easing.OutCubic
        }
    }
    Behavior on width {
        enabled: !root.lifted
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
        }
    }
    Behavior on height {
        enabled: !root.lifted
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
        }
    }

    // Where would a drop at (sx, sy) screen px land?
    function aim(sx: real, sy: real): var {
        const stripH = Tokens.top ? Tokens.pitch * 11 : -1000;
        const railW = Tokens.side === "off" ? -1000 : Tokens.pitch * 13;
        if (Tokens.top && sy < stripH + 48)
            return Object.assign({ target: "strip" }, Dock.stripAim(sx, screenW));
        if (Tokens.side !== "off" && sx > screenW - railW - 48)
            return { target: "rail", zone: "", order: Dock.railAim(sy) };
        return { target: "home", zone: "", order: 0 };
    }

    MouseArea {
        id: grab
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: root.lifted ? Qt.ClosedHandCursor : Qt.ArrowCursor
        property point start
        property point grabOffset
        property bool moved: false

        Timer {
            id: hold
            interval: 200
            onTriggered: root.lift()
        }

        onPressed: mouse => {
            start = mapToItem(root.parent, mouse.x, mouse.y);
            grabOffset = Qt.point(mouse.x, mouse.y);
            moved = false;
            hold.restart();
        }
        onPositionChanged: mouse => {
            const p = mapToItem(root.parent, mouse.x, mouse.y);
            const dx = p.x - start.x, dy = p.y - start.y;
            if (!root.lifted && Math.abs(dx) + Math.abs(dy) > 6)
                root.lift();
            if (!root.lifted)
                return;
            moved = true;
            root.drag = Qt.point(dx, dy);
            const a = root.aim(p.x, p.y);
            Panels.drag = Object.assign({ id: root.panel.id, from: "home", x: p.x, y: p.y }, a);
        }
        onReleased: mouse => {
            hold.stop();
            if (!root.lifted) {
                root.click();
                return;
            }
            const d = Panels.drag;
            root.lifted = false;
            Panels.drag = null;
            if (d && d.target !== "home") {
                root.drag = Qt.point(0, 0);
                Panels.place(root.panel.id, d.target, d.zone, d.order, 0, 0);
                return;
            }
            // Home: snap to the 24 px grid (two units).
            const nx = Math.round((root.homeX + root.drag.x) / (root.unit * 2)) * 2;
            const ny = Math.round((root.homeY + root.drag.y) / (root.unit * 2)) * 2;
            root.drag = Qt.point(0, 0);
            if (nx !== root.panel.x || ny !== root.panel.y)
                Panels.move(root.panel.id, Math.max(0, nx), Math.max(0, ny));
        }
        onCanceled: {
            hold.stop();
            root.lifted = false;
            root.drag = Qt.point(0, 0);
            Panels.drag = null;
        }
    }

    function lift(): void {
        if (lifted)
            return;
        lifted = true;
        Panels.fold();
        Panels.typing = false;
        Panels.drag = { id: panel.id, from: "home", target: "home", zone: "", order: 0, x: x, y: y };
    }

    function click(): void {
        const c = template?.click ?? "expand";
        if (c === "none")
            return;
        if (c === "expand") {
            if (template && (template.expanded || template.big))
                Panels.expand(panel.id);
            return;
        }
        sink.run(c);
    }

    // ── The board ───────────────────────────────────────────────────
    DotSurface {
        id: surface
        cols: root.cols
        rows: root.rows
        flat: root.raw
        visible: !(root.raw && root.photo)
        shape: root.rect && root.skin.round > 0 && !root.raw ? Shapes.rounded(root.cols, root.rows, root.skin.round) : Shapes.path(root.panel.shape, root.cols, root.rows)

        // ── Frame ──
        LedRing {
            visible: Tokens.borders && !root.raw && root.rect && (root.skin.frame === "ring" || root.skin.frame === "double")
            width: root.cols
            height: root.rows
            color: root.tube
            gain: LedFx.on ? 0.7 : 0.6
            offset: (root.cols * 7 + root.rows * 13) % 100 / 100
        }
        // Double rule: a second, still ring two dots in.
        Rectangle {
            visible: !root.raw && root.rect && root.skin.frame === "double"
            x: 2
            y: 2
            width: root.cols - 4
            height: root.rows - 4
            color: "transparent"
            border.width: 1
            border.color: root.tube
            opacity: 0.55
        }
        // Plain: one still ring.
        Rectangle {
            visible: !root.raw && root.rect && root.skin.frame === "plain"
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: root.tube
        }
        // Bezel: a dim two-dot surround, then the ring.
        Rectangle {
            visible: !root.raw && root.rect && root.skin.frame === "bezel"
            anchors.fill: parent
            color: "transparent"
            border.width: 2
            border.color: Tokens.slot1
            opacity: 0.3
        }
        Rectangle {
            visible: !root.raw && root.rect && root.skin.frame === "bezel"
            x: 2
            y: 2
            width: root.cols - 4
            height: root.rows - 4
            color: "transparent"
            border.width: 1
            border.color: root.tube
        }
        // Brackets: the four corners only.
        Repeater {
            model: !root.raw && root.skin.frame === "brackets" ? 4 : 0
            Item {
                required property int index
                readonly property int len: Math.max(4, Math.min(12, Math.floor(Math.min(root.cols, root.rows) / 5)))
                x: index % 2 ? root.cols - len : 0
                y: index > 1 ? root.rows - len : 0
                width: len
                height: len
                Rectangle {
                    y: parent.index > 1 ? parent.len - 1 : 0
                    width: parent.len
                    height: 1
                    color: root.tube
                }
                Rectangle {
                    x: parent.index % 2 ? parent.len - 1 : 0
                    width: 1
                    height: parent.len
                    color: root.tube
                }
            }
        }
        // Bevel: light from the top left, shade to the bottom right.
        Item {
            visible: !root.raw && root.rect && root.skin.frame === "bevel"
            anchors.fill: parent
            Rectangle {
                width: parent.width
                height: 1
                color: Tokens.slot1
            }
            Rectangle {
                width: 1
                height: parent.height
                color: Tokens.slot1
            }
            Rectangle {
                y: parent.height - 1
                width: parent.width
                height: 1
                color: root.tube
                opacity: 0.6
            }
            Rectangle {
                x: parent.width - 1
                width: 1
                height: parent.height
                color: root.tube
                opacity: 0.6
            }
        }
        // Any other outline: the ring follows the shape.
        Shape {
            visible: Tokens.borders && !root.raw && (!root.rect || root.skin.round > 0) && root.skin.frame !== "brackets"
            width: root.cols
            height: root.rows
            preferredRendererType: Shape.CurveRenderer
            opacity: !LedFx.on ? 0.6 : LedFx.musical ? 0.4 + 0.6 * Math.min(1, LedFx.bass + LedFx.beat * 0.5) : 0.45 + 0.35 * Math.sin(LedFx.time * 2)
            ShapePath {
                strokeWidth: 2
                strokeColor: root.tube
                fillColor: "transparent"
                PathSvg {
                    path: surface.shape
                }
            }
        }

        // ── Title band ──
        Rectangle {
            visible: root.header
            x: root.edge
            y: root.edge
            width: root.cols - root.edge * 2
            height: Tokens.lineDots
            color: root.tube
            DotText {
                x: 2
                width: parent.width - right.implicitWidth - 6
                elide: Text.ElideRight
                text: root.words.head
                color: Tokens.glass
            }
            DotText {
                id: right
                anchors.right: parent.right
                anchors.rightMargin: 2
                text: root.words.headR
                color: Tokens.glass
            }
        }

        // ── Content ──
        PanelNode {
            x: root.edge + root.inset + 1
            y: root.topInset + root.inset + (root.header ? 0 : 1)
            width: root.cols - (root.edge + root.inset + 1) * 2
            height: root.rows - y - root.edge - root.inset - 1
            node: root.layout ?? ({})
            ctx: root.ctx
            sink: sink
            tube: root.tube
            clip: true
        }
    }

    // ── Raw images: full resolution, cut to the shape ───────────────
    Item {
        id: crisp
        anchors.fill: parent
        visible: root.raw && root.photo
        layer.enabled: visible
        layer.effect: MultiEffect {
            maskEnabled: !root.rect
            maskSource: crispMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0
        }

        Image {
            anchors.fill: parent
            source: root.photo && root.panel.source ? "file://" + root.panel.source.replace(/^~(?=\/)/, Quickshell.env("HOME")) : ""
            sourceSize: Qt.size(width, height)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }
    Shape {
        id: crispMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillColor: "white"
            PathSvg {
                path: Shapes.path(root.panel.shape, root.width, root.height) || `M 0 0 L ${root.width} 0 L ${root.width} ${root.height} L 0 ${root.height} Z`
            }
        }
    }
}
