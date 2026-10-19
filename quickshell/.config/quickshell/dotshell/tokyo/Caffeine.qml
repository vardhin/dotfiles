import QtQuick
import qs

// Caffeine, Tokyo Night: a neon coffee cup, steaming while the screen is
// held awake; asleep, the whole sign drops to a dark violet tube. A click
// toggles. Expanded, timers, who else holds the screen, the idle steps.
Face {
    id: root

    readonly property bool on: !!ctx.on
    readonly property string remaining: ctx.left ?? ""
    // "42:10" or "1H 2:05" → "42 MIN LEFT".
    readonly property string leftWords: {
        const m = /^(?:(\d+)H )?(\d+):\d+$/.exec(remaining);
        if (!m)
            return on ? "UNTIL TURNED OFF" : "NORMAL IDLE";
        const h = Number(m[1] ?? 0), mm = Number(m[2]);
        return (h ? h + " H " : "") + mm + " MIN LEFT";
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : sign
    }

    // The cup on its saucer, two wisps of steam over it.
    component Cup: Item {
        id: cup
        property bool lit: true
        readonly property color ink: lit ? Ink.cyan : Ink.deep
        readonly property real k: height / 76
        readonly property real line: Math.max(2, Math.round(3 * k))
        // Body: open at the top, round at the bottom.
        Item {
            x: 8 * cup.k
            y: cup.height - 48 * cup.k
            width: 40 * cup.k
            height: 40 * cup.k
            clip: true
            Tube {
                y: -height * 0.5
                width: parent.width
                height: parent.height * 1.5
                radius: 14 * cup.k
                line: cup.line
                tint: cup.ink
                glow: cup.lit ? 0.7 : 0
            }
        }
        // Handle.
        Item {
            x: 46 * cup.k
            y: cup.height - 38 * cup.k
            width: 14 * cup.k
            height: 18 * cup.k
            clip: true
            Tube {
                x: -width / 2
                width: parent.width * 2
                height: parent.height
                radius: 10 * cup.k
                line: cup.line
                tint: cup.ink
                glow: cup.lit ? 0.7 : 0
            }
        }
        // Saucer.
        Tube {
            y: cup.height - cup.line
            width: 60 * cup.k
            height: cup.line
            radius: 1
            line: 0
            fill: cup.ink
            tint: cup.ink
            glow: cup.lit ? 0.7 : 0
        }
        // Steam, rising.
        Repeater {
            model: cup.lit ? [[16, 2, 18], [30, 0, 22]] : []
            Tube {
                id: wisp
                required property var modelData
                required property int index
                x: modelData[0] * cup.k
                y: modelData[1] * cup.k
                width: cup.line
                height: modelData[2] * cup.k
                radius: width / 2
                line: 0
                fill: Ink.pink
                tint: Ink.pink
                glow: 0.7
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: wisp.visible
                    PauseAnimation {
                        duration: wisp.index * 700
                    }
                    NumberAnimation {
                        from: 1
                        to: 0.25
                        duration: 1400
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        from: 0.25
                        to: 1
                        duration: 1400
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }
    }

    // ── Compact ─────────────────────────────────────────────────────
    Component {
        id: sign
        Item {
            id: s
            readonly property real cupH: Math.round(height * 0.63)
            readonly property real padX: Math.round(height * 0.15)
            readonly property real textX: padX + cupH * 64 / 76 + Math.round(height * 0.12)

            Glass {
                id: glass
                radius: 24
                Column {
                    x: root.d(s.textX)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Neon {
                        text: root.on ? "AWAKE" : "SLEEPY"
                        size: Math.round(glass.rows * 0.3)
                        height: Math.round(size * 0.9)
                        color: root.on ? Ink.cyan : Ink.pink
                        opacity: root.on ? 1 : 0.55
                        halo: root.on
                    }
                    Words {
                        small: true
                        text: root.on ? "眠らない · NO SLEEP" : "眠り · IDLE OK"
                        color: root.on ? Ink.pink : Ink.violet
                        opacity: root.on ? 1 : 0.6
                    }
                    Words {
                        small: true
                        text: root.leftWords
                        color: Ink.violet
                        opacity: root.on ? 1 : 0.6
                    }
                }
            }
            Cup {
                x: s.padX
                y: (s.height - height) / 2
                width: height * 64 / 76
                height: s.cupH
                lit: root.on
            }
            // The cup and its words toggle; the rim still expands.
            Hit {
                anchors.fill: parent
                anchors.margins: Math.round(s.padX * 0.7)
                action: "caffeine toggle"
            }
            Sign {
                radius: 24
                tone: root.on ? "pink" : "dim"
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

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: 28
                color: Ink.glass
            }
            Item {
                anchors.fill: parent
                anchors.margins: 12

                Glass {
                    id: glass
                    radius: 18
                    Item {
                        id: page
                        x: 5
                        y: 5
                        width: glass.cols - 10
                        height: glass.rows - 10
                        readonly property int chipY: head.height + 3
                        readonly property int chipH: 9
                        readonly property int stepH: 15

                        Neon {
                            id: head
                            width: page.width * 0.62
                            text: root.on ? "STAYING AWAKE" : "IDLE AS USUAL"
                            size: Math.round(Math.min(page.height * 0.13, 15))
                            height: Math.round(size * 0.95)
                            color: root.on ? Ink.cyan : Ink.pink
                            halo: root.on
                        }
                        MatrixText {
                            anchors.right: parent.right
                            y: Math.round((head.height - 5) / 2)
                            height: 5
                            font: "3x5"
                            text: root.on ? root.leftWords : "IDLE STEPS RUN"
                            color: Ink.violet
                        }

                        MatrixText {
                            id: holdWord
                            y: page.chipY + page.chipH + 4
                            height: 5
                            font: "3x5"
                            text: "ALSO HOLDING THE SCREEN"
                            color: Ink.violet
                        }
                        Column {
                            id: holders
                            y: holdWord.y + 8
                            width: page.width
                            spacing: 2
                            Repeater {
                                model: (root.ctx.holders ?? []).slice(0, Math.max(0, Math.floor((page.height - holders.y - page.stepH - 10) / 7)))
                                Item {
                                    required property var modelData
                                    width: holders.width
                                    height: 5
                                    MatrixText {
                                        width: parent.width * 0.55
                                        height: 5
                                        font: "3x5"
                                        text: modelData.who
                                        color: Ink.pink
                                    }
                                    MatrixText {
                                        anchors.right: parent.right
                                        width: parent.width * 0.42
                                        height: 5
                                        font: "3x5"
                                        align: "right"
                                        text: modelData.why
                                        color: Ink.pink
                                        opacity: 0.7
                                    }
                                }
                            }
                            MatrixText {
                                visible: (root.ctx.holders ?? []).length === 0
                                height: 5
                                font: "3x5"
                                text: "NOTHING ELSE"
                                color: Ink.deep
                            }
                        }

                        MatrixText {
                            id: stepWord
                            y: page.height - page.stepH - 8
                            height: 5
                            font: "3x5"
                            text: "IDLE TIMINGS"
                            color: Ink.violet
                        }
                        Row {
                            id: stepRow
                            y: page.height - page.stepH
                            spacing: 3
                            readonly property int cardW: Math.floor((page.width - 6) / 3)
                            Repeater {
                                model: b.steps
                                Item {
                                    required property var modelData
                                    width: stepRow.cardW
                                    height: page.stepH
                                    MatrixText {
                                        x: 3
                                        y: 2
                                        height: 5
                                        font: "3x5"
                                        text: modelData[0]
                                        color: Ink.violet
                                    }
                                    Words {
                                        x: 3
                                        y: 8
                                        room: parent.width - 5
                                        width: parent.width - 5
                                        text: modelData[1]
                                        color: Ink.cyan
                                        opacity: root.on ? 0.45 : 1
                                    }
                                }
                            }
                        }
                    }
                }

                // Crisp: the timer buttons and the step cards' rims.
                Row {
                    id: timerRow
                    x: glass.x + page.x * root.pitch
                    y: glass.y + (page.y + page.chipY) * root.pitch
                    spacing: 5
                    readonly property real w: page.width * root.pitch
                    Repeater {
                        model: b.timers
                        Chip {
                            required property var modelData
                            width: (timerRow.w - 20) / 5
                            height: page.chipH * root.pitch
                            size: 11
                            text: modelData[0]
                            tone: modelData[2] ? "on" : "pink"
                            action: modelData[1]
                        }
                    }
                }
                Repeater {
                    model: 3
                    Tube {
                        required property int index
                        x: glass.x + (page.x + index * (stepRow.cardW + 3)) * root.pitch
                        y: glass.y + (page.y + stepRow.y) * root.pitch
                        width: stepRow.cardW * root.pitch
                        height: page.stepH * root.pitch
                        radius: 10
                        line: 1.5
                        tint: Ink.deep
                        glow: 0
                    }
                }
            }
            Sign {
                radius: 28
                inner: true
                innerInset: 12
                tone: root.on ? "pink" : "dim"
            }
        }
    }
}
