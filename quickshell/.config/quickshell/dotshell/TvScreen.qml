import QtQuick
import QtMultimedia
import Quickshell
import qs.services

// The Dot TV picture inside the shell: the saved video file played muted with
// Qt Multimedia, drawn as LED dots by shaders/tvled.frag at the Tv.screen
// settings (pitch, dot size, shape, color mode, glow, dither). mpv keeps the
// sound, the queue and MPRIS; this follows it: same track, play/pause, and a
// seek whenever the two drift apart by more than a third of a second.
//
// Lives in a Pane's overlay (screen px). A track that is still streaming, not
// saved yet, shows its art until the file lands.
Item {
    id: root

    // Set false while hidden: decoding stops.
    property bool active: visible
    readonly property string path: Media.isTv ? (Tv.byId[Media.tvId]?.path ?? "") : ""
    readonly property bool hasVideo: path !== "" && player.hasVideo
    readonly property real dpr: QsWindow.window?.devicePixelRatio ?? 1

    MediaPlayer {
        id: player
        source: root.active && root.path ? "file://" + root.path : ""
        videoOutput: video
        // No audioOutput: mpv plays the sound.
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferedMedia)
                root.sync(true);
        }
    }

    function sync(force: bool): void {
        if (!active || !path)
            return;
        const want = Media.position * 1000;
        if (force || Math.abs(player.position - want) > 350)
            player.position = want;
        if (Media.isPlaying && player.playbackState !== MediaPlayer.PlayingState)
            player.play();
        else if (!Media.isPlaying && player.playbackState === MediaPlayer.PlayingState)
            player.pause();
    }

    Connections {
        target: Media
        function onIsPlayingChanged() {
            root.sync(false);
        }
    }
    Timer {
        running: root.active && root.path !== ""
        interval: 1000
        repeat: true
        onTriggered: root.sync(false)
    }
    onActiveChanged: if (!active) player.stop()

    // Letterboxed into the screen; the bars are glass.
    Rectangle {
        anchors.fill: parent
        color: Tokens.glass
    }
    VideoOutput {
        id: video
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectFit
        visible: false
        layer.enabled: true
    }
    // No video: the art, through the same dots.
    Image {
        id: still
        anchors.fill: parent
        visible: false
        layer.enabled: true
        source: !root.hasVideo ? Media.art : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true
    }

    ShaderEffect {
        anchors.fill: parent
        readonly property var sc: Tv.screen
        readonly property var era: Tokens.current
        property variant source: root.hasVideo ? video : still
        property size size: Qt.size(width * root.dpr, height * root.dpr)
        property real pitch: sc.pitch * root.dpr
        property real dotSize: sc.dotSize / 100
        property real shape: {
            const s = sc.shape === "era" ? era.shape : sc.shape;
            return s === "square" ? 1 : s === "bubble" ? 2 : 0;
        }
        property real mode: ({ era: 0, mono: 1, "8": 2, "16": 3, "24": 4, raw: 5 })[sc.color] ?? 0
        property real glow: sc.glow / 100
        property real dither: sc.dither ? 1 : 0
        property color ramp0: era.ramp[0]
        property color ramp1: era.ramp[1]
        property color ramp2: era.ramp[2]
        property color ramp3: era.ramp[3]
        property color tube: era.slots[0]
        property color unlitColor: era.unlit
        property color glassColor: era.glass
        fragmentShader: Qt.resolvedUrl("shaders/tvled.frag.qsb")
    }
}
