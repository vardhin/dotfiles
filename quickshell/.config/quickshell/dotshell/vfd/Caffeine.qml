import QtQuick
import qs
import qs.tokyo as T

// Caffeine, VFD: the coffee maker's timer. BREW KEEP WARM AUTO OFF over
// the time left in big amber dots (dark 88:88 when it is off), what it is
// doing under that; beside the display ON/OFF and +30 MIN keys. Expanded,
// the timers as keys, who else holds the screen, and the idle steps in
// ruled cards.
T.Face {
    id: root

    readonly property bool on: !!ctx.on
    readonly property string remaining: ctx.left ?? ""
    // "42:10" or "1H 2:05" -> hours and minutes.
    readonly property var hm: {
        const m = /^(?:(\d+)H )?(\d+):\d+$/.exec(remaining);
        return m ? [Number(m[1] ?? 0), Number(m[2])] : null;
    }
    readonly property string clock: !on ? "" : hm ? hm[0] + ":" + String(hm[1]).padStart(2, "0") : "ON"
    readonly property string leftWords: hm ? (hm[0] ? hm[0] + " H " : "") + hm[1] + " MIN LEFT" : on ? "UNTIL TURNED OFF" : "NORMAL IDLE"

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : maker
    }

    // ── Compact: the timer ──────────────────────────────────────────
    Component {
        id: maker
        Unit {
            id: u
            side: Math.round(Math.min(110, root.width * 0.3))
            readonly property int padX: 4
            readonly property int size: Math.max(1, Math.min(3, Math.floor((rows - 18) / 7), Math.floor((cols - padX * 2) / 30)))

            // BREW  KEEP WARM  AUTO OFF
            Row {
                x: u.padX
                y: 3
                spacing: 5
                Repeater {
                    model: u.cols >= 80 ? [["BREW", false, Ink.cyan], ["KEEP WARM", root.on, Ink.amber], ["AUTO OFF", root.on && !!root.hm, Ink.cyan]] : [["WARM", root.on, Ink.amber], ["AUTO", root.on && !!root.hm, Ink.cyan]]
                    MatrixText {
                        required property var modelData
                        height: 5
                        font: "3x5"
                        text: modelData[0]
                        color: modelData[1] ? modelData[2] : Ink.ghost
                    }
                }
            }
            Digits {
                x: u.padX
                y: 10 + Math.max(0, Math.floor((u.rows - 20 - height) / 2))
                width: implicitWidth
                height: implicitHeight
                size: u.size
                cells: 4
                mask: root.on ? "" : "8:88"
                text: root.clock
                color: Ink.amber
            }
            MatrixText {
                x: u.padX
                y: u.rows - 8
                width: u.cols - u.padX * 2
                height: 5
                font: "3x5"
                scroll: true
                text: root.on ? "KEEPS SCREEN AWAKE · " + root.leftWords : "OFF · SCREEN IDLES AS USUAL"
                color: Ink.teal
            }

            rack: Column {
                anchors.fill: parent
                spacing: 6
                Key {
                    width: parent.width
                    height: (parent.height - parent.spacing) / 2
                    size: 9
                    text: "• ON/OFF"
                    ink: root.on ? Ink.amber : "transparent"
                    action: "caffeine toggle"
                }
                Key {
                    width: parent.width
                    height: (parent.height - parent.spacing) / 2
                    size: 9
                    text: "+ 30 MIN"
                    action: "caffeine for " + ((root.hm ? root.hm[0] * 60 + root.hm[1] : 0) + 30)
                }
            }
        }
    }

    // ── Expanded: timers ────────────────────────────────────────────
    Component {
        id: board
        Unit {
            id: u
            readonly property var timers: [
                ["30 M", "caffeine for 30", false],
                ["1 H", "caffeine for 60", false],
                ["2 H", "caffeine for 120", false],
                ["UNTIL OFF", "caffeine on", root.on && !root.remaining],
                ["OFF", "caffeine off", !root.on]
            ]
            readonly property var steps: [["DIM", "5 MIN"], ["LOCK", "7:30"], ["SCREEN OFF", "7:45"]]
            readonly property int padX: 4
            readonly property int keyY: 4 + title.height + 5
            readonly property int keyH: 10
            readonly property int stepH: rows >= 90 ? 18 : 15
            readonly property int stepY: rows - 4 - stepH
            readonly property int cardW: Math.floor((cols - padX * 2 - 6) / 3)

            // STAYING AWAKE                         42 MIN LEFT
            Digits {
                id: title
                x: u.padX
                y: 4
                width: implicitWidth
                height: implicitHeight
                size: text.length * 12 + 4 + leftText.implicitWidth <= u.cols - u.padX * 2 ? 2 : 1
                ghosts: false
                text: root.on ? "STAYING AWAKE" : "IDLE AS USUAL"
                color: root.on ? Ink.amber : Ink.teal
            }
            MatrixText {
                id: leftText
                visible: title.width + implicitWidth + 4 <= u.cols - u.padX * 2
                anchors.right: parent.right
                anchors.rightMargin: u.padX
                y: title.y + title.height - 5
                width: implicitWidth
                height: 5
                font: "3x5"
                text: root.leftWords
                color: Ink.teal
            }

            MatrixText {
                id: also
                x: u.padX
                y: u.keyY + u.keyH + 4
                height: 5
                font: "3x5"
                text: "ALSO HOLDING THE SCREEN"
                color: Ink.teal
            }
            Column {
                id: holders
                x: u.padX
                y: also.y + 8
                width: u.cols - u.padX * 2
                spacing: 3
                Repeater {
                    model: (root.ctx.holders ?? []).slice(0, Math.max(0, Math.floor((u.stepY - 9 - holders.y) / 8)))
                    Item {
                        required property var modelData
                        width: holders.width
                        height: 5
                        MatrixText {
                            width: parent.width - why.implicitWidth - 6
                            height: 5
                            font: "3x5"
                            text: modelData.who
                            color: Ink.cyan
                        }
                        MatrixText {
                            id: why
                            anchors.right: parent.right
                            width: implicitWidth
                            height: 5
                            font: "3x5"
                            text: modelData.why
                            color: Ink.teal
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
                x: u.padX
                y: u.stepY - 8
                height: 5
                font: "3x5"
                text: "IDLE TIMINGS"
                color: Ink.teal
            }
            Repeater {
                model: u.steps
                Item {
                    required property var modelData
                    required property int index
                    x: u.padX + index * (u.cardW + 3)
                    y: u.stepY
                    width: u.cardW
                    height: u.stepH
                    MatrixText {
                        x: 3
                        y: 3
                        height: 5
                        font: "3x5"
                        text: modelData[0]
                        color: Ink.teal
                    }
                    MatrixText {
                        x: 3
                        y: 10
                        width: parent.width - 5
                        height: 7
                        text: modelData[1]
                        color: Ink.cyan
                    }
                }
            }

            over: [
                Row {
                    id: keys
                    readonly property real w: u.px(u.cols - u.padX * 2)
                    x: u.px(u.padX)
                    y: u.px(u.keyY)
                    spacing: 5
                    Repeater {
                        model: u.timers
                        Key {
                            required property var modelData
                            width: (keys.w - 20) / 5
                            height: u.px(u.keyH)
                            size: 9
                            text: modelData[0]
                            on: modelData[2]
                            dim: true
                            action: modelData[1]
                        }
                    }
                },
                Repeater {
                    model: 3
                    Box {
                        required property int index
                        dx: u.padX + index * (u.cardW + 3)
                        dy: u.stepY
                        dw: u.cardW
                        dh: u.stepH
                    }
                }
            ]
        }
    }
}
