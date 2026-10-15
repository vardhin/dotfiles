import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs
import qs.services

// Volume, mic and output device. Bars are draggable and scrollable.
Pane {
    id: pane

    name: "audio"
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
            label: "VOLUME"
            labelColor: Tokens.slot2
            DotText {
                text: Audio.muted ? "OFF" : Math.round(Audio.volume * 100)
            }
            DotButton {
                text: "MUTE"
                active: Audio.muted
                onClicked: Audio.toggleMute()
            }
        }
        VuBar {
            segments: Math.floor((pane.inner + 1) / 4)
            segWidth: 3
            max: 1.5
            value: Audio.muted ? 0 : Audio.volume
            interactive: true
            onMoved: v => Audio.setVolume(v)
        }

        Item {
            width: 1
            height: 2
        }

        Line {
            label: "MIC"
            labelColor: Tokens.slot2
            DotText {
                text: Audio.micMuted ? "OFF" : Math.round(Audio.micVolume * 100)
            }
            DotButton {
                text: "MUTE"
                active: Audio.micMuted
                onClicked: Audio.toggleMicMute()
            }
        }
        VuBar {
            segments: Math.floor((pane.inner + 1) / 4)
            segWidth: 3
            max: 1.5
            value: Audio.micMuted ? 0 : Audio.micVolume
            interactive: true
            onMoved: v => Audio.setMicVolume(v)
        }

        Item {
            width: 1
            height: 2
        }
        Rule {}

        DotText {
            height: Tokens.lineDots
            text: "OUTPUT"
            color: Tokens.slot2
        }

        Repeater {
            model: Audio.sinks

            DotButton {
                required property PwNode modelData
                width: pane.inner
                text: (modelData.description || modelData.nickname || modelData.name).toUpperCase()
                active: modelData === Audio.sink
                onClicked: Audio.useSink(modelData)
            }
        }

        DotButton {
            text: "MIXER"
            color: Tokens.slot1
            onClicked: {
                Ui.close();
                Quickshell.execDetached(["pavucontrol"]);
            }
        }
    }
}
