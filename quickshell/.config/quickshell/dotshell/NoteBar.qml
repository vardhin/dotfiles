import QtQuick
import qs.services

// The note bar, as duolightbars draws its note strip
// (~/Documents/git/duolightbars, frontend/src/lib/lighting/renderer.ts): one
// column per semitone, MIDI 48..83 (C3..B5), from Basic Pitch's notes for the
// song (services/Notes.qml), or for a stream with no file the peaks of a
// second cava (Media.notes). Every key is always there, unlit,
// white keys a shade brighter than black ones, so a note's place never moves;
// a sounding note rises from the bottom as tall as it is loud, the loudest
// one in the second tube. With `labels`, C3 C4 C5 under their keys and where
// the notes come from at the right.
//   NoteBar { width: 108; height: 16; labels: true }
Item {
    id: root

    property bool labels: false

    readonly property int count: Media.noteCount
    readonly property var notes: Notes.ready ? Notes.values : Media.notes
    readonly property int colWidth: Math.max(1, Math.floor((width + 1) / count) - 1)
    readonly property int used: count * (colWidth + 1) - 1
    readonly property int labelH: labels ? 6 : 0
    readonly property int keysH: height - labelH
    readonly property string key: "notebar-" + Math.random().toString(36).slice(2)
    // The loudest note now.
    readonly property int lead: {
        let at = -1, best = 0.05;
        for (let i = 0; i < count; i++)
            if ((notes[i] ?? 0) > best) {
                best = notes[i];
                at = i;
            }
        return at;
    }

    function mix(a: color, b: color, t: real): color {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }
    readonly property color whiteKey: mix(Tokens.unlit, Tokens.slot0, 0.14)
    readonly property color blackKey: mix(Tokens.unlit, Tokens.slot0, 0.05)

    // Basic Pitch when it has the song; the cava only when it does not.
    readonly property bool cava: visible && !Notes.ready
    onVisibleChanged: Notes.want(key, visible)
    onCavaChanged: Media.wantNotes(key, cava)
    Component.onCompleted: {
        Notes.want(key, visible);
        Media.wantNotes(key, cava);
    }
    Component.onDestruction: {
        Notes.want(key, false);
        Media.wantNotes(key, false);
    }

    Item {
        x: Math.floor((root.width - root.used) / 2)
        width: root.used
        height: root.keysH

        Repeater {
            model: root.count

            Item {
                id: k
                required property int index
                readonly property int pitch: 48 + index
                readonly property bool black: [1, 3, 6, 8, 10].includes(pitch % 12)
                readonly property real value: root.notes[index] ?? 0
                readonly property int lit: Math.round(value * height)

                x: index * (root.colWidth + 1)
                width: root.colWidth
                height: root.keysH

                // The key, unlit; black keys shorter, like a keyboard.
                Rectangle {
                    y: k.black ? Math.round(parent.height * 0.25) : 0
                    width: parent.width
                    height: parent.height - y
                    color: k.black ? root.blackKey : root.whiteKey
                }
                Rectangle {
                    visible: k.lit > 0
                    y: parent.height - k.lit
                    width: parent.width
                    height: k.lit
                    color: k.index === root.lead ? Tokens.slot1 : Tokens.slot0
                }
            }
        }

        // Where the notes come from.
        MatrixText {
            visible: root.labels
            font: "3x5"
            x: root.used - width
            y: root.keysH + 1
            width: implicitWidth
            height: implicitHeight
            text: Notes.ready ? "BASIC PITCH" : Notes.status === "analysing" ? "READING NOTES" : Notes.status === "failed" ? "NOTES FAILED · PEAKS" : "PEAKS"
            color: Notes.ready ? Tokens.slot2 : Tokens.slot1
        }

        // C3 C4 C5 under their keys.
        Repeater {
            model: root.labels ? [0, 12, 24] : []
            MatrixText {
                required property var modelData
                font: "3x5"
                x: modelData * (root.colWidth + 1)
                y: root.keysH + 1
                width: implicitWidth
                height: implicitHeight
                text: "C" + (3 + modelData / 12)
                color: Tokens.slot2
            }
        }
    }
}
