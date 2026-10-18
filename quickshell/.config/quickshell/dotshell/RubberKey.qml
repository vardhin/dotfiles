import QtQuick
import QtQuick.Shapes

// One key of a device's key row (Hardware.js `keys`): an icon (an SVG path on
// a 16 x 14 box) or a word. `grip(kind, area, mouse)`, when set, also gets the
// presses, so a panel can still be held or dragged from its keys; a press it
// turned into a drag is not a click.
Item {
    id: key

    required property var hw
    property string icon: ""
    property string label: ""
    property color ink: hw.keys.ink
    property var grip: null
    property bool dragged: false

    signal clicked

    height: hw.keys.h

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: hit.pressed ? 1 : 0
        radius: key.hw.keys.radius
        gradient: Gradient {
            GradientStop {
                position: 0
                color: hit.pressed ? key.hw.keys.downTop : hit.containsMouse ? key.hw.keys.hover : key.hw.keys.top
            }
            GradientStop {
                position: 1
                color: hit.pressed ? key.hw.keys.downBottom : key.hw.keys.bottom
            }
        }
        Rectangle {
            visible: !hit.pressed
            x: 3
            y: 1
            width: parent.width - 6
            height: 1
            color: key.hw.keys.edge
        }
    }
    Shape {
        visible: key.icon !== ""
        anchors.centerIn: parent
        anchors.verticalCenterOffset: hit.pressed ? 1 : 0
        width: 16
        height: 14
        scale: 0.78
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillColor: key.ink
            PathSvg {
                path: key.icon
            }
        }
    }
    Text {
        visible: key.label !== ""
        anchors.centerIn: parent
        anchors.verticalCenterOffset: hit.pressed ? 1 : 0
        text: key.label
        color: key.ink
        font.family: Tokens.font
        font.pixelSize: Tokens.fontPx
    }
    MouseArea {
        id: hit
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => {
            key.dragged = false;
            if (key.grip)
                key.grip("press", hit, mouse);
        }
        onPositionChanged: mouse => {
            if (pressed && key.grip)
                key.grip("move", hit, mouse);
        }
        onReleased: mouse => {
            if (key.grip)
                key.dragged = key.grip("release", hit, mouse);
        }
        onCanceled: {
            if (key.grip)
                key.grip("cancel", hit, null);
        }
        onClicked: {
            if (!key.dragged)
                key.clicked();
        }
    }
}
