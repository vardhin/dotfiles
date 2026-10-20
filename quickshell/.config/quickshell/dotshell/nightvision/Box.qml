import QtQuick
import QtQuick.Shapes
import qs

// A thin crisp rule round a part of the glass: the cards' green rule
// (`tone` ""), the picked row's bright white one ("bright"), a lit one
// ("lit"); `dashed` for the battery's reading cards, `bloom` for the
// picked workspace's inner green haze.
//   Box { x: 20; y: 30; width: 120; height: 60; tone: "bright" }
Item {
    id: box

    property string tone: ""
    property bool dashed: false
    property bool bloom: false
    property int line: 1
    readonly property color ink: tone === "bright" ? Ink.bright : tone === "lit" ? Ink.lit : tone === "deep" ? Ink.deep : Ink.rule

    Rectangle {
        visible: box.bloom
        anchors.fill: parent
        color: "transparent"
        border.width: Math.min(8, box.width / 6)
        border.color: Ink.hover
        opacity: 0.6
    }
    Rectangle {
        visible: !box.dashed
        anchors.fill: parent
        color: "transparent"
        border.width: box.line
        border.color: box.ink
    }
    Shape {
        visible: box.dashed
        anchors.fill: parent
        ShapePath {
            strokeWidth: box.line
            strokeColor: box.ink
            fillColor: "transparent"
            strokeStyle: ShapePath.DashLine
            dashPattern: [3, 2]
            startX: 0.5
            startY: 0.5
            PathLine { x: box.width - 0.5; y: 0.5 }
            PathLine { x: box.width - 0.5; y: box.height - 0.5 }
            PathLine { x: 0.5; y: box.height - 0.5 }
            PathLine { x: 0.5; y: 0.5 }
        }
    }
}
