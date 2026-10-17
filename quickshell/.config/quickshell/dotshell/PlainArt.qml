import QtQuick

// A picture as it is, not as dots: cover art and thumbnails. Laid out in
// dots like anything on a DotSurface, but drawn on the surface's plainLayer
// above the dot shader, in screen px, so it stays sharp.
//   PlainArt { width: 32; height: 48; source: Media.art }
// Shows nothing until the image loads, so the board's unlit dots stay.
Item {
    id: root

    property alias source: img.source
    property int fillMode: Image.PreserveAspectCrop
    readonly property bool ready: img.status === Image.Ready

    // The DotSurface this sits on.
    readonly property Item host: {
        for (let p = parent; p; p = p.parent)
            if (p.plainLayer !== undefined)
                return p.plainLayer;
        return null;
    }

    Image {
        id: img
        parent: root.host
        visible: root.visible && root.ready && root.host !== null
        fillMode: root.fillMode
        smooth: true
        mipmap: true
        asynchronous: true
        clip: true
        sourceSize: Qt.size(width * 2, height * 2)
    }

    // Follow the spot in the canvas: shelves scroll and fold, panes move.
    function place(): void {
        if (!root.host)
            return;
        const a = root.mapToItem(root.host, 0, 0);
        const b = root.mapToItem(root.host, root.width, root.height);
        img.x = Math.round(a.x);
        img.y = Math.round(a.y);
        img.width = Math.round(b.x) - img.x;
        img.height = Math.round(b.y) - img.y;
    }
    FrameAnimation {
        running: root.visible && root.host !== null
        onTriggered: root.place()
    }
    Component.onCompleted: place()
}
