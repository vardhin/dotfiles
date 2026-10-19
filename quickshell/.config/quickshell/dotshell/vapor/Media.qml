import QtQuick
import qs
import qs.services
import qs.tokyo as T

// The media panel, compact, in Vaporwave (panel design canvas, "Now
// playing", the VAPORWAVE column): now_playing.exe, a Windows media
// player. The cover as a dark dot screen (the matched video plays in its
// place), the title spaced wide in yellow dots and the artist and album in
// pink on a dot screen beside it, the progress bar in violet and cyan
// blocks (a click seeks), ⏮ ⏯ ⏭ push buttons, the time, and VID VIS LYR
// lit hot pink when there is a video, a visualiser, lyrics. A click
// anywhere else opens MEDIA.
T.Face {
    id: root

    readonly property bool active: !!ctx.active
    readonly property bool playing: !!ctx.playing
    readonly property real progress: active ? Math.max(0, Math.min(1, ctx.progress ?? 0)) : 0

    Win {
        id: win
        anchors.fill: parent
        icon: "♪"
        title: "now_playing.exe"
        boxed: true
    }

    // ── The cover ───────────────────────────────────────────────────
    Crt {
        id: art
        readonly property real edge: Math.floor(Math.min(root.height - win.bodyY - 16, root.width * 0.26) / root.pitch) * root.pitch + 2
        x: 10
        y: win.bodyY + 8
        width: edge
        height: edge
        MediaArt {
            width: art.cols
            height: art.rows
            src: root.active ? (root.ctx.art ?? "") : ""
            stripe: Ink.violet
            sun: Ink.yellow
            ground: Ink.pink
        }
        Loader {
            anchors.fill: parent
            active: root.active && !!root.ctx.hasVideo
            sourceComponent: MatchVideo {}
        }
    }

    Item {
        id: side
        x: art.x + art.width + 10
        y: art.y
        width: root.width - x - 10
        height: art.height

        // The display: title and artist.
        Crt {
            id: display
            width: parent.width
            height: parent.height - 16 - 5 - 6 - 26
            Say {
                x: 3
                y: 1
                width: display.cols - 6
                height: Math.max(8, display.rows - 10)
                verticalAlignment: Text.AlignVCenter
                text: root.active ? String(root.ctx.title || root.words.idle || "").toUpperCase() : String(root.words.idle || "Nothing playing").toUpperCase()
                size: Math.max(8, Math.min(display.rows - 10, 16))
                spacing: Math.max(1, Math.round(size * 0.25))
            }
            MatrixText {
                x: 3
                y: display.rows - 8
                width: display.cols - 6
                height: 7
                font: text.length * 6 <= width ? "5x7" : "3x5"
                scroll: true
                text: root.active ? [root.ctx.artist, root.ctx.album].filter(s => !!s).join(" · ") : (root.ctx.count ?? 0) + " in the library"
                color: Ink.pink
            }
        }
        Meter {
            id: seek
            y: display.height + 5
            width: parent.width
            height: 16
            value: root.progress
            seek: root.active
            onSeeked: f => Media.seekTo(f)
        }
        Item {
            y: seek.y + seek.height + 6
            width: parent.width
            height: 26
            Row {
                id: keys
                height: parent.height
                spacing: 6
                Repeater {
                    model: [["prev", () => Media.previous()], [root.playing ? "pause" : "play", () => Media.toggle()], ["next", () => Media.next()]]
                    Key {
                        required property var modelData
                        width: 34
                        height: keys.height
                        glyph: modelData[0]
                        onTap: modelData[1]()
                    }
                }
            }
            Pen {
                x: keys.width + 10
                width: lit.x - x - 6
                height: parent.height
                horizontalAlignment: Text.AlignHCenter
                text: root.active ? Media.clock(root.ctx.pos) + " / " + Media.clock(root.ctx.len) : "-:-- / -:--"
                size: 18
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 11
            }
            Row {
                id: lit
                anchors.right: parent.right
                height: parent.height
                spacing: 4
                Repeater {
                    model: [["VID", root.active && !!root.ctx.hasVideo], ["VIS", root.active], ["LYR", root.active && Lyrics.has]]
                    Key {
                        required property var modelData
                        width: 34
                        height: lit.height
                        text: modelData[0]
                        on: modelData[1]
                        action: "pane media"
                    }
                }
            }
        }
    }
}
