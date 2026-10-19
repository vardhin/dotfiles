import QtQuick
import qs
import qs.services
import qs.tokyo as T

// The media panel, compact, in Split-Flap (panel design canvas, "Now
// playing", the SPLIT-FLAP column): the NOW PLAYING board, screwed to the
// wall. The title on big flap tiles (a long one pages through), the
// artist and album on small ones, the seek line as a row of yellow
// segments (a click seeks), the time on flap tiles in yellow, ⏮ ⏯ ⏭ keys
// (play/pause yellow) and VID VIS LYR lit orange when there is a video, a
// visualiser, lyrics. "● ON AIR" while it plays. A click anywhere else
// opens MEDIA.
T.Face {
    id: root

    readonly property bool active: !!ctx.active
    readonly property bool playing: !!ctx.playing
    readonly property real progress: active ? Math.max(0, Math.min(1, ctx.progress ?? 0)) : 0
    readonly property int p: Tokens.pitch

    Housing {
        id: box
        anchors.fill: parent
        label: "NOW PLAYING"
        status: !root.active ? "OFF AIR" : root.playing ? "ON AIR" : "PAUSED"
        statusInk: root.playing ? Ink.yellow : Ink.label
        screws: true
    }

    Item {
        id: body
        x: 14
        y: box.bodyY + 2
        width: root.width - 28
        height: root.height - y - 12
        readonly property real keysH: 24
        readonly property real seekH: 2 * root.p + 2
        // The title in 5x7 tiles, the artist in 3x5 ones, when both fit.
        readonly property bool roomy: 9 * root.p + 7 * root.p + seekH + keysH + 18 <= height

        Flaps {
            id: title
            width: body.width
            font: body.roomy ? "5x7" : "3x5"
            page: true
            text: root.active ? String(root.ctx.title || root.words.idle || "") : String(root.words.idle || "NOTHING PLAYING")
            color: Ink.white
        }
        Flaps {
            id: artist
            y: title.height + 4
            width: body.width
            font: "3x5"
            page: true
            text: root.active ? [root.ctx.artist, root.ctx.album].filter(s => !!s).join(" · ") : (root.ctx.count ?? 0) + " IN THE LIBRARY"
            color: Ink.dim
        }
        // The seek line: yellow segments up to where it is.
        Item {
            id: seek
            y: artist.y + artist.height + 6
            width: body.width
            height: body.seekH
            readonly property int n: Math.max(8, Math.floor(width / (3 * root.p)))
            Row {
                spacing: root.p
                Repeater {
                    model: seek.n
                    Rectangle {
                        required property int index
                        width: (seek.width - (seek.n - 1) * root.p) / seek.n
                        height: seek.height
                        radius: 1
                        color: (index + 0.5) / seek.n <= root.progress ? Ink.yellow : Ink.upper
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                enabled: root.active
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => Media.seekTo(Math.max(0, Math.min(1, (mouse.x - 4) / seek.width)))
            }
        }
        Item {
            y: body.height - body.keysH
            width: body.width
            height: body.keysH
            Flaps {
                anchors.verticalCenter: parent.verticalCenter
                font: body.roomy ? "5x7" : "3x5"
                cells: 5
                spin: false
                text: root.active ? Media.clock(root.ctx.pos) : "-:--"
                color: Ink.yellow
                T.Hit {
                    anchors.fill: parent
                    action: "pane media"
                }
            }
            Row {
                anchors.right: parent.right
                height: parent.height
                spacing: 4
                Repeater {
                    model: [["prev", () => Media.previous(), false], [root.playing ? "pause" : "play", () => Media.toggle(), true], ["next", () => Media.next(), false]]
                    Key {
                        required property var modelData
                        width: 32
                        height: body.keysH
                        glyph: modelData[0]
                        on: modelData[2]
                        onTap: modelData[1]()
                    }
                }
                Item {
                    width: 4
                    height: 1
                }
                Repeater {
                    model: [["VID", root.active && !!root.ctx.hasVideo], ["VIS", root.active], ["LYR", root.active && Lyrics.has]]
                    Key {
                        required property var modelData
                        width: 32
                        height: body.keysH
                        text: modelData[0]
                        tone: modelData[1] ? Ink.orange : "transparent"
                        action: "pane media"
                    }
                }
            }
        }
    }
}
