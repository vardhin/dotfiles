import QtQuick
import QtQuick.Effects
import qs.services
import "Matrix.js" as Matrix

// The media readout, in dots (a DotSurface canvas, 1 px = 1 dot), as the
// era's device draws it (Hardware.js `readout`): the one display the media
// device shows, on the mini panel and at the top of MEDIA's NOW page
// (Super M) alike. The VFD's, for one:
//
//   ST ♪ TV RPT RND VIS LYR annunciators .............. the player
//   THE TITLE, one 5x7 cell per character ............ 1:38 (amber)
//   ARTIST · ALBUM ....................................... /3:54
//   a segment bar (click to seek)
//
// Other eras put the cover art at the left (square or round, a gunsight on
// it), a fixed word over the title instead of the annunciators, a prompt
// and a blinking cursor round the title, the title in split-flap tiles,
// code raining behind, and their own progress bar (blocks, lives, a line
// with a knob, chevrons, `[####----]`, a box, a tube, a dimension line,
// flap tiles), with the time after it, or nowhere (tubes or a head band
// show it). The colors are the era's tubes, by role (`ink`).
//
// On the mini panel (`full` false) the lyrics and the music are always in it
// too: under the title the line being sung, lit left to right as it is sung
// (karaoke) and breathing, rolling up to the next line (the artist instead
// while a song has none); under that a thin spectrum, each bar with a peak
// dot that falls back slowly. MEDIA (`full`) has its own spectrum, note bar
// and lyrics sheet under the readout, so there it is just the track.
//
// What does not fit goes first as it gets shorter: the spectrum, the lyric,
// the sub line, the legends, then the art.
Item {
    id: root

    // The device (Hardware.get): its `readout`.
    required property var hw
    property var ctx: Feeds.mediaFeed
    property string idle: "NOTHING PLAYING"
    // MEDIA's NOW page: no lyric line or spectrum in here.
    property bool full: false
    // Extra room at the sides (a pill window's round ends).
    property int inL: 0
    property int inR: 0

    readonly property var ro: hw.readout
    readonly property bool active: !!ctx.active
    readonly property bool playing: !!ctx.playing

    // The era's tubes by role.
    readonly property var slots: [Tokens.slot0, Tokens.slot1, Tokens.slot2]
    readonly property color cTitle: slots[ro.ink[0]] ?? Tokens.slot0
    readonly property color cSub: slots[ro.ink[1]] ?? Tokens.slot2
    readonly property color cTime: slots[ro.ink[2]] ?? Tokens.slot1
    readonly property color cBar: slots[ro.ink[3]] ?? Tokens.slot0
    readonly property color cAlt: slots[ro.ink[4]] ?? Tokens.slot1
    // The unlit cell grid, faintly through the glass.
    readonly property color ghost: Qt.rgba(Tokens.unlit.r + (Tokens.slot0.r - Tokens.unlit.r) * 0.06, Tokens.unlit.g + (Tokens.slot0.g - Tokens.unlit.g) * 0.06, Tokens.unlit.b + (Tokens.slot0.b - Tokens.unlit.b) * 0.06, 1)

    readonly property int padX: 4
    readonly property int padY: height >= 34 ? 3 : 2
    readonly property int left0: padX + inL
    readonly property int right0: width - padX - inR
    // What fits: the sub line and the legends go first as the dots get
    // coarser (bigger pitch, same panel; a shorter slot).
    readonly property bool roomy: height >= 30
    readonly property bool legends: ro.legends !== "none" && height >= 22
    readonly property bool annunciators: ro.legends === "annunciators"

    // The cover, left, as tall as the window; a round one sits in a pill's
    // round end, where the side room is. MEDIA (`full`) shows its own.
    readonly property int artSize: Math.max(0, Math.min(height - padY * 2, Math.round((width - padX * 2) * 0.3)))
    readonly property int artX: ro.art === "round" && inL > 0 ? Math.max(1, Math.round((height - artSize) / 2)) : left0
    readonly property bool artOn: ro.art !== "none" && !full && height >= 16 && right0 - artX - artSize - 4 >= 40
    readonly property int textX: artOn ? artX + artSize + 4 : left0

    readonly property bool timeRight: ro.time === "right"
    readonly property int rightW: timeRight ? Math.max(time.implicitWidth, total.implicitWidth, 23) : 0
    readonly property int leftW: right0 - textX - (timeRight ? rightW + 6 : 0)

    // Split-flap tiles stand a dot proud of the cells, above and below.
    readonly property int flapPad: ro.flaps ? 1 : 0
    readonly property int barH: ({
            segments: 2,
            blocks: 3,
            lives: 2,
            line: 3,
            chevrons: 5,
            box: 6,
            tube: 6,
            dim: 5,
            flap: 5,
            text: 7
        })[ro.bar] ?? 2
    readonly property int barY: height - padY - barH
    readonly property int midTop: legends ? padY + 5 : padY
    readonly property int midBot: barY - 1
    readonly property int midH: 7 + flapPad * 2 + (full && lyricRow ? 9 : 0) + (roomy ? 3 + 5 : 0)
    // Mini: title at the top of the middle, then the lyric (or sub line),
    // then the spectrum down to the bar.
    // MEDIA shows the sung line here too when the lyrics are synced (its
    // sheet below the music is for unsynced ones).
    readonly property bool lyricRow: height >= 28 && Lyrics.has && (!full || Lyrics.synced)
    readonly property int titleY: (full ? midTop + Math.floor((midBot - midTop - midH) / 2) : midTop + 2) + flapPad
    readonly property int lyricY: titleY + 9 + flapPad
    // MEDIA keeps the artist under the sung line; the mini panel has no room.
    readonly property int subY: titleY + flapPad + (full && lyricRow ? 19 : 10)
    readonly property bool spectrumRow: !full && height >= 34
    readonly property int spectrumY: (lyricRow ? lyricY + 9 : titleY + flapPad + (roomy ? 16 : 9))

    // ── Code rain, behind everything ────────────────────────────────
    Canvas {
        id: rain
        anchors.fill: parent
        visible: root.ro.rain
        property var drops: []
        readonly property string tint: String(Tokens.slot2)
        function seed(): void {
            const n = Math.max(1, Math.floor(width / 3));
            const d = [];
            for (let i = 0; i < n; i++)
                d.push({ y: Math.random() * height * 2 - height, v: 0.3 + Math.random() * 0.6, len: 4 + Math.floor(Math.random() * 8) });
            drops = d;
        }
        onWidthChanged: seed()
        onHeightChanged: seed()
        Timer {
            interval: 90
            repeat: true
            running: rain.visible && root.visible
            onTriggered: {
                for (const d of rain.drops) {
                    d.y += d.v;
                    if (d.y - d.len > rain.height) {
                        d.y = -Math.random() * rain.height;
                        d.v = 0.3 + Math.random() * 0.6;
                    }
                }
                rain.requestPaint();
            }
        }
        onPaint: {
            const c = getContext("2d");
            c.reset();
            c.fillStyle = tint;
            for (let i = 0; i < drops.length; i++) {
                const d = drops[i], head = Math.floor(d.y);
                for (let k = 0; k < d.len; k++) {
                    c.globalAlpha = 0.45 * (1 - k / d.len);
                    c.fillRect(i * 3 + 1, head - k, 1, 1);
                }
            }
        }
    }

    // ── The cover ───────────────────────────────────────────────────
    Item {
        id: art
        visible: root.artOn
        x: root.artX
        y: Math.round((root.height - root.artSize) / 2)
        width: root.artSize
        height: root.artSize
        readonly property bool round: root.ro.art === "round"
        readonly property string src: root.active ? (root.ctx.art ?? "") : ""

        // No cover (or not loaded yet): stripes and a sun, in the era.
        Canvas {
            id: placeholder
            anchors.fill: parent
            visible: cover.status !== Image.Ready
            readonly property string sig: [width, height, art.round, root.cTitle, root.cSub, root.ghost].join()
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
                c.fillStyle = String(root.ghost);
                c.fillRect(0, 0, w, h);
                c.fillStyle = String(root.cSub);
                c.globalAlpha = 0.45;
                for (let y = 1; y < h; y += 3)
                    c.fillRect(0, y, w, 1);
                c.globalAlpha = 1;
                c.fillStyle = String(root.cTitle);
                c.beginPath();
                c.arc(w / 2, h * 0.55, w * 0.22, 0, Math.PI * 2);
                c.fill();
                c.restore();
            }
        }

        Item {
            anchors.fill: parent
            visible: cover.status === Image.Ready
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

        // A gunsight on it (goggles).
        Canvas {
            anchors.fill: parent
            visible: root.ro.reticle
            readonly property string sig: [width, height, root.cTitle].join()
            onSigChanged: requestPaint()
            onPaint: {
                const c = getContext("2d");
                c.reset();
                const w = width, m = Math.floor(w / 2), e = Math.max(2, Math.round(w * 0.1));
                c.fillStyle = String(root.cTitle);
                c.fillRect(m, e, 1, w - e * 2);
                c.fillRect(e, m, w - e * 2, 1);
                c.strokeStyle = String(root.cTitle);
                c.lineWidth = 1;
                c.beginPath();
                c.arc(m + 0.5, m + 0.5, Math.max(3, Math.round(w * 0.2)), 0, Math.PI * 2);
                c.stroke();
            }
        }
    }

    // ── Over the title: the annunciators, or a fixed word ───────────
    Row {
        visible: root.legends && root.annunciators
        x: root.textX
        y: root.padY
        spacing: 4
        Repeater {
            model: [
                { t: "ST", on: root.playing },
                { t: "♪", on: root.active && !root.ctx.hasVideo },
                { t: "TV", on: !!root.ctx.tv },
                { t: "RPT", on: (Media.player?.loopState ?? 0) !== 0 },
                { t: "RND", on: !!Media.player?.shuffle },
                { t: "LYR", on: !!root.ctx.hasLyrics }
            ]
            MatrixText {
                required property var modelData
                font: "3x5"
                text: modelData.t
                width: implicitWidth
                height: implicitHeight
                color: !modelData.on ? root.ghost : Tokens.slot0
            }
        }
    }
    MatrixText {
        visible: root.legends && root.annunciators
        font: "3x5"
        x: root.width - root.padX - root.inR - width
        y: root.padY
        width: Math.min(implicitWidth, root.rightW + 12)
        height: implicitHeight
        align: "right"
        // The player's last word (MOZILLA FIREFOX: FIREFOX), cut to fit.
        text: String(root.ctx.player ?? "").trim().split(/\s+/).pop()
        color: Tokens.slot2
    }
    MatrixText {
        visible: root.legends && !root.annunciators
        font: "3x5"
        x: root.textX
        y: root.padY
        width: Math.min(implicitWidth, root.right0 - root.textX)
        height: implicitHeight
        text: root.ro.legends
        color: Tokens.slot2
    }

    // ── The title ───────────────────────────────────────────────────
    // In its cells; anything the 5x7 set can't draw (CJK, Devanagari) in
    // the shell's pixel font instead.
    readonly property string title: root.ro.prefix + (root.active ? (root.ctx.title || root.idle) : root.idle)
    readonly property bool matrix: Matrix.covers("5x7", title)

    // Split-flap: a tile behind each cell, its seam across the middle.
    Repeater {
        model: root.ro.flaps && root.matrix ? Math.max(0, Math.floor((root.leftW + 2) / 7)) : 0
        Rectangle {
            required property int index
            x: root.textX + index * 7 - 1
            y: root.titleY - 1
            width: 6
            height: 9
            color: Tokens.unlit
            Rectangle {
                y: 4
                width: parent.width
                height: 1
                color: Tokens.glass
            }
        }
    }
    MatrixText {
        id: titleText
        visible: root.matrix
        x: root.textX
        y: root.titleY
        width: root.leftW
        height: implicitHeight
        text: root.title
        gap: root.ro.flaps ? 2 : 1
        ghost: root.ro.cells ? root.ghost : "transparent"
        cells: root.ro.cells
        scroll: true
        color: root.cTitle
    }
    DotText {
        visible: !root.matrix
        x: root.textX
        y: root.titleY - 2
        width: root.leftW
        height: 11
        elide: Text.ElideRight
        text: root.title.toUpperCase()
        color: root.cTitle
    }
    // A prompt's cursor, blinking after the title while it fits.
    Rectangle {
        property bool on: true
        visible: root.ro.cursor && root.matrix && on && titleText.shown.length < titleText.capacity
        x: root.textX + titleText.shown.length * titleText.advance
        y: root.titleY
        width: 5
        height: 7
        color: root.cTitle
        Timer {
            interval: 530
            repeat: true
            running: root.ro.cursor && root.visible
            onTriggered: parent.on = !parent.on
        }
    }

    MatrixText {
        id: time
        visible: root.timeRight
        x: root.width - root.padX - root.inR - width
        y: root.titleY
        width: implicitWidth
        height: implicitHeight
        align: "right"
        text: root.active ? Media.clock(root.ctx.pos) : "-:--"
        color: root.active ? root.cTime : root.ghost
    }

    // Who and what, small, under the title; the length under the time.
    MatrixText {
        visible: root.roomy && (!root.lyricRow || root.full)
        font: "3x5"
        x: root.textX
        y: root.subY
        width: root.leftW
        height: implicitHeight
        scroll: true
        text: root.active ? [root.ctx.artist, root.ctx.album].filter(s => !!s).join(" · ") : (root.ctx.count ?? 0) + " IN THE LIBRARY"
        color: root.cSub
    }
    MatrixText {
        id: total
        visible: root.roomy && root.timeRight
        font: "3x5"
        x: root.width - root.padX - root.inR - width
        y: root.subY
        width: implicitWidth
        height: implicitHeight
        align: "right"
        text: root.active && root.ctx.len > 0 ? "/" + Media.clock(root.ctx.len) : ""
        color: root.cSub
    }

    // ── The progress bar ────────────────────────────────────────────
    readonly property real progress: active ? (ctx.progress ?? 0) : 0

    // The time after the bar, small (or 5x7 beside a tall one).
    MatrixText {
        id: barTime
        visible: root.ro.time === "bar" && root.ro.bar !== "text"
        font: root.barH >= 7 ? "5x7" : "3x5"
        x: root.textX + root.leftW - width
        y: root.barY + Math.round((root.barH - implicitHeight) / 2)
        width: implicitWidth
        height: implicitHeight
        align: "right"
        text: root.active ? Media.clock(root.ctx.pos) : "-:--"
        color: root.active ? root.cTime : root.ghost
    }

    // A terminal's bar, in words: [########------] 1:38/3:54.
    MatrixText {
        visible: root.ro.bar === "text"
        x: root.textX
        y: root.barY
        width: root.leftW
        height: implicitHeight
        color: root.cBar
        text: {
            // The time and length, or just the time, or no time: whatever
            // leaves the bar ten cells.
            const cap = Math.max(0, Math.floor((width + 1) / 6));
            const pos = root.active ? Media.clock(root.ctx.pos) : "-:--";
            const t = root.ro.time !== "bar" ? "" : [pos + "/" + Media.clock(root.ctx.len), pos].find(s => cap - 3 - s.length >= 10) ?? "";
            const n = Math.max(0, cap - 2 - (t ? t.length + 1 : 0));
            const k = Math.round(root.progress * n);
            return "[" + "#".repeat(k) + "-".repeat(n - k) + "]" + (t ? " " + t : "");
        }
    }

    Canvas {
        id: bar
        visible: root.ro.bar !== "text"
        x: root.textX
        y: root.barY
        width: Math.max(1, root.leftW - (barTime.visible ? barTime.width + 3 : 0))
        height: root.barH
        readonly property string sig: [width, height, root.ro.bar, root.ro.stripe, Math.round(root.progress * width), root.cBar, root.cAlt, root.ghost, Tokens.glass].join()
        onSigChanged: requestPaint()
        onPaint: {
            const c = getContext("2d");
            c.reset();
            const W = width, H = height, p = root.progress, s = root.ro.bar;
            const main = String(root.cBar), alt = String(root.cAlt), off = String(root.ghost);
            const box = (x, y, w, h, col) => {
                c.fillStyle = col;
                c.fillRect(x, y, w, h);
            };
            // A row of cells `step` apart, lit up to the progress.
            const cells = (step, cw, draw) => {
                const n = Math.max(1, Math.floor((W - cw) / step) + 1), lit = Math.round(p * n);
                for (let i = 0; i < n; i++)
                    draw(i * step, i < lit ? (root.ro.stripe && i % 2 ? alt : main) : off, i < lit);
            };
            const k = Math.round(p * W);
            switch (s) {
            case "blocks":
                cells(4, 3, (x, col) => box(x, 0, 3, 3, col));
                break;
            case "lives":
                cells(4, 3, (x, col) => box(x, 0, 3, 2, col));
                break;
            case "chevrons":
                cells(5, 4, (x, col) => {
                    for (const [dx, dy] of [[0, 0], [1, 1], [2, 2], [1, 3], [0, 4]])
                        box(x + dx, dy, 2, 1, col);
                });
                break;
            case "flap":
                cells(4, 3, (x, col) => {
                    box(x, 0, 3, H, col);
                    box(x, 2, 3, 1, String(Tokens.glass));
                });
                break;
            case "line":
                box(0, 1, W, 1, off);
                box(0, 1, k, 1, main);
                box(Math.max(0, Math.min(W - 3, k - 1)), 0, 3, 3, alt);
                break;
            case "box":
            case "tube":
                {
                    const rim = s === "tube" ? off : alt, r = s === "tube" ? 1 : 0;
                    box(r, 0, W - r * 2, 1, rim);
                    box(r, H - 1, W - r * 2, 1, rim);
                    box(0, r, 1, H - r * 2, rim);
                    box(W - 1, r, 1, H - r * 2, rim);
                    box(2, 2, Math.round(p * (W - 4)), H - 4, main);
                }
                break;
            case "dim":
                box(0, 2, W, 1, alt);
                box(0, 0, 1, H, alt);
                box(W - 1, 0, 1, H, alt);
                box(Math.max(1, Math.min(W - 3, k)), 0, 2, H, main);
                break;
            default:
                cells(3, 2, (x, col) => box(x, 0, 2, 2, col));
            }
        }
    }
    MouseArea {
        x: root.textX
        y: root.barY - 2
        width: bar.visible ? bar.width : root.leftW
        height: root.barH + 4
        enabled: root.active
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => Media.seekTo(Math.max(0, Math.min(1, mouse.x / width)))
    }

    // ── The spectrum, thin, above the bar ───────────────────────────
    Item {
        id: vis
        visible: root.spectrumRow && root.midBot - 1 - root.spectrumY >= 3
        x: root.textX
        y: root.spectrumY
        width: root.leftW
        height: root.midBot - 1 - root.spectrumY
        readonly property int n: Math.max(1, Math.floor((width + 1) / 3))
        readonly property string key: "readout-" + Math.random().toString(36).slice(2)
        onVisibleChanged: Media.want(key, visible)
        Component.onCompleted: Media.want(key, visible)
        Component.onDestruction: Media.want(key, false)

        Repeater {
            model: vis.n
            Item {
                id: col
                required property int index
                x: index * 3
                width: 2
                height: vis.height
                readonly property real value: {
                    const src = Media.bars, k = src.length;
                    const a = Math.floor(index * k / vis.n), b = Math.max(a + 1, Math.floor((index + 1) * k / vis.n));
                    let sum = 0;
                    for (let i = a; i < b; i++)
                        sum += src[i] ?? 0;
                    return Math.max(0, Math.min(1, sum / (b - a)));
                }
                readonly property int lit: Math.round(value * height)
                // The peak: jumps up with the bar, falls back slowly.
                property real peak: 0
                onLitChanged: {
                    if (lit >= peak) {
                        fall.stop();
                        peak = lit;
                    } else if (!fall.running) {
                        fall.from = peak;
                        fall.restart();
                    }
                }
                NumberAnimation {
                    id: fall
                    target: col
                    property: "peak"
                    to: 0
                    duration: 900
                    easing.type: Easing.InQuad
                }
                Rectangle {
                    width: 2
                    height: col.height
                    color: root.ghost
                }
                Rectangle {
                    y: col.height - col.lit
                    width: 2
                    height: col.lit
                    color: root.cBar
                }
                Rectangle {
                    visible: col.peak >= 1
                    y: col.height - Math.round(col.peak)
                    width: 2
                    height: 1
                    color: root.cAlt
                }
            }
        }
    }

    // ── The line being sung, karaoke, rolling up ────────────────────
    LyricLine {
        visible: root.lyricRow
        x: root.textX
        y: root.lyricY
        width: root.leftW
        color: root.cTitle
        rest: root.cSub
        ghost: root.ro.cells ? root.ghost : "transparent"
        cells: root.ro.cells
        playing: root.playing
    }
}
