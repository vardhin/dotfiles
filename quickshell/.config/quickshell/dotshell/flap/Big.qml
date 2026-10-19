import QtQuick
import qs

// One big flap tile, crisp, with its character in VT323 printed in square
// dots, the hinge across it; a change spins it through a few digits
// before it settles (the clock's hours and minutes).
//   Big { width: 60; height: 90; text: "2" }
Item {
    id: big

    property string text: ""
    property color color: Ink.white
    property bool spin: true
    readonly property int pitch: Tokens.pitch

    property string shown: text
    property int turns: 0
    onTextChanged: {
        if (!spin || !visible) {
            shown = text;
            return;
        }
        turns = 5;
        spinner.restart();
    }
    Timer {
        id: spinner
        interval: 45
        repeat: true
        onTriggered: {
            if (--big.turns <= 0) {
                stop();
                big.shown = big.text;
                return;
            }
            big.shown = "0123456789"[Math.floor(Math.random() * 10)];
        }
    }

    Tile {
        anchors.fill: parent
    }
    Dots {
        id: ink
        anchors.fill: parent
        Say {
            width: ink.cols
            height: ink.rows
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: big.shown
            // VT323's digits stand about 0.7 of its size.
            size: Math.round(Math.min(ink.rows * 1.05, ink.cols * 1.6))
            color: big.color
        }
    }
    Rectangle {
        y: Math.floor(big.height / 2) - 1
        width: parent.width
        height: 2
        color: Ink.seam
    }
}
