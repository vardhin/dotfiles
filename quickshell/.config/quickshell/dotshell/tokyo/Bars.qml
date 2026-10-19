import QtQuick

// A history as standing bars in dots (1 px = 1 dot): the last values that
// fit, newest on the right, each lit to its height.
//   Bars { width: 40; height: 14; values: ctx.cpuHist; color: Ink.cyan }
Item {
    id: bars

    property var values: []
    property color color: Ink.cyan
    property int barW: 2
    property int gap: 1
    readonly property int count: Math.max(1, Math.floor((width + gap) / (barW + gap)))
    readonly property var shown: {
        const v = values ?? [];
        const s = v.slice(-count);
        return Array(Math.max(0, count - s.length)).fill(0).concat(s);
    }

    Row {
        anchors.bottom: parent.bottom
        spacing: bars.gap
        Repeater {
            model: bars.shown
            Rectangle {
                required property var modelData
                anchors.bottom: parent.bottom
                width: bars.barW
                height: Math.max(1, Math.round(Math.max(0, Math.min(1, modelData)) * bars.height))
                color: bars.color
                opacity: modelData > 0 ? 1 : 0.25
            }
        }
    }
}
