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

    readonly property bool lifted: grab.lifted
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
    // Below the node, so the item's own actions (clicks) win.
    MouseArea {
        id: grab
        z: -1
        anchors.fill: parent
        enabled: !root.ghost
        property bool lifted: false
        property point start

        Timer {
            id: hold
            interval: 200
            onTriggered: grab.lift()
        }
        function lift(): void {
            if (lifted)
                return;
            lifted = true;
            Panels.drag = { id: root.panel.id, from: root.place, target: root.place, zone: root.panel.zone, order: root.panel.order, x: start.x, y: start.y };
        }
        function screenPos(mouse: var): point {
            const p = mapToItem(null, mouse.x, mouse.y);
            return Qt.point(root.originX + p.x, p.y);
        }
        onPressed: mouse => {
            start = screenPos(mouse);
            hold.restart();
        }
        onPositionChanged: mouse => {
            const p = screenPos(mouse);
            if (!lifted && Math.abs(p.x - start.x) + Math.abs(p.y - start.y) > 6)
                lift();
            if (!lifted)
                return;
            const stripH = Tokens.top ? Tokens.pitch * 11 : -1000;
            const railW = Tokens.side === "off" ? -1000 : Tokens.pitch * 13;
            let aim;
            if (Tokens.top && p.y < stripH + 48)
                aim = Object.assign({ target: "strip" }, Dock.stripAim(p.x, root.screenW));
            else if (Tokens.side !== "off" && p.x > root.screenW - railW - 48)
                aim = { target: "rail", zone: "", order: Dock.railAim(p.y) };
            else
                aim = { target: "home", zone: "", order: 0 };
            Panels.drag = Object.assign({ id: root.panel.id, from: root.place, x: p.x, y: p.y }, aim);
        }
        onReleased: {
            hold.stop();
            if (!lifted)
                return;
            lifted = false;
            const d = Panels.drag;
            Panels.drag = null;
            if (!d)
                return;
            if (d.target === "home") {
                // Panels live only on home: anywhere else, it snaps back.
                if ((Hyprland.focusedWorkspace?.id ?? 0) !== Tokens.home)
                    return;
                Panels.place(root.panel.id, "home", "", 0, Math.max(0, Math.round(d.x / 24) * 2), Math.max(0, Math.round(d.y / 24) * 2));
            } else {
                Panels.place(root.panel.id, d.target, d.zone, d.order, 0, 0);
            }
        }
        onCanceled: {
            hold.stop();
            lifted = false;
            Panels.drag = null;
        }
    }
}
