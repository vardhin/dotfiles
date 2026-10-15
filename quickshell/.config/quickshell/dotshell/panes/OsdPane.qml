import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// OSD: one VU-meter line at the bottom center for volume, mic and
// brightness changes. Nothing to click; it goes away after 1.5 s.
Pane {
    id: pane

    name: "osd"
    managed: false
    shown: false
    grab: false
    keyboard: WlrKeyboardFocus.None
    screen: Ui.focusedScreen()

    anchors.bottom: true
    margins.bottom: 24

    property string kind: "volume"
    readonly property real value: kind === "volume" ? (Audio.muted ? 0 : Audio.volume) : kind === "mic" ? (Audio.micMuted ? 0 : Audio.micVolume) : Brightness.value
    readonly property bool off: (kind === "volume" && Audio.muted) || (kind === "mic" && Audio.micMuted)

    cols: line.width + 8
    rows: Tokens.lineDots + 6

    function show(k: string): void {
        kind = k;
        shown = true;
        hide.restart();
    }

    Connections {
        target: Audio
        function onChanged(k) {
            pane.show(k);
        }
    }
    Connections {
        target: Brightness
        function onChanged() {
            pane.show("brightness");
        }
    }

    Timer {
        id: hide
        interval: 1500
        onTriggered: pane.shown = false
    }

    Row {
        id: line
        x: 4
        y: 3
        height: Tokens.lineDots
        spacing: Tokens.charDots

        DotText {
            width: 3 * Tokens.charDots
            text: pane.kind === "volume" ? "VOL" : pane.kind === "mic" ? "MIC" : "BRT"
            color: Tokens.slot2
        }
        VuBar {
            anchors.verticalCenter: parent.verticalCenter
            segments: 32
            max: pane.kind === "brightness" ? 1 : 1.5
            hot: 0.8
            value: pane.value
        }
        DotText {
            width: 4 * Tokens.charDots
            horizontalAlignment: Text.AlignRight
            text: pane.off ? "OFF" : Math.round(pane.value * 100)
        }
    }
}
