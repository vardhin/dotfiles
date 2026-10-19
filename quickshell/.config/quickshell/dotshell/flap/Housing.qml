import QtQuick
import qs.tokyo as T

// A departure board's housing, crisp: near black, a 2 px grey rim inside
// its edge, the small print across the top (`label` at the left, "● " and
// `status` at the right in `statusInk`; a click on the status runs
// `statusAction`), and with `screws` a screw head in each corner (the
// media board). Contents start at `bodyY`.
//   Housing { anchors.fill: parent; label: "SYSTEM STATUS"; status: "NOMINAL" }
Item {
    id: housing

    property string label: ""
    property string status: ""
    property color statusInk: Ink.yellow
    property string statusAction: ""
    property bool screws: false
    property real padX: 14
    readonly property real headY: 8
    readonly property real bodyY: label || status ? 24 : 10

    Rectangle {
        anchors.fill: parent
        color: Ink.housing
        border.width: 2
        border.color: Ink.rim
    }
    Repeater {
        model: housing.screws ? [[5, 5], [1, 5], [5, 1], [1, 1]] : []
        Rectangle {
            required property var modelData
            x: modelData[0] === 5 ? 5 : housing.width - 11
            y: modelData[1] === 5 ? 5 : housing.height - 11
            width: 6
            height: 6
            radius: 3
            color: Ink.c("#3a3a3a", "#b5ae9e")
            Rectangle {
                x: 1
                width: 4
                height: 1
                color: Ink.c("#555555", "#9c9585")
            }
        }
    }
    Print {
        x: housing.padX
        y: housing.headY
        width: housing.width - housing.padX * 2 - stat.implicitWidth - 8
        height: 12
        text: housing.label
    }
    Print {
        id: stat
        anchors.right: parent.right
        anchors.rightMargin: housing.padX
        y: housing.headY
        height: 12
        visible: housing.status !== ""
        text: "● " + housing.status
        color: housing.statusInk
        T.Hit {
            anchors.fill: parent
            anchors.margins: -4
            visible: housing.statusAction !== ""
            action: housing.statusAction
        }
    }
}
