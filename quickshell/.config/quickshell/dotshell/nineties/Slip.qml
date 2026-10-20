import QtQuick

// A sticky slip, crisp (Clipboard): cream paper tilted a hair, a hard dark
// shadow under its bottom right. `lit` makes it the yellow one (the newest
// or the picked copy), tilted the other way.
//   Slip { width: 300; height: 26; lit: true }
Item {
    id: slip

    property bool lit: false
    property real tilt: lit ? 0.6 : -0.6
    property real drop: 2

    rotation: tilt
    antialiasing: true
    Rectangle {
        x: slip.drop
        y: slip.drop
        width: slip.width
        height: slip.height
        color: Ink.shadow
        antialiasing: true
    }
    Rectangle {
        anchors.fill: parent
        color: slip.lit ? Ink.c("#ffe600", "#ffe14a") : Ink.slip
        antialiasing: true
    }
}
