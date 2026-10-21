import QtQuick
import QtQuick.Effects
import qs
import qs.tokyo as T

// A 90s Nights key, crisp and leaning 10°: an electric-blue outline with
// its word in Audiowide (30 M, VID, ALL); `on` fills it yellow with dark
// words (the picked one, LYR with lyrics). `tone` "chrome" is the white →
// magenta transport key, "hot" the white → hot pink one (play/pause),
// "pink" a hot pink slab that glows (TURBO), "red" an alarm outline;
// `glyph` puts a transport glyph in place of the word. A click runs
// `action` and fires tap(); held down it sinks a px.
//   Key { width: 60; height: 20; text: "1 H"; on: true; action: "caffeine for 60" }
Item {
    id: key

    property string text: ""
    property bool on: false
    property string tone: ""
    property string glyph: ""
    property string action: ""
    property real textPx: 10
    property bool lean: true
    property bool slanted: true
    signal tap

    readonly property bool chrome: tone === "chrome" || tone === "hot"
    readonly property bool slab: tone === "pink"
    readonly property color ink: chrome || on || slab ? Ink.night : tone === "red" ? Ink.red : tone === "dim" ? Ink.dim : Ink.blue

    opacity: enabled ? 1 : 0.4

    Item {
        id: face
        width: key.width
        height: key.height
        y: hit.pressed ? 1 : 0
        antialiasing: true
        transform: Lean {
            item: face
            deg: key.lean ? 10 : 0
        }
        layer.enabled: key.slab && Tokens.neon
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Ink.pink
            shadowBlur: 0.25
            blurMax: 12
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }
        Rectangle {
            antialiasing: true
            anchors.fill: parent
            color: key.on ? Ink.yellow : key.slab ? Ink.pink : "transparent"
            border.width: key.on || key.chrome || key.slab ? 0 : 1
            border.color: key.tone === "red" ? Ink.red : key.tone === "dim" ? Ink.dim : Ink.blue
            gradient: key.chrome ? chromeG : null
        }
        Gradient {
            id: chromeG
            GradientStop {
                position: 0
                color: Ink.white
            }
            GradientStop {
                position: 1
                color: key.tone === "hot" ? Ink.pink : Ink.magenta
            }
        }
        Rectangle {
            antialiasing: true
            visible: hit.containsMouse
            anchors.fill: parent
            color: key.on || key.chrome || key.slab ? Qt.rgba(1, 1, 1, 0.18) : Ink.c(Qt.rgba(31 / 255, 168 / 255, 1, 0.15), Qt.rgba(10 / 255, 132 / 255, 214 / 255, 0.12))
        }
        Pen {
            visible: key.glyph === ""
            anchors.fill: parent
            anchors.leftMargin: 3
            anchors.rightMargin: 3
            horizontalAlignment: Text.AlignHCenter
            text: key.text
            size: key.textPx
            slanted: key.slanted
            color: key.ink
        }
        Glyph {
            visible: key.glyph !== ""
            anchors.centerIn: parent
            width: Math.round(key.height * 0.5)
            height: Math.round(key.height * 0.5)
            kind: key.glyph
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
