import QtQuick
import qs
import qs.tokyo as T

// Caffeine, 90s Nights: a rocker switch in the slanted sign (I lit and
// glowing keeps the screen awake; a click flips it), WIDE AWAKE or CHILL
// MODE in sunset dots and the time left spaced wide in electric blue.
// Expanded, TIMERS: STAYING AWAKE big, the timers as leaning keys (the
// picked one yellow), what else holds the screen in pink, and the idle
// steps on leaning cards.
T.Face {
    id: root

    readonly property bool on: !!ctx.on
    readonly property string remaining: ctx.left ?? ""
    // "42:10" or "1H 2:05" -> hours and minutes.
    readonly property var hm: {
        const m = /^(?:(\d+)H )?(\d+):\d+$/.exec(remaining);
        return m ? [Number(m[1] ?? 0), Number(m[2])] : null;
    }
    readonly property string leftWords: hm ? (hm[0] ? hm[0] + " H " : "") + hm[1] + " MIN LEFT" : on ? "UNTIL TURNED OFF" : "NORMAL IDLE"
    readonly property var steps: [["DIM", "5 MIN"], ["LOCK", "7:30"], ["SCREEN OFF", "7:45"]]

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : panel
    }

    // ── Compact: the rocker ─────────────────────────────────────────
    Component {
        id: panel
        Item {
            id: c
            readonly property int p: Tokens.pitch
            readonly property real swH: Math.round(height * 0.74)
            readonly property real swW: Math.round(swH * 0.68)
            readonly property real midY: height / 2
            readonly property real textX: rocker.x + rocker.width + 16
            readonly property real room: plate.rightAt(midY) - textX - 8
            // Two lines of the title, as big as the room allows.
            readonly property int k: Math.max(1, Math.min(Math.floor(height * 0.18 / p / 7), Math.floor(room / p / (6 * 6))))

            Plate {
                id: plate
                anchors.fill: parent
                Column {
                    x: Math.round((c.textX - plate.rim) / c.p)
                    y: Math.round((c.midY - (7 * c.k * 2 + 2) * c.p / 2 - 9 - plate.rim) / c.p)
                    spacing: 2
                    Repeater {
                        model: root.on ? ["WIDE", "AWAKE"] : ["CHILL", "MODE"]
                        Word {
                            required property string modelData
                            width: implicitWidth
                            height: 7 * c.k
                            dots: 7 * c.k
                            fontAt: 99
                            text: modelData
                            stops: Ink.sunset
                        }
                    }
                }
            }
            Rocker {
                id: rocker
                x: plate.leftAt(y) + 12
                y: Math.round(c.midY - c.swH / 2)
                width: c.swW
                height: c.swH
                on: root.on
                action: "caffeine toggle"
            }
            Pen {
                x: c.textX
                y: Math.round(c.midY + 7 * c.k * c.p + 2)
                width: c.room
                height: 14
                text: root.leftWords
                size: 10
                spacing: 2
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
            readonly property real padX: 16
            readonly property real titleY: 16
            readonly property real titleH: Math.max(9 * p, Math.min(44, height * 0.12))
            readonly property real keyY: titleY + titleH + 12
            readonly property real stepH: Math.max(16 * p, Math.min(50, height * 0.15))
            readonly property real stepY: height - 18 - stepH
            readonly property real stepW: (width - padX * 2 - 16) / 3
            function dx(px: real): int {
                return Math.round((px - plate.surface.x) / p);
            }
            function dy(px: real): int {
                return Math.round((px - plate.surface.y) / p);
            }
            readonly property int x0: dx(padX)
            readonly property int w0: dx(width - padX) - x0

            Plate {
                id: plate
                anchors.fill: parent
                slant: false

                // STAYING AWAKE                   42 min left
                Word {
                    id: title
                    x: b.x0
                    y: b.dy(b.titleY)
                    width: Math.min(implicitWidth, b.w0)
                    height: Math.floor(b.titleH / b.p)
                    dots: height
                    text: root.on ? "STAYING AWAKE" : "CHILL MODE"
                    stops: Ink.sunset
                }
                MatrixText {
                    visible: title.width + implicitWidth + 6 <= b.w0
                    x: b.x0 + b.w0 - width
                    y: title.y + title.height - 6
                    width: implicitWidth
                    height: 5
                    font: "3x5"
                    text: root.leftWords
                    color: Ink.blue
                }
                MatrixText {
                    id: also
                    x: b.x0
                    y: b.dy(b.keyY + 22) + 4
                    height: 5
                    font: "3x5"
                    text: "ALSO HOLDING THE SCREEN"
                    color: Ink.blue
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
                                color: Ink.pink
                            }
                            MatrixText {
                                id: why
                                anchors.right: parent.right
                                width: implicitWidth
                                height: 7
                                text: modelData.why
                                color: Ink.pink
                                opacity: 0.7
                            }
                        }
                    }
                    MatrixText {
                        visible: !(root.ctx.holders ?? []).length
                        height: 5
                        font: "3x5"
                        text: "NOTHING ELSE"
                        color: Ink.dim
                    }
                }
                MatrixText {
                    x: b.x0
                    y: b.dy(b.stepY) - 8
                    height: 5
                    font: "3x5"
                    text: "IDLE TIMINGS"
                    color: Ink.blue
                }
                Repeater {
                    model: root.steps
                    Item {
                        id: sv
                        required property var modelData
                        required property int index
                        readonly property real px: b.padX + index * (b.stepW + 8)
                        x: b.dx(px) + 3
                        y: b.dy(b.stepY) + 2
                        width: b.dx(px + b.stepW) - x - 2
                        height: b.dy(b.stepY + b.stepH) - y - 1
                        MatrixText {
                            width: parent.width
                            height: 5
                            font: "3x5"
                            scroll: true
                            text: sv.modelData[0]
                            color: Ink.blue
                        }
                        MatrixText {
                            y: parent.height - 8
                            width: parent.width
                            height: 7
                            text: sv.modelData[1]
                            color: Ink.yellow
                        }
                    }
                }
            }
            Row {
                x: b.padX + 2
                y: b.keyY
                spacing: 6
                Repeater {
                    model: b.timers
                    Key {
                        required property var modelData
                        width: (b.width - b.padX * 2 - 4 - 24) / 5
                        height: 22
                        textPx: width < 70 ? 8 : 10
                        text: modelData[0]
                        on: modelData[2]
                        action: modelData[1]
                    }
                }
            }
            Repeater {
                model: root.steps
                Stat {
                    required property int index
                    x: b.padX + index * (b.stepW + 8)
                    y: b.stepY
                    width: b.stepW
                    height: b.stepH
                }
            }
        }
    }
}
