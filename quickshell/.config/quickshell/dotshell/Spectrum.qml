import QtQuick
import qs.services

// A spectrum analyser in dots: `bars` columns from Media.bars (cava), each
// lit from the bottom like a VU meter: first tube, then second, then accent
// at the top. Asks Media for cava only while it is visible.
//   Spectrum { width: 96; height: 20; bars: 24 }
Item {
    id: root

    property int bars: 24
    property int gap: 1
    readonly property int barWidth: Math.max(1, Math.floor((width + gap) / bars) - gap)
    // Unique per instance, for Media.want().
    readonly property string key: "spectrum-" + Math.random().toString(36).slice(2)

    onVisibleChanged: Media.want(key, visible)
    Component.onCompleted: Media.want(key, visible)
    Component.onDestruction: Media.want(key, false)

    // Whole-dot bars rarely fill the width exactly: centered.
    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: root.gap

        Repeater {
            model: root.bars

            Item {
                required property int index
                // Bands are spread evenly over the bars; neighbors averaged.
                readonly property real value: {
                    const src = Media.bars, n = src.length;
                    const a = Math.floor(index * n / root.bars), b = Math.max(a + 1, Math.floor((index + 1) * n / root.bars));
                    let s = 0;
                    for (let i = a; i < b; i++)
                        s += src[i] ?? 0;
                    return s / (b - a);
                }
                readonly property int lit: Math.round(value * root.height)
                readonly property int low: Math.round(root.height * 0.6)
                readonly property int mid: Math.round(root.height * 0.85)

                width: root.barWidth
                height: root.height

                Rectangle {
                    y: parent.height - height
                    width: parent.width
                    height: Math.min(parent.lit, parent.low)
                    color: Tokens.slot0
                }
                Rectangle {
                    visible: parent.lit > parent.low
                    y: parent.height - parent.low - height
                    width: parent.width
                    height: Math.min(parent.lit, parent.mid) - parent.low
                    color: Tokens.slot1
                }
                Rectangle {
                    visible: parent.lit > parent.mid
                    y: parent.height - parent.lit
                    width: parent.width
                    height: parent.lit - parent.mid
                    color: Tokens.slot2
                }
            }
        }
    }
}
