import QtQuick
import qs
import qs.services
import qs.tokyo as T

// The media panel, compact, in Blueprint (panel design canvas, "Now
// playing", the BLUEPRINT column): FIG. 1 — NOW PLAYING, drawn on the
// sheet. The cover in dots in a drawn frame (crossed out while there is
// none; the matched video plays in its place) with its dimension line, the
// seek line with its end ticks and a white playhead ("t = 1:38" over it,
// the length at the end; a click seeks), round outlined keys (back, a
// heavier play, next), the line being sung in dots beside them, and a
// title block: TITLE, BY, and SHOW (what there is to show, boxed: the
// video, the visualiser, the lyrics).
T.Face {
    id: root

    readonly property bool active: !!ctx.active
    readonly property bool playing: !!ctx.playing
    readonly property real progress: active ? Math.max(0, Math.min(1, ctx.progress ?? 0)) : 0

    // ── Where things go, in px ──────────────────────────────────────
    readonly property int artPx: Math.round(Math.min(height * 0.62, width * 0.25) / pitch) * pitch
    readonly property int artX: 22
    readonly property int artY: Math.round((height - artPx) / 2) - 10
    readonly property int textX: artX + artPx + 20
    readonly property int textW: width - textX - 14
    readonly property int seekY: artY + 36
    readonly property int keyD: 26
    readonly property int keysY: seekY + 26
    readonly property int tableW: Math.min(210, width - textX + 30)

    Paper {
        anchors.fill: parent
    }

    // ── The cover, framed ───────────────────────────────────────────
    Rectangle {
        x: 8
        y: root.artY
        width: 1
        height: root.artPx
        color: Ink.line
    }
    Item {
        id: art
        x: root.artX
        y: root.artY
        width: root.artPx
        height: root.artPx
        clip: true
        Dots {
            anchors.fill: parent
            anchors.margins: 2
            glow: false
            visible: root.active && !!root.ctx.art
            MediaArt {
                width: parent.width
                height: parent.height
                src: root.active ? (root.ctx.art ?? "") : ""
                stripe: Ink.deep
                sun: Ink.pale
                ground: Ink.done
            }
        }
        // No cover: the drafting stand-in, a crossed box.
        Stroke {
            anchors.fill: parent
            visible: !(root.active && !!root.ctx.art)
            path: `M 0 ${art.height} L ${art.width} 0 M 0 0 L ${art.width} ${art.height}`
            color: Ink.c(Qt.rgba(232 / 255, 241 / 255, 1, 0.6), Qt.rgba(28 / 255, 47 / 255, 110 / 255, 0.55))
        }
        Loader {
            anchors.fill: parent
            active: root.active && !!root.ctx.hasVideo
            sourceComponent: MatchVideo {}
        }
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1.5
            border.color: Ink.ink
        }
    }
    // ◂ 30 ▸ : the cover's width in dots.
    Rectangle {
        x: art.x
        y: art.y + art.height + 8
        width: art.width
        height: 1
        color: Ink.line
        Pen {
            y: 3
            width: parent.width
            height: 12
            horizontalAlignment: Text.AlignHCenter
            text: "◂ " + Math.round(root.artPx / root.pitch) + " ▸"
        }
    }

    // ── FIG. 1 and the seek line ────────────────────────────────────
    Pen {
        x: root.textX
        y: root.artY
        width: root.textW
        height: 14
        text: "FIG. 1 — NOW PLAYING"
    }
    Item {
        id: seek
        x: root.textX
        y: root.seekY
        width: root.textW
        height: 14
        Rectangle {
            y: 6
            width: parent.width
            height: 1
            color: Ink.line
        }
        Rectangle {
            width: 1
            height: 14
            color: Ink.line
        }
        Rectangle {
            anchors.right: parent.right
            width: 1
            height: 14
            color: Ink.line
        }
        Rectangle {
            id: head
            visible: root.active
            x: Math.round((parent.width - 2) * root.progress)
            y: -2
            width: 2
            height: 18
            color: Ink.white
        }
        Pen {
            visible: root.active
            x: Math.max(0, Math.min(parent.width - width - 40, head.x - width / 2))
            y: -17
            height: 14
            text: "t = " + Media.clock(root.ctx.pos)
            color: Ink.white
        }
        Pen {
            anchors.right: parent.right
            anchors.rightMargin: 6
            y: -17
            height: 14
            text: root.active ? Media.clock(root.ctx.len) : "-:--"
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -5
            enabled: root.active
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => Media.seekTo(Math.max(0, Math.min(1, (mouse.x - 5) / seek.width)))
        }
    }

    // ── Round keys ──────────────────────────────────────────────────
    component Knob: Item {
        id: k
        property string icon: ""
        property bool heavy: false
        signal tap
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: hit.containsMouse ? Ink.c(Qt.rgba(1, 1, 1, 0.08), Qt.rgba(28 / 255, 47 / 255, 110 / 255, 0.08)) : "transparent"
            border.width: k.heavy ? 1.5 : 1
            border.color: k.heavy ? Ink.white : Ink.ink
        }
        // The icons, outlined (the design's 16 x 14 drawings, centred).
        Stroke {
            x: (k.width - 12) / 2
            y: (k.height - 11) / 2
            width: 12
            height: 11
            color: k.heavy ? Ink.white : Ink.ink
            line: 1.2
            path: k.icon === "prev" ? "M 0.6 0.6 L 2.4 0.6 L 2.4 10.4 L 0.6 10.4 Z M 11.4 0.6 L 3.4 5.5 L 11.4 10.4 Z" : k.icon === "next" ? "M 0.6 0.6 L 8.6 5.5 L 0.6 10.4 Z M 9.6 0.6 L 11.4 0.6 L 11.4 10.4 L 9.6 10.4 Z" : k.icon === "pause" ? "M 2 0.6 L 5 0.6 L 5 10.4 L 2 10.4 Z M 7 0.6 L 10 0.6 L 10 10.4 L 7 10.4 Z" : "M 2 0.6 L 11 5.5 L 2 10.4 Z"
        }
        T.Hit {
            id: hit
            anchors.fill: parent
            onTap: k.tap()
        }
    }
    Row {
        id: keys
        x: root.textX
        y: root.keysY
        spacing: 10
        Knob {
            width: root.keyD
            height: root.keyD
            icon: "prev"
            onTap: Media.previous()
        }
        Knob {
            width: root.keyD
            height: root.keyD
            heavy: true
            icon: root.playing ? "pause" : "play"
            onTap: Media.toggle()
        }
        Knob {
            width: root.keyD
            height: root.keyD
            icon: "next"
            onTap: Media.next()
        }
    }
    // The line being sung, in dots.
    Dots {
        x: keys.x + keys.width + 12
        y: keys.y + Math.round((root.keyD - 7 * root.pitch) / 2)
        width: root.width - x - 14
        height: 8 * root.pitch
        visible: root.active && Lyrics.has
        LyricLine {
            width: parent.width
            color: Ink.white
            rest: Ink.line
            playing: root.playing
        }
    }

    // ── The title block ─────────────────────────────────────────────
    Table {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: root.tableW
        labelW: 48
        rowH: 18
        sizes: ({ 0: 13 })
        rows: [["TITLE", root.active ? (root.ctx.title || root.words.idle || "") : (root.words.idle || "NOTHING PLAYING")], ["BY", root.active ? [root.ctx.artist, root.ctx.album].filter(s => !!s).join(" · ") : (root.ctx.count ?? 0) + " IN THE LIBRARY"], ["SHOW", ""]]
        cells: ({ 2: show })
    }
    Component {
        id: show
        Item {
            Row {
                x: 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Repeater {
                    model: [["VID", root.active && !!root.ctx.hasVideo], ["VIS", root.active], ["LYR", root.active && Lyrics.has]]
                    Item {
                        id: w
                        required property var modelData
                        width: word.implicitWidth + 8
                        height: 14
                        Rectangle {
                            visible: w.modelData[1]
                            anchors.fill: parent
                            color: "transparent"
                            border.width: 1
                            border.color: Ink.white
                        }
                        Pen {
                            id: word
                            anchors.centerIn: parent
                            text: w.modelData[0]
                            color: w.modelData[1] ? Ink.white : Ink.line
                            font.strikeout: !w.modelData[1]
                        }
                    }
                }
            }
        }
    }
}
