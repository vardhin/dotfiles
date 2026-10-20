import QtQuick
import qs
import qs.services
import qs.tokyo as T

// Capture, Night Vision: a bodycam's finder. Inside four white reticle
// corners, BODYCAM · STANDBY in dim small print, STBY big in bright dots,
// and its keys as lit words: SHOT takes the target, REC records, REGION
// and WINDOW pick the target (the picked one boxed in white). Recording:
// BODYCAM · RECORDING, ● REC T+01:23 (the dot blinking), STOP (boxed) and
// MIC (bright while it records the mic). Expanded, OPTIONS on the CRT:
// TARGET, AUDIO and TAKE as rows of keys (the picked one lit), then the
// latest shots as EVIDENCE in green, and where they go.
T.Face {
    id: root

    readonly property bool recording: !!ctx.recording
    // What SHOT and REC take, picked here or on the expanded board.
    property string target: "area"
    readonly property string elapsed: String(ctx.elapsed ?? "00:00")
    property bool blink: true
    readonly property string recAct: "capture rec " + (target === "area" ? "area" : "screen")

    Timer {
        interval: 600
        repeat: true
        running: root.visible && root.recording
        onTriggered: root.blink = !root.blink
        onRunningChanged: root.blink = true
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : finder
    }

    // ── Compact: the finder ─────────────────────────────────────────
    Component {
        id: finder
        Scope {
            id: s
            readonly property real bx: (Math.max(18, rx * 0.42) + 6)
            readonly property real by: Math.max(8, height * 0.13) + 3
            readonly property int l: dx(bx + 8)
            readonly property int w: dx(width - bx - 8) - l
            readonly property int t: dy(by + 4)
            readonly property int h: dy(height - by - 4) - t
            // Room for the full words in 3x5? Else the short ones.
            readonly property bool terse: !root.recording && (4 + 3 + 6 + 6) * 4 + 15 > w
            readonly property var keys: root.recording ? [
                { t: "STOP", a: "capture stop", box: true, lit: true },
                { t: "MIC", a: "capture audio", box: false, lit: !!root.ctx.audio }
            ] : [
                { t: "SHOT", a: "capture shot " + root.target, box: false, lit: false },
                { t: "REC", a: root.recAct, box: false, lit: false },
                { t: s.terse ? "AREA" : "REGION", a: "", pick: "area", box: root.target === "area", lit: root.target === "area" },
                { t: s.terse ? "WIN" : "WINDOW", a: "", pick: "window", box: root.target === "window", lit: root.target === "window" }
            ]
            // 5x7 keys when they fit across with room between.
            readonly property bool roomy: keys.reduce((n, k) => n + k.t.length * 6 + 10, 0) <= w && h >= 30
            readonly property int keyH: roomy ? 7 : 5
            readonly property string word: root.recording ? "● REC T+" + root.elapsed : "STBY"
            readonly property int bigH: Math.max(7, Math.min(h - 5 - keyH - 10, Math.floor(w / (0.72 * word.length))))

            MatrixText {
                x: s.l
                y: s.t
                width: s.w
                height: 5
                font: "3x5"
                align: "center"
                text: root.recording ? (s.w >= 19 * 4 ? "BODYCAM · RECORDING" : "BODYCAM · REC") : (s.w >= 17 * 4 ? "BODYCAM · STANDBY" : "BODYCAM · STBY")
                color: Ink.dim
            }
            Say {
                x: s.l
                y: s.t + 5 + Math.round((s.h - 5 - s.keyH - s.bigH * 1.3) / 2)
                width: s.w
                height: Math.round(s.bigH * 1.3)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                size: Math.round(s.bigH * 1.32)
                text: root.recording && !root.blink ? "  REC T+" + root.elapsed : s.word
                elide: Text.ElideNone
            }
            Row {
                id: keyRow
                x: s.l + Math.round((s.w - width) / 2)
                y: s.t + s.h - s.keyH - 1
                spacing: s.roomy ? 8 : 4
                Repeater {
                    id: keyRep
                    model: s.keys
                    MatrixText {
                        required property var modelData
                        width: implicitWidth
                        height: s.keyH
                        font: s.roomy ? "5x7" : "3x5"
                        text: modelData.t
                        color: modelData.lit ? Ink.bright : Ink.lit
                    }
                }
            }
            // The keys' hits and the picked one's white box, over the dots.
            Repeater {
                parent: s.over
                model: s.keys
                Item {
                    required property var modelData
                    required property int index
                    readonly property Item word: keyRep.count > index ? keyRep.itemAt(index) : null
                    x: word ? s.px(keyRow.x + word.x) - 4 : 0
                    y: s.py(keyRow.y) - 3
                    width: word ? word.width * Tokens.pitch + 8 : 0
                    height: s.keyH * Tokens.pitch + 6
                    Box {
                        anchors.fill: parent
                        visible: modelData.box
                        tone: "bright"
                        dashed: !root.recording
                    }
                    T.Hit {
                        anchors.fill: parent
                        action: modelData.a
                        onTap: if (modelData.pick)
                            root.target = modelData.pick
                    }
                }
            }
            Brackets {
                parent: s.over
                x: s.bx
                y: s.by
                width: s.width - s.bx * 2
                height: s.height - s.by * 2
            }
        }
    }

    // ── Expanded: the options ───────────────────────────────────────
    Component {
        id: board
        Scope {
            id: b
            crt: true
            readonly property var opts: [
                { name: "TARGET", keys: [["REGION", root.target === "area", () => root.target = "area"], ["WINDOW", root.target === "window", () => root.target = "window"], ["SCREEN", root.target === "screen", () => root.target = "screen"]] },
                { name: "AUDIO", keys: [["NONE", !root.ctx.audio, () => { if (root.ctx.audio) root.run("capture audio"); }], ["MIC", !!root.ctx.audio, () => { if (!root.ctx.audio) root.run("capture audio"); }]] },
                { name: "TAKE", keys: [["SHOT", false, () => root.run("capture shot " + root.target)], [root.recording ? "STOP " + root.elapsed : "RECORD", root.recording, () => root.run(root.recording ? "capture stop" : root.recAct)], ["PICK COLOR", false, () => root.run("capture pick")]] }
            ]
            readonly property int p: Tokens.pitch
            readonly property real padX: (Math.max(16, rx * 0.36) + 10)
            readonly property real padY: (Math.max(12, ry * 0.6) + 8)
            readonly property real labW: Math.min(6 * 6 * p + 10, (width - padX * 2) * 0.24)
            readonly property real rowH: 20
            readonly property bool wide: labW / p >= 6 * 6
            readonly property string labFont: wide ? "5x7" : "3x5"
            readonly property real recentY: padY + 3 * (rowH + 8) + 4
            readonly property real footY: height - padY - 5 * p
            readonly property real thumbW: (width - padX * 2 - 24) / 4
            readonly property real thumbH: Math.max(20, Math.min(thumbW * 0.62, footY - 6 - 5 * p - 6 - recentY - 9 * p))
            readonly property var recent: (root.ctx.recent ?? []).slice(0, 4)

            Repeater {
                model: b.opts
                MatrixText {
                    required property var modelData
                    required property int index
                    x: b.dx(b.padX)
                    y: b.dy(b.padY + index * (b.rowH + 8) + b.rowH / 2) - (b.wide ? 3 : 2)
                    width: b.dx(b.padX + b.labW) - x
                    height: b.wide ? 7 : 5
                    font: b.labFont
                    text: modelData.name
                    color: Ink.dim
                }
            }
            MatrixText {
                x: b.dx(b.padX)
                y: b.dy(b.recentY)
                height: b.wide ? 7 : 5
                font: b.labFont
                text: "EVIDENCE"
                color: Ink.dim
            }
            Repeater {
                model: b.recent
                MatrixText {
                    required property var modelData
                    required property int index
                    x: b.dx(b.padX + index * (b.thumbW + 8))
                    y: b.dy(b.recentY + 9 * b.p + b.thumbH + 5)
                    width: Math.floor(b.thumbW / b.p)
                    height: 5
                    font: "3x5"
                    align: "center"
                    text: String(modelData.name).replace(/\.[a-z0-9]+$/i, "").slice(-12)
                    color: Ink.dim
                }
            }
            MatrixText {
                visible: !b.recent.length
                x: b.dx(b.padX)
                y: b.dy(b.recentY) + 11
                height: 5
                font: "3x5"
                text: "NO EVIDENCE YET"
                color: Ink.dim
            }
            MatrixText {
                x: b.dx(b.padX)
                y: b.dy(b.footY)
                width: b.dx(b.width - b.padX) - x
                height: 5
                font: "3x5"
                scroll: true
                text: "EVIDENCE → ~/PICTURES · ~/VIDEOS"
                color: Ink.dim
            }

            Repeater {
                parent: b.over
                model: b.opts
                Row {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property real w: b.width - b.padX * 2 - b.labW
                    x: b.padX + b.labW
                    y: b.padY + index * (b.rowH + 8)
                    spacing: 6
                    Repeater {
                        model: row.modelData.keys
                        Key {
                            required property var modelData
                            width: (row.w - 12) / 3
                            height: b.rowH
                            text: modelData[0]
                            on: modelData[1]
                            onTap: modelData[2]()
                        }
                    }
                }
            }
            // The latest shots, in green, ruled lit.
            Row {
                parent: b.over
                x: b.padX
                y: b.recentY + 9 * b.p
                spacing: 8
                Repeater {
                    model: b.recent
                    Item {
                        required property var modelData
                        width: b.thumbW
                        height: b.thumbH
                        Pic {
                            anchors.fill: parent
                            anchors.margins: 1
                            source: "file://" + parent.modelData.path
                        }
                        Box {
                            anchors.fill: parent
                            tone: "lit"
                        }
                        T.Hit {
                            anchors.fill: parent
                            action: "open " + parent.modelData.path
                        }
                    }
                }
            }
        }
    }
}
