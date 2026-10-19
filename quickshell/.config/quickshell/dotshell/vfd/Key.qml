import QtQuick
import QtQuick.Effects
import qs
import qs.tokyo as T

// A hard key on the stereo: gunmetal, lit along its top, its legend
// printed crisp. `on` is the one picked: the legend in cyan and a cyan
// ring round the key. `led` puts a lamp strip under the legend (a preset
// key's: lit, half lit, dark). A click runs `action` and fires tap().
//   Key { text: "TEXT"; on: true; action: "..." }
Rectangle {
    id: key

    property string text: ""
    property bool on: false
    property bool dim: false
    property string action: ""
    property real size: 8
    property real pad: 6
    // The lamp under the legend; transparent for none.
    property color led: "transparent"
    property bool ledGlow: false
    // The legend's own colour (REC in red); transparent for the usual.
    property color ink: "transparent"
    signal tap

    implicitWidth: Math.round(label.implicitWidth + pad * 2)
    implicitHeight: Math.round(size + 10)
    radius: 3
    color: Ink.keyEdge
    border.width: on ? 1 : 0
    border.color: Ink.cyan

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 1
        anchors.margins: key.on ? 1 : 0
        radius: 3
        gradient: Gradient {
            GradientStop {
                position: 0
                color: hit.pressed ? Ink.keyBottom : hit.containsMouse ? Qt.lighter(Ink.keyTop, 1.15) : Ink.keyTop
            }
            GradientStop {
                position: 1
                color: Ink.keyBottom
            }
        }
    }
    Text {
        id: label
        anchors.centerIn: parent
        anchors.verticalCenterOffset: (hit.pressed ? 1 : 0) - (key.led.a > 0 ? 3 : 0)
        text: key.text
        color: key.ink.a > 0 ? key.ink : key.on ? Ink.cyan : key.dim ? Ink.keyDim : Ink.keyInk
        font.family: Tokens.font
        font.pixelSize: key.size
        font.letterSpacing: 1
    }
    T.Hit {
        id: hit
        anchors.fill: parent
        action: key.action
        onTap: key.tap()
    }
    Rectangle {
        visible: key.led.a > 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: label.y + label.height + 3
        width: 18
        height: 3
        radius: 1.5
        color: key.led
        layer.enabled: key.ledGlow && visible
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: key.led
            shadowBlur: 0.5
            blurMax: 12
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }
    }
}
