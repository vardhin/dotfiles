import QtQuick
import Quickshell.Services.UPower
import qs
import qs.services

// Battery level, time left, draw, health and the power profile.
Pane {
    id: pane

    name: "battery"
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
            label: "BATTERY"
            labelColor: Tokens.slot2
            DotText {
                text: Power.present ? Power.percent + "%" : "AC"
            }
        }
        VuBar {
            visible: Power.present
            segments: Math.floor((pane.inner + 1) / 4)
            segWidth: 3
            max: 1
            hot: 1
            value: Power.fraction
        }
        Line {
            visible: Power.present
            label: Power.stateText
            labelColor: Tokens.slot1
            DotText {
                text: Power.timeText
                color: Tokens.slot1
            }
        }
        Line {
            visible: Power.present && Power.watts > 0.1
            label: "DRAW"
            labelColor: Tokens.slot1
            DotText {
                text: Power.watts.toFixed(1) + " W"
                color: Tokens.slot1
            }
        }
        Line {
            visible: Power.present && Power.health > 0
            label: "HEALTH"
            labelColor: Tokens.slot1
            DotText {
                text: Math.round(Power.health) + "%"
                color: Tokens.slot1
            }
        }

        Item {
            width: 1
            height: 2
        }
        Rule {}

        DotText {
            height: Tokens.lineDots
            text: "PROFILE"
            color: Tokens.slot2
        }
        Row {
            spacing: 3
            Repeater {
                model: Power.hasPerformance ? [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance] : [PowerProfile.PowerSaver, PowerProfile.Balanced]

                DotButton {
                    required property int modelData
                    text: Power.profileName(modelData)
                    active: Power.profile === modelData
                    onClicked: Power.setProfile(modelData)
                }
            }
        }
    }
}
