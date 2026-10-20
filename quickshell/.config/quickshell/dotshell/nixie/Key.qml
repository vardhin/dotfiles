import QtQuick
import qs
import qs.tokyo as T

// A brass key, crisp: a pill ruled in brass with its word in Silkscreen
// (the design's SHOT, WINDOW, 30 M). `on` fills it with polished brass and
// dark words (REGION, 1 H, the picked kind); `tone` "hot" is the red-orange
// cathode key that glows (REC, STOP, ON AIR), "lit" the bright orange one
// (LYR with lyrics). `radius` 3 gives the media board's square tabs. A
// click runs `action` and fires tap(); held down it sinks a px.
//   Key { width: 70; height: 22; text: "1 H"; on: true; action: "caffeine for 60" }
Item {
    id: key

    property string text: ""
    property bool on: false
    property string tone: ""
    property string action: ""
    property real textPx: 7
    property real radius: height / 2
    signal tap

    readonly property bool hot: tone === "hot"
    readonly property bool lamp: tone === "lit"
    readonly property color ink: hot ? Ink.digit : lamp ? Ink.c("#2b130a", "#fbf5e8") : on ? Ink.c("#3a1d0e", "#3a1d0e") : Ink.brass

    opacity: enabled ? 1 : 0.45

    Glow {
        visible: key.hot || key.lamp
        anchors.fill: face
        radius: face.radius
        color: key.hot ? Ink.deep : Ink.orange
        halo: 5
    }
    Rectangle {
        id: face
        anchors.fill: parent
        anchors.topMargin: hit.pressed ? 1 : 0
        anchors.bottomMargin: hit.pressed ? -1 : 0
        radius: key.radius
        color: key.hot ? Ink.deep : key.lamp ? Ink.orange : "transparent"
        border.width: key.hot || key.lamp || key.on ? 0 : 1
        border.color: Ink.brass
        // Polished brass: lit from the top left.
        Rectangle {
            visible: key.on && !key.hot && !key.lamp
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: Ink.c("#c99a52", "#c99a52")
                }
                GradientStop {
                    position: 0.35
                    color: Ink.brassHi
                }
                GradientStop {
                    position: 1
                    color: Ink.brassLo
                }
            }
        }
        Rectangle {
            visible: hit.containsMouse
            anchors.fill: parent
            radius: parent.radius
            color: Ink.c(Qt.rgba(1, 200 / 255, 150 / 255, 0.1), Qt.rgba(90 / 255, 50 / 255, 20 / 255, 0.08))
        }
        Print {
            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            horizontalAlignment: Text.AlignHCenter
            text: key.text
            size: key.textPx
            spacing: key.width < 52 ? 0 : 1
            color: key.ink
        }
    }
    T.Hit {
        id: hit
        anchors.fill: parent
        action: key.action
        onTap: key.tap()
    }
}
