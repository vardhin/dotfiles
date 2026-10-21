import QtQuick
import QtQuick.Effects

// A small neon button: a pill outline round a word, crisp (the design's
// buttons sit over the dots, not in them).
//   tone   dim     violet word in a deep rule (the usual)
//          pink    cyan    red (glows)
//          on      filled cyan, dark word (the one picked)
//   Chip { text: "REGION"; tone: "cyan"; action: "capture shot area" }
Rectangle {
    id: chip

    property string text: ""
    property string tone: "dim"
    property string action: ""
    property real size: 10
    property real pad: 7
    signal tap

    readonly property color tint: tone === "pink" ? Ink.pink : tone === "cyan" || tone === "on" ? Ink.cyan : tone === "red" ? Ink.red : Ink.deep
    readonly property color ink: tone === "on" ? Ink.glass : tone === "dim" ? Ink.violet : tint
    readonly property bool lit: tone === "on" || tone === "red"

    implicitWidth: Math.round(label.implicitWidth + pad * 2 + 3)
    implicitHeight: Math.round(size + 8)
    radius: height / 2
    color: tone === "on" ? Ink.cyan : hit.containsMouse ? Qt.rgba(tint.r, tint.g, tint.b, 0.16) : "transparent"
    border.width: 1.5
    border.color: tone === "dim" && hit.containsMouse ? Ink.violet : tint
    antialiasing: true

    layer.enabled: lit && visible
    layer.effect: MultiEffect {
        shadowEnabled: Ink.neon
        shadowColor: chip.tint
        shadowBlur: 0.25
        blurMax: 12
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
    }

    Text {
        id: label
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 0.5
        text: chip.text
        color: chip.ink
        font.family: Ink.family
        font.pixelSize: chip.size
        font.letterSpacing: 0.5
    }

    Hit {
        id: hit
        anchors.fill: parent
        action: chip.action
        onTap: chip.tap()
    }
}
