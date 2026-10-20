import QtQuick
import qs
import qs.services
import qs.tokyo as T

// The media panel, compact, in Nixie (panel design canvas, "Now playing",
// the NIXIE column): a valve radio in its walnut case. The position on four
// tubes with glowing colons, the title and artist on a dot screen ruled in
// brass, the seek line as a glass tube filling orange (a click seeks), round
// brass ⏮ ⏯ ⏭ knobs, and VID VIS LYR tabs that light orange when there is
// a video, a visualiser, lyrics. A click anywhere else opens MEDIA.
T.Face {
    id: root

    readonly property bool active: !!ctx.active
    readonly property bool playing: !!ctx.playing
    readonly property real progress: active ? Math.max(0, Math.min(1, ctx.progress ?? 0)) : 0
    readonly property int p: Tokens.pitch
    // m:ss -> four digits for the tubes.
    readonly property string digits: {
        const t = active ? String(Media.clock(ctx.pos)) : "0:00";
        const m = /^(?:(\d+):)?(\d+):(\d\d)$/.exec(t);
        if (!m)
            return "00:00";
        const mins = Number(m[1] ?? 0) * 60 + Number(m[2]);
        return String(Math.min(99, mins)).padStart(2, "0") + ":" + m[3];
    }

    Wood {
        anchors.fill: parent
    }
    T.Hit {
        anchors.fill: parent
        action: "pane media"
    }

    Item {
        id: body
        x: 12
        y: 12
        width: root.width - 24
        height: root.height - 24
        readonly property real tubeH: Math.max(30, Math.min(height - 8, 80))
        readonly property real tubeW: Math.min(tubeH * 0.53, (width * 0.42 - 20) / 4.2)
        readonly property real knobH: Math.max(20, Math.min(30, height * 0.24))

        Tubes {
            id: time
            anchors.verticalCenter: parent.verticalCenter
            height: body.tubeH
            tubeW: body.tubeW
            gap: 4
            text: root.digits
            lit: root.active
        }

        Item {
            id: right
            x: time.width + 12
            width: body.width - x
            height: body.height

            Glass {
                id: screen
                width: parent.width
                height: Math.max(9 * root.p + 4, parent.height - body.knobH - 30)
                readonly property bool roomy: rows >= 18
                MatrixText {
                    x: 3
                    y: screen.roomy ? Math.round((screen.rows - 16) / 2) : 2
                    width: screen.cols - 6
                    height: 7
                    scroll: true
                    text: root.active ? String(root.ctx.title || "") : String(root.words.idle || "NOTHING PLAYING")
                    color: Ink.digit
                }
                MatrixText {
                    x: 3
                    y: screen.roomy ? Math.round((screen.rows - 16) / 2) + 9 : 10
                    width: screen.cols - 6
                    height: screen.roomy ? 7 : 5
                    font: screen.roomy ? "5x7" : "3x5"
                    scroll: true
                    text: root.active ? [root.ctx.artist, root.ctx.album].filter(s => !!s).join(" · ") : (root.ctx.count ?? 0) + " IN THE LIBRARY"
                    color: Ink.orange
                }
            }
            // The seek tube.
            Item {
                id: seek
                y: screen.height + 8
                width: parent.width
                height: 12
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Ink.c(Qt.rgba(1, 170 / 255, 110 / 255, 0.08), Qt.rgba(1, 1, 1, 0.4))
                    border.width: 1
                    border.color: Ink.c(Qt.rgba(1, 200 / 255, 150 / 255, 0.35), Qt.rgba(122 / 255, 70 / 255, 30 / 255, 0.4))
                }
                Glow {
                    visible: root.progress > 0
                    x: 3
                    y: 3
                    width: Math.max(height, (seek.width - 6) * root.progress)
                    height: seek.height - 6
                    radius: height / 2
                    color: Ink.orange
                    halo: 4
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    enabled: root.active
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => Media.seekTo(Math.max(0, Math.min(1, (mouse.x - 4) / seek.width)))
                }
            }
            Row {
                anchors.bottom: parent.bottom
                spacing: 10
                Repeater {
                    model: [["prev", () => Media.previous(), 0.8], [root.playing ? "pause" : "play", () => Media.toggle(), 1], ["next", () => Media.next(), 0.8]]
                    Knob {
                        required property var modelData
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.round(body.knobH * modelData[2])
                        height: width
                        glyph: modelData[0]
                        onTap: modelData[1]()
                    }
                }
            }
            Row {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Math.round((body.knobH - 18) / 2)
                spacing: 6
                Repeater {
                    model: [["VID", root.active && !!root.ctx.hasVideo], ["VIS", root.active], ["LYR", root.active && Lyrics.has]]
                    Key {
                        required property var modelData
                        width: 30
                        height: 18
                        radius: 3
                        text: modelData[0]
                        tone: modelData[1] ? "lit" : ""
                        action: "pane media"
                    }
                }
            }
        }
    }
}
