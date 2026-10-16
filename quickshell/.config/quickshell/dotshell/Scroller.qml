import QtQuick

// One line of LED text in a fixed box. Still when it fits; otherwise it runs
// right to left one dot per step and loops seamlessly (two copies, a gap of
// `gapChars` between), like a shop-window sign. Pauses on hover.
//   Scroller { width: 112; text: Media.title.toUpperCase() }
Item {
    id: root

    property string text
    property color color: Tokens.slot0
    property int stepMs: 45
    property int gapChars: 4
    property real textOpacity: 1

    readonly property bool runs: one.implicitWidth > width
    readonly property int period: one.implicitWidth + gapChars * Tokens.charDots

    implicitHeight: Tokens.fontPx
    clip: true

    property int offset: 0
    onTextChanged: offset = 0

    Row {
        x: root.runs ? -root.offset : 0
        height: root.height
        spacing: root.gapChars * Tokens.charDots
        opacity: root.textOpacity

        DotText {
            id: one
            text: root.text
            color: root.color
        }
        DotText {
            visible: root.runs
            text: root.text
            color: root.color
        }
    }

    HoverHandler {
        id: hover
    }

    Timer {
        running: root.runs && root.visible && !hover.hovered
        interval: root.stepMs
        repeat: true
        onTriggered: root.offset = (root.offset + 1) % Math.max(1, root.period)
    }
}
