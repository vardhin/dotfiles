import QtQuick

// A camera lens in a brass mount, crisp: the walnut ring, a brass band, the
// dark barrel and the glass (the capture board's 92 px lens, scaled). While
// `live`, the glass holds a faint red glint.
//   Lens { width: 92; height: 92; live: true }
Item {
    id: lens

    property bool live: false
    readonly property real r: Math.min(width, height) / 2

    Rectangle {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 2
        width: lens.r * 2
        height: width
        radius: lens.r
        color: Ink.c(Qt.rgba(0, 0, 0, 0.5), Qt.rgba(90 / 255, 50 / 255, 20 / 255, 0.2))
    }
    // Outside in: walnut 100-75 %, brass 74-71, walnut 70-53, brass 52-47,
    // barrel 46-31, glass.
    Repeater {
        model: [[1, Ink.woodA], [0.74, Ink.brass], [0.7, Ink.woodB], [0.52, Ink.brass], [0.46, Ink.unlit], [0.3, Ink.c("#0a0503", "#1a0d06")]]
        Rectangle {
            required property var modelData
            anchors.centerIn: parent
            width: lens.r * 2 * modelData[0]
            height: width
            radius: width / 2
            color: modelData[1]
        }
    }
    Rectangle {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: -lens.r * 0.1
        anchors.verticalCenterOffset: -lens.r * 0.1
        width: lens.r * 0.22
        height: width
        radius: width / 2
        color: lens.live ? Ink.red : Qt.rgba(1, 1, 1, 0.12)
        opacity: lens.live ? 0.8 : 1
        SequentialAnimation on opacity {
            running: lens.live
            loops: Animation.Infinite
            NumberAnimation {
                to: 0.25
                duration: 700
            }
            NumberAnimation {
                to: 0.8
                duration: 700
            }
        }
    }
}
