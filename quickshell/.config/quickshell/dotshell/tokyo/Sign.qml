import QtQuick

// The sign's tubes, over its glass: a pink tube round the edge and, on the
// big (expanded) boards, a cyan one inside it.
//   tone   pink    lit
//          red     alarm (battery low)
//          dim     switched off (caffeine asleep, DND): a violet tube, dim
Item {
    id: sign

    property real radius: 26
    property bool inner: false
    // Where the cyan tube runs: 8 px in on a small sign, 12 on a big board
    // (where it rims the dot glass).
    property real innerInset: 8
    property string tone: "pink"
    readonly property color tint: tone === "red" ? Ink.red : tone === "dim" ? Ink.deep : Ink.pink

    anchors.fill: parent

    Tube {
        anchors.fill: parent
        anchors.margins: 1.5
        radius: sign.radius
        line: 3
        tint: sign.tint
        glow: sign.tone === "dim" ? 0.4 : 1
    }
    Tube {
        visible: sign.inner
        anchors.fill: parent
        anchors.margins: sign.innerInset
        radius: Math.max(4, sign.radius - sign.innerInset)
        line: 2
        tint: Ink.cyan
        opacity: 0.75
        glow: 0.6
    }
}
