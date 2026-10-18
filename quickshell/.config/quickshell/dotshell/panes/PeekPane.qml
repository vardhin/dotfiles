import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs
import qs.services
import "../Skins.js" as Skins
import "../Templates.js" as Templates

// A docked item opened in place: a click on a strip or rail item where it
// has no action of its own (DockItem.qml) shows the whole panel, its
// expanded layout, under the strip or beside the rail. The foot moves it:
// onto this workspace's desktop, or across to the other bar.
Pane {
    id: pane

    name: "peek"
    // Nearly solid: it sits over whatever window is under the bar.
    surface.glassAlpha: 0.94

    readonly property var at: Panels.peek
    readonly property var panel: at ? Panels.find(at.id) : null
    readonly property var template: panel ? Templates.get(panel.template) : null
    readonly property var layout: template ? Templates.layout(template, "expanded", panel.layout) : null
    readonly property string feedId: panel ? (panel.feed || template?.feed || "") : ""
    readonly property var ctx: panel ? Object.assign({ "~": Skins.words(Tokens.era, template), "@": panel }, Feeds.get(feedId)) : ({})
    readonly property color tube: [Tokens.slot0, Tokens.slot1, Tokens.slot2][panel?.slot ?? 0] ?? Tokens.slot0
    readonly property bool fromRail: at?.place === "rail"

    // The expanded size, in dots, plus the title and foot lines.
    readonly property int bodyCols: Math.round(Math.max(panel?.w ?? 30, template?.big?.w ?? 0) * Panels.unit / Tokens.pitch)
    readonly property int bodyRows: Math.round(Math.max(panel?.h ?? 12, template?.big?.h ?? 0) * Panels.unit / Tokens.pitch)
    cols: Math.max(bodyCols, foot.implicitWidth + 8) + 8
    rows: bodyRows + Tokens.lineDots * 2 + 12

    // Under the strip at the item, or beside the rail at the item.
    anchors {
        top: true
        left: !fromRail
        right: fromRail
    }
    margins {
        left: fromRail ? 0 : Math.max(0, Math.min((at?.x ?? 0) - width / 2, (screen?.width ?? 1920) - width))
        top: fromRail ? Math.max(0, Math.min((at?.y ?? 0) - height / 2 - stripH, (screen?.height ?? 1080) - stripH - height)) : 0
    }

    // Wake the feed while open.
    onShownChanged: want(shown)
    property string wanted: ""
    function want(on: bool): void {
        if (wanted) {
            Feeds.want(wanted, "peek", false);
            for (const w of Templates.get(wantedT)?.wants ?? [])
                Feeds.want(w, "peek", false);
        }
        wanted = on ? feedId : "";
        wantedT = on ? (panel?.template ?? "") : "";
        if (on && wanted) {
            Feeds.want(wanted, "peek", true);
            for (const w of template?.wants ?? [])
                Feeds.want(w, "peek", true);
        }
    }
    property string wantedT: ""
    onFeedIdChanged: if (shown) want(true)

    QtObject {
        id: sink
        function run(a: string): void {
            const w = a.split(/\s+/);
            if (w[0] === "panel") {
                if (w[1] === "fold")
                    Ui.close();
                else if (w[1] === "pop" && pane.panel)
                    Panels.pop(pane.panel.id, w[2]);
                return;
            }
            Actions.run(a);
        }
    }

    // ── Title ───────────────────────────────────────────────────────
    DotText {
        x: 4
        y: 4
        height: Tokens.lineDots
        width: pane.cols - 8 - esc.implicitWidth - 4
        elide: Text.ElideRight
        text: (pane.template?.title ?? "").toUpperCase()
        color: Tokens.slot2
    }
    DotText {
        id: esc
        anchors.right: parent.right
        anchors.rightMargin: 4
        y: 4
        height: Tokens.lineDots
        text: "ESC"
        color: Tokens.slot1
        opacity: 0.6
    }

    // ── The panel ───────────────────────────────────────────────────
    PanelNode {
        x: 4
        y: 4 + Tokens.lineDots + 2
        width: pane.cols - 8
        height: pane.bodyRows
        node: pane.layout ?? ({})
        ctx: pane.ctx
        sink: sink
        tube: pane.tube
        clip: true
    }

    // ── Foot: where it lives ────────────────────────────────────────
    Row {
        id: foot
        x: 4
        y: pane.rows - Tokens.lineDots - 3
        spacing: 3 * Tokens.charDots

        FootWord {
            text: "ON DESKTOP"
            onClicked: {
                const p = pane.panel;
                const ws = Hyprland.focusedWorkspace?.id ?? 0;
                // Right of centre, under the strip; World draws it there.
                const x = Math.round(((pane.screen?.width ?? 1920) / 2) / 24) * 2;
                Ui.close();
                Panels.place(p.id, "home", "", 0, x, 6, ws);
            }
        }
        FootWord {
            text: pane.fromRail ? "TO STRIP" : "TO RAIL"
            onClicked: {
                const p = pane.panel;
                Ui.close();
                if (pane.fromRail)
                    Panels.place(p.id, "strip", "r", 99, 0, 0, 0);
                else
                    Panels.place(p.id, "rail", "", 99, 0, 0, 0);
            }
        }
        FootWord {
            text: "CLOSE"
            onClicked: Ui.close()
        }
    }

    component FootWord: Item {
        id: fw
        property alias text: word.text
        signal clicked
        implicitWidth: word.implicitWidth
        implicitHeight: Tokens.lineDots
        DotText {
            id: word
            height: Tokens.lineDots
            color: Tokens.slot1
            opacity: m.containsMouse ? 1 : 0.75
        }
        Rectangle {
            visible: m.containsMouse
            y: parent.height - 2
            width: word.implicitWidth
            height: 1
            color: Tokens.slot1
        }
        MouseArea {
            id: m
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: fw.clicked()
        }
    }
}
