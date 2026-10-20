import QtQuick
import qs
import qs.tokyo as T

// Caffeine, Night Vision: the display's sentry. SENTRY · DISPLAY in dim
// small print, ON WATCH (or STOOD DOWN) big in bright dots, and under it
// when it is relieved and who else is holding the screen (RELIEF IN 42M ·
// ALSO MPV), or the idle steps while it is down. A click flips it.
// Expanded, TIMERS on the CRT: STAYING AWAKE big and the time left, the
// timers as keys (the picked one lit), OTHER SENTRIES (what else holds
// the screen), and the STAND-DOWN SCHEDULE in ruled cards.
T.Face {
    id: root

    readonly property bool on: !!ctx.on
    readonly property string remaining: ctx.left ?? ""
    // "42:10" or "1H 2:05" -> hours and minutes.
    readonly property var hm: {
        const m = /^(?:(\d+)H )?(\d+):\d+$/.exec(remaining);
        return m ? [Number(m[1] ?? 0), Number(m[2])] : null;
    }
    readonly property var holders: (ctx.holders ?? []).filter(h => h.who !== "dotshell")
    readonly property string relief: hm ? "RELIEF IN " + (hm[0] ? hm[0] + "H" : "") + hm[1] + "M" : "UNTIL STOOD DOWN"
    readonly property string also: holders.length ? " · ALSO " + String(holders[0].who).toUpperCase() : ""
    readonly property var steps: [["DIM", "5 MIN"], ["LOCK", "7:30"], ["SCREEN OFF", "7:45"]]

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : sentry
    }

    // ── Compact: the sentry ─────────────────────────────────────────
    Component {
        id: sentry
        Scope {
            id: s
            readonly property int l: dx((Math.max(18, rx * 0.55) + 8))
            readonly property int w: dx(width - (Math.max(18, rx * 0.55) + 8)) - l
            readonly property string word: root.on ? "ON WATCH" : "STOOD DOWN"
            readonly property int bigH: Math.max(7, Math.min(Math.floor(rows * 0.3), 16, Math.floor(w / (0.72 * word.length))))
            readonly property int block: 5 + 4 + bigH + 4 + 5
            readonly property int t: Math.round((rows - block) / 2)

            MatrixText {
                x: s.l
                y: s.t
                width: s.w
                height: 5
                font: "3x5"
                text: s.w >= 64 ? "SENTRY · DISPLAY" : "SENTRY"
                color: Ink.dim
            }
            Say {
                x: s.l
                y: s.t + 9 - Math.round(s.bigH * 0.15)
                width: s.w
                height: Math.round(s.bigH * 1.3)
                verticalAlignment: Text.AlignVCenter
                size: Math.round(s.bigH * 1.32)
                text: s.word
                color: root.on ? Ink.bright : Ink.lit
                elide: Text.ElideNone
            }
            MatrixText {
                x: s.l
                y: s.t + 9 + s.bigH + 4
                width: s.w
                height: 5
                font: "3x5"
                scroll: true
                text: root.on ? root.relief + root.also : "DIM T+5M · LOCK T+7M"
                color: Ink.lit
            }
            T.Hit {
                parent: s.over
                anchors.fill: parent
                action: "caffeine toggle"
            }
        }
    }

    // ── Expanded: the timers ────────────────────────────────────────
    Component {
        id: board
        Scope {
            id: b
            crt: true
            readonly property var timers: [
                ["30 M", "caffeine for 30", false],
                ["1 H", "caffeine for 60", false],
                ["2 H", "caffeine for 120", false],
                ["UNTIL OFF", "caffeine on", root.on && !root.remaining],
                ["OFF", "caffeine off", !root.on]
            ]
            readonly property int p: Tokens.pitch
            readonly property real padX: (Math.max(16, rx * 0.36) + 10)
            readonly property real titleY: (Math.max(12, ry * 0.6) + 8)
            readonly property real titleH: Math.max(9 * p, Math.min(40, height * 0.11))
            readonly property real keyY: titleY + titleH + 8
            readonly property real stepH: Math.max(18 * p, Math.min(56, height * 0.16))
            readonly property real stepY: height - (Math.max(12, ry * 0.6) + 8) - stepH
            readonly property real stepW: (width - padX * 2 - 24) / 3
            readonly property int x0: dx(padX)
            readonly property int w0: dx(width - padX) - x0

            // STAYING AWAKE                   42 min left
            Say {
                id: title
                x: b.x0
                y: b.dy(b.titleY) - Math.round(b.titleH / b.p * 0.15)
                width: Math.min(Math.ceil(implicitWidth) + 2, b.w0)
                height: Math.round(b.titleH / b.p * 1.3)
                verticalAlignment: Text.AlignVCenter
                size: Math.round(b.titleH / b.p * 1.32)
                text: root.on ? "STAYING AWAKE" : "STOOD DOWN"
            }
            MatrixText {
                visible: title.width + implicitWidth + 6 <= b.w0
                x: b.x0 + b.w0 - width
                y: b.dy(b.titleY + b.titleH) - 6
                width: implicitWidth
                height: 5
                font: "3x5"
                text: root.hm ? (root.hm[0] ? root.hm[0] + " H " : "") + root.hm[1] + " MIN LEFT" : root.on ? "UNTIL TURNED OFF" : "NORMAL IDLE"
                color: Ink.lit
            }
            MatrixText {
                id: also
                x: b.x0
                y: b.dy(b.keyY + 20) + 4
                height: 5
                font: "3x5"
                text: "OTHER SENTRIES"
                color: Ink.dim
            }
            Column {
                id: holders
                x: b.x0
                y: also.y + 9
                width: b.w0
                spacing: 3
                Repeater {
                    model: (root.ctx.holders ?? []).slice(0, Math.max(0, Math.floor((b.dy(b.stepY) - 9 - holders.y + 3) / 10)))
                    Item {
                        required property var modelData
                        width: holders.width
                        height: 7
                        MatrixText {
                            width: parent.width - why.implicitWidth - 6
                            height: 7
                            text: modelData.who + (modelData.who === "dotshell" ? " (caffeine)" : "")
                            color: Ink.lit
                        }
                        MatrixText {
                            id: why
                            anchors.right: parent.right
                            width: implicitWidth
                            height: 7
                            text: modelData.why
                            color: Ink.lit
                            opacity: 0.75
                        }
                    }
                }
                MatrixText {
                    visible: !(root.ctx.holders ?? []).length
                    height: 5
                    font: "3x5"
                    text: "NONE ON WATCH"
                    color: Ink.dim
                }
            }
            MatrixText {
                x: b.x0
                y: b.dy(b.stepY) - 8
                height: 5
                font: "3x5"
                text: "STAND-DOWN SCHEDULE"
                color: Ink.dim
            }
            Repeater {
                model: root.steps
                Item {
                    id: sv
                    required property var modelData
                    required property int index
                    readonly property real px: b.padX + index * (b.stepW + 12)
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
                        color: Ink.dim
                    }
                    MatrixText {
                        y: parent.height - 8
                        width: parent.width
                        height: 7
                        text: sv.modelData[1]
                        color: Ink.bright
                    }
                }
            }

            Row {
                parent: b.over
                x: b.padX
                y: b.keyY
                spacing: 8
                Repeater {
                    model: b.timers
                    Key {
                        required property var modelData
                        width: (b.width - b.padX * 2 - 32) / 5
                        height: 20
                        text: modelData[0]
                        on: modelData[2]
                        action: modelData[1]
                    }
                }
            }
            Repeater {
                parent: b.over
                model: root.steps
                Box {
                    required property int index
                    x: b.padX + index * (b.stepW + 12)
                    y: b.stepY
                    width: b.stepW
                    height: b.stepH
                }
            }
        }
    }
}
