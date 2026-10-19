import QtQuick
import qs
import qs.tokyo as T

// Caffeine, Blueprint: FIG. 7, the idle inhibit as a circuit. Switch S1
// in the line to the idle timer, closed (the blade down across the
// terminals) while it keeps the screen awake, thrown open otherwise, and
// under it what that means and the time left, all crisp. A click anywhere
// throws the switch. Expanded, SHEET 8: the state in dots, the timers as
// drafting keys (the picked one solid), who else holds the screen, and
// the idle setpoints in frames.
T.Face {
    id: root

    readonly property bool on: !!ctx.on
    readonly property string remaining: ctx.left ?? ""
    // "42:10" or "1H 2:05" -> hours and minutes.
    readonly property var hm: {
        const m = /^(?:(\d+)H )?(\d+):\d+$/.exec(remaining);
        return m ? [Number(m[1] ?? 0), Number(m[2])] : null;
    }
    readonly property string leftWords: hm ? (hm[0] ? hm[0] + " h " : "") + hm[1] + " min left" : on ? "until turned off" : "idles as usual"

    Paper {
        anchors.fill: parent
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : circuit
    }

    // ── Compact: FIG. 7 ─────────────────────────────────────────────
    Component {
        id: circuit
        Item {
            id: c
            // The drawing: the design's 250 x 60, stretched to the width.
            readonly property real k: Math.min(1, (width - 28) / 250)
            readonly property real wy: 28 + 34 * k
            readonly property real t1: 14 + 74 * k
            readonly property real t2: 14 + 126 * k
            readonly property real r: 4
            // The blade's angle: 0 closed, about 28° thrown open.
            property real lift: root.on ? 0 : 0.48
            Behavior on lift {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutBack
                }
            }

            T.Hit {
                anchors.fill: parent
                action: "caffeine toggle"
            }

            Pen {
                x: 14
                y: 10
                width: parent.width - 28
                height: 14
                text: "FIG. 7 — IDLE INHIBIT, S1"
            }
            Stroke {
                anchors.fill: parent
                path: `M 14 ${c.wy} L ${c.t1 - c.r} ${c.wy} M ${c.t2 + c.r} ${c.wy} L ${c.width - 14} ${c.wy}`
                color: Ink.ink
                line: 1.5
            }
            Repeater {
                model: [c.t1, c.t2]
                Rectangle {
                    required property real modelData
                    x: modelData - c.r
                    y: c.wy - c.r
                    width: c.r * 2
                    height: c.r * 2
                    radius: c.r
                    color: "transparent"
                    border.width: 1.5
                    border.color: Ink.ink
                }
            }
            Stroke {
                anchors.fill: parent
                readonly property real len: c.t2 - c.t1 - c.r * 2
                path: `M ${c.t1 + c.r} ${c.wy} L ${(c.t1 + c.r + Math.cos(c.lift) * len).toFixed(1)} ${(c.wy - Math.sin(c.lift) * len).toFixed(1)}`
                color: Ink.white
                line: 2
            }
            Pen {
                x: 14 + 100 * c.k - 60
                y: c.wy + 10
                width: 120
                height: 12
                horizontalAlignment: Text.AlignHCenter
                text: root.on ? "S1 · CLOSED" : "S1 · OPEN"
                size: 9
            }
            Pen {
                x: 14 + 190 * c.k - 60
                y: c.wy - 20
                width: 120
                height: 12
                horizontalAlignment: Text.AlignHCenter
                text: "→ IDLE TIMER"
                size: 9
            }
            Pen {
                x: 14
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                width: parent.width - 28
                height: 14
                text: root.on ? "CLOSED: IDLE TIMER BYPASSED" + (root.hm ? " · " + root.leftWords.toUpperCase().replace(" LEFT", "") : "") : "OPEN: IDLE TIMER IN CIRCUIT"
                size: 11
                color: Ink.ink
            }
        }
    }

    // ── Expanded: SHEET 8 ───────────────────────────────────────────
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
            readonly property int cols: Math.floor(width / p)
            readonly property int rows: Math.floor(height / p)
            readonly property int padX: Math.ceil(16 / p)
            readonly property int topY: Math.ceil(30 / p)
            readonly property int bigPx: Math.max(10, Math.min(13, Math.floor((cols - padX * 2) / 11)))
            readonly property int keyY: topY + bigPx + 3
            readonly property int keyH: 8
            readonly property int stepH: 15
            readonly property int stepY: rows - 5 - stepH
            readonly property int cardW: Math.floor((cols - padX * 2 - 6) / 3)

            Sheet {
                title: "SHEET 8 — IDLE CIRCUIT"
            }
            // The timers and the setpoints' frames, crisp.
            Row {
                x: b.padX * b.p
                y: b.keyY * b.p
                spacing: 4
                Repeater {
                    model: b.timers
                    Key {
                        required property var modelData
                        width: ((b.cols - b.padX * 2) * b.p - 16) / 5
                        height: b.keyH * b.p
                        text: modelData[0]
                        on: modelData[2]
                        action: modelData[1]
                    }
                }
            }
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    x: (b.padX + index * (b.cardW + 3)) * b.p
                    y: b.stepY * b.p
                    width: b.cardW * b.p
                    height: b.stepH * b.p
                    color: "transparent"
                    border.width: 1
                    border.color: Ink.line
                }
            }

            Dots {
                anchors.fill: parent

                // STAYING AWAKE                    42 min left
                Say {
                    id: title
                    x: b.padX
                    y: b.topY
                    width: Math.min(implicitWidth, b.cols - b.padX * 2)
                    text: root.on ? "STAYING AWAKE" : "IDLE AS USUAL"
                    size: b.bigPx
                }
                MatrixText {
                    visible: title.implicitWidth + implicitWidth + 4 <= b.cols - b.padX * 2
                    anchors.right: parent.right
                    anchors.rightMargin: b.padX
                    y: b.topY + b.bigPx - 8
                    width: implicitWidth
                    height: 5
                    font: "3x5"
                    text: root.leftWords
                    color: Ink.line
                }

                MatrixText {
                    id: also
                    x: b.padX
                    y: b.keyY + b.keyH + 4
                    height: 5
                    font: "3x5"
                    text: "PARALLEL HOLDS"
                    color: Ink.line
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
                                color: Ink.ink
                            }
                            MatrixText {
                                id: why
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: implicitWidth
                                height: 5
                                font: "3x5"
                                text: modelData.why
                                color: Ink.ink
                                opacity: 0.7
                            }
                        }
                    }
                    MatrixText {
                        visible: !(root.ctx.holders ?? []).length
                        height: 5
                        font: "3x5"
                        text: "NOTHING ELSE"
                        color: Ink.line
                        opacity: 0.6
                    }
                }

                MatrixText {
                    x: b.padX
                    y: b.stepY - 8
                    height: 5
                    font: "3x5"
                    text: "TIMER SETPOINTS"
                    color: Ink.line
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
                            color: Ink.line
                        }
                        MatrixText {
                            x: 3
                            y: 8
                            width: parent.width - 5
                            height: 7
                            text: modelData[1]
                            color: Ink.white
                        }
                    }
                }
            }
        }
    }
}
