import QtQuick
import QtQuick.Effects
import qs.services
import "Hardware.js" as Hardware

// The media panel, compact, in the Tokyo Night era: a neon sign (panel
// design canvas, "Now playing", sk.tokyo). The whole pill is dot glass, a
// pink tube round its edge and a cyan one inside it, glowing over the dots.
//
//   ╭──────────────────────────────────────────────╮
//   │ ( record )  Track Title                       │  title: pixel font, dots
//   │ (  art   )  the line being sung / artist      │  karaoke, or who
//   │ (  or    )  ▁▃▅▂▇▃▁▅▂▃▆  the spectrum         │  pink bars, dots
//   │ ( video  )  ━━━━━━━●─────────────             │  line + knob (crisp)
//   │             (|<) (||) (>|)         1:38 / 3:54│  neon keys (crisp)
//   ╰──────────────────────────────────────────────╯
//
// No VID / VIS / LYR switches: the matched video plays in the record's
// place, the spectrum and the sung line are in the sign whenever there is
// something to show.
Item {
    id: root

    required property var ctx
    required property var sink
    required property var panel
    required property var words

    readonly property var hw: Hardware.get("tokyo", Tokens.flipped)
    readonly property bool active: !!ctx.active
    readonly property bool playing: !!ctx.playing
    readonly property real progress: active ? (ctx.progress ?? 0) : 0
    readonly property int pitch: Tokens.pitch

    // Clicks and drags from a key: a hold or a drag still lifts the panel.
    function grip(kind: string, area: Item, mouse: var): bool {
        const p = area.mapToItem(null, mouse?.x ?? 0, mouse?.y ?? 0);
        return sink.grip(kind, p.x, p.y);
    }

    // ── Where things go, in px ──────────────────────────────────────
    readonly property int pad: Math.round(height * 0.11)
    // The record sits in the round end.
    readonly property int artPx: height - pad * 2
    readonly property int textPx: pad + artPx + 16
    readonly property int textW: width - textPx - Math.round(height * 0.26)
    // The column, top to bottom.
    readonly property int titleH: Tokens.fontPx * pitch
    readonly property int lineH: 7 * pitch
    readonly property int keysH: 30
    readonly property int barH: 10
    readonly property int specH: Math.max(0, height - pad * 2 - titleH - lineH - barH - keysH - 3 - 5 - 5 - 4)
    readonly property int titleY: pad
    readonly property int lineY: titleY + titleH + 3
    readonly property int specY: lineY + lineH + 5
    readonly property int barY: specY + specH + 5
    readonly property int keysY: barY + barH + 4

    // ── The glass, in dots ──────────────────────────────────────────
    DotSurface {
        id: screen
        anchors.centerIn: parent
        cols: Math.floor(parent.width / pitch)
        rows: Math.floor(parent.height / pitch)
        shape: Hardware.rounded(0, 0, cols, rows, rows / 2)

        Item {
            id: dots
            width: screen.cols
            height: screen.rows
            function d(px: real): int {
                return Math.round(px / root.pitch);
            }

            // The record: grooves round a label, the cover on the label.
            Item {
                id: record
                x: dots.d(root.pad)
                y: Math.round((dots.height - width) / 2)
                width: dots.d(root.artPx)
                height: width

                Canvas {
                    anchors.fill: parent
                    readonly property string sig: [width, Tokens.slot0, Tokens.flipped].join()
                    onSigChanged: requestPaint()
                    onPaint: {
                        const c = getContext("2d");
                        c.reset();
                        const r = width / 2;
                        for (let k = Math.floor(r); k > 0; k--) {
                            c.fillStyle = String(Tokens.ink(k % 2 ? "#3b4261" : "#292e42"));
                            c.beginPath();
                            c.arc(r, r, k, 0, Math.PI * 2);
                            c.fill();
                        }
                        // The label's pink rim.
                        c.fillStyle = String(Tokens.slot0);
                        c.beginPath();
                        c.arc(r, r, Math.max(2, Math.round(r * 0.42)), 0, Math.PI * 2);
                        c.fill();
                    }
                }
                MediaArt {
                    anchors.centerIn: parent
                    width: Math.max(2, Math.round(parent.width * 0.42) * 2 - 2)
                    height: width
                    round: true
                    src: root.active ? (root.ctx.art ?? "") : ""
                    stripe: Tokens.ink("#3b4261")
                    sun: Tokens.slot1
                    ground: Tokens.ink("#16161e")
                }

                // The matched video, in the record's place, cut round.
                Item {
                    anchors.fill: parent
                    visible: root.active && !!root.ctx.hasVideo
                    layer.enabled: visible
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: disc
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 0
                    }
                    Loader {
                        anchors.fill: parent
                        active: parent.visible
                        sourceComponent: MatchVideo {}
                    }
                }
                Rectangle {
                    id: disc
                    anchors.fill: parent
                    radius: width / 2
                    visible: false
                    layer.enabled: true
                }
            }

            // Track Title, in the pixel font (lower case, any script).
            Item {
                x: dots.d(root.textPx)
                y: dots.d(root.titleY)
                width: dots.d(root.textW)
                height: Tokens.fontPx
                clip: true
                DotText {
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.active ? (root.ctx.title || root.words.idle) : root.words.idle
                    color: Tokens.slot1
                }
            }

            // The line being sung; who it is by when there are no lyrics.
            LyricLine {
                visible: Lyrics.has
                x: dots.d(root.textPx)
                y: dots.d(root.lineY)
                width: dots.d(root.textW)
                color: Tokens.slot1
                rest: Tokens.slot0
                playing: root.playing
            }
            MatrixText {
                visible: !Lyrics.has
                x: dots.d(root.textPx)
                y: dots.d(root.lineY)
                width: dots.d(root.textW)
                height: implicitHeight
                scroll: true
                text: root.active ? [root.ctx.artist, root.ctx.album].filter(s => !!s).join(" · ") : (root.ctx.count ?? 0) + " IN THE LIBRARY"
                color: Tokens.slot0
            }

            // The music, pink.
            Spectrum {
                visible: root.active && height >= 3
                x: dots.d(root.textPx)
                y: dots.d(root.specY)
                width: dots.d(root.textW)
                height: dots.d(root.specH)
                bars: Math.max(4, Math.floor((width + 1) / 3))
            }
        }
    }

    // ── The tubes ───────────────────────────────────────────────────
    Faceplate {
        anchors.fill: parent
        hw: Object.assign({}, root.hw, { plate: Object.assign({}, root.hw.plate, { color: "transparent" }) })
    }

    // ── Where the track is: a line, lit to a knob ───────────────────
    Item {
        id: bar
        x: root.textPx
        y: root.barY
        width: root.textW
        height: root.barH
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 2
            color: Tokens.slot2
            opacity: 0.5
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(parent.width * root.progress)
            height: 3
            color: Tokens.slot1
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: Tokens.neon
                shadowColor: Tokens.slot1
                shadowBlur: 0.4
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }
        }
        Rectangle {
            x: Math.round(parent.width * root.progress) - 5
            anchors.verticalCenter: parent.verticalCenter
            width: 10
            height: 10
            radius: 5
            color: "#ffffff"
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: Tokens.neon
                shadowColor: Tokens.slot1
                shadowBlur: 0.5
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            enabled: root.active
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => Media.seekTo(Math.max(0, Math.min(1, (mouse.x - 4) / bar.width)))
        }
    }

    // ── Neon keys, and the time ─────────────────────────────────────
    Row {
        x: root.textPx
        y: root.keysY
        height: root.keysH
        spacing: 10
        Repeater {
            model: root.hw.keys.items
            DeviceKey {
                required property var modelData
                anchors.verticalCenter: parent.verticalCenter
                spec: modelData
                grip: root.grip
                width: modelData.w ?? 28
                height: modelData.h ?? 28
                onAct: what => what === "prev" ? Media.previous() : what === "next" ? Media.next() : Media.toggle()
            }
        }
    }
    Text {
        anchors.right: bar.right
        y: root.keysY + Math.round((root.keysH - height) / 2)
        text: root.active ? Media.clock(root.ctx.pos) + " / " + Media.clock(root.ctx.len) : "-:--"
        color: Tokens.slot2
        font.family: Tokens.font
        font.pixelSize: 11
    }
}
