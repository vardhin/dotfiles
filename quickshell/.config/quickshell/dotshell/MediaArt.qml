import QtQuick
import QtQuick.Effects
import qs.services

// The track's cover, in dots (on a DotSurface canvas, 1 px = 1 dot), square
// or round. Until there is one (or while it loads): the design canvas's
// stand-in, stripes with a sun in the era's colors.
//
//   MediaArt { width: 30; height: 30; src: ctx.art; round: true }
Item {
    id: art

    property string src: ""
    property bool round: false
    // The stand-in's colors: stripes, the sun, the ground.
    property color stripe: Tokens.slot2
    property color sun: Tokens.slot1
    property color ground: Tokens.unlit

    readonly property bool ready: cover.status === Image.Ready

    Canvas {
        anchors.fill: parent
        visible: !art.ready
        readonly property string sig: [width, height, art.round, art.stripe, art.sun, art.ground].join()
        onSigChanged: requestPaint()
        onPaint: {
            const c = getContext("2d");
            c.reset();
            const w = width, h = height;
            c.save();
            c.beginPath();
            if (art.round)
                c.arc(w / 2, h / 2, w / 2, 0, Math.PI * 2);
            else
                c.rect(0, 0, w, h);
            c.clip();
            c.fillStyle = String(art.ground);
            c.fillRect(0, 0, w, h);
            c.fillStyle = String(art.stripe);
            for (let y = 2; y < h; y += 3)
                c.fillRect(0, y, w, 1);
            c.fillStyle = String(art.sun);
            c.beginPath();
            c.arc(w / 2, h * 0.58, w * 0.22, 0, Math.PI * 2);
            c.fill();
            c.restore();
        }
    }

    Item {
        anchors.fill: parent
        visible: art.ready
        layer.enabled: art.round && visible
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: disc
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0
        }
        Image {
            id: cover
            anchors.fill: parent
            source: art.src
            sourceSize: Qt.size(width, height)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
        }
    }
    Rectangle {
        id: disc
        anchors.fill: parent
        radius: width / 2
        visible: false
        layer.enabled: true
    }
}
