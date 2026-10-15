import QtQuick

// LED-sign ticker: scrolls `text` right to left one dot per step, then
// emits `finished` after `passes` full passes. Restart with run().
Item {
    id: root

    property string text
    property color color: Tokens.slot0
    property int passes: 1
    property int stepMs: 22
    signal finished

    clip: true
    implicitHeight: Tokens.fontPx

    function run(): void {
        label.x = width;
        done = 0;
        timer.restart();
    }

    property int done: 0

    DotText {
        id: label
        height: root.height
        text: root.text
        color: root.color
    }

    Timer {
        id: timer
        interval: root.stepMs
        repeat: true
        onTriggered: {
            label.x -= 1;
            if (label.x < -label.implicitWidth) {
                root.done += 1;
                if (root.done >= root.passes) {
                    stop();
                    root.finished();
                } else {
                    label.x = root.width;
                }
            }
        }
    }
}
