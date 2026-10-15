import QtQuick

// Split-flap text, like an airport departure board: when `text` changes,
// each character spins through random glyphs and settles left to right.
DotText {
    id: root

    property string target
    property int flips: 6           // frames each character spins
    property int stagger: 1         // extra frames per column, left to right
    readonly property string glyphs: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

    property int frame: 0
    readonly property int frames: flips + target.length * stagger

    onTargetChanged: {
        frame = 0;
        flipTimer.restart();
    }
    Component.onCompleted: text = target

    Timer {
        id: flipTimer
        interval: 28
        repeat: true
        onTriggered: {
            root.frame += 1;
            if (root.frame >= root.frames) {
                stop();
                root.text = root.target;
                return;
            }
            let out = "";
            for (let i = 0; i < root.target.length; i++) {
                const c = root.target[i];
                const settled = root.frame >= root.flips + i * root.stagger;
                out += settled || c === " " ? c : root.glyphs[Math.floor(Math.random() * root.glyphs.length)];
            }
            root.text = out;
        }
    }
}
