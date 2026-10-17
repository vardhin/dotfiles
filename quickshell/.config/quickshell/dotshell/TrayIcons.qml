import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

// Tray icons as dot glyphs: the icon only supplies a silhouette, the dots
// take an era color (accent when an item needs attention). Click activates,
// right click opens the item's menu, middle click is its secondary action,
// the wheel scrolls it. The top strip and the tray panel both use this.
//   TrayIcons { height: 11 }                 a row
//   TrayIcons { vertical: true }            a column (the rail)
//   TrayIcons { only: "telegram" }          one item, by id
Item {
    id: root

    property bool vertical: false
    property string only: ""
    property int size: 9
    property int gap: 3

    readonly property var items: SystemTray.items.values.filter(i => !only || i.id === only)

    implicitWidth: vertical ? size + 2 : Math.max(0, items.length * (size + gap) - gap)
    implicitHeight: vertical ? Math.max(0, items.length * (size + gap) - gap) : size + 2

    Grid {
        anchors.centerIn: parent
        columns: root.vertical ? 1 : Math.max(1, root.items.length)
        spacing: root.gap

        Repeater {
            model: root.items

            Item {
                id: glyph
                required property SystemTrayItem modelData
                width: root.size
                height: root.size

                IconImage {
                    id: icon
                    anchors.fill: parent
                    implicitSize: root.size
                    source: glyph.modelData.icon
                    layer.enabled: true
                    visible: false
                }
                Rectangle {
                    anchors.fill: icon
                    color: glyph.modelData.status === Status.NeedsAttention ? Tokens.slot2 : Tokens.slot1
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: icon
                        maskThresholdMin: 0.4
                        maskSpreadAtMin: 0
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        const item = glyph.modelData;
                        if (mouse.button === Qt.MiddleButton) {
                            item.secondaryActivate();
                        } else if (mouse.button === Qt.RightButton || item.onlyMenu) {
                            if (item.hasMenu) {
                                const win = QsWindow.window;
                                const p = glyph.mapToItem(null, 0, glyph.height);
                                item.display(win, p.x, p.y);
                            }
                        } else {
                            item.activate();
                        }
                    }
                    onWheel: wheel => glyph.modelData.scroll(wheel.angleDelta.y / 120, false)
                }
            }
        }
    }
}
