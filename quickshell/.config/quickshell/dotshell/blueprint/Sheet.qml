import QtQuick

// An expanded panel's sheet heading, crisp: "SHEET 4 — LOAD SCHEDULE" at
// the top left and "REV A" at the top right, in pale blue.
//   Sheet { width: parent.width; title: "SHEET 4 — LOAD SCHEDULE" }
Item {
    id: sheet

    property string title: ""
    property string rev: "REV A"

    x: 14
    y: 10
    width: parent.width - 28
    height: 14

    Pen {
        width: parent.width - revWord.implicitWidth - 10
        height: parent.height
        text: sheet.title
    }
    Pen {
        id: revWord
        anchors.right: parent.right
        height: parent.height
        text: sheet.rev
    }
}
