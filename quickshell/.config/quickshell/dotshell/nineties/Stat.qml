import QtQuick
import qs.tokyo as T

// A reading's card, crisp: a deep violet rule leaning 6° (the expanded
// boards' RATE / HEALTH / DIM / LOCK cards). Its words go on the glass in
// dots under it. A click runs `action` when it has one.
//   Stat { width: 100; height: 40 }
Item {
    id: stat

    property string action: ""
    property bool on: false

    Rectangle {
        id: rule
        anchors.fill: parent
        color: "transparent"
        border.width: 1
        border.color: stat.on ? Ink.yellow : Ink.deep
        antialiasing: true
        transform: Lean {
            item: rule
            deg: 6
        }
    }
    T.Hit {
        anchors.fill: parent
        visible: stat.action !== ""
        action: stat.action
    }
}
