import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.services
import qs.vfd as Vfd
import qs.tokyo as Tokyo
import qs.vapor as Vw
import qs.flap as Fl
import "Skins.js" as Skins
import "Templates.js" as Templates

// A panel docked in the top strip or the side rail: its strip or rail form
// (Templates.js), drawn straight onto the strip's or rail's dot canvas
// (1 px = 1 dot). It tells Panels where it sits, so a dragged panel can aim
// between items, and it can itself be dragged: hold 200 ms (or just drag)
// and pull it out onto the desktop of the workspace you are on, or along
// the bar to reorder, or across to the other bar. A click where the item has
// no action of its own opens the whole panel beside it (PeekPane.qml).
//   DockItem { panel: p; place: "strip"; originX: 0 }
Item {
    id: root

    required property var panel
    property string place: "strip"
    // A live ghost of a panel being dragged over this bar (no input).
    property bool ghost: false
    // The bar window's left edge on the screen, in px.
    property real originX: 0
    property int screenW: 1920
    property int screenH: 1080

    readonly property var template: Templates.get(panel.template)
    readonly property string mode: place === "rail" ? "rail" : "strip"
    readonly property var layout: Templates.layout(template, mode, panel.layout)
    readonly property string feedId: panel.feed || template?.feed || ""
    readonly property var ctx: Object.assign({ "~": Skins.words(Tokens.era, template), "@": panel }, Feeds.get(feedId))
    readonly property color tube: [Tokens.slot0, Tokens.slot1, Tokens.slot2][panel.slot] ?? Tokens.slot0

    // No frame around docked items; kept at 0 (the node still reads them).
    readonly property int padX: 0
    readonly property int padY: 0

    // VFD draws its own strip and rail forms (vfd/Docked.qml) for these.
    readonly property bool vfdForm: Tokens.era === "vfd" && !panel.layout && ["media", "clock", "workspaces", "system", "battery", "messages", "capture", "caffeine", "clipboard", "todo"].includes(template?.name ?? "")
    // Tokyo Night likewise (tokyo/Docked.qml).
    readonly property bool tokyoForm: Tokens.era === "tokyo" && !panel.layout && ["media", "clock", "workspaces", "system", "battery", "messages", "capture", "caffeine", "clipboard", "todo"].includes(template?.name ?? "")
    // Vaporwave likewise, dark dots on the lilac taskbar (vapor/Docked.qml).
    readonly property bool vaporForm: Tokens.era === "vapor" && !panel.layout && ["media", "clock", "workspaces", "system", "battery", "messages", "capture", "caffeine", "clipboard", "todo"].includes(template?.name ?? "")
    // Split-Flap likewise, characters on flap tiles drawn in dots (flap/Docked.qml).
    readonly property bool flapForm: Tokens.era === "flap" && !panel.layout && ["media", "clock", "workspaces", "system", "battery", "messages", "capture", "caffeine", "clipboard", "todo"].includes(template?.name ?? "")
    readonly property Item form: vfdForm ? vfd.item : tokyoForm ? tokyo.item : vaporForm ? vapor.item : flapForm ? flap.item : node

    visible: layout !== null && (vfdForm ? (vfd.item?.shown ?? false) : tokyoForm ? (tokyo.item?.shown ?? false) : vaporForm ? (vapor.item?.shown ?? false) : flapForm ? (flap.item?.shown ?? false) : node.shown)
    implicitWidth: mode === "rail" ? Tokens.railDots : (form?.implicitWidth ?? 0) + padX * 2
    implicitHeight: mode === "rail" ? (form?.implicitHeight ?? 0) + padY * 2 : 11
    width: implicitWidth
    height: implicitHeight
    opacity: ghost ? 0.6 : lifted && (Panels.drag?.target ?? place) !== place ? 0.25 : 1

    Component.onCompleted: want(true)
    Component.onDestruction: {
        want(false);
        publish(false);
    }
    onVisibleChanged: want(visible)
    function want(on: bool): void {
        if (ghost)
            return;
        if (feedId)
            Feeds.want(feedId, "dock-" + panel.id, on);
        for (const w of template?.wants ?? [])
            Feeds.want(w, "dock-" + panel.id, on);
    }

    // ── Where it sits, for aiming ───────────────────────────────────
    onXChanged: publishLater.restart()
    onYChanged: publishLater.restart()
    onWidthChanged: publishLater.restart()
    onHeightChanged: publishLater.restart()
    Timer {
        id: publishLater
        interval: 50
        onTriggered: root.publish(true)
    }
    function publish(on: bool): void {
        if (ghost)
            return;
        const s = Object.assign({}, Panels.slots);
        if (on && visible) {
            const a = mapToItem(null, 0, 0), b = mapToItem(null, width, height);
            s[panel.id] = { place: place, zone: panel.zone ?? "", order: panel.order ?? 0, x: originX + a.x, y: a.y, w: b.x - a.x, h: b.y - a.y };
        } else {
            delete s[panel.id];
        }
        Panels.slots = s;
    }

    QtObject {
        id: sink
        // A docked item has no room to expand: "panel expand" opens the
        // peek; pop works as on the desktop.
        function run(a: string): void {
            const w = a.split(/\s+/);
            if (w[0] === "panel") {
                if (w[1] === "expand")
                    root.peek();
                else if (w[1] === "pop")
                    Panels.pop(root.panel.id, w[2]);
                return;
            }
            Ui.from = root.mode;
            Actions.run(a);
        }
        // Held or dragged from a clickable part of the item (PanelNode.grip);
        // x y in the bar window's px.
        function grip(kind: string, x: real, y: real): bool {
            const p = Qt.point(root.originX + x, y);
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

    // In the rail the form stands centred in its two glyphs of width.
    PanelNode {
        id: node
        width: root.mode === "rail" ? Math.min(root.width, Math.max(1, implicitWidth)) : root.width - root.padX * 2
        x: root.mode === "rail" ? Math.floor((root.width - width) / 2) : root.padX
        y: root.padY
        height: root.height - root.padY * 2
        node: root.layout ?? ({})
        ctx: root.ctx
        sink: sink
        tube: root.tube
        enabled: !root.ghost
        visible: !root.vfdForm && !root.tokyoForm && !root.vaporForm && !root.flapForm && shown
    }
    Loader {
        id: tokyo
        active: root.tokyoForm
        enabled: !root.ghost
        sourceComponent: Tokyo.Docked {
            template: root.template?.name ?? ""
            rail: root.mode === "rail"
            ctx: root.ctx
            sink: sink
            panel: root.panel
            words: root.ctx["~"] ?? ({})
        }
    }
    Loader {
        id: vapor
        active: root.vaporForm
        enabled: !root.ghost
        sourceComponent: Vw.Docked {
            template: root.template?.name ?? ""
            rail: root.mode === "rail"
            ctx: root.ctx
            sink: sink
            panel: root.panel
            words: root.ctx["~"] ?? ({})
        }
    }
    Loader {
        id: flap
        active: root.flapForm
        enabled: !root.ghost
        sourceComponent: Fl.Docked {
            template: root.template?.name ?? ""
            rail: root.mode === "rail"
            ctx: root.ctx
            sink: sink
            panel: root.panel
            words: root.ctx["~"] ?? ({})
        }
    }
    Loader {
        id: vfd
        active: root.vfdForm
        enabled: !root.ghost
        sourceComponent: Vfd.Docked {
            template: root.template?.name ?? ""
            rail: root.mode === "rail"
            ctx: root.ctx
            sink: sink
            panel: root.panel
            words: root.ctx["~"] ?? ({})
        }
    }

    // ── Drag out ────────────────────────────────────────────────────
    // Press, move, release in screen px, from the grab area below or from
    // a clickable node through sink.grip. release() says whether the press
    // became a drag.
    property bool lifted: false
    property point start
    Timer {
        id: hold
        interval: 200
        onTriggered: root.lift()
    }
    function lift(): void {
        if (lifted)
            return;
        lifted = true;
        Panels.drag = { id: panel.id, from: place, target: place, zone: panel.zone, order: panel.order, x: start.x, y: start.y };
    }
    function press(p: point): void {
        start = p;
        hold.restart();
    }
    function move(p: point): void {
        if (!lifted && Math.abs(p.x - start.x) + Math.abs(p.y - start.y) > 6)
            lift();
        if (!lifted)
            return;
        const stripH = Tokens.top ? Tokens.pitch * 11 : -1000;
        const railW = Tokens.side === "off" ? -1000 : Tokens.pitch * Tokens.railDots;
        let aim;
        if (Tokens.top && p.y < stripH + 48)
            aim = Object.assign({ target: "strip" }, Dock.stripAim(p.x, screenW));
        else if (Tokens.side !== "off" && p.x > screenW - railW - 48)
            aim = { target: "rail", zone: "", order: Dock.railAim(p.y) };
        else
            aim = { target: "home", zone: "", order: 0 };
        Panels.drag = Object.assign({ id: panel.id, from: place, x: p.x, y: p.y }, aim);
    }
    function release(): bool {
        hold.stop();
        if (!lifted)
            return false;
        lifted = false;
        const d = Panels.drag;
        Panels.drag = null;
        if (!d)
            return true;
        if (d.target === "home") {
            // Pulled out anywhere: it lands on this workspace's desktop
            // with its corner at the cursor (24 px grid, where DragLayer
            // drew the outline), kept on screen.
            const w = panel.w * Panels.unit, h = panel.h * Panels.unit;
            const x = Math.max(0, Math.min(d.x, screenW - w)), y = Math.max(Tokens.pitch * 11, Math.min(d.y, screenH - h));
            Panels.place(panel.id, "home", "", 0, Math.round(x / 24) * 2, Math.round(y / 24) * 2, Hyprland.focusedWorkspace?.id ?? 0);
        } else {
            Panels.place(panel.id, d.target, d.zone, d.order, 0, 0, 0);
        }
        return true;
    }

    // Open the whole panel beside the item; a template with a click of its
    // own (media: MEDIA, the one full player) opens that instead.
    function peek(): void {
        const own = template?.click ?? "";
        if (own && own !== "expand" && own !== "none") {
            Actions.run(own);
            return;
        }
        const c = mapToItem(null, width / 2, height / 2);
        const open = Ui.pane === "peek" && Panels.peek?.id === panel.id;
        Panels.peek = { id: panel.id, place: place, x: originX + c.x, y: c.y };
        if (open)
            Ui.close();
        else
            Ui.open("peek", null);
    }
    function cancel(): void {
        hold.stop();
        lifted = false;
        Panels.drag = null;
    }

    // ── Its name, while hovered ─────────────────────────────────────
    HoverHandler {
        id: hov
        enabled: !root.ghost
        onHoveredChanged: {
            if (hovered) {
                hintLater.restart();
            } else {
                hintLater.stop();
                if (Panels.hint?.id === root.panel.id)
                    Panels.hint = null;
            }
        }
    }
    Timer {
        id: hintLater
        interval: 450
        onTriggered: {
            if (root.lifted || !hov.hovered)
                return;
            const a = root.mapToItem(null, 0, 0), b = root.mapToItem(null, root.width, root.height);
            Panels.hint = { id: root.panel.id, place: root.place, x: root.originX + a.x, y: a.y, w: b.x - a.x, h: b.y - a.y };
        }
    }
    onLiftedChanged: if (lifted && Panels.hint?.id === panel.id) Panels.hint = null

    // Right-click: close to the shelf (panel manager, Super O).
    MouseArea {
        z: -2
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: Panels.close(root.panel.id)
    }

    // Below the node, so the item's own actions (clicks) win; those pass
    // their presses on through sink.grip.
    MouseArea {
        id: grab
        z: -1
        anchors.fill: parent
        enabled: !root.ghost
        cursorShape: root.lifted ? Qt.ClosedHandCursor : Qt.ArrowCursor
        function screenPos(mouse: var): point {
            const p = mapToItem(null, mouse.x, mouse.y);
            return Qt.point(root.originX + p.x, p.y);
        }
        onPressed: mouse => root.press(screenPos(mouse))
        onPositionChanged: mouse => root.move(screenPos(mouse))
        onReleased: {
            if (!root.release())
                root.peek();
        }
        onCanceled: root.cancel()
    }
}
