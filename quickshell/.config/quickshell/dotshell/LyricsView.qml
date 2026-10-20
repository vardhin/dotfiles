import QtQuick
import qs.services

// Synced lyrics on a dot canvas, karaoke style: the sheet glides up so the
// line being sung sits a third of the way down; that line lights left to
// right as it is sung (Lyrics.lineProgress, on Lyrics' smooth clock), sung
// lines dim behind it and the ones to come fade with distance. Unsynced
// lyrics list from the top. The wheel scrolls either: unsynced for as long as
// you like; synced it peeks, and glides back to the sung line 3 s after.
//   LyricsView { width: 160; height: 52 }
Item {
    id: root

    property color tube: Tokens.slot0
    readonly property int perLine: Tokens.lineDots
    readonly property int shownLines: Math.max(1, Math.floor(height / perLine))
    readonly property int current: Lyrics.index
    readonly property int lead: Math.floor((shownLines - 1) / 3)
    // Lines scrolled by the wheel, away from where the sheet would sit.
    property int manual: 0
    readonly property int maxDown: Math.max(0, Lyrics.lines.length - (Lyrics.synced ? 1 : shownLines))

    clip: true

    Connections {
        target: Lyrics
        function onLinesChanged() {
            root.manual = 0;
        }
    }
    Timer {
        id: back
        interval: 3000
        onTriggered: if (Lyrics.synced) root.manual = 0
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            const notches = Math.round(wheel.angleDelta.y / 120) || Math.sign(wheel.angleDelta.y);
            const base = Lyrics.synced ? Math.max(0, root.current) - root.lead : 0;
            // Keep the sheet within the lyrics.
            const at = Math.max(0, Math.min(root.maxDown, base + root.manual - notches));
            // At either end: the page around it scrolls instead.
            wheel.accepted = at - base !== root.manual;
            root.manual = at - base;
            back.restart();
        }
    }

    DotText {
        visible: !Lyrics.has
        width: parent.width
        height: root.perLine
        text: Lyrics.status === "looking" ? "LOOKING UP LYRICS" : "NO LYRICS"
        color: Tokens.slot1
        opacity: 0.5
    }

    Column {
        id: sheet
        visible: Lyrics.has
        width: parent.width
        // Whole dots only: the canvas samples one texel per dot.
        y: Math.round(offset)
        property real offset: ((Lyrics.synced ? root.lead - Math.max(0, root.current) : 0) - root.manual) * root.perLine
        Behavior on offset {
            NumberAnimation {
                duration: 280
                easing.type: Easing.OutCubic
            }
        }

        Repeater {
            model: Lyrics.lines

            Item {
                id: row
                required property var modelData
                required property int index
                readonly property int away: index - root.current
                readonly property bool now: Lyrics.synced && away === 0
                // Only the rows in view are drawn. The row itself stays
                // visible: a Column drops hidden children from its layout,
                // which would pull the sheet up past the sung line.
                readonly property bool shown: !Lyrics.synced || Math.abs(away - root.manual) <= root.shownLines
                width: sheet.width
                height: root.perLine

                DotText {
                    id: line
                    visible: row.shown
                    width: parent.width
                    elide: Text.ElideRight
                    text: row.modelData.text.toUpperCase()
                    color: row.now ? Tokens.slot2 : Tokens.slot1
                    opacity: !Lyrics.synced ? 0.8 : row.now ? 1 : row.away < 0 ? 0.3 : Math.max(0.25, 0.75 - 0.15 * (row.away - 1))
                }
                // The wipe: the same line in the tube, cut at how far it
                // has been sung.
                Item {
                    visible: row.now && row.shown
                    width: Math.round(Math.min(parent.width, line.implicitWidth) * Lyrics.lineProgress)
                    height: parent.height
                    clip: true
                    DotText {
                        width: row.width
                        elide: Text.ElideRight
                        text: line.text
                        color: root.tube
                    }
                }
            }
        }
    }
}
