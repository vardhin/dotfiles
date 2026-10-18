import QtQuick
import qs.services

// The media device's key row: previous, play / pause, next (1 : 1.4 : 1).
// The same row on the mini panel and on the full device (Super M).
Row {
    id: keys

    required property var hw
    property var grip: null

    readonly property real unit: (width - spacing * 2) / 3.4

    height: hw.keys.h
    spacing: hw.keys.gap

    RubberKey {
        hw: keys.hw
        grip: keys.grip
        width: Math.floor(keys.unit)
        icon: "M0 1 L3 1 L3 13 L0 13 Z M15 1 L4 7 L15 13 Z"
        onClicked: Media.previous()
    }
    RubberKey {
        hw: keys.hw
        grip: keys.grip
        width: Math.floor(keys.unit * 1.4)
        icon: Media.isPlaying ? "M1 0 L5 0 L5 16 L1 16 Z M9 0 L13 0 L13 16 L9 16 Z" : "M2 0 L14 8 L2 16 Z"
        ink: Tokens.slot0
        onClicked: Media.toggle()
    }
    RubberKey {
        hw: keys.hw
        grip: keys.grip
        width: Math.floor(keys.unit)
        icon: "M1 1 L12 7 L1 13 Z M13 1 L16 1 L16 13 L13 13 Z"
        onClicked: Media.next()
    }
}
