import QtQuick
import qs

// Interim display settings (Super T): era, dot pitch, dot size, color depth.
// Every choice is a token, so it persists and applies live. Phase 5 replaces
// this with the full era set and the cascade flip.
Pane {
    id: pane

    name: "eras"
    anchors {
        top: true
        right: true
    }

    readonly property int inner: 40 * Tokens.charDots
    cols: inner + 8
    rows: col.implicitHeight + 8

    component Choices: Row {
        id: choices
        required property string token
        required property var options      // [[value, label], ...]
        required property string current
        spacing: 2

        Repeater {
            model: choices.options

            DotButton {
                required property var modelData
                text: modelData[1]
                active: choices.current === String(modelData[0])
                onClicked: Tokens.set(choices.token, String(modelData[0]))
            }
        }
    }

    Column {
        id: col
        x: 4
        y: 4
        width: pane.inner
        spacing: 3

        DotText {
            height: Tokens.lineDots
            text: "ERA"
            color: Tokens.slot2
        }
        Choices {
            token: "era"
            options: Eras.ids.map(id => [id, Eras.all[id].name.toUpperCase()])
            current: Tokens.era
        }

        Rule {}

        Line {
            label: "PITCH"
            Choices {
                token: "pitch"
                options: [[3, "FINE"], [5, "MED"], [8, "COARSE"], [12, "CHUNKY"]]
                current: String(Tokens.pitch)
            }
        }
        Line {
            label: "DOT SIZE"
            Choices {
                token: "dotSize"
                options: [[60, "60"], [70, "70"], [80, "80"], [90, "90"], [100, "100"]]
                current: String(Math.round(Tokens.dotSize * 100))
            }
        }
        Line {
            label: "DEPTH"
            Choices {
                token: "depth"
                options: [["era", "ERA"], ["8", "8 BIT"], ["16", "16"], ["24", "24"]]
                current: Tokens.depth
            }
        }
    }
}
