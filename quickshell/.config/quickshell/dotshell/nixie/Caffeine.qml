import QtQuick
import qs
import qs.tokyo as T

// Caffeine, Nixie: a toggle switch on a steel plate in the walnut case (up
// keeps the screen awake; a click flips it), STAY AWAKE · ENGAGED or SAFE
// in brass, the minutes left on two tubes (cold when off) and a line in
// orange under them. Expanded, TIMERS: the case's dot screen with STAYING
// AWAKE big, the timers as brass keys (the picked one polished), what else
// is holding the screen, and the idle steps on cards.
T.Face {
    id: root

    readonly property bool on: !!ctx.on
    readonly property string remaining: ctx.left ?? ""
    // "42:10" or "1H 2:05" -> hours and minutes.
    readonly property var hm: {
        const m = /^(?:(\d+)H )?(\d+):\d+$/.exec(remaining);
        return m ? [Number(m[1] ?? 0), Number(m[2])] : null;
    }
    readonly property int mins: hm ? hm[0] * 60 + hm[1] : 0
    readonly property string leftWords: hm ? (hm[0] ? hm[0] + " H " : "") + hm[1] + " MIN LEFT" : on ? "UNTIL TURNED OFF" : "IDLES AS USUAL"
    readonly property var steps: [["DIM", "5 MIN"], ["LOCK", "7:30"], ["SCREEN OFF", "7:45"]]

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : panel
    }

    // ── Compact: the switch ─────────────────────────────────────────
    Component {
        id: panel
        Item {
            id: c
            readonly property real leverH: height - 30
            readonly property real tubeH: Math.max(24, Math.min(leverH * 0.58, (width - leverH * 0.62 - 60) * 0.85))

            Wood {
                anchors.fill: parent
            }
            Lever {
                id: lever
                x: 14
                y: 15
                width: Math.round(c.leverH * 0.62)
                height: c.leverH
                on: root.on
                action: "caffeine toggle"
            }
            Column {
                x: lever.x + lever.width + 14
                anchors.verticalCenter: lever.verticalCenter
                width: c.width - x - 14
                spacing: 6
                Print {
                    width: parent.width
                    text: root.on ? "STAY AWAKE · ENGAGED" : "STAY AWAKE · SAFE"
                    size: 7
                }
                Tubes {
                    height: c.tubeH
                    tubeW: c.tubeH * 0.58
                    gap: 2
                    text: !root.on ? "00" : !root.hm ? "--" : root.mins <= 99 ? String(root.mins).padStart(2, "0") : String(root.hm[0]).padStart(2, "0")
                    lit: root.on
                }
                Pen {
                    width: parent.width
                    text: !root.on ? "switch up to stay awake" : !root.hm ? "until switched off" : root.mins <= 99 ? "minutes remaining" : "hours remaining"
                    size: 12
                }
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
            readonly property real padX: 24
            readonly property real titleY: 22
            readonly property real titleH: Math.max(9 * p, Math.min(54, height * 0.14))
            readonly property real keyY: titleY + titleH + 12
            readonly property real stepH: Math.max(16 * p, Math.min(54, height * 0.16))
            readonly property real stepY: height - 24 - stepH
            readonly property real stepW: (width - padX * 2 - 20) / 3
            function dx(px: real): int {
                return Math.round((px - box.sx - box.screen.surface.x) / p);
            }
            function dy(px: real): int {
                return Math.round((px - box.sy - box.screen.surface.y) / p);
            }
            readonly property int x0: dx(padX)
            readonly property int w0: dx(width - padX) - x0

            Case {
                id: box
                anchors.fill: parent

                // STAYING AWAKE                        42 MIN LEFT
                Word {
                    id: title
                    x: b.x0
                    y: b.dy(b.titleY)
                    width: Math.min(implicitWidth, b.w0)
                    height: Math.floor(b.titleH / b.p)
                    dots: height
                    text: root.on ? "STAYING AWAKE" : "IDLE AS USUAL"
                    spacing: 1
                }
                MatrixText {
                    visible: title.implicitWidth + implicitWidth + 6 <= b.w0
                    x: b.x0 + b.w0 - width
                    y: title.y + title.height - 6
                    width: implicitWidth
                    height: 5
                    font: "3x5"
                    text: root.leftWords
                    color: Ink.brass
                }
                MatrixText {
                    id: also
                    x: b.x0
                    y: b.dy(b.keyY + 22) + 4
                    height: 5
                    font: "3x5"
                    text: "ALSO HOLDING THE SCREEN"
                    color: Ink.brass
                }
                Column {
                    id: holders
                    x: b.x0
                    y: also.y + 9
                    width: b.w0
                    spacing: 3
                    Repeater {
                        model: (root.ctx.holders ?? []).slice(0, Math.max(0, Math.floor((b.dy(b.stepY) - 10 - holders.y) / 10)))
                        Item {
                            required property var modelData
                            width: holders.width
                            height: 7
                            MatrixText {
                                width: parent.width - why.implicitWidth - 6
                                height: 7
                                text: modelData.who
                                color: Ink.orange
                            }
                            MatrixText {
                                id: why
                                anchors.right: parent.right
                                width: implicitWidth
                                height: 7
                                text: modelData.why
                                color: Ink.amber
                            }
                        }
                    }
                    MatrixText {
                        visible: !(root.ctx.holders ?? []).length
                        height: 5
                        font: "3x5"
                        text: "NOTHING ELSE"
                        color: Ink.deep
                    }
                }
                MatrixText {
                    x: b.x0
                    y: b.dy(b.stepY) - 8
                    height: 5
                    font: "3x5"
                    text: "IDLE TIMINGS"
                    color: Ink.brass
                }
                Repeater {
                    model: root.steps
                    Item {
                        id: sv
                        required property var modelData
                        required property int index
                        readonly property real px: b.padX + index * (b.stepW + 10)
                        x: b.dx(px) + 3
                        y: b.dy(b.stepY) + 2
                        width: b.dx(px + b.stepW) - x - 2
                        height: b.dy(b.stepY + b.stepH) - y - 1
                        MatrixText {
                            width: parent.width
                            height: 5
                            font: "3x5"
                            text: sv.modelData[0]
                            color: Ink.brass
                        }
                        MatrixText {
                            y: parent.height - 8
                            width: parent.width
                            height: 7
                            text: sv.modelData[1]
                            color: Ink.orange
                        }
                    }
                }
            }
            Row {
                x: b.padX
                y: b.keyY
                spacing: 8
                Repeater {
                    model: b.timers
                    Key {
                        required property var modelData
                        width: (b.width - b.padX * 2 - 32) / 5
                        height: 22
                        text: modelData[0]
                        on: modelData[2]
                        action: modelData[1]
                    }
                }
            }
            Repeater {
                model: root.steps
                Card {
                    required property int index
                    x: b.padX + index * (b.stepW + 10)
                    y: b.stepY
                    width: b.stepW
                    height: b.stepH
                }
            }
        }
    }
}
