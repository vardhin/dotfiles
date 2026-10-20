import QtQuick
import qs
import qs.services
import qs.tokyo as T

// The media panel, compact, in 90s Nights (panel design canvas, "Now
// playing", the 90S NIGHTS column): the slanted sign as a car deck. The
// cover in dots at the left (the outrun sun until there is one; the
// matched video over it), the title in sunset dots, the artist and album
// spaced wide in blue, the seek bar as a run of chevrons lit yellow and
// pink (a click seeks), the chrome ⏮ ⏯ ⏭ keys, the time in yellow, and
// VID VIS LYR keys that light yellow when there is a video, a visualiser,
// lyrics. A click anywhere else opens MEDIA.
T.Face {
    id: root

    readonly property bool active: !!ctx.active
    readonly property bool playing: !!ctx.playing
    readonly property real progress: active ? Math.max(0, Math.min(1, ctx.progress ?? 0)) : 0
    readonly property int p: Tokens.pitch
    readonly property real padY: Math.max(10, height * 0.08)
    // The cover: square, 12 px clear of the rim all round (its top left
    // corner is the one the slant comes closest to).
    readonly property real pad: 12
    readonly property real artE: Math.floor((height - (plate.rim + pad) * 2) / p) * p
    readonly property real artY: Math.round((height - artE) / 2)
    readonly property real keyH: Math.round(Math.max(18, Math.min(24, height * 0.15)))
    readonly property real keysY: height - padY - keyH - 2
    readonly property real artX: plate.leftAt(artY) + pad
    readonly property real colX: artX + artE + 14
    // The key row: transport keys scaled to leave room for the tags.
    readonly property real rowW: plate.rightAt(keysY + keyH / 2) - 12 - colX - 2
    readonly property real tagW: rowW >= 260 ? 32 : 28
    readonly property real keyS: Math.max(0.6, Math.min(keyH / 22, (rowW - (tagW * 3 + 12) - 12 - 10) / 100))
    Plate {
        id: plate
        anchors.fill: parent

        // The cover.
        Item {
            x: Math.ceil((root.artX - plate.rim) / root.p)
            y: Math.ceil((root.artY - plate.rim) / root.p)
            width: Math.round(root.artE / root.p)
            height: width
            MediaArt {
                anchors.fill: parent
                src: root.active ? (root.ctx.art ?? "") : ""
                stripe: Ink.magenta
                sun: Ink.yellow
                ground: Ink.deep
            }
            Loader {
                anchors.fill: parent
                active: root.active && !!root.ctx.hasVideo
                sourceComponent: MatchVideo {}
            }
        }

        // TRACK TITLE / ARTIST · ALBUM / ▶▶▶▶
        Item {
            id: words
            x: Math.round((root.colX + 6 - plate.rim) / root.p)
            y: Math.round((root.padY + 2 - plate.rim) / root.p)
            width: Math.floor((plate.rightAt(root.padY + 20) - 12 - root.colX) / root.p)
            height: 30
            readonly property string title: root.active ? String(root.ctx.title || "") : String(root.words.idle || "NOTHING PLAYING")
            // Twice the size when it fits whole.
            readonly property int k: title.length * 12 <= width && root.height >= 120 ? 2 : 1
            Grad {
                width: parent.width
                height: 7 * words.k
                stops: Ink.sunset
                MatrixText {
                    width: parent.width
                    height: parent.height
                    size: words.k
                    scroll: true
                    text: words.title
                    color: "white"
                }
            }
            MatrixText {
                y: 7 * words.k + 3
                width: parent.width
                height: 7
                gap: 2
                scroll: true
                text: root.active ? [root.ctx.artist, root.ctx.album].filter(s => !!s).join(" · ") : (root.ctx.count ?? 0) + " IN THE LIBRARY"
                color: Ink.blue
            }
            Chevrons {
                id: seek
                y: 7 * words.k + 3 + 7 + 4
                width: parent.width
                height: 5
                value: root.progress
            }
        }
    }
    T.Hit {
        anchors.fill: parent
        z: -1
        action: "pane media"
    }
    // A click on the chevrons seeks.
    MouseArea {
        x: plate.surface.x + words.x * root.p
        y: plate.surface.y + (words.y + seek.y) * root.p - 4
        width: words.width * root.p
        height: 5 * root.p + 8
        enabled: root.active
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => Media.seekTo(Math.max(0, Math.min(1, mouse.x / width)))
    }
    Row {
        x: root.colX + 2
        y: root.keysY
        spacing: 6
        Repeater {
            model: [["prev", () => Media.previous(), 30, "chrome"], [root.playing ? "pause" : "play", () => Media.toggle(), 40, "hot"], ["next", () => Media.next(), 30, "chrome"]]
            Key {
                required property var modelData
                width: Math.round(modelData[2] * root.keyS)
                height: root.keyH
                glyph: modelData[0]
                tone: modelData[3]
                onTap: modelData[1]()
            }
        }
    }
    Pen {
        id: time
        x: root.colX + 2 + Math.round(100 * root.keyS) + 18
        y: root.keysY
        height: root.keyH
        width: Math.max(0, tags.x - x - 6)
        horizontalAlignment: Text.AlignHCenter
        visible: width >= 30
        text: root.active ? Media.clock(root.ctx.pos) : "0:00"
        size: 14
        color: Ink.yellow
    }
    Row {
        id: tags
        x: plate.rightAt(root.keysY + root.keyH / 2) - 12 - width
        y: root.keysY
        spacing: 6
        Repeater {
            model: [["VID", root.active && !!root.ctx.hasVideo], ["VIS", root.active], ["LYR", root.active && Lyrics.has]]
            Key {
                required property var modelData
                width: root.tagW
                height: root.keyH
                textPx: root.tagW < 32 ? 9 : 10
                text: modelData[0]
                on: modelData[1]
                action: "pane media"
            }
        }
    }
}
