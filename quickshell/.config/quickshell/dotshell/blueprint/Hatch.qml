import QtQuick

// Section hatching, crisp: 45° lines `gap` px apart, clipped to the item
// (the design's cut battery cell and floor plan furniture).
//   Hatch { width: 90; height: 56; color: Ink.hatch }
Item {
    id: hatch

    property color color: Ink.hatch
    property real gap: 6

    clip: true
    Canvas {
        anchors.fill: parent
        readonly property string sig: [width, height, hatch.color, hatch.gap].join()
        onSigChanged: requestPaint()
        onPaint: {
            const c = getContext("2d");
            c.reset();
            c.strokeStyle = String(hatch.color);
            c.lineWidth = 1;
            c.beginPath();
            for (let x = -height; x < width + height; x += hatch.gap) {
                c.moveTo(x, height);
                c.lineTo(x + height, 0);
            }
            c.stroke();
        }
    }
}
