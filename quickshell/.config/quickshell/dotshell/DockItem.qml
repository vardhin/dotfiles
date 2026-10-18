import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.services
import "Skins.js" as Skins
import "Templates.js" as Templates

// A panel docked in the top strip or the side rail: its strip or rail form
// (Templates.js), drawn straight onto the strip's or rail's dot canvas
// (1 px = 1 dot). It tells Panels where it sits, so a dragged panel can aim
// between items, and it can itself be dragged: hold 200 ms (or just drag)
// and pull it out onto home, or along the bar to reorder, or across to the
// other bar.
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

    visible: layout !== null && node.shown
    implicitWidth: mode === "rail" ? 13 : node.implicitWidth
    implicitHeight: mode === "rail" ? node.implicitHeight : 11
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
        function run(a: string): void {
            if (a.startsWith("panel "))
                return;
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

    PanelNode {
        id: node
        width: root.width
        height: root.height
        node: root.layout ?? ({})
        ctx: root.ctx
        sink: sink
        tube: root.tube
        enabled: !root.ghost
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
        const railW = Tokens.side === "off" ? -1000 : Tokens.pitch * 13;
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
            // Pulled out anywhere: it lands on home with its corner at the
            // cursor (24 px grid, where World draws the outline), kept on
            // screen, and shows there when you go home.
            const t = Templates.get(panel.template);
            const w = panel.w * Panels.unit, h = panel.h * Panels.unit;
            const x = Math.max(0, Math.min(d.x, screenW - w)), y = Math.max(Tokens.pitch * 11, Math.min(d.y, screenH - h));
            Panels.place(panel.id, "home", "", 0, Math.round(x / 24) * 2, Math.round(y / 24) * 2);
            if ((Hyprland.focusedWorkspace?.id ?? 0) !== Tokens.home)
                Notify.send("Dot Shell", (t?.title ?? panel.template) + " is on home now", { urgency: "low", transient: true });
        } else {
            Panels.place(panel.id, d.target, d.zone, d.order, 0, 0);
        }
        return true;
    }
    function cancel(): void {
        hold.stop();
        lifted = false;
        Panels.drag = null;
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
        onReleased: root.release()
        onCanceled: root.cancel()
    }
}
