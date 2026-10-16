import QtQuick
import Quickshell
import qs
import qs.services

// CAPTURE (Super Shift P, or Super Shift Print): screenshots, screen
// recordings and the color picker, through services/Capture.qml.
// Arrows (or hjkl) move, Enter runs, the underlined letter runs directly.
Pane {
    id: pane

    name: "capture"

    readonly property var lines: [
        { head: "SHOT", items: [
            { key: "A", label: "AREA", run: () => Capture.shot("area") },
            { key: "S", label: "SCREEN", run: () => Capture.shot("screen") },
            { key: "W", label: "WINDOW", run: () => Capture.shot("window") },
            { key: "E", label: "EDIT", run: () => Capture.shot("edit") },
            { key: "D", label: "DELAY 5", run: () => Capture.shot("delay") }
        ] },
        { head: "REC", items: Capture.recording ? [
            { key: "T", label: "STOP " + Capture.clock(Capture.elapsed), run: () => Capture.stop() }
        ] : [
            { key: "R", label: "REGION", run: () => Capture.rec("area") },
            { key: "F", label: "FULL", run: () => Capture.rec("screen") },
            { key: "U", label: Capture.audio ? "SOUND ON" : "SOUND OFF", stay: true, run: () => Capture.audio = !Capture.audio }
        ] },
        { head: "PICK", items: [
            { key: "C", label: "COLOR", run: () => Capture.pick() }
        ] }
    ]
    property int line: 0
    property int col: 0

    readonly property int headChars: 6
    readonly property int gap: Tokens.charDots * 2 - 4
    // In dots: each button is its label plus 2 dots of padding a side.
    readonly property int widest: Math.max(...lines.map(l => l.items.reduce((n, it) => n + it.label.length * Tokens.charDots + 4, 0) + (l.items.length - 1) * gap))
    cols: headChars * Tokens.charDots + widest + 16
    rows: Tokens.lineDots * (lines.length + 2) + 14

    function run(l: int, c: int): void {
        const it = lines[l]?.items[c];
        if (!it)
            return;
        if (!it.stay)
            Ui.close();
        it.run();
    }

    onOpened: {
        line = Capture.recording ? 1 : 0;
        col = 0;
    }
    onKeyPressed: event => {
        const k = event.key;
        const n = lines[line].items.length;
        if (k === Qt.Key_Left || k === Qt.Key_H || k === Qt.Key_Backtab)
            col = (col + n - 1) % n;
        else if (k === Qt.Key_Right || k === Qt.Key_L || k === Qt.Key_Tab)
            col = (col + 1) % n;
        else if (k === Qt.Key_Up || k === Qt.Key_K) {
            line = (line + lines.length - 1) % lines.length;
            col = Math.min(col, lines[line].items.length - 1);
        } else if (k === Qt.Key_Down || k === Qt.Key_J) {
            line = (line + 1) % lines.length;
            col = Math.min(col, lines[line].items.length - 1);
        } else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space)
            run(line, col);
        else {
            const t = event.text.toUpperCase();
            for (let l = 0; l < lines.length; l++) {
                const c = lines[l].items.findIndex(it => it.key === t);
                if (c >= 0) {
                    run(l, c);
                    break;
                }
            }
        }
    }
    // The REC line changes length when a recording starts or stops.
    onLinesChanged: col = Math.min(col, lines[line].items.length - 1)

    Item {
        x: 8
        y: 4
        width: pane.cols - 16
        height: Tokens.lineDots

        DotText {
            text: "CAPTURE"
            color: Tokens.slot2
        }
        DotText {
            anchors.right: parent.right
            visible: Capture.recording
            text: "REC " + Capture.clock(Capture.elapsed)
            color: Tokens.slot2
        }
    }

    Column {
        x: 8
        y: 6 + Tokens.lineDots
        spacing: 0

        Repeater {
            model: pane.lines

            Item {
                id: lineItem
                required property var modelData
                required property int index
                width: pane.cols - 16
                height: Tokens.lineDots

                DotText {
                    text: lineItem.modelData.head
                    color: Tokens.slot1
                    opacity: 0.6
                }

                Row {
                    x: pane.headChars * Tokens.charDots
                    spacing: pane.gap

                    Repeater {
                        model: lineItem.modelData.items

                        Item {
                            id: item
                            required property var modelData
                            required property int index
                            width: button.width
                            height: Tokens.lineDots

                            DotButton {
                                id: button
                                text: item.modelData.label
                                active: pane.line === lineItem.index && pane.col === item.index
                                color: lineItem.index === 1 ? Tokens.slot2 : Tokens.slot0
                                onClicked: pane.run(lineItem.index, item.index)
                            }
                            // Hotkey: underline under its letter.
                            Rectangle {
                                readonly property int at: item.modelData.label.indexOf(item.modelData.key)
                                x: button.pad + at * Tokens.charDots
                                y: Tokens.lineDots - 1
                                width: Tokens.charDots - 1
                                height: 1
                                visible: !button.active
                                color: button.color
                            }
                        }
                    }
                }
            }
        }
    }

    DotText {
        x: 8
        y: 8 + Tokens.lineDots * (pane.lines.length + 1)
        height: Tokens.lineDots
        text: "ARROWS MOVE   ENTER RUN   ESC CLOSE"
        color: Tokens.slot1
        opacity: 0.5
    }
}
