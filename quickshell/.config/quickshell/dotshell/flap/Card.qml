import QtQuick

// A card inside the housing, crisp: a step lighter than it, ruled in the
// rim's grey (the expanded boards' gauges, message groups, desks). `on`
// rules it yellow, 2 px (the picked one).
//   Card { width: 120; height: 60; on: true }
Rectangle {
    property bool on: false

    color: Ink.card
    border.width: 2
    border.color: on ? Ink.yellow : Ink.rim
}
