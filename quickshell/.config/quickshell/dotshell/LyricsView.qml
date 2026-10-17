import QtQuick
import qs.services

// Synced lyrics on a dot canvas: the line playing now in the panel's tube,
// the lines around it dimmed, scrolled so the current line sits a third of
// the way down. Unsynced lyrics just list from the top.
//   LyricsView { width: 160; height: 52 }
Item {
    id: root

    property color tube: Tokens.slot0
    readonly property int perLine: Tokens.lineDots
    readonly property int shownLines: Math.max(1, Math.floor(height / perLine))
    readonly property int current: Lyrics.index
    readonly property int first: Lyrics.synced ? Math.max(0, current - Math.floor((shownLines - 1) / 3)) : 0

    clip: true

    DotText {
        visible: !Lyrics.has
        width: parent.width
        height: root.perLine
        text: Lyrics.status === "looking" ? "LOOKING UP LYRICS" : "NO LYRICS"
        color: Tokens.slot1
        opacity: 0.5
    }

    Column {
        visible: Lyrics.has
        width: parent.width
        Repeater {
            model: Lyrics.lines.slice(root.first, root.first + root.shownLines)
            Item {
                required property var modelData
                required property int index
                readonly property bool now: root.first + index === root.current
                width: parent.width
                height: root.perLine
                Scroller {
                    visible: parent.now
                    width: parent.width
                    height: parent.height
                    text: parent.modelData.text.toUpperCase()
                    color: root.tube
                }
                DotText {
                    visible: !parent.now
                    width: parent.width
                    elide: Text.ElideRight
                    text: parent.modelData.text.toUpperCase()
                    color: Tokens.slot1
                    opacity: 0.45
                }
            }
        }
    }
}
