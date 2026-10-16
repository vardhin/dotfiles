import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.services

// Session menu (Super Backspace). Arrows or h/l move, Enter runs,
// the underlined letter runs directly.
Pane {
    id: pane

    name: "session"

    readonly property var actions: [
        { key: "L", label: "LOCK", run: () => Lock.lock() },
        { key: "O", label: "LOGOUT", run: () => Hyprland.dispatch("exit") },
        { key: "S", label: "SUSPEND", run: () => Quickshell.execDetached(["systemctl", "suspend"]) },
        { key: "R", label: "REBOOT", run: () => Quickshell.execDetached(["systemctl", "reboot"]) },
        { key: "P", label: "POWER OFF", run: () => Quickshell.execDetached(["systemctl", "poweroff"]) }
    ]
    property int selected: 0

    cols: row.implicitWidth + 16
    rows: Tokens.lineDots * 2 + 14

    function run(i: int): void {
        Ui.close();
        actions[i].run();
    }

    onOpened: selected = 0
    onKeyPressed: event => {
        const k = event.key;
        if (k === Qt.Key_Left || k === Qt.Key_H || k === Qt.Key_Backtab)
            selected = (selected + actions.length - 1) % actions.length;
        else if (k === Qt.Key_Right || k === Qt.Key_Tab)
            selected = (selected + 1) % actions.length;
        else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space)
            run(selected);
        else {
            const i = actions.findIndex(a => a.key === event.text.toUpperCase());
            if (i >= 0)
                run(i);
        }
    }

    DotText {
        x: 8
        y: 4
        height: Tokens.lineDots
        text: "SESSION"
        color: Tokens.slot2
    }

    Row {
        id: row
        x: 8
        y: 6 + Tokens.lineDots
        spacing: Tokens.charDots * 2

        Repeater {
            model: pane.actions

            Item {
                id: item
                required property var modelData
                required property int index
                width: button.width
                height: Tokens.lineDots

                DotButton {
                    id: button
                    text: item.modelData.label
                    active: pane.selected === item.index
                    color: item.index >= 3 ? Tokens.slot2 : Tokens.slot0
                    onClicked: pane.run(item.index)
                }
                // Hotkey: underline under its letter.
                Rectangle {
                    readonly property int at: item.modelData.label.indexOf(item.modelData.key)
                    x: button.pad + at * Tokens.charDots
                    y: Tokens.lineDots - 1
                    width: Tokens.charDots - 1
                    height: 1
                    visible: pane.selected !== item.index
                    color: button.color
                }
            }
        }
    }
}
