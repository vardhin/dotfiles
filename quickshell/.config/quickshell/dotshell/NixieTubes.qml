import QtQuick
import QtQuick.Effects
import qs.services

// Nixie tubes beside a device's display window (Hardware.js `side`, kind
// "tubes"): four glass tubes and a colon showing where the track is, mm:ss,
// each digit a glowing cathode over the dim 8 of the ones behind it, under a
// fine anode mesh (panel design canvas, "Now playing", Nixie). Hardware, not
// dots: drawn crisply, in screen px.
Item {
    id: root

    property var ctx: Feeds.mediaFeed

    // mm:ss of the position, two digits each (99:59 at most).
    readonly property string digits: {
        const s = Math.max(0, Math.floor(ctx?.active ? ctx.pos ?? 0 : 0));
        const m = Math.min(99, Math.floor(s / 60));
        return String(m).padStart(2, "0") + String(s % 60).padStart(2, "0");
    }
    readonly property bool lit: !!ctx?.active

    readonly property int colonW: 10
    readonly property int gap: 4
    readonly property int tubeW: Math.max(8, Math.floor((width - colonW - gap * 4) / 4))
    readonly property int tubeH: Math.min(height, Math.round(tubeW * 1.9))

    Row {
        anchors.centerIn: parent
        spacing: root.gap

        Repeater {
            model: 5

            Item {
                id: slot
                required property int index
                readonly property bool colon: index === 2
                readonly property string ch: root.digits[index < 2 ? index : index - 1] ?? "0"
                width: colon ? root.colonW : root.tubeW
                height: root.tubeH

                // The colon: two neon dots.
                Column {
                    visible: slot.colon
                    anchors.centerIn: parent
                    spacing: Math.round(root.tubeH * 0.18)
                    Repeater {
                        model: 2
                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: root.lit ? "#ff7a1a" : "#3a1a0a"
                            layer.enabled: root.lit
                            layer.effect: MultiEffect {
                                shadowEnabled: true
                                shadowColor: "#ff7a1a"
                                shadowBlur: 0.5
                                shadowHorizontalOffset: 0
                                shadowVerticalOffset: 0
                            }
                        }
                    }
                }

                // The tube: a glass envelope, round on top.
                Rectangle {
                    id: tube
                    visible: !slot.colon
                    anchors.fill: parent
                    topLeftRadius: width / 2
                    topRightRadius: width / 2
                    bottomLeftRadius: 4
                    bottomRightRadius: 4
                    border.width: 1
                    border.color: Qt.rgba(1, 0.78, 0.59, 0.3)
                    clip: true
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0
                            color: Qt.rgba(1, 0.67, 0.43, 0.14)
                        }
                        GradientStop {
                            position: 0.45
                            color: Qt.rgba(1, 0.67, 0.43, 0.03)
                        }
                        GradientStop {
                            position: 1
                            color: Qt.rgba(1, 0.67, 0.43, 0.1)
                        }
                    }

                    // The anode mesh, a fine diamond lattice.
                    Canvas {
                        anchors.fill: parent
                        anchors.topMargin: 8
                        anchors.bottomMargin: 8
                        anchors.leftMargin: 5
                        anchors.rightMargin: 5
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onPaint: {
                            const c = getContext("2d");
                            c.reset();
                            c.strokeStyle = Qt.rgba(1, 0.59, 0.31, 0.12);
                            c.lineWidth = 1;
                            c.beginPath();
                            const k = Math.tan(Math.PI / 6) * height;
                            for (let x = -k; x < width + k; x += 5) {
                                c.moveTo(x, 0);
                                c.lineTo(x + k, height);
                                c.moveTo(x + k, 0);
                                c.lineTo(x, height);
                            }
                            c.stroke();
                        }
                    }

                    // The other cathodes, dark behind the lit one.
                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 2
                        text: "8"
                        color: "#3a1a0a"
                        font.family: Tokens.font
                        font.pixelSize: Math.round(root.tubeH * 0.66)
                    }
                    Text {
                        visible: root.lit
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 2
                        text: slot.ch
                        color: "#ffc285"
                        font.family: Tokens.font
                        font.pixelSize: Math.round(root.tubeH * 0.66)
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: "#ff7a1a"
                            shadowBlur: 0.6
                            shadowHorizontalOffset: 0
                            shadowVerticalOffset: 0
                        }
                    }
                }
            }
        }
    }
}
