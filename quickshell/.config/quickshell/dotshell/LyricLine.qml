import QtQuick
import qs.services

// The line being sung, on a dot canvas (1 px = 1 dot), one 5x7 row: lit
// left to right as it is sung (karaoke) and breathing, rolling up to the
// next line. Before the first line (an intro) it counts down to it; with
// unsynced lyrics it scrolls the first line. The media devices' lyric row.
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
    clip: true

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

    MatrixText {
        y: -Math.round(lyr.roll * 9)
        visible: lyr.roll < 1
        width: lyr.width
        height: implicitHeight
        text: lyr.was
        color: lyr.color
    }
    MatrixText {
        y: Math.round((1 - lyr.roll) * 9)
        width: lyr.width
        height: implicitHeight
        text: lyr.now
        ghost: lyr.ghost
        cells: lyr.cells
        color: Qt.rgba(lyr.color.r + (1 - lyr.color.r) * 0.3 * lyr.breath, lyr.color.g + (1 - lyr.color.g) * 0.3 * lyr.breath, lyr.color.b + (1 - lyr.color.b) * 0.3 * lyr.breath, 1)
        rest: lyr.rest
        // Lit as far as it has been sung; long lines keep the singing part
        // in view, three fifths across.
        litChars: Lyrics.synced && Lyrics.has ? Math.round(Lyrics.lineProgress * shown.length) : -1
        follow: shown.length > capacity && litChars >= 0 ? Math.max(0, Math.min(shown.length - capacity, litChars - Math.floor(capacity * 0.6))) : -1
        scroll: !(Lyrics.synced && Lyrics.has)
    }
}
