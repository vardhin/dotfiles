pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Default speaker and microphone over PipeWire. Volume keys keep using
// pactl; the OSD reacts to the resulting change signals.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? false

    // Hardware outputs (not app streams), for the output picker.
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)

    // Emitted on user-visible changes once PipeWire has settled, not during
    // the startup sync (so the OSD does not pop at login).
    signal changed(string kind)

    property bool settled: false
    Timer {
        running: Pipewire.ready
        interval: 1500
        onTriggered: root.settled = true
    }

    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() {
            if (root.settled)
                root.changed("volume");
        }
        function onMutedChanged() {
            if (root.settled)
                root.changed("volume");
        }
    }

    Connections {
        target: root.source?.audio ?? null
        function onVolumeChanged() {
            if (root.settled)
                root.changed("mic");
        }
        function onMutedChanged() {
            if (root.settled)
                root.changed("mic");
        }
    }

    function setVolume(v: real): void {
        if (sink?.audio) {
            sink.audio.muted = false;
            sink.audio.volume = Math.max(0, Math.min(1.5, v));
        }
    }
    function toggleMute(): void {
        if (sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }
    function setMicVolume(v: real): void {
        if (source?.audio) {
            source.audio.muted = false;
            source.audio.volume = Math.max(0, Math.min(1.5, v));
        }
    }
    function toggleMicMute(): void {
        if (source?.audio)
            source.audio.muted = !source.audio.muted;
    }
    function useSink(node: PwNode): void {
        Pipewire.preferredDefaultAudioSink = node;
    }
}
