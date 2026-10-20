import QtQuick
import QtQuick.Effects

// Paints its children's ink with a gradient (the design's background-clip
// text: SYSTEM, 72%, the clock's chrome 9:47). Size it to the children.
// `stops` is a list of [position, color], top to bottom (or left to right
// with `across`). Works on a dot canvas too (1 px = 1 dot).
//   Grad { width: 60; height: 9; stops: Ink.sunset; Say { text: "72%" } }
Item {
    id: grad

    property var stops: Ink.sunset
    property bool across: false
    default property alias content: ink.data

    Item {
        id: ink
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.smooth: false
    }
    Rectangle {
        id: fill
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.smooth: false
        gradient: Gradient {
            id: g
            orientation: grad.across ? Gradient.Horizontal : Gradient.Vertical
        }
    }
    Component {
        id: stopC
        GradientStop {}
    }
    function build(): void {
        const list = [];
        for (const s of grad.stops)
            list.push(stopC.createObject(g, {
                position: s[0],
                color: s[1]
            }));
        g.stops = list;
    }
    onStopsChanged: build()
    Component.onCompleted: build()

    MultiEffect {
        anchors.fill: parent
        source: fill
        maskEnabled: true
        maskSource: ink
        maskThresholdMin: 0.0
        maskSpreadAtMin: 0.0
    }
}
