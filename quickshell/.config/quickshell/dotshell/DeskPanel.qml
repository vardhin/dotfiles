import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import qs.services
import qs.tokyo as Tokyo
import qs.vfd as Vfd
import qs.aero as Aero
import qs.blueprint as Bp
import qs.vapor as Vw
import qs.flap as Fl
import qs.nixie as Nx
import qs.nineties as Ni
import qs.nightvision as Nv
import "Shapes.js" as Shapes
import "Skins.js" as Skins
import "Templates.js" as Templates

// One desktop panel (see services/Panels.qml): its template's
// layout (Templates.js) bound to its feed (Feeds.qml), drawn by PanelNode on
// a DotSurface inside the era's frame (Skins.js).
//   click            expand (or the template's own click); click outside folds
//   hold 200 ms, or drag     lift it: the strip and the rail arm their slots;
//                    drop near the top to dock it in the strip, near the right
//                    edge for the rail, anywhere else to move it (24 px grid)
Item {
    id: root

    required property var panel
    // Where its workspace starts in the world layer (World.qml lays the
    // workspaces side by side), in px.
    property real originX: 0
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
    // A face of its own (the design canvas's hardware for this era) instead
    // of the generic board: the media panel, compact, in the eras whose
    // device is done (MediaDevice.qml).
    readonly property bool mediaFaced: panel.template === "media" && !expanded && !raw && rect && !!devices[Tokens.era]
    // Tokyo Night draws every template as its own neon sign (tokyo/), compact
    // and expanded; a panel with a layout or feed of its own keeps the board.
    readonly property Component tokyoFace: Tokens.era === "tokyo" && !raw && rect && !panel.layout && !panel.feed ? (tokyoFaces[panel.template] ?? null) : null
    // VFD draws each template as the car stereo's head unit (vfd/), the same way.
    readonly property Component vfdFace: Tokens.era === "vfd" && !raw && rect && !panel.layout && !panel.feed ? (vfdFaces[panel.template] ?? null) : null
    // Frutiger Aero draws each template on its own sky glass (aero/).
    readonly property Component aeroFace: Tokens.era === "aero" && !raw && rect && !panel.layout && !panel.feed ? (aeroFaces[panel.template] ?? null) : null
    // Blueprint draws each template as a sheet of drafting paper (blueprint/).
    readonly property Component blueprintFace: Tokens.era === "blueprint" && !raw && rect && !panel.layout && !panel.feed ? (blueprintFaces[panel.template] ?? null) : null
    // Vaporwave draws each template as a Windows 95 window (vapor/).
    readonly property Component vaporFace: Tokens.era === "vapor" && !raw && rect && !panel.layout && !panel.feed ? (vaporFaces[panel.template] ?? null) : null
    // Split-Flap draws each template as a departure board (flap/).
    readonly property Component flapFace: Tokens.era === "flap" && !raw && rect && !panel.layout && !panel.feed ? (flapFaces[panel.template] ?? null) : null
    // Nixie draws each template as valve-era kit in a walnut case (nixie/).
    readonly property Component nixieFace: Tokens.era === "nixie" && !raw && rect && !panel.layout && !panel.feed ? (nixieFaces[panel.template] ?? null) : null
    // 90s Nights draws each template as a slanted neon sign or a gadget (nineties/).
    readonly property Component ninetiesFace: Tokens.era === "nineties" && !raw && rect && !panel.layout && !panel.feed ? (ninetiesFaces[panel.template] ?? null) : null
    // Night Vision draws each template as a green dot scope (nightvision/).
    readonly property Component nightvisionFace: Tokens.era === "nightvision" && !raw && rect && !panel.layout && !panel.feed ? (nightvisionFaces[panel.template] ?? null) : null
    // Notes: no board at all, just its words (NotesPanel.qml).
    readonly property bool notes: panel.template === "notes"
    readonly property bool faced: mediaFaced || tokyoFace !== null || vfdFace !== null || aeroFace !== null || blueprintFace !== null || vaporFace !== null || flapFace !== null || nixieFace !== null || ninetiesFace !== null || nightvisionFace !== null || notes
    // Any other board in Tokyo Night still gets the sign's neon tube.
    readonly property bool tokyoRim: Tokens.era === "tokyo" && !faced && rect && !raw

    // Frame insets in dots: the ring, and the title band when the era has one.
    readonly property bool header: skin.header === true && rows >= 30 && !["sign", "image", "pixels", "dock"].includes(panel.template)
    readonly property int edge: raw ? 0 : skin.frame === "bezel" ? 4 : skin.frame === "double" ? 4 : 2
    // Eras with no title band name the panel in the frame's top edge
    // instead, so every panel says what it is.
    readonly property bool legend: !header && !raw && rect && !["sign", "image", "pixels", "dock"].includes(panel.template)
    readonly property int topInset: header ? edge + Tokens.lineDots + 1 : legend ? Tokens.lineDots : edge
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
    readonly property QtObject actions: sink
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
        // Held or dragged from a clickable node (PanelNode.grip).
        function grip(kind: string, x: real, y: real): bool {
            const p = root.parent.mapFromItem(null, x, y);
            if (kind === "press")
                root.press(p);
            else if (kind === "move")
                root.move(p);
            else if (kind === "release")
                return root.release();
            else
                root.cancel();
            return false;
        }
    }

    // ── Placement and drag ──────────────────────────────────────────
    property point drag: Qt.point(0, 0)
    property bool lifted: false
    readonly property string target: lifted ? (Panels.drag?.target ?? "home") : "home"
    readonly property bool overDock: lifted && target !== "home"

    x: originX + homeX + drag.x
    y: homeY + drag.y
    width: pxW
    height: pxH
    z: lifted ? 3 : expanded ? 2 : 0
    // Over a dock slot the board shrinks toward the cursor and fades: the
    // slot shows its strip or rail form as a live ghost instead.
    scale: overDock ? 0.42 : lifted ? 0.97 : 1
    // MEDIA open out of this panel (Pane `from`): the full device stands in
    // its place until it has shrunk back in.
    readonly property bool grownOut: panel.template === "media" && Ui.grown === "media" && Panels.mediaHome()?.id === panel.id
    opacity: overDock ? 0.3 : grownOut ? 0 : 1
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
        if (Templates.deskOnly.includes(panel.template))
            return { target: "home", zone: "", order: 0 };
        const stripH = Tokens.top ? Tokens.pitch * 11 : -1000;
        const railW = Tokens.side === "off" ? -1000 : Tokens.pitch * Tokens.railDots;
        if (Tokens.top && sy < stripH + 48)
            return Object.assign({ target: "strip" }, Dock.stripAim(sx, screenW));
        if (Tokens.side !== "off" && sx > screenW - railW - 48)
            return { target: "rail", zone: "", order: Dock.railAim(sy) };
        return { target: "home", zone: "", order: 0 };
    }

    // Press, move, release in root.parent's px: from the grab area below,
    // and from clickable nodes through sink.grip. release() says whether
    // the press became a drag. Aiming is in screen px (the world layer
    // covers the screen; its parent is shifted by the workspace).
    property point start
    function press(p: point): void {
        start = p;
        hold.restart();
    }
    function move(p: point): void {
        const dx = p.x - start.x, dy = p.y - start.y;
        if (!lifted && Math.abs(dx) + Math.abs(dy) > 6)
            lift();
        if (!lifted)
            return;
        drag = Qt.point(dx, dy);
        const s = root.parent.mapToItem(null, p.x, p.y);
        Panels.drag = Object.assign({ id: panel.id, from: "home", x: s.x, y: s.y }, aim(s.x, s.y));
    }
    function release(): bool {
        hold.stop();
        if (!lifted)
            return false;
        const d = Panels.drag;
        lifted = false;
        Panels.drag = null;
        if (d && d.target !== "home") {
            drag = Qt.point(0, 0);
            Panels.place(panel.id, d.target, d.zone, d.order, 0, 0, 0);
            return true;
        }
        // Home: snap to the 24 px grid (two units).
        const nx = Math.round((homeX + drag.x) / (unit * 2)) * 2;
        const ny = Math.round((homeY + drag.y) / (unit * 2)) * 2;
        drag = Qt.point(0, 0);
        if (nx !== panel.x || ny !== panel.y)
            Panels.move(panel.id, Math.max(0, nx), Math.max(0, ny));
        return true;
    }
    function cancel(): void {
        hold.stop();
        lifted = false;
        drag = Qt.point(0, 0);
        Panels.drag = null;
    }
    Timer {
        id: hold
        interval: 200
        onTriggered: root.lift()
    }

    // Right-click: close to the shelf (panel manager, Super O).
    MouseArea {
        z: -2
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: Panels.close(root.panel.id)
    }

    MouseArea {
        id: grab
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: root.lifted ? Qt.ClosedHandCursor : Qt.ArrowCursor

        onPressed: mouse => root.press(mapToItem(root.parent, mouse.x, mouse.y))
        onPositionChanged: mouse => root.move(mapToItem(root.parent, mouse.x, mouse.y))
        onReleased: {
            if (!root.release())
                root.click();
        }
        onCanceled: root.cancel()
    }

    function lift(): void {
        if (lifted)
            return;
        lifted = true;
        Panels.fold();
        Panels.typing = false;
        const s = root.parent.mapToItem(null, start.x, start.y);
        Panels.drag = { id: panel.id, from: "home", target: "home", zone: "", order: 0, x: s.x, y: s.y };
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
        visible: !(root.raw && root.photo) && !root.faced
        shape: root.rect && root.skin.round > 0 && !root.raw ? Shapes.rounded(root.cols, root.rows, root.skin.round) : Shapes.path(root.panel.shape, root.cols, root.rows)

        // ── Frame ──
        LedRing {
            visible: Tokens.borders && !root.raw && root.rect && !root.tokyoRim && (root.skin.frame === "ring" || root.skin.frame === "double")
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
            visible: Tokens.borders && !root.raw && !root.tokyoRim && (!root.rect || root.skin.round > 0) && root.skin.frame !== "brackets"
            width: root.cols
            height: root.rows
            preferredRendererType: Shape.CurveRenderer
            // Breathes, but never so far down that the outline reads as missing.
            opacity: !LedFx.on ? 0.7 : LedFx.musical ? 0.6 + 0.4 * Math.min(1, LedFx.bass + LedFx.beat * 0.5) : 0.75 + 0.2 * Math.sin(LedFx.time * 2)
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

        // ── Legend: the name cut into the top edge ──
        Rectangle {
            visible: root.legend
            x: root.edge + 3
            y: 0
            width: legendText.implicitWidth + 4
            height: Tokens.lineDots - 2
            color: Tokens.glass
            DotText {
                id: legendText
                x: 2
                height: parent.height
                text: (root.template?.title ?? root.panel.template).toUpperCase()
                color: Tokens.slot2
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

    // One skin per era (the design canvas's sk.<era>), as they are done.
    readonly property var devices: ({
            vfd: vfdDevice,
            tokyo: tokyoDevice,
            aero: aeroDevice,
            blueprint: blueprintDevice,
            vapor: vaporDevice,
            flap: flapDevice,
            nixie: nixieDevice,
            nineties: ninetiesDevice,
            nightvision: nightvisionDevice
        })
    Component {
        id: nightvisionDevice
        Nv.Media {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
        }
    }
    Component {
        id: ninetiesDevice
        Ni.Media {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
        }
    }
    Component {
        id: nixieDevice
        Nx.Media {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
        }
    }
    Component {
        id: flapDevice
        Fl.Media {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
        }
    }
    Component {
        id: vaporDevice
        Vw.Media {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
        }
    }
    Component {
        id: blueprintDevice
        Bp.Media {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
        }
    }
    Component {
        id: vfdDevice
        MediaDevice {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
        }
    }
    Component {
        id: aeroDevice
        Aero.Media {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
        }
    }
    Component {
        id: tokyoDevice
        MediaTokyo {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
        }
    }
    Loader {
        anchors.fill: parent
        active: root.mediaFaced
        sourceComponent: root.devices[Tokens.era] ?? null
    }

    Loader {
        anchors.fill: parent
        active: root.tokyoRim && Tokens.borders
        sourceComponent: Tokyo.Sign {
            radius: root.skin.round * Tokens.pitch
        }
    }

    Loader {
        anchors.fill: parent
        active: root.notes
        sourceComponent: NotesPanel {
            panel: root.panel
        }
    }

    readonly property var tokyoFaces: ({
            clock: tkClock,
            workspaces: tkWorkspaces,
            system: tkSystem,
            battery: tkBattery,
            messages: tkMessages,
            capture: tkCapture,
            caffeine: tkCaffeine,
            tray: tkTray,
            downloads: tkDownloads,
            files: tkFiles,
            clipboard: tkClipboard,
            todo: tkTodo,
            screenshots: tkScreenshots,
            dock: tkDock
        })
    Loader {
        anchors.fill: parent
        active: root.tokyoFace !== null
        sourceComponent: root.tokyoFace
    }
    Component {
        id: tkClock
        Tokyo.Clock {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: tkWorkspaces
        Tokyo.Workspaces {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: tkSystem
        Tokyo.System {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: tkBattery
        Tokyo.Battery {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: tkMessages
        Tokyo.Messages {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: tkCapture
        Tokyo.Capture {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: tkTray
        Tokyo.Tray {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: tkDownloads
        Tokyo.Downloads {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: tkFiles
        Tokyo.Files {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: tkClipboard
        Tokyo.Clipboard {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: tkTodo
        Tokyo.Todo {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: tkScreenshots
        Tokyo.Screenshots {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: tkDock
        Tokyo.Dock {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: tkCaffeine
        Tokyo.Caffeine {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }

    readonly property var vfdFaces: ({
            caffeine: vfCaffeine,
            capture: vfCapture,
            messages: vfMessages,
            battery: vfBattery,
            system: vfSystem,
            clipboard: vfClipboard,
            todo: vfTodo,
            clock: vfClock,
            workspaces: vfWorkspaces
        })
    Loader {
        anchors.fill: parent
        active: root.vfdFace !== null
        sourceComponent: root.vfdFace
    }
    Component {
        id: vfClipboard
        Vfd.Clipboard {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: vfTodo
        Vfd.Todo {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: vfClock
        Vfd.Clock {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: vfWorkspaces
        Vfd.Workspaces {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: vfBattery
        Vfd.Battery {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: vfMessages
        Vfd.Messages {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: vfCapture
        Vfd.Capture {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: vfCaffeine
        Vfd.Caffeine {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: vfSystem
        Vfd.System {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }

    readonly property var aeroFaces: ({
            system: aeSystem,
            clock: aeClock,
            workspaces: aeWorkspaces,
            battery: aeBattery,
            messages: aeMessages,
            capture: aeCapture,
            caffeine: aeCaffeine,
            clipboard: aeClipboard,
            todo: aeTodo
        })
    Loader {
        anchors.fill: parent
        active: root.aeroFace !== null
        sourceComponent: root.aeroFace
    }
    Component {
        id: aeClock
        Aero.Clock {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: aeWorkspaces
        Aero.Workspaces {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: aeBattery
        Aero.Battery {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: aeMessages
        Aero.Messages {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: aeCapture
        Aero.Capture {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: aeCaffeine
        Aero.Caffeine {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: aeClipboard
        Aero.Clipboard {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: aeTodo
        Aero.Todo {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: aeSystem
        Aero.System {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }

    readonly property var blueprintFaces: ({
            system: bpSystem,
            clock: bpClock,
            workspaces: bpWorkspaces,
            battery: bpBattery,
            messages: bpMessages,
            capture: bpCapture,
            caffeine: bpCaffeine,
            clipboard: bpClipboard,
            todo: bpTodo
        })
    Loader {
        anchors.fill: parent
        active: root.blueprintFace !== null
        sourceComponent: root.blueprintFace
    }
    Component {
        id: bpSystem
        Bp.System {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: bpClock
        Bp.Clock {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: bpWorkspaces
        Bp.Workspaces {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: bpBattery
        Bp.Battery {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: bpMessages
        Bp.Messages {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: bpCapture
        Bp.Capture {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: bpCaffeine
        Bp.Caffeine {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: bpClipboard
        Bp.Clipboard {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: bpTodo
        Bp.Todo {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }

    readonly property var nixieFaces: ({
            system: nxSystem,
            clock: nxClock,
            workspaces: nxWorkspaces,
            battery: nxBattery,
            messages: nxMessages,
            capture: nxCapture,
            caffeine: nxCaffeine,
            clipboard: nxClipboard,
            todo: nxTodo
        })
    Loader {
        anchors.fill: parent
        active: root.nixieFace !== null
        sourceComponent: root.nixieFace
    }
    Component {
        id: nxSystem
        Nx.System {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: nxClock
        Nx.Clock {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: nxWorkspaces
        Nx.Workspaces {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: nxBattery
        Nx.Battery {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: nxMessages
        Nx.Messages {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: nxCapture
        Nx.Capture {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: nxCaffeine
        Nx.Caffeine {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: nxClipboard
        Nx.Clipboard {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: nxTodo
        Nx.Todo {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }

    readonly property var ninetiesFaces: ({
            system: niSystem,
            clock: niClock,
            workspaces: niWorkspaces,
            battery: niBattery,
            messages: niMessages,
            capture: niCapture,
            caffeine: niCaffeine,
            clipboard: niClipboard,
            todo: niTodo
        })
    Loader {
        anchors.fill: parent
        active: root.ninetiesFace !== null
        sourceComponent: root.ninetiesFace
    }
    Component {
        id: niSystem
        Ni.System {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: niClock
        Ni.Clock {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: niWorkspaces
        Ni.Workspaces {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: niBattery
        Ni.Battery {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: niMessages
        Ni.Messages {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: niCapture
        Ni.Capture {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: niCaffeine
        Ni.Caffeine {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: niClipboard
        Ni.Clipboard {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: niTodo
        Ni.Todo {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }

    readonly property var nightvisionFaces: ({
            system: nvSystem,
            clock: nvClock,
            workspaces: nvWorkspaces,
            battery: nvBattery,
            messages: nvMessages,
            capture: nvCapture,
            caffeine: nvCaffeine,
            clipboard: nvClipboard,
            todo: nvTodo
        })
    Loader {
        anchors.fill: parent
        active: root.nightvisionFace !== null
        sourceComponent: root.nightvisionFace
    }
    Component {
        id: nvSystem
        Nv.System {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: nvClock
        Nv.Clock {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: nvWorkspaces
        Nv.Workspaces {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: nvBattery
        Nv.Battery {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: nvMessages
        Nv.Messages {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: nvCapture
        Nv.Capture {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: nvCaffeine
        Nv.Caffeine {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: nvClipboard
        Nv.Clipboard {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: nvTodo
        Nv.Todo {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }

    readonly property var flapFaces: ({
            system: flSystem,
            clock: flClock,
            workspaces: flWorkspaces,
            battery: flBattery,
            messages: flMessages,
            capture: flCapture,
            caffeine: flCaffeine,
            clipboard: flClipboard,
            todo: flTodo
        })
    Loader {
        anchors.fill: parent
        active: root.flapFace !== null
        sourceComponent: root.flapFace
    }
    Component {
        id: flSystem
        Fl.System {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: flClock
        Fl.Clock {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: flWorkspaces
        Fl.Workspaces {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: flBattery
        Fl.Battery {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: flMessages
        Fl.Messages {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: flCapture
        Fl.Capture {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: flCaffeine
        Fl.Caffeine {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: flClipboard
        Fl.Clipboard {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: flTodo
        Fl.Todo {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }

    readonly property var vaporFaces: ({
            system: vwSystem,
            clock: vwClock,
            workspaces: vwWorkspaces,
            battery: vwBattery,
            messages: vwMessages,
            capture: vwCapture,
            caffeine: vwCaffeine,
            clipboard: vwClipboard,
            todo: vwTodo
        })
    Loader {
        anchors.fill: parent
        active: root.vaporFace !== null
        sourceComponent: root.vaporFace
    }
    Component {
        id: vwSystem
        Vw.System {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: vwClock
        Vw.Clock {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: vwWorkspaces
        Vw.Workspaces {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: vwBattery
        Vw.Battery {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: vwMessages
        Vw.Messages {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: vwCapture
        Vw.Capture {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: vwCaffeine
        Vw.Caffeine {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: vwClipboard
        Vw.Clipboard {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
        }
    }
    Component {
        id: vwTodo
        Vw.Todo {
            ctx: root.ctx
            sink: root.actions
            panel: root.panel
            words: root.words
            big: root.expanded
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
