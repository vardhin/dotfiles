import QtQuick
import qs.services
import "Matrix.js" as Matrix

// The line being sung, on a dot canvas (1 px = 1 dot), one 5x7 row: lit
// left to right as it is sung (karaoke) and breathing, rolling up to the
// next line. Before the first line (an intro) it counts down to it; with
// unsynced lyrics it scrolls the first line. The media devices' lyric row.
// A line the 5x7 set can't draw (Telugu, Tamil, Japanese) goes in the
// shell's pixel font instead, 11 dots tall, spilling 2 above and below the
// row the way the title does.
//
//   LyricLine { width: 90; color: Tokens.slot1; rest: Tokens.slot2 }
Item {
    id: lyr

    property color color: Tokens.slot0
    // The part not sung yet.
    property color rest: Tokens.slot2
    property color ghost: "transparent"
    property bool cells: false
    property bool playing: Media.isPlaying

    height: 7

    // Brighter on the in-breath (MeowMuzic's active line).
    property real breath: 0
    SequentialAnimation on breath {
        running: lyr.visible && lyr.playing && Lyrics.synced
        loops: Animation.Infinite
        NumberAnimation {
            to: 1
            duration: 900
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            to: 0
            duration: 900
            easing.type: Easing.InOutSine
        }
    }
    readonly property color lit: Qt.rgba(color.r + (1 - color.r) * 0.3 * breath, color.g + (1 - color.g) * 0.3 * breath, color.b + (1 - color.b) * 0.3 * breath, 1)
    readonly property bool karaoke: Lyrics.synced && Lyrics.has

    readonly property string now: Lyrics.has ? (Lyrics.synced ? (Lyrics.index < 0 ? "♪ IN " + Media.clock(Math.max(0, (Lyrics.lines[0]?.t ?? 0) - Lyrics.clock)) : Lyrics.line) : Lyrics.lines[0]?.text ?? "") : Lyrics.status === "looking" ? "LOOKING UP LYRICS" : "NO LYRICS"
    // The line rolling out, and how far the roll is (0 .. 1).
    property string was: ""
    property real roll: 1
    onNowChanged: {
        roll = 0;
        rollIn.restart();
    }
    NumberAnimation {
        id: rollIn
        target: lyr
        property: "roll"
        to: 1
        duration: 220
        easing.type: Easing.OutCubic
        onFinished: lyr.was = lyr.now
    }

    readonly property bool matrixNow: Matrix.covers("5x7", now)
    readonly property bool matrixWas: Matrix.covers("5x7", was)
    // Either line in the pixel font: the window grows to its 11 dots.
    readonly property bool tall: !matrixNow || roll < 1 && !matrixWas
    readonly property int step: tall ? 13 : 9

    Item {
        id: win
        y: lyr.tall ? -2 : 0
        width: lyr.width
        height: lyr.tall ? 11 : 7
        clip: true

        // ── The line rolling out ──
        MatrixText {
            visible: lyr.roll < 1 && lyr.matrixWas
            y: (lyr.tall ? 2 : 0) - Math.round(lyr.roll * lyr.step)
            width: lyr.width
            height: implicitHeight
            text: lyr.was
            color: lyr.color
        }
        DotText {
            visible: lyr.roll < 1 && !lyr.matrixWas
            y: -Math.round(lyr.roll * lyr.step)
            width: lyr.width
            height: 11
            elide: Text.ElideRight
            text: lyr.was.toUpperCase()
            color: lyr.color
        }

        // ── The line coming in ──
        MatrixText {
            visible: lyr.matrixNow
            y: (lyr.tall ? 2 : 0) + Math.round((1 - lyr.roll) * lyr.step)
            width: lyr.width
            height: implicitHeight
            text: lyr.now
            ghost: lyr.ghost
            cells: lyr.cells
            color: lyr.lit
            rest: lyr.rest
            // Lit as far as it has been sung; long lines keep the singing
            // part in view, three fifths across.
            litChars: lyr.karaoke ? Math.round(Lyrics.lineProgress * shown.length) : -1
            follow: shown.length > capacity && litChars >= 0 ? Math.max(0, Math.min(shown.length - capacity, litChars - Math.floor(capacity * 0.6))) : -1
            scroll: !lyr.karaoke
        }
        // In the pixel font: the rest colour under, the sung part over it
        // cut at how far it has been sung; a long line slides to keep the
        // singing part three fifths across (unsynced, it elides).
        Item {
            id: wide
            visible: !lyr.matrixNow
            y: Math.round((1 - lyr.roll) * lyr.step)
            width: lyr.width
            height: 11
            clip: true

            readonly property int full: under.implicitWidth
            readonly property int wiped: Math.round(full * Lyrics.lineProgress)
            readonly property int shift: lyr.karaoke && full > width ? Math.max(0, Math.min(full - width, wiped - Math.floor(width * 0.6))) : 0

            DotText {
                id: under
                x: -wide.shift
                width: lyr.karaoke ? implicitWidth : wide.width
                height: 11
                elide: lyr.karaoke ? Text.ElideNone : Text.ElideRight
                text: lyr.now.toUpperCase()
                color: lyr.karaoke ? lyr.rest : lyr.lit
            }
            Item {
                visible: lyr.karaoke
                x: -wide.shift
                width: wide.wiped
                height: 11
                clip: true
                DotText {
                    width: under.width
                    height: 11
                    text: under.text
                    color: lyr.lit
                }
            }
        }
    }
}
