import QtQuick
import qs
import qs.tokyo as T

// Caffeine, Vaporwave: display.cpl, the screen saver dialog. "Keep the
// screen awake" as a check box (a click turns it on or off), "Wait:" and
// what it means in a white field ("Never" while it holds, the minutes
// left on a timer), and OK (the timers here). Expanded, display.cpl —
// Screen Saver: STAYING AWAKE in dots and the time left, the timers as
// push buttons (the picked one hot pink), the programs preventing standby
// and the power scheme's steps in white boxes.
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

    Win {
        id: win
        anchors.fill: parent
        icon: "☕"
        title: root.big ? "display.cpl — Screen Saver" : "display.cpl"
        controls: "help"
        big: root.big
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : dialog
    }

    // ── Compact: the dialog ─────────────────────────────────────────
    Component {
        id: dialog
        Item {
            id: c
            readonly property real topY: win.bodyY + 8

            Check {
                x: 12
                y: c.topY
                on: root.on
                text: "Keep the screen awake"
                action: "caffeine toggle"
            }
            Row {
                x: 12
                y: c.topY + 28
                height: 26
                spacing: 6
                Pen {
                    height: parent.height
                    text: "Wait:"
                    size: 17
                }
                Item {
                    width: wait.implicitWidth + 14
                    height: parent.height
                    Rectangle {
                        anchors.fill: parent
                        color: Ink.hi
                    }
                    Bevel {
                        anchors.fill: parent
                        sunk: true
                    }
                    Pen {
                        id: wait
                        anchors.centerIn: parent
                        text: !root.on ? "5 min" : root.hm ? (root.hm[0] ? root.hm[0] + " h " : "") + root.hm[1] + " min" : "Never"
                        size: 17
                    }
                    T.Hit {
                        anchors.fill: parent
                        action: "panel expand"
                    }
                }
                Pen {
                    visible: root.on
                    height: parent.height
                    text: "(" + (root.hm ? "timer" : root.leftWords) + ")"
                    size: 17
                    color: Ink.label
                }
            }
            Key {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                width: 60
                height: 24
                text: "OK"
                action: "panel expand"
            }
        }
    }

    // ── Expanded: Screen Saver ──────────────────────────────────────
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
            readonly property real wellY: win.bodyY + 8
            readonly property real wellH: height - wellY - 10
            readonly property real padX: 22
            readonly property real keyY: wellY + 44
            readonly property real stepH: 58
            readonly property real stepY: wellY + wellH - 10 - stepH
            readonly property real stepW: (width - padX * 2 - 16) / 3
            // In dots.
            readonly property int x0: Math.ceil(padX / p)
            readonly property int w0: Math.floor((width - padX * 2) / p)

            Well {
                x: 10
                y: b.wellY
                width: parent.width - 20
                height: b.wellH
            }
            Row {
                x: b.padX
                y: b.keyY
                spacing: 4
                Repeater {
                    model: b.timers
                    Key {
                        required property var modelData
                        width: (b.width - b.padX * 2 - 16) / 5
                        height: 22
                        text: modelData[0]
                        on: modelData[2]
                        action: modelData[1]
                    }
                }
            }
            Repeater {
                model: 3
                Item {
                    required property int index
                    x: b.padX + index * (b.stepW + 8)
                    y: b.stepY
                    width: b.stepW
                    height: b.stepH
                    Rectangle {
                        anchors.fill: parent
                        color: Ink.hi
                    }
                    Bevel {
                        anchors.fill: parent
                        sunk: true
                    }
                }
            }

            Dots {
                anchors.fill: parent

                // STAYING AWAKE                        42 min left
                MatrixText {
                    id: title
                    x: b.x0
                    y: Math.ceil((b.wellY + 12) / b.p)
                    width: implicitWidth
                    height: 7
                    text: root.on ? "STAYING AWAKE" : "IDLE AS USUAL"
                    color: Ink.ink
                }
                MatrixText {
                    visible: title.implicitWidth + implicitWidth + 4 <= b.w0
                    x: b.x0 + b.w0 - width
                    y: title.y + 2
                    width: implicitWidth
                    height: 5
                    font: "3x5"
                    text: root.leftWords
                    color: Ink.label
                }
                MatrixText {
                    id: also
                    x: b.x0
                    y: Math.ceil((b.keyY + 22) / b.p) + 4
                    height: 5
                    font: "3x5"
                    text: "Programs preventing standby:"
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
                                color: Ink.label
                            }
                        }
                    }
                    MatrixText {
                        visible: !(root.ctx.holders ?? []).length
                        height: 5
                        font: "3x5"
                        text: "nothing else"
                        color: Ink.label
                        opacity: 0.6
                    }
                }
                MatrixText {
                    x: b.x0
                    y: Math.floor(b.stepY / b.p) - 8
                    height: 5
                    font: "3x5"
                    text: "Power schemes:"
                    color: Ink.label
                }
                Repeater {
                    model: b.steps
                    Item {
                        required property var modelData
                        required property int index
                        x: Math.ceil((b.padX + index * (b.stepW + 8)) / b.p) + 2
                        y: Math.ceil(b.stepY / b.p) + 2
                        width: Math.floor(b.stepW / b.p) - 4
                        height: Math.floor(b.stepH / b.p) - 4
                        MatrixText {
                            width: parent.width
                            height: 5
                            font: "3x5"
                            scroll: true
                            text: modelData[0]
                            color: Ink.label
                        }
                        MatrixText {
                            y: 7
                            width: parent.width
                            height: 7
                            text: modelData[1]
                            color: Ink.ink
                        }
                    }
                }
            }
        }
    }
}
