import QtQuick
import Quickshell
import Quickshell.Io
import qs
import "Binds.js" as Binds

// Live shortcuts (Super /): read from `hyprctl -j binds` every time it opens,
// so it always matches the running config. Descriptions come from `bindd`
// lines in keybinds.conf; binds without one get a best guess.
Pane {
    id: pane

    name: "cheatsheet"

    readonly property int colChars: 35
    readonly property int colWidth: colChars * Tokens.charDots
    cols: Math.min(maxCols - 8, colWidth * 2 + Tokens.charDots * 2 + 8)
    rows: Math.min(maxRows - 16, board.implicitHeight + Tokens.lineDots + 14)

    property var groups: []
    // Two columns, balanced by line count.
    readonly property var split: {
        const total = groups.reduce((n, g) => n + g.items.length + 2, 0);
        const left = [], right = [];
        let n = 0;
        for (const g of groups) {
            (n < total / 2 ? left : right).push(g);
            n += g.items.length + 2;
        }
        return [left, right];
    }

    onOpened: binds.running = true
    onKeyPressed: event => {
        const step = Tokens.lineDots * 4;
        if (event.key === Qt.Key_Up || event.key === Qt.Key_K)
            flick.contentY = Math.max(0, flick.contentY - step);
        else if (event.key === Qt.Key_Down || event.key === Qt.Key_J)
            flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), flick.contentY + step);
    }

    Process {
        id: binds
        command: ["hyprctl", "-j", "binds"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    pane.groups = Binds.group(JSON.parse(text));
                } catch (e) {
                    pane.groups = [];
                }
            }
        }
    }

    Item {
        id: header
        x: 4
        y: 4
        width: pane.cols - 8
        height: Tokens.lineDots

        DotText {
            text: "SHORTCUTS"
            color: Tokens.slot2
        }
        DotText {
            anchors.right: parent.right
            text: "J K SCROLL   ESC CLOSE"
            color: Tokens.slot1
            opacity: 0.5
        }
    }

    Flickable {
        id: flick
        x: 4
        y: header.y + header.height + 4
        width: pane.cols - 8
        height: pane.rows - y - 4
        contentHeight: board.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Row {
            id: board
            spacing: Tokens.charDots * 2

            Repeater {
                model: pane.split

                Column {
                    id: column
                    required property var modelData
                    width: pane.colWidth
                    spacing: 6

                    Repeater {
                        model: column.modelData

                        Column {
                            id: group
                            required property var modelData
                            width: pane.colWidth

                            DotText {
                                height: Tokens.lineDots
                                text: group.modelData.name.toUpperCase()
                                color: Tokens.slot2
                            }
                            Rule {}
                            Item {
                                width: 1
                                height: 2
                            }

                            Repeater {
                                model: group.modelData.items

                                Item {
                                    id: entry
                                    required property var modelData
                                    width: pane.colWidth
                                    height: Tokens.lineDots

                                    DotText {
                                        id: combo
                                        width: 13 * Tokens.charDots
                                        text: entry.modelData.combo
                                        color: Tokens.slot0
                                        elide: Text.ElideRight
                                    }
                                    DotText {
                                        x: combo.width + Tokens.charDots
                                        width: parent.width - x
                                        text: entry.modelData.action
                                        color: Tokens.slot1
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
