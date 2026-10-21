import QtQuick

// The moon sticker on the ceiling: a glow-star crescent behind the clock's
// words (the compact board). A disc with a disc cut out of it (so the
// glass's unlit dots show through the bite), drawn on the sign's glass in
// dots, dim enough that the time reads over it.
// (Once the outrun sun; the name stays so the faces need no change.)
//   Sun { width: 50; height: 50 }
Canvas {
    id: sun

    readonly property color tint: Ink.yellow

    opacity: 0.35
    onTintChanged: requestPaint()
    onWidthChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d");
        const r = width / 2;
        ctx.reset();
        ctx.fillStyle = tint;
        ctx.beginPath();
        ctx.arc(r, r, r, 0, Math.PI * 2);
        ctx.fill();
        ctx.globalCompositeOperation = "destination-out";
        ctx.beginPath();
        ctx.arc(r + r * 0.64, r - r * 0.24, r, 0, Math.PI * 2);
        ctx.fill();
    }
}
