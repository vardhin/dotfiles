import QtQuick
import QtQuick.Effects
import qs
import qs.tokyo as T

// Caffeine, Frutiger Aero: a glossy mug on the sky (coffee in it and a
// wisp of steam while it keeps the screen awake), "Stay awake: On" and a
// green slide switch, and the time left. A click anywhere toggles it.
// Expanded, the timers as glossy keys, who else holds the screen, and the
// idle steps on white cards, the words in bubble dots.
T.Face {
    id: root

    readonly property bool on: !!ctx.on
    readonly property string remaining: ctx.left ?? ""
    // "42:10" or "1H 2:05" -> hours and minutes.
    readonly property var hm: {
        const m = /^(?:(\d+)H )?(\d+):\d+$/.exec(remaining);
        return m ? [Number(m[1] ?? 0), Number(m[2])] : null;
    }
    readonly property string leftWords: hm ? (hm[0] ? hm[0] + " h " : "") + hm[1] + " min left" : on ? "Until turned off" : "Screen idles as usual"

    Sky {
        anchors.fill: parent
        radius: root.big ? 28 : Math.min(26, height * 0.22)
        gloss: false
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : mug
    }

    // ── Compact: the mug and the switch ─────────────────────────────
    Component {
        id: mug
        Item {
            id: c
            readonly property real s: Math.min(1.3, height / 100)

            T.Hit {
                anchors.fill: parent
                action: "caffeine toggle"
            }

            Item {
                id: cup
                x: 18
                anchors.verticalCenter: parent.verticalCenter
                width: 56 * c.s
                height: 62 * c.s
                // The handle.
                Rectangle {
                    x: 38 * c.s
                    y: parent.height - 32 * c.s
                    width: 16 * c.s
                    height: 18 * c.s
                    radius: 9 * c.s
                    color: "transparent"
                    border.width: 4 * c.s
                    border.color: Ink.pale
                }
                Rectangle {
                    x: 4 * c.s
                    y: parent.height - height
                    width: 40 * c.s
                    height: 46 * c.s
                    topLeftRadius: 6 * c.s
                    topRightRadius: 6 * c.s
                    bottomLeftRadius: 16 * c.s
                    bottomRightRadius: 16 * c.s
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0
                            color: "white"
                        }
                        GradientStop {
                            position: 0.5
                            color: Ink.pale
                        }
                        GradientStop {
                            position: 1
                            color: Ink.plate2
                        }
                    }
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: Ink.shadow
                        shadowBlur: 0.2
                        blurMax: 8
                        shadowVerticalOffset: 2
                        shadowHorizontalOffset: 0
                    }
                }
                // The coffee, or the empty mug's rim.
                Rectangle {
                    x: 8 * c.s
                    y: parent.height - 42 * c.s
                    width: 32 * c.s
                    height: 8 * c.s
                    radius: height / 2
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: root.on ? "#8a5a2e" : Ink.ice
                        }
                        GradientStop {
                            position: 1
                            color: root.on ? "#3a2010" : Ink.pale
                        }
                    }
                }
                // Steam.
                Rectangle {
                    id: steam
                    visible: root.on
                    x: 18 * c.s
                    width: 4 * c.s
                    height: 14 * c.s
                    radius: width / 2
                    color: Qt.rgba(1, 1, 1, 0.95)
                    SequentialAnimation on y {
                        running: root.on
                        loops: Animation.Infinite
                        NumberAnimation {
                            from: 6 * c.s
                            to: -2 * c.s
                            duration: 1600
                        }
                    }
                    SequentialAnimation on opacity {
                        running: root.on
                        loops: Animation.Infinite
                        NumberAnimation {
                            from: 0.95
                            to: 0
                            duration: 1600
                        }
                    }
                }
            }

            Item {
                id: slot
                x: cup.x + cup.width + 14
                width: parent.width - x - 14
                height: parent.height
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    scale: Math.min(1, slot.width / Math.max(1, implicitWidth))
                    transformOrigin: Item.Left
                    spacing: 6
                    Text {
                        text: "Stay awake: " + (root.on ? "On" : "Off")
                        color: Ink.navy
                        font.family: Ink.family
                        font.pixelSize: 16
                    }
                    // The switch.
                    Rectangle {
                        width: 64
                        height: 26
                        radius: 13
                        border.width: root.on ? 0 : 1
                        border.color: Ink.pale
                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: root.on ? "#b9f0a8" : Ink.ice
                            }
                            GradientStop {
                                position: 1
                                color: root.on ? Ink.green : Ink.pale
                            }
                        }
                        Rectangle {
                            y: 2
                            x: root.on ? parent.width - width - 2 : 2
                            width: 22
                            height: 22
                            radius: 11
                            gradient: Gradient {
                                GradientStop {
                                    position: 0
                                    color: "white"
                                }
                                GradientStop {
                                    position: 1
                                    color: Ink.pale
                                }
                            }
                            border.width: 1
                            border.color: Qt.rgba(11 / 255, 63 / 255, 128 / 255, 0.2)
                            Behavior on x {
                                NumberAnimation {
                                    duration: 160
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }
                    Text {
                        text: root.leftWords
                        color: Ink.blue
                        font.family: Ink.family
                        font.pixelSize: 12
                    }
                }
            }
        }
    }

    // ── Expanded: timers ────────────────────────────────────────────
    Component {
        id: board
        Item {
            id: b
            readonly property var timers: [
                ["30 M", "caffeine for 30", false],
                ["1 H", "caffeine for 60", false],
                ["2 H", "caffeine for 120", false],
                ["UNTIL OFF", "caffeine on", root.on && !root.remaining],
                ["OFF", "caffeine off", !root.on]
            ]
            readonly property var steps: [["DIM", "5 MIN"], ["LOCK", "7:30"], ["SCREEN OFF", "7:45"]]
            readonly property int p: Tokens.pitch
            readonly property int padX: 6
            readonly property int cols: Math.floor(width / p)
            readonly property int rows: Math.floor(height / p)
            readonly property int bigPx: Math.max(10, Math.min(13, Math.floor((cols - padX * 2) / 11)))
            readonly property int keyY: 4 + bigPx + 4
            readonly property int keyH: 10
            readonly property int stepH: 15
            readonly property int stepY: rows - 5 - stepH
            readonly property int cardW: Math.floor((cols - padX * 2 - 6) / 3)

            // The timers, crisp.
            Row {
                id: keys
                x: b.padX * b.p
                y: b.keyY * b.p
                spacing: 6
                Repeater {
                    model: b.timers
                    Key {
                        required property var modelData
                        width: ((b.cols - b.padX * 2) * b.p - 24) / 5
                        height: b.keyH * b.p
                        radius: height / 2
                        textPx: 12
                        text: modelData[0]
                        look: modelData[2] ? "green" : "plain"
                        action: modelData[1]
                    }
                }
            }
            Repeater {
                model: 3
                Card {
                    required property int index
                    x: (b.padX + index * (b.cardW + 3)) * b.p
                    y: b.stepY * b.p
                    width: b.cardW * b.p
                    height: b.stepH * b.p
                }
            }

            Dots {
                anchors.fill: parent

                // STAYING AWAKE                    42 min left
                Say {
                    id: title
                    x: b.padX
                    y: 3
                    width: Math.min(implicitWidth, b.cols - b.padX * 2)
                    text: root.on ? "STAYING AWAKE" : "IDLE AS USUAL"
                    size: b.bigPx
                }
                MatrixText {
                    visible: title.implicitWidth + implicitWidth + 4 <= b.cols - b.padX * 2
                    anchors.right: parent.right
                    anchors.rightMargin: b.padX
                    y: 3 + b.bigPx - 7
                    width: implicitWidth
                    height: 5
                    font: "3x5"
                    text: root.leftWords
                    color: Ink.blue
                }

                MatrixText {
                    id: also
                    x: b.padX
                    y: b.keyY + b.keyH + 4
                    height: 5
                    font: "3x5"
                    text: "ALSO KEEPING THE SCREEN ON"
                    color: Ink.blue
                }
                Column {
                    id: holders
                    x: b.padX
                    y: also.y + 8
                    width: b.cols - b.padX * 2
                    spacing: 2
                    Repeater {
                        model: (root.ctx.holders ?? []).slice(0, Math.max(0, Math.floor((b.stepY - 9 - holders.y) / 9)))
                        Item {
                            required property var modelData
                            width: holders.width
                            height: 7
                            MatrixText {
                                width: parent.width - why.implicitWidth - 6
                                height: 7
                                text: modelData.who
                                color: Ink.navy
                            }
                            MatrixText {
                                id: why
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: implicitWidth
                                height: 5
                                font: "3x5"
                                text: modelData.why
                                color: Ink.blue
                            }
                        }
                    }
                    MatrixText {
                        visible: !(root.ctx.holders ?? []).length
                        height: 5
                        font: "3x5"
                        text: "NOTHING ELSE"
                        color: Ink.navy
                        opacity: 0.4
                    }
                }

                MatrixText {
                    x: b.padX
                    y: b.stepY - 8
                    height: 5
                    font: "3x5"
                    text: "POWER PLAN"
                    color: Ink.blue
                }
                Repeater {
                    model: b.steps
                    Item {
                        required property var modelData
                        required property int index
                        x: b.padX + index * (b.cardW + 3)
                        y: b.stepY
                        width: b.cardW
                        height: b.stepH
                        MatrixText {
                            x: 3
                            y: 2
                            width: parent.width - 5
                            height: 5
                            font: "3x5"
                            scroll: true
                            text: modelData[0]
                            color: Ink.blue
                        }
                        MatrixText {
                            x: 3
                            y: 8
                            width: parent.width - 5
                            height: 7
                            text: modelData[1]
                            color: Ink.navy
                        }
                    }
                }
            }
        }
    }
}
