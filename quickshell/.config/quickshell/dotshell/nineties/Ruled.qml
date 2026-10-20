import QtQuick

// Notebook ruling, crisp (Todo): light blue lines every `step` px from
// `from` down, and the pink margin line at `margin` px.
//   Ruled { anchors.fill: parent; step: 24; margin: 30 }
Item {
    id: ruled

    property real step: 24
    property real from: step
    property real margin: 30

    Repeater {
        model: Math.max(0, Math.floor((ruled.height - ruled.from) / ruled.step) + 1)
        Rectangle {
            required property int index
            y: Math.round(ruled.from + index * ruled.step) - 1
            width: ruled.width
            height: 1
            color: Ink.paperRule
        }
    }
    Rectangle {
        visible: ruled.margin > 0
        x: ruled.margin
        width: 1
        height: ruled.height
        color: Ink.paperMargin
    }
}
