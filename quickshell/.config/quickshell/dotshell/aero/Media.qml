import QtQuick
import QtQuick.Effects
import qs
import qs.services
import qs.tokyo as T

// The media panel, compact, in Frutiger Aero (panel design canvas, "Now
// playing", sk.aero): a sky glass pill. The cover as bubble dots in a
// rounded window (the matched video plays in its place), the title and
// the line being sung (or who it is by) in dots, a green glass progress
// bar, and glossy marble keys: back, a big green play, next.
//
//   ╭────────────────────────────────────────────╮
//   │ ╭──────╮  Track Title                       │
//   │ │ art  │  the line being sung / artist      │
//   │ │      │  ▬▬▬▬▬▬▬▬▬▬───────────────          │
//   │ ╰──────╯  (◂◂) ( ❚❚ ) (▸▸)      1:38 / 3:54 │
//   ╰────────────────────────────────────────────╯
T.Face {
    id: root

    readonly property bool active: !!ctx.active
    readonly property bool playing: !!ctx.playing
    readonly property real progress: active ? (ctx.progress ?? 0) : 0

    // ── Where things go, in px ──────────────────────────────────────
    readonly property int pad: Math.round(height * 0.12)
    readonly property int artPx: Math.round(height * 0.7)
    readonly property int textPx: pad + artPx + 18
    readonly property int textW: width - textPx - Math.round(height * 0.2)
    readonly property int keysH: Math.max(30, Math.min(40, Math.round(height * 0.24)))
    readonly property int titleY: pad
    readonly property int lineY: titleY + Tokens.fontPx * pitch + 4
    readonly property int keysY: height - pad - keysH
    readonly property int barY: Math.round((lineY + 7 * pitch + keysY) / 2) - 5

    Sky {
        anchors.fill: parent
        radius: Math.min(40, height / 2 - 4)
        glossInset: 40
    }

    // ── The cover, in a rounded window ──────────────────────────────
    Item {
        id: art
        x: root.pad + 6
        anchors.verticalCenter: parent.verticalCenter
        width: root.artPx
        height: root.artPx
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: artMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0
        }
        Rectangle {
            anchors.fill: parent
            color: Ink.ice
        }
        Dots {
            anchors.fill: parent
            glow: false
            MediaArt {
                width: parent.width
                height: parent.height
                src: root.active ? (root.ctx.art ?? "") : ""
                stripe: Ink.navy
                sun: Ink.pale
                ground: Ink.blue
            }
        }
        Loader {
            anchors.fill: parent
            active: root.active && !!root.ctx.hasVideo
            sourceComponent: MatchVideo {}
        }
    }
    Rectangle {
        id: artMask
        anchors.fill: art
        radius: Math.round(root.artPx * 0.2)
        visible: false
        layer.enabled: true
    }
    // Its glass rim and shine.
    Rectangle {
        anchors.fill: art
        radius: artMask.radius
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.8)
    }
    Rectangle {
        x: art.x + 6
        y: art.y + 3
        width: art.width - 12
        height: art.height * 0.4
        topLeftRadius: artMask.radius - 3
        topRightRadius: artMask.radius - 3
        bottomLeftRadius: 40
        bottomRightRadius: 40
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(1, 1, 1, 0.45)
            }
            GradientStop {
                position: 1
                color: Qt.rgba(1, 1, 1, 0)
            }
        }
    }

    // ── The words, in dots ──────────────────────────────────────────
    Dots {
        id: type
        x: root.textPx
        y: 0
        width: root.textW
        height: root.barY

        // Track Title, in the pixel font (lower case, any script).
        DotText {
            y: Math.round(root.titleY / root.pitch)
            width: parent.width
            height: Tokens.fontPx
            elide: Text.ElideRight
            text: root.active ? (root.ctx.title || root.words.idle) : root.words.idle
            color: Ink.navy
        }
        // The line being sung; who it is by when there are no lyrics.
        LyricLine {
            visible: Lyrics.has
            y: Math.round(root.lineY / root.pitch)
            width: parent.width
            color: Ink.navy
            rest: Ink.sky
            playing: root.playing
        }
        MatrixText {
            visible: !Lyrics.has
            y: Math.round(root.lineY / root.pitch)
            width: parent.width
            height: implicitHeight
            scroll: true
            text: root.active ? [root.ctx.artist, root.ctx.album].filter(s => !!s).join(" — ") : (root.ctx.count ?? 0) + " IN THE LIBRARY"
            color: Ink.blue
        }
    }

    // ── Where the track is: a green glass bar ───────────────────────
    Item {
        id: bar
        x: root.textPx
        y: root.barY
        width: root.textW
        height: 10
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            border.width: 1
            border.color: "white"
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Ink.track
                }
                GradientStop {
                    position: 1
                    color: "white"
                }
            }
        }
        Rectangle {
            width: Math.max(height, parent.width * root.progress)
            height: parent.height
            radius: height / 2
            visible: root.active
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Ink.lime
                }
                GradientStop {
                    position: 1
                    color: Ink.green
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            enabled: root.active
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => Media.seekTo(Math.max(0, Math.min(1, (mouse.x - 4) / bar.width)))
        }
    }

    // ── Marble keys, and the time ───────────────────────────────────
    component Marble: Item {
        id: m
        property string glyph: ""
        property int hue: 1
        signal tap
        Orb {
            anchors.fill: parent
            hue: m.hue
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Ink.shadow
                shadowBlur: 0.25
                blurMax: 8
                shadowVerticalOffset: 2
                shadowHorizontalOffset: 0
            }
        }
        Text {
            anchors.centerIn: parent
            text: m.glyph
            color: Ink.navy
            font.family: Ink.family
            font.pixelSize: Math.round(m.height * 0.38)
            font.bold: true
        }
        T.Hit {
            anchors.fill: parent
            onTap: m.tap()
        }
    }
    Row {
        id: keys
        x: root.textPx
        y: root.keysY
        height: root.keysH
        spacing: 10
        Marble {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(root.keysH * 0.75)
            height: width
            glyph: "◂◂"
            onTap: Media.previous()
        }
        Marble {
            anchors.verticalCenter: parent.verticalCenter
            width: root.keysH
            height: width
            hue: 2
            glyph: root.playing ? "❚❚" : "▶"
            onTap: Media.toggle()
        }
        Marble {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(root.keysH * 0.75)
            height: width
            glyph: "▸▸"
            onTap: Media.next()
        }
    }
    Text {
        anchors.right: bar.right
        anchors.verticalCenter: keys.verticalCenter
        text: root.active ? Media.clock(root.ctx.pos) + " / " + Media.clock(root.ctx.len) : "-:--"
        color: Ink.blue
        font.family: Ink.family
        font.pixelSize: 14
    }
}
