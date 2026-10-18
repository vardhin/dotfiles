import QtQuick
import qs.services

// One run of docked panels: a zone of the top strip, or the side rail. While
// a panel is dragged, the run arms: a dim slot at its end shows it takes
// drops, and when the drag aims here a live ghost of the panel (its strip or
// rail form) opens at the aimed spot and the neighbours slide over.
//   DockRow { place: "strip"; zone: "r" }        DockRow { place: "rail" }
//
// The Repeater's model is only the docked panels, which do not change during
// a drag: a model rebuilt on every move would recreate the delegates and
// destroy the very item being dragged out (its mouse grab with it). The
// ghost opens inside the cell it lands before, or at the end.
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
    readonly property string dragId: d?.id ?? ""
    readonly property int aimOrder: aimed ? d.order : -1
    // The docked ids other than the dragged one: the order a drop aims at.
    readonly property var others: docked.filter(p => p.id !== dragId).map(p => p.id)
    readonly property var dragged: aimed ? Panels.find(dragId) : null

    implicitWidth: vertical ? 13 : flow.implicitWidth + (endGhost.active ? endGhost.width + (flow.implicitWidth ? spacing : 0) : 0) + (armed ? arm.width + spacing : 0)
    implicitHeight: vertical ? flow.implicitHeight + (endGhost.active ? endGhost.height + (flow.implicitHeight ? spacing : 0) : 0) + (armed ? arm.height + spacing : 0) : 11

    Grid {
        id: flow
        columns: root.vertical ? 1 : Math.max(1, root.docked.length)
        rowSpacing: 0
        columnSpacing: 0
        // Neighbours slide over when the ghost opens.
        move: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        Repeater {
            model: root.docked

            Item {
                id: cell
                required property var modelData
                required property int index
                // The dragged item folds away while it aims at its own run
                // (the ghost stands in), but stays alive to keep the drag.
                readonly property bool folded: root.aimed && modelData.id === root.dragId
                readonly property bool ghostHere: root.aimed && !folded && root.others.indexOf(modelData.id) === root.aimOrder
                readonly property int gap: root.spacing
                // No gap after the last item (the end ghost and the armed
                // slot bring their own).
                readonly property int tail: index === root.docked.length - 1 ? 0 : gap

                implicitWidth: root.vertical ? 13 : (ghostHere ? ghost.width + gap : 0) + (folded || !item.visible ? 0 : item.width + tail)
                implicitHeight: root.vertical ? (ghostHere ? ghost.height + gap : 0) + (folded || !item.visible ? 0 : item.height + tail) : 11
                width: implicitWidth
                height: implicitHeight

                Loader {
                    id: ghost
                    active: cell.ghostHere && root.dragged !== null
                    sourceComponent: ghostItem
                }

                DockItem {
                    id: item
                    panel: cell.modelData
                    place: root.place
                    originX: root.originX
                    screenW: root.screenW
                    screenH: root.screenH
                    x: root.vertical ? 0 : (cell.ghostHere ? ghost.width + cell.gap : 0)
                    y: root.vertical ? (cell.ghostHere ? ghost.height + cell.gap : 0) : 0
                    opacity: cell.folded ? 0 : (lifted ? 0.25 : 1)
                }
            }
        }
    }

    // The ghost at the end of the run.
    Loader {
        id: endGhost
        active: root.aimed && root.dragged !== null && root.aimOrder >= root.others.length
        x: root.vertical ? 0 : flow.implicitWidth + (flow.implicitWidth ? root.spacing : 0)
        y: root.vertical ? flow.implicitHeight + (flow.implicitHeight ? root.spacing : 0) : 0
        sourceComponent: ghostItem
    }

    Component {
        id: ghostItem
        DockItem {
            panel: root.dragged
            ghost: true
            place: root.place
            originX: root.originX
            screenW: root.screenW
            screenH: root.screenH
        }
    }

    // Armed: a dim slot at the end of the run.
    Rectangle {
        id: arm
        visible: root.armed
        x: root.vertical ? 1 : flow.implicitWidth + (flow.implicitWidth ? root.spacing : 0)
        y: root.vertical ? flow.implicitHeight + (flow.implicitHeight ? root.spacing : 0) : 1
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
