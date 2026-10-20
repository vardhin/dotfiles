import QtQuick

// Ivory paper on the wood, crisp, with its shadow under it (the todo pad,
// the clipboard slips, the message tickets, the message centre's cards).
// `tone` "hi" lifts it to the warm paper of a picked slip.
//   Paper { width: 300; height: 40 }
Item {
    id: sheet

    property string tone: ""
    property real lift: 2
    property alias color: face.color

    Rectangle {
        x: 0
        y: sheet.lift
        width: parent.width
        height: parent.height
        color: Ink.c(Qt.rgba(0, 0, 0, 0.45), Qt.rgba(90 / 255, 50 / 255, 20 / 255, 0.18))
        visible: sheet.lift > 0
    }
    Rectangle {
        id: face
        anchors.fill: parent
        color: sheet.tone === "hi" ? Ink.paperWarm : Ink.paper
    }
}
