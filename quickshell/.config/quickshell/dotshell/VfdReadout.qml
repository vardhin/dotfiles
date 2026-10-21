import QtQuick
import qs.services
import "Matrix.js" as Matrix

// The VFD media readout, in dots (a DotSurface canvas, 1 px = 1 dot): the
// one display the media device shows, on the mini panel and at the top of
// MEDIA's NOW page (Super M) alike.
//
//   ST ♪ TV RPT RND VIS LYR annunciators .............. the player
//   THE TITLE, one 5x7 cell per character ............ 1:38 (amber)
//   ARTIST · ALBUM ....................................... /3:54
//   a segment bar (click to seek)
//
// On the mini panel (`full` false) the lyrics and the music are always in it
// too: under the title the line being sung, lit left to right as it is sung
// (karaoke) and breathing, rolling up to the next line (the artist instead
// while a song has none); under that a thin spectrum, each bar with a peak
// dot that falls back slowly. MEDIA (`full`) has its own spectrum, note bar
// and lyrics sheet under the readout, so there it is just the track.
//
// What does not fit goes first as it gets shorter: the spectrum, the lyric,
// the sub line, then the annunciators.
Item {
    id: root

    property var ctx: Feeds.mediaFeed
    property string idle: "NOTHING PLAYING"
    // MEDIA's NOW page: no lyric line or spectrum in here.
    property bool full: false
    readonly property bool active: !!ctx.active
    readonly property bool playing: !!ctx.playing
    // The unlit cell grid, faintly through the glass.
    readonly property color ghost: Qt.rgba(Tokens.unlit.r + (Tokens.slot0.r - Tokens.unlit.r) * 0.06, Tokens.unlit.g + (Tokens.slot0.g - Tokens.unlit.g) * 0.06, Tokens.unlit.b + (Tokens.slot0.b - Tokens.unlit.b) * 0.06, 1)

    readonly property int padX: 4
    readonly property int padY: height >= 34 ? 3 : 2
    // What fits: the sub line and the annunciators go first as the
    // dots get coarser (bigger pitch, same panel; a shorter slot).
    readonly property bool roomy: height >= 30
    readonly property bool legends: height >= 22
    readonly property int rightW: Math.max(time.implicitWidth, total.implicitWidth, 23)
    readonly property int leftW: width - padX * 2 - rightW - 6
    readonly property int midTop: legends ? padY + 5 : padY
    readonly property int midBot: height - padY - 3
    readonly property int midH: 7 + (full && lyricRow ? 9 : 0) + (roomy ? 3 + 5 : 0)
    // Mini: title at the top of the middle, then the lyric (or sub line),
    // then the spectrum down to the segment bar.
    // MEDIA shows the sung line here too when the lyrics are synced (its
    // sheet below the music is for unsynced ones).
    readonly property bool lyricRow: height >= 28 && Lyrics.has && (!full || Lyrics.synced)
    // MEDIA keeps the artist under the sung line; the mini panel has no room.
    readonly property int subY: titleY + (full && lyricRow ? 19 : 10)
    readonly property bool spectrumRow: !full && height >= 34
    readonly property int titleY: full ? midTop + Math.floor((midBot - midTop - midH) / 2) : midTop + 2
    readonly property int lyricY: titleY + 9
    readonly property int spectrumY: (lyricRow ? lyricY + 9 : titleY + (roomy ? 16 : 9))

    // Annunciators: fixed legends, lit when they apply.
    Row {
        visible: root.legends
        x: root.padX
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
                color: !modelData.on ? root.ghost : modelData.hot ? Tokens.slot1 : Tokens.slot0
            }
        }
    }
    MatrixText {
        visible: root.legends
        font: "3x5"
        x: root.width - root.padX - width
        y: root.padY
        width: Math.min(implicitWidth, root.rightW + 12)
        height: implicitHeight
        align: "right"
        // The player's last word (MOZILLA FIREFOX: FIREFOX), cut to fit.
        text: String(root.ctx.player ?? "").trim().split(/\s+/).pop()
        color: Tokens.slot2
    }

    // The title, in its cells; anything the 5x7 set can't draw
    // (CJK, Devanagari) in the shell's pixel font instead.
    readonly property string title: root.active ? (root.ctx.title || root.idle) : root.idle
    readonly property bool matrix: Matrix.covers("5x7", title)
    MatrixText {
        visible: root.matrix
        x: root.padX
        y: root.titleY
        width: root.leftW
        height: implicitHeight
        text: root.title
        ghost: root.ghost
        cells: true
        scroll: true
        color: Tokens.slot0
    }
    DotText {
        visible: !root.matrix
        x: root.padX
        y: root.titleY - 2
        width: root.leftW
        height: 11
        elide: Text.ElideRight
        text: root.title.toUpperCase()
        color: Tokens.slot0
    }
    MatrixText {
        id: time
        x: root.width - root.padX - width
        y: root.titleY
        width: implicitWidth
        height: implicitHeight
        align: "right"
        text: root.active ? Media.clock(root.ctx.pos) : "-:--"
        color: root.active ? Tokens.slot1 : root.ghost
    }

    // Who and what, small, under the title; the length under the time.
    MatrixText {
        visible: root.roomy && (!root.lyricRow || root.full)
        font: "3x5"
        x: root.padX
        y: root.subY
        width: root.leftW
        height: implicitHeight
        scroll: true
        text: root.active ? [root.ctx.artist, root.ctx.album].filter(s => !!s).join(" · ") : (root.ctx.count ?? 0) + " IN THE LIBRARY"
        color: Tokens.slot2
    }
    MatrixText {
        id: total
        visible: root.roomy
        font: "3x5"
        x: root.width - root.padX - width
        y: root.subY
        width: implicitWidth
        height: implicitHeight
        align: "right"
        text: root.active && root.ctx.len > 0 ? "/" + Media.clock(root.ctx.len) : ""
        color: Tokens.slot2
    }

    // The segment bar: 2-dot segments, one dot apart.
    Item {
        id: bar
        x: root.padX
        y: root.midBot + 1
        width: root.leftW
        height: 2
        readonly property int n: Math.max(1, Math.floor((width + 1) / 3))
        readonly property int lit: root.active ? Math.round((root.ctx.progress ?? 0) * n) : 0
        Repeater {
            model: bar.n
            Rectangle {
                required property int index
                x: index * 3
                width: 2
                height: 2
                color: index < bar.lit ? Tokens.slot0 : root.ghost
            }
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -2
            enabled: root.active
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => Media.seekTo(Math.max(0, Math.min(1, mouse.x / bar.width)))
        }
    }

    // ── The spectrum, thin, above the segment bar ───────────────────
    Item {
        id: vis
        visible: root.spectrumRow && root.midBot - 1 - root.spectrumY >= 3
        x: root.padX
        y: root.spectrumY
        width: root.leftW
        height: root.midBot - 1 - root.spectrumY
        readonly property int n: Math.max(1, Math.floor((width + 1) / 3))
        readonly property string key: "vfd-" + Math.random().toString(36).slice(2)
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
                    color: Tokens.slot0
                }
                Rectangle {
                    visible: col.peak >= 1
                    y: col.height - Math.round(col.peak)
                    width: 2
                    height: 1
                    color: Tokens.slot1
                }
            }
        }
    }

    // ── The line being sung, karaoke, rolling up ────────────────────
    LyricLine {
        visible: root.lyricRow
        x: root.padX
        y: root.lyricY
        width: root.leftW
        color: Tokens.slot0
        rest: Tokens.slot2
        ghost: root.ghost
        cells: true
        playing: root.playing
    }
}
