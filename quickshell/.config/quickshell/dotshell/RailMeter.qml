import QtQuick

// A vertical meter for the side rail: 3-dot wide segments, lit from the
// bottom up to `value` (0 .. 1); the top ones take the hotter tubes.
Item {
    id: meter
    property real value: 0
    readonly property int segments: 16

    width: 3
    height: segments * 2 - 1

    Column {
        spacing: 1
        Repeater {
            model: meter.segments
            Rectangle {
                required property int index
                // Top segment first.
                readonly property real at: (meter.segments - index) / meter.segments
                width: 3
                height: 1
                visible: meter.value >= at - 0.5 / meter.segments
                color: at > 0.9 ? Tokens.slot2 : at > 0.7 ? Tokens.slot1 : Tokens.slot0
            }
        }
    }
}
