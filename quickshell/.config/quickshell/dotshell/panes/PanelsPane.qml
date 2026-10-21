import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs
import qs.services
import "../Templates.js" as Templates

// Panel manager (Super O): every panel by where it is, with DESK STRIP RAIL
// to send it there and × to close it to the shelf; NEW spawns a fresh one.
// Right-click any panel to close it here.
Pane {
    id: pane

    name: "panels"
    anchors {
        top: true
        right: true
    }

    readonly property int inner: 40 * Tokens.charDots
    cols: inner + 8
    // Capped to the screen; the list scrolls inside.
    rows: Math.min(col.implicitHeight + 8, maxRows)

    readonly property var groups: [
        { label: "ON DESKTOP", list: Panels.home },
        { label: "IN STRIP", list: Panels.strip },
        { label: "IN RAIL", list: Panels.rail },
        { label: "CLOSED", list: Panels.shelf }
    ]

    function title(p: var): string {
        const t = Templates.get(p.template);
        const n = (t?.title ?? p.template).toUpperCase();
        return p.id === p.template ? n : n + " " + p.id.toUpperCase();
    }

    Flickable {
        x: 4
        y: 4
        width: pane.inner
        height: pane.rows - 8
        contentWidth: width
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

    Column {
        id: col
        width: pane.inner
        spacing: 3

        Line {
            label: "PANELS"
            labelColor: Tokens.slot2
            DotButton {
                visible: Panels.undo !== null
                text: "UNDO"
                onClicked: Panels.undoLast()
            }
        }

        Repeater {
            model: pane.groups

            Column {
                id: group
                required property var modelData
                width: pane.inner
                spacing: 2
                visible: modelData.list.length > 0

                Rule {}
                DotText {
                    height: Tokens.lineDots
                    text: group.modelData.label
                    color: Tokens.slot1
                    opacity: 0.6
                }
                Repeater {
                    model: group.modelData.list

                    Line {
                        id: row
                        required property var modelData
                        label: pane.title(modelData)
                        DotButton {
                            visible: !Templates.stripOnly.includes(row.modelData.template)
                            text: "DESK"
                            active: row.modelData.place === "home"
                            onClicked: Panels.open(row.modelData.id, "home")
                        }
                        DotButton {
                            visible: !Templates.deskOnly.includes(row.modelData.template)
                            text: "STRIP"
                            active: row.modelData.place === "strip"
                            onClicked: Panels.open(row.modelData.id, "strip")
                        }
                        DotButton {
                            visible: !Templates.deskOnly.includes(row.modelData.template)
                            text: "RAIL"
                            active: row.modelData.place === "rail"
                            onClicked: Panels.open(row.modelData.id, "rail")
                        }
                        DotButton {
                            text: "X"
                            enabled: row.modelData.place !== "shelf"
                            onClicked: Panels.close(row.modelData.id)
                        }
                    }
                }
            }
        }

        Rule {
            visible: newRow.visible
        }

        DotText {
            id: newRow
            visible: true
            height: Tokens.lineDots
            text: "NEW"
            color: Tokens.slot1
            opacity: 0.6
        }
        Flow {
            width: pane.inner
            spacing: 3
            Repeater {
                // The missing ones: one panel of each kind.
                model: Templates.homeSet.concat(Templates.deskOnly).filter(t => !Panels.panels.some(p => p.template === t))
                DotButton {
                    required property string modelData
                    text: (Templates.get(modelData)?.title ?? modelData).toUpperCase()
                    onClicked: Panels.spawn(modelData, { place: "home", x: 4, y: 6, ws: Hyprland.focusedWorkspace?.id ?? 0 })
                }
            }
        }
    }
    }
}
