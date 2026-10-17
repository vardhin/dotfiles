import QtQuick
import qs

// An episode as the ANIME page draws it, in its grid and in the legend: the
// number dim when watched, bright otherwise, in the accent while it plays;
// underlined when saved, faintly while queued, a growing line while it
// downloads.
Item {
    id: chip

    property string ep
    property string mark: "new"         // new saved queued getting
    property bool seen: false
    property bool playing: false
    property real pct: 0
    property bool picked: false
    property bool warn: false

    height: Tokens.lineDots + 1

    Frame {
        anchors.fill: parent
        visible: chip.picked
        border.color: chip.warn ? Tokens.slot2 : Tokens.slot0
    }
    DotText {
        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        text: chip.warn ? "DEL" : chip.ep
        color: chip.playing || chip.warn ? Tokens.slot2 : chip.seen ? Tokens.slot1 : Tokens.slot0
        opacity: chip.seen && !chip.playing ? 0.55 : 1
    }
    Rectangle {
        visible: chip.mark !== "new"
        x: 2
        y: parent.height - 3
        width: chip.mark === "getting" ? Math.max(1, Math.round((parent.width - 4) * chip.pct / 100)) : parent.width - 4
        height: 2
        color: Tokens.slot2
        opacity: chip.mark === "queued" ? 0.35 : 1
    }
}
