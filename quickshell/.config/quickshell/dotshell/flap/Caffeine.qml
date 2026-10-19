import QtQuick
import qs
import qs.tokyo as T

// Caffeine, Split-Flap: the SCREEN board. AWAKE in yellow and the time
// left on flap tiles, or IDLE OK and when it dims (a click on the board's
// first row turns it on or off). Expanded, SCREEN · STAY AWAKE: STAYING
// AWAKE big in dots and the time left, the timers as keys (the picked one
// yellow), what else is holding the screen, and the idle steps in yellow
// on dot screens.
T.Face {
    id: root

    readonly property bool on: !!ctx.on
    readonly property string remaining: ctx.left ?? ""
    // "42:10" or "1H 2:05" -> hours and minutes.
    readonly property var hm: {
        const m = /^(?:(\d+)H )?(\d+):\d+$/.exec(remaining);
        return m ? [Number(m[1] ?? 0), Number(m[2])] : null;
    }
    readonly property string leftWords: hm ? (hm[0] ? hm[0] + " H " : "") + hm[1] + " MIN LEFT" : on ? "UNTIL TURNED OFF" : "IDLES AS USUAL"
    readonly property var steps: [["DIM", "5 MIN"], ["LOCK", "7:30"], ["SCREEN OFF", "7:45"]]

    Housing {
        id: box
        anchors.fill: parent
        label: root.big ? "SCREEN · STAY AWAKE" : "SCREEN"
        status: root.on ? "AWAKE" : "IDLE OK"
        statusInk: root.on ? Ink.yellow : Ink.label
        statusAction: "caffeine toggle"
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : rows
    }

    // ── Compact ─────────────────────────────────────────────────────
    Component {
        id: rows
        Item {
            Rows {
                x: 14
                y: box.bodyY + 2
                width: parent.width - 28
                height: parent.height - y - 10
                lines: root.on ? [
                    { spans: [["AWAKE", Ink.yellow]], action: "caffeine toggle" },
                    [[root.hm ? (root.hm[0] ? root.hm[0] + "H " : "") + root.hm[1] + " MIN LEFT" : "UNTIL OFF", Ink.white]]
                ] : [
                    { spans: [["IDLE OK", Ink.dim]], action: "caffeine toggle" },
                    [["DIM AT " + root.steps[0][1].replace(" MIN", "M"), Ink.white]]
                ]
            }
        }
    }

    // ── Expanded: the timers ────────────────────────────────────────
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
            readonly property int p: Tokens.pitch
            readonly property real padX: 14
            readonly property real titleY: box.bodyY + 4
            readonly property real titleH: Math.max(9 * p, Math.min(48, height * 0.13))
            readonly property real keyY: titleY + titleH + 10
            readonly property real stepH: Math.max(16 * p, Math.min(54, height * 0.17))
            readonly property real stepY: height - 12 - stepH
            readonly property real stepW: (width - padX * 2 - 20) / 3
            readonly property int x0: Math.ceil(padX / p)
            readonly property int w0: Math.floor((width - padX * 2) / p)

            Row {
                x: b.padX
                y: b.keyY
                spacing: 6
                Repeater {
                    model: b.timers
                    Key {
                        required property var modelData
                        width: (b.width - b.padX * 2 - 24) / 5
                        height: 24
                        text: modelData[0]
                        on: modelData[2]
                        action: modelData[1]
                    }
                }
            }
            Repeater {
                model: root.steps
                Glass {
                    id: step
                    required property var modelData
                    required property int index
                    x: b.padX + index * (b.stepW + 10)
                    y: b.stepY
                    width: b.stepW
                    height: b.stepH
                    MatrixText {
                        x: 2
                        y: 2
                        width: step.cols - 4
                        height: 5
                        font: "3x5"
                        scroll: true
                        text: step.modelData[0]
                        color: Ink.label
                    }
                    MatrixText {
                        x: 2
                        y: step.rows - 9
                        width: step.cols - 4
                        height: 7
                        text: step.modelData[1]
                        color: Ink.yellow
                    }
                    Rectangle {
                        y: Math.floor(step.height / 2)
                        width: step.width
                        height: 1
                        color: Ink.seam
                    }
                }
            }

            Dots {
                id: ink
                anchors.fill: parent

                // STAYING AWAKE                        42 MIN LEFT
                Say {
                    id: title
                    x: b.x0
                    y: Math.round(b.titleY / b.p)
                    height: Math.floor(b.titleH / b.p)
                    verticalAlignment: Text.AlignVCenter
                    text: root.on ? "STAYING AWAKE" : "IDLE AS USUAL"
                    size: Math.floor(b.titleH / b.p * 1.2)
                    spacing: 1
                }
                MatrixText {
                    visible: title.implicitWidth + implicitWidth + 6 <= b.w0
                    x: b.x0 + b.w0 - width
                    y: title.y + Math.round((title.height - 5) / 2)
                    width: implicitWidth
                    height: 5
                    font: "3x5"
                    text: root.leftWords
                    color: Ink.label
                }
                MatrixText {
                    id: also
                    x: b.x0
                    y: Math.ceil((b.keyY + 24) / b.p) + 4
                    height: 5
                    font: "3x5"
                    text: "ALSO HOLDING THE SCREEN"
                    color: Ink.label
                }
                Column {
                    id: holders
                    x: b.x0
                    y: also.y + 8
                    width: b.w0
                    spacing: 2
                    Repeater {
                        model: (root.ctx.holders ?? []).slice(0, Math.max(0, Math.floor((Math.floor(b.stepY / b.p) - 9 - holders.y) / 9)))
                        Item {
                            required property var modelData
                            width: holders.width
                            height: 7
                            MatrixText {
                                width: parent.width - why.implicitWidth - 6
                                height: 7
                                text: modelData.who
                                color: Ink.white
                            }
                            MatrixText {
                                id: why
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: implicitWidth
                                height: 5
                                font: "3x5"
                                text: modelData.why
                                color: Ink.dim
                            }
                        }
                    }
                    MatrixText {
                        visible: !(root.ctx.holders ?? []).length
                        height: 5
                        font: "3x5"
                        text: "NOTHING ELSE"
                        color: Ink.label
                    }
                }
                MatrixText {
                    x: b.x0
                    y: Math.floor(b.stepY / b.p) - 8
                    height: 5
                    font: "3x5"
                    text: "IDLE TIMINGS"
                    color: Ink.label
                }
            }
        }
    }
}
