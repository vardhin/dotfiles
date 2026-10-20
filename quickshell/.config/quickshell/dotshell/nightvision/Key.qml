import QtQuick
import qs
import qs.tokyo as T

// A Night Vision key, crisp on the glass: a thin green rule with its word
// in Share Tech Mono (30 M, REGION, ALL); `on` fills it lit green with dark
// words (the picked one); `tone` "bright" rules it and its word in the
// bright phosphor (PASTE, OPEN, the picked capture mode), "dim" fades it.
// A click runs `action` and fires tap(); held down it sinks a px.
//   Key { width: 60; height: 20; text: "1 H"; on: true; action: "caffeine for 60" }
Item {
    id: key

    property string text: ""
    property bool on: false
    property string tone: ""
    property string action: ""
    property real textPx: Math.max(9, Math.min(13, height * 0.62))
    property bool boxed: true
    property real spacing: 1
    signal tap

    readonly property color ink: on ? Ink.night : tone === "bright" ? Ink.bright : tone === "dim" ? Ink.dim : Ink.lit

    implicitWidth: Math.ceil(label.implicitWidth) + 16
    implicitHeight: 20
    opacity: enabled ? 1 : 0.4

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: hit.pressed ? 1 : 0
        anchors.bottomMargin: hit.pressed ? -1 : 0
        color: key.on ? Ink.lit : hit.containsMouse ? Ink.hover : "transparent"
        border.width: key.on || !key.boxed ? 0 : 1
        border.color: key.tone === "bright" ? Ink.bright : key.tone === "dim" ? Ink.deep : Ink.rule

        Text {
            id: label
            anchors.fill: parent
            anchors.leftMargin: 3
            anchors.rightMargin: 3
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: key.text
            color: key.ink
            font.family: Ink.family
            font.pixelSize: key.textPx
            font.letterSpacing: key.spacing
            elide: Text.ElideRight
        }
    }
    T.Hit {
        id: hit
        anchors.fill: parent
        action: key.action
        onTap: key.tap()
    }
}
