import QtQuick
import qs.services

// One run of docked panels: a zone of the top strip, or the side rail. While
// a panel is dragged, the run arms: a dim slot at its end shows it takes
// drops, and when the drag aims here a live ghost of the panel (its strip or
// rail form) opens at the aimed spot and the neighbours slide over.
//   DockRow { place: "strip"; zone: "r" }        DockRow { place: "rail" }
Item {
    id: root

    property string place: "strip"
    property string zone: ""
    property real originX: 0
    property int screenW: 1920
    property int screenH: 1080
    readonly property bool vertical: place === "rail"
    property int spacing: vertical ? 4 : 6

    readonly property var docked: place === "rail" ? Panels.rail : Panels.inStrip(zone)
    readonly property var d: Panels.drag
    readonly property bool aimed: d !== null && d.target === place && (place === "rail" || d.zone === zone)
    readonly property bool armed: d !== null && !aimed
    // The run as drawn: the docked panels, with the ghost spliced in.
    readonly property var entries: {
        const list = docked.filter(p => !(aimed && p.id === d.id)).map(p => ({ panel: p, ghost: false }));
        if (aimed) {
            const p = Panels.find(d.id);
            if (p)
                list.splice(Math.min(d.order, list.length), 0, { panel: p, ghost: true });
        }
        return list;
    }

    implicitWidth: vertical ? 13 : flow.implicitWidth + (armed ? arm.width + spacing : 0)
    implicitHeight: vertical ? flow.implicitHeight + (armed ? arm.height + spacing : 0) : 11

    Grid {
        id: flow
        columns: root.vertical ? 1 : Math.max(1, root.entries.length)
        rowSpacing: root.spacing
        columnSpacing: root.spacing
        // Neighbours slide over when the ghost opens.
        move: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        Repeater {
            model: root.entries
            DockItem {
                required property var modelData
                panel: modelData.panel
                ghost: modelData.ghost
                place: root.place
                originX: root.originX
                screenW: root.screenW
                screenH: root.screenH
            }
        }
    }

    // Armed: a dim slot at the end of the run.
    Rectangle {
        id: arm
        visible: root.armed
        x: root.vertical ? 1 : flow.implicitWidth + (root.entries.length ? root.spacing : 0)
        y: root.vertical ? flow.implicitHeight + (root.entries.length ? root.spacing : 0) : 1
        width: root.vertical ? 11 : 9
        height: root.vertical ? 9 : 9
        color: "transparent"
        border.width: 1
        border.color: Tokens.slot1
        opacity: 0.6
        Rectangle {
            anchors.centerIn: parent
            width: 3
            height: 1
            color: Tokens.slot1
        }
        Rectangle {
            anchors.centerIn: parent
            width: 1
            height: 3
            color: Tokens.slot1
        }
    }
}
