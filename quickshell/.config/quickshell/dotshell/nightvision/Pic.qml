import QtQuick
import qs

// A picture seen through the scope: its light mapped onto the phosphor's
// greens, as dots (the EVIDENCE thumbs, the media panel's target); sized
// in screen px. `round` cuts it to a circle.
//   Pic { width: 160; height: 90; source: "file:///…/shot.png" }
Item {
    id: pic

    property alias source: img.source
    property bool round: false
    readonly property bool ready: img.status === Image.Ready

    DotSurface {
        id: dots
        anchors.centerIn: parent
        cols: Math.max(1, Math.floor(pic.width / Tokens.pitch))
        rows: Math.max(1, Math.floor(pic.height / Tokens.pitch))
        imageMode: true
        dither: true
        shape: pic.round ? "M 0 " + (rows / 2) + " A " + (cols / 2) + " " + (rows / 2) + " 0 1 1 " + cols + " " + (rows / 2) + " A " + (cols / 2) + " " + (rows / 2) + " 0 1 1 0 " + (rows / 2) + " Z" : ""
        Image {
            id: img
            width: dots.cols
            height: dots.rows
            sourceSize: Qt.size(dots.cols * 2, dots.rows * 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
        }
    }
}
