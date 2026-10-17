import QtQuick

// A 0..1 bar on a dot canvas: a faint track, lit up to `value`. `blocks`
// draws it as segments with a dark dot between (the stereo and handheld
// eras); otherwise solid. `vertical` fills from the bottom.
//   DotBar { width: 40; height: 3; value: Sys.cpu }
Item {
    id: bar

    property real value: 0
    property bool vertical: false
    property bool blocks: false
    property color ink: Tokens.slot0

    readonly property int len: vertical ? height : width
    readonly property int lit: Math.round(Math.max(0, Math.min(1, value)) * len)

    Rectangle {
        anchors.fill: parent
        color: Tokens.slot1
        opacity: 0.18
    }
    Rectangle {
        visible: !bar.blocks
        y: bar.vertical ? bar.height - bar.lit : 0
        width: bar.vertical ? bar.width : bar.lit
        height: bar.vertical ? bar.lit : bar.height
        color: bar.ink
    }
    Repeater {
        model: bar.blocks ? Math.floor((bar.len + 1) / 4) : 0
        Rectangle {
            required property int index
            visible: (index + 1) * 4 - 1 <= bar.lit + 1
            x: bar.vertical ? 0 : index * 4
            y: bar.vertical ? bar.height - (index + 1) * 4 + 1 : 0
            width: bar.vertical ? bar.width : 3
            height: bar.vertical ? 3 : bar.height
            color: bar.ink
        }
    }
}
