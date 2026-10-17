import QtQuick
import qs.services

// The note bar: one column per semitone, MIDI 48..83 (36 columns), from the
// second cava in services/Media.qml. Drawn like the spectrum: lit from the
// bottom through the three tubes, with a 6% floor so silent notes still
// show as a row of dim dots. No key labels, no piano backing.
//   NoteBar { width: 108; height: 12 }
Item {
    id: root

    readonly property int count: Media.noteCount
    readonly property int colWidth: Math.max(1, Math.floor((width + 1) / count) - 1)
    readonly property string key: "notebar-" + Math.random().toString(36).slice(2)

    onVisibleChanged: Media.wantNotes(key, visible)
    Component.onCompleted: Media.wantNotes(key, visible)
    Component.onDestruction: Media.wantNotes(key, false)

    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 1

        Repeater {
            model: root.count

            Item {
                required property int index
                readonly property real value: Media.notes[index] ?? 0
                readonly property int floorDots: Math.max(1, Math.round(root.height * 0.06))
                readonly property int lit: Math.max(floorDots, Math.round(value * root.height))
                readonly property int low: Math.round(root.height * 0.6)
                readonly property int mid: Math.round(root.height * 0.85)

                width: root.colWidth
                height: root.height

                Rectangle {
                    y: parent.height - height
                    width: parent.width
                    height: Math.min(parent.lit, parent.low)
                    color: Tokens.slot0
                    opacity: parent.value > 0.02 ? 1 : 0.35
                }
                Rectangle {
                    visible: parent.lit > parent.low
                    y: parent.height - parent.low - height
                    width: parent.width
                    height: Math.min(parent.lit, parent.mid) - parent.low
                    color: Tokens.slot1
                }
                Rectangle {
                    visible: parent.lit > parent.mid
                    y: parent.height - parent.lit
                    width: parent.width
                    height: parent.lit - parent.mid
                    color: Tokens.slot2
                }
            }
        }
    }
}
