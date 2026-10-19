import QtQuick
import qs
import "../Shapes.js" as Shapes

// A picture as LED dots in its own colours (the design's dot-masked
// thumbnails), cut to a rounded rectangle; sized in screen px.
//   DotPic { width: 160; height: 90; source: "file:///…/shot.png"; radius: 12 }
Item {
    id: pic

    property alias source: img.source
    property real radius: 8
    readonly property bool ready: img.status === Image.Ready

    DotSurface {
        id: dots
        anchors.centerIn: parent
        cols: Math.max(1, Math.floor(pic.width / Tokens.pitch))
        rows: Math.max(1, Math.floor(pic.height / Tokens.pitch))
        shape: Shapes.rounded(cols, rows, Math.round(pic.radius / Tokens.pitch))
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
