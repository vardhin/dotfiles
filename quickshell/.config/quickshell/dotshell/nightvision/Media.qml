import QtQuick
import qs
import qs.services
import qs.nineties as Ni
import qs.tokyo as T

// The media panel, compact, in Night Vision (panel design canvas, "Now
// playing", the NIGHT VISION column): the target in the scope. The cover
// round at the left, seen in green (the matched video over it), under a
// white crosshair and ring; TGT ACQ · CH 02 in dim small print, the title
// big in bright dots, the artist and album lit, RNG and the seek line of
// dots (a click seeks) with the time, then ◁◁ ❚❚ ▷▷ and [vid] [vis] [lyr]
// (lit solid when there is a video, a visualiser, lyrics). A click
// anywhere else opens MEDIA.
T.Face {
    id: root

    readonly property bool active: !!ctx.active
    readonly property bool playing: !!ctx.playing
    readonly property real progress: active ? Math.max(0, Math.min(1, ctx.progress ?? 0)) : 0
    readonly property int p: Tokens.pitch

    Scope {
        id: s
        anchors.fill: parent

        readonly property real artE: Math.round(height * 0.6 / root.p) * root.p
        readonly property real artX: (Math.max(14, rx * 0.3) + 6)
        readonly property real artY: Math.round((height - artE) / 2)
        readonly property real colX: artX + artE + 14
        readonly property real colR: width - (Math.max(18, rx * 0.4) + 8)
        readonly property real padY: Math.max(10, height * 0.12) + 4
        readonly property real keyH: Math.round(Math.max(16, Math.min(22, height * 0.13)))
        readonly property real keysY: height - padY - keyH
        readonly property int l: dx(colX)
        readonly property int w: dx(colR) - l
        readonly property int t: dy(padY)
        readonly property string title: root.active ? String(root.ctx.title || "") : String(root.words.idle || "NOTHING PLAYING")
        // Twice the size when it fits whole.
        readonly property int k: title.length * 12 <= w && height >= 120 ? 2 : 1
        readonly property int seekY: dy(keysY) - 9

        // TGT ACQ · CH 02 / TRACK TITLE / ARTIST · ALBUM
        MatrixText {
            x: s.l
            y: s.t
            width: s.w
            height: 5
            font: "3x5"
            text: root.active ? (root.playing ? "TGT ACQ · CH 02" : "TGT HELD · CH 02") : "NO TARGET · SCANNING"
            color: Ink.dim
        }
        MatrixText {
            x: s.l
            y: s.t + 8
            width: s.w
            height: 7 * s.k
            size: s.k
            dot: s.k >= 2 ? s.k - 1 : s.k
            scroll: true
            text: s.title
            color: Ink.bright
        }
        MatrixText {
            x: s.l
            y: s.t + 8 + 7 * s.k + 3
            width: s.w
            height: 7
            scroll: true
            text: root.active ? [root.ctx.artist, root.ctx.album].filter(v => !!v).join(" / ") : (root.ctx.count ?? 0) + " IN THE LIBRARY"
            color: Ink.lit
        }
        // RNG ·······•········· 01:38
        Item {
            x: s.l
            y: s.seekY
            width: s.w
            height: 5
            MatrixText {
                id: rng
                width: implicitWidth
                height: 5
                font: "3x5"
                text: "RNG"
                color: Ink.dim
            }
            MatrixText {
                id: clock
                x: parent.width - width
                width: implicitWidth
                height: 5
                font: "3x5"
                text: root.active ? Media.clock(root.ctx.pos) : "0:00"
                color: Ink.bright
            }
            Item {
                id: line
                x: rng.width + 3
                width: parent.width - x - clock.width - 3
                height: 5
                readonly property int n: Math.max(0, Math.floor((width + 1) / 2))
                Repeater {
                    model: line.n
                    Rectangle {
                        required property int index
                        x: index * 2
                        y: 2
                        width: 1
                        height: 1
                        color: index / line.n < root.progress ? Ink.lit : Ink.deep
                    }
                }
            }
        }
    }

    // The target: the cover round, in green, the crosshair over it.
    DotSurface {
        id: art
        x: s.artX
        y: s.artY
        cols: Math.round(s.artE / root.p)
        rows: cols
        imageMode: true
        dither: true
        shape: "M 0 " + (rows / 2) + " A " + (cols / 2) + " " + (rows / 2) + " 0 1 1 " + cols + " " + (rows / 2) + " A " + (cols / 2) + " " + (rows / 2) + " 0 1 1 0 " + (rows / 2) + " Z"
        MediaArt {
            anchors.fill: parent
            round: true
            src: root.active ? (root.ctx.art ?? "") : ""
            stripe: Ink.c("#2b8a22", "#7a7a4a")
            sun: Ink.c("#c9ffb8", "#262b14")
            ground: Ink.c("#0f3a0c", "#c4bd98")
        }
        Loader {
            anchors.fill: parent
            active: root.active && !!root.ctx.hasVideo
            sourceComponent: MatchVideo {}
        }
    }
    Reticle {
        anchors.fill: art
        ring: 0.42
        reach: 0.86
    }

    T.Hit {
        anchors.fill: parent
        z: -1
        action: "pane media"
    }
    // A click on the seek line seeks.
    MouseArea {
        x: s.px(s.l)
        y: s.py(s.seekY) - 4
        width: s.w * root.p
        height: 5 * root.p + 8
        enabled: root.active
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => Media.seekTo(Math.max(0, Math.min(1, mouse.x / width)))
    }
    Row {
        x: s.colX
        y: s.keysY
        spacing: 2
        Repeater {
            model: [["prev", () => Media.previous(), Ink.lit], [root.playing ? "pause" : "play", () => Media.toggle(), Ink.bright], ["next", () => Media.next(), Ink.lit]]
            Item {
                id: tk
                required property var modelData
                width: Math.round(s.keyH * 1.25)
                height: s.keyH
                Rectangle {
                    anchors.fill: parent
                    color: hit.containsMouse ? Ink.hover : "transparent"
                }
                Ni.Glyph {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: hit.pressed ? 1 : 0
                    width: Math.round(s.keyH * 0.62)
                    height: Math.round(s.keyH * 0.54)
                    kind: tk.modelData[0]
                    color: tk.modelData[2]
                }
                T.Hit {
                    id: hit
                    anchors.fill: parent
                    onTap: tk.modelData[1]()
                }
            }
        }
    }
    Row {
        id: tags
        x: s.colR - width
        y: s.keysY
        spacing: 3
        Repeater {
            model: [["vid", root.active && !!root.ctx.hasVideo], ["vis", root.active], ["lyr", root.active && Lyrics.has]]
            Key {
                required property var modelData
                width: 42
                height: s.keyH
                textPx: 11
                spacing: 0
                boxed: false
                text: "[" + modelData[0] + "]"
                on: modelData[1]
                action: "pane media"
            }
        }
    }
}
