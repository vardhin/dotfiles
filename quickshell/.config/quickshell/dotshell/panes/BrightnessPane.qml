import QtQuick
import qs
import qs.services

// Backlight, night warmth and caffeine: everything about the light.
Pane {
    id: pane

    name: "brightness"
    anchors {
        top: true
        right: true
    }

    readonly property int inner: 36 * Tokens.charDots
    cols: inner + 8
    rows: col.implicitHeight + 8

    Column {
        id: col
        x: 4
        y: 4
        width: pane.inner
        spacing: 3

        Line {
            label: "BRIGHTNESS"
            labelColor: Tokens.slot2
            DotText {
                text: Brightness.available ? Math.round(Brightness.value * 100) : "N/A"
            }
        }
        VuBar {
            enabled: Brightness.available
            segments: Math.floor((pane.inner + 1) / 4)
            segWidth: 3
            max: 1
            hot: 1
            value: Brightness.value
            interactive: true
            onMoved: v => Brightness.set(v)
        }

        Item {
            width: 1
            height: 2
        }
        Rule {}

        Line {
            label: "NIGHT WARMTH"
            DotButton {
                text: ScreenShader.on ? "ON" : "OFF"
                active: ScreenShader.on
                onClicked: ScreenShader.toggle()
            }
        }
        Line {
            label: "CAFFEINE"
            DotButton {
                text: Idle.caffeine ? "ON" : "OFF"
                active: Idle.caffeine
                onClicked: Idle.setCaffeine(!Idle.caffeine)
            }
        }
    }
}
