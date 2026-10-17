import QtQuick
import QtMultimedia
import qs.services

// The matched music video (services/VideoMatch.qml) on a dot canvas: played
// muted, kept within a third of a second of the track, drawn as LED dots by
// the surface it sits on. Dot TV videos play their saved file instead.
//   MatchVideo { width: 107; height: 60 }
Item {
    id: root

    readonly property string key: "matchvideo-" + Math.random().toString(36).slice(2)
    readonly property string tvPath: Media.isVideo ? (Tv.byId[Media.tvId]?.path ?? "") : ""
    readonly property string source: tvPath ? "file://" + tvPath : VideoMatch.url

    onVisibleChanged: VideoMatch.want(key, visible)
    Component.onCompleted: VideoMatch.want(key, visible)
    Component.onDestruction: VideoMatch.want(key, false)

    MediaPlayer {
        id: player
        source: root.visible ? root.source : ""
        videoOutput: out
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferedMedia)
                root.sync(true);
        }
    }

    function sync(force: bool): void {
        if (!visible || !source)
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
        running: root.visible && root.source !== ""
        interval: 1000
        repeat: true
        onTriggered: root.sync(false)
    }

    VideoOutput {
        id: out
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }
}
