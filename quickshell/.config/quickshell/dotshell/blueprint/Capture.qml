import QtQuick
import qs
import qs.tokyo as T

// Capture, Blueprint: FIG. 6, the capture frustum. The camera, dashed
// rays out to the target (REGION, WINDOW or SCREEN; heavier while
// recording) and a title block: the mode, the time and what to do (SHOT,
// a boxed REC, the targets; recording, a boxed STOP and MIC), all crisp.
// Expanded, SHEET 7: the settings as rows of drafting keys (labels in
// dots) and the recent captures as framed pictures in dots.
T.Face {
    id: root

    readonly property bool recording: !!ctx.recording
    // What SHOT and REC take, picked here or on the expanded board.
    property string target: "area"
    readonly property string targetWord: ({ area: "REGION", window: "WINDOW", screen: "SCREEN" })[target]

    Paper {
        anchors.fill: parent
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : frustum
    }

    // ── Compact: FIG. 6 ─────────────────────────────────────────────
    Component {
        id: frustum
        Item {
            id: c
            readonly property real tableW: Math.min(200, width * 0.52)
            // The drawing: the design's 160 x 96 from (10, 26).
            readonly property real k: Math.max(0.5, Math.min(1, (width - tableW - 6) / 150, (height - 30) / 96))
            function px(v: real): real {
                return 10 + v * k;
            }
            function py(v: real): real {
                return 26 + v * k;
            }

            Pen {
                x: 14
                y: 8
                width: parent.width - 28
                height: 14
                text: "FIG. 6 — CAPTURE FRUSTUM"
            }
            Stroke {
                anchors.fill: parent
                path: `M ${c.px(4)} ${c.py(38)} L ${c.px(22)} ${c.py(38)} L ${c.px(22)} ${c.py(56)} L ${c.px(4)} ${c.py(56)} Z`
                color: Ink.ink
                line: 1.5
            }
            Stroke {
                anchors.fill: parent
                path: `M ${c.px(22)} ${c.py(40)} L ${c.px(140)} ${c.py(6)} M ${c.px(22)} ${c.py(54)} L ${c.px(140)} ${c.py(90)}`
                color: Ink.line
                dash: [4, 3]
            }
            Rectangle {
                x: c.px(96)
                y: c.py(22)
                width: 44 * c.k
                height: 52 * c.k
                color: "transparent"
                border.width: root.recording ? 2.5 : 1.5
                border.color: Ink.white
            }
            Pen {
                x: c.px(118) - 40
                y: c.py(80)
                width: 80
                height: 10
                horizontalAlignment: Text.AlignHCenter
                text: root.recording ? "RECORDING" : root.targetWord
                size: 8
            }

            Table {
                id: block
                anchors.right: parent.right
                y: 26
                width: c.tableW
                labelW: 40
                rows: [["MODE", root.recording ? "RECORD" : "SHOT"], ["T", root.recording ? (root.ctx.elapsed ?? "") + " ELAPSED" : "READY"], ["DO", ""]]
                cells: ({ 2: doRow })
            }
            Component {
                id: doRow
                Item {
                    Row {
                        id: words
                        x: 4
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5
                        scale: Math.min(1, (parent.width - 6) / Math.max(1, implicitWidth))
                        transformOrigin: Item.Left
                        Repeater {
                            model: root.recording ? [
                                { t: "STOP", box: true, lit: true, a: "capture stop" },
                                { t: "MIC", box: false, lit: !!root.ctx.audio, a: "capture audio" }
                            ] : [
                                { t: "SHOT", box: false, lit: false, a: "capture shot " + root.target },
                                { t: "REC", box: true, lit: true, a: "capture rec " + (root.target === "area" ? "area" : "screen") },
                                { t: "REGION", box: false, lit: root.target === "area", a: "", pick: "area" },
                                { t: "WINDOW", box: false, lit: root.target === "window", a: "", pick: "window" }
                            ]
                            Item {
                                id: w
                                required property var modelData
                                width: word.implicitWidth + (modelData.box ? 6 : 0)
                                height: 14
                                Rectangle {
                                    visible: w.modelData.box
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Ink.white
                                }
                                Pen {
                                    id: word
                                    anchors.centerIn: parent
                                    text: w.modelData.t
                                    color: w.modelData.lit ? Ink.white : Ink.line
                                }
                                T.Hit {
                                    anchors.fill: parent
                                    anchors.margins: -2
                                    action: w.modelData.a
                                    onTap: if (w.modelData.pick)
                                        root.target = w.modelData.pick
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Expanded: SHEET 7 ───────────────────────────────────────────
    Component {
        id: board
        Item {
            id: b
            readonly property var opts: [
                { name: "TARGET", keys: [["REGION", root.target === "area", () => root.target = "area"], ["WINDOW", root.target === "window", () => root.target = "window"], ["SCREEN", root.target === "screen", () => root.target = "screen"]] },
                { name: "AUDIO", keys: [["NONE", !root.ctx.audio, () => { if (root.ctx.audio) root.run("capture audio"); }], ["MIC", !!root.ctx.audio, () => { if (!root.ctx.audio) root.run("capture audio"); }]] },
                { name: "TAKE", keys: [["SHOT", false, () => root.run("capture shot " + root.target)], [root.recording ? "STOP " + (root.ctx.elapsed ?? "") : "RECORD", root.recording, () => root.run(root.recording ? "capture stop" : "capture rec " + (root.target === "area" ? "area" : "screen"))], ["PICK COLOR", false, () => root.run("capture pick")]] }
            ]
            readonly property int p: Tokens.pitch
            readonly property int cols: Math.floor(width / p)
            readonly property int rows: Math.floor(height / p)
            readonly property int padX: Math.ceil(16 / p)
            readonly property int topY: Math.ceil(30 / p)
            readonly property int labW: 28
            readonly property int rowH: 8
            readonly property int recentY: topY + opts.length * (rowH + 4) + 2
            readonly property int thumbW: Math.floor((cols - padX * 2 - 9) / 4)
            readonly property int thumbH: Math.max(8, Math.min(Math.round(thumbW * 0.56), rows - recentY - 8 - 8 - 10))

            Sheet {
                title: "SHEET 7 — CAPTURE SETTINGS"
            }
            Repeater {
                model: b.opts
                Row {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property real w: (b.cols - b.padX * 2 - b.labW) * b.p
                    x: (b.padX + b.labW) * b.p
                    y: (b.topY + index * (b.rowH + 4)) * b.p
                    spacing: 6
                    Repeater {
                        model: row.modelData.keys
                        Key {
                            required property var modelData
                            width: (row.w - 12) / 3
                            height: b.rowH * b.p
                            text: modelData[0]
                            on: modelData[1]
                            onTap: modelData[2]()
                        }
                    }
                }
            }
            Row {
                x: b.padX * b.p
                y: (b.recentY + 8) * b.p
                spacing: 3 * b.p
                Repeater {
                    model: (root.ctx.recent ?? []).slice(0, 4)
                    Item {
                        required property var modelData
                        width: b.thumbW * b.p
                        height: b.thumbH * b.p
                        T.DotPic {
                            anchors.fill: parent
                            anchors.margins: 1
                            radius: 0
                            source: "file://" + parent.modelData.path
                        }
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.width: 1
                            border.color: Ink.ink
                        }
                        T.Hit {
                            anchors.fill: parent
                            action: "open " + parent.modelData.path
                        }
                    }
                }
            }

            Dots {
                anchors.fill: parent
                Repeater {
                    model: b.opts
                    MatrixText {
                        required property var modelData
                        required property int index
                        x: b.padX
                        y: b.topY + index * (b.rowH + 4) + 2
                        height: 5
                        font: "3x5"
                        text: modelData.name
                        color: Ink.line
                    }
                }
                MatrixText {
                    x: b.padX
                    y: b.recentY
                    height: 5
                    font: "3x5"
                    text: "DETAILS - RECENT"
                    color: Ink.line
                }
                Repeater {
                    model: (root.ctx.recent ?? []).slice(0, 4)
                    MatrixText {
                        required property var modelData
                        required property int index
                        x: b.padX + index * (b.thumbW + 3)
                        y: b.recentY + 8 + b.thumbH + 2
                        width: b.thumbW
                        height: 5
                        font: "3x5"
                        align: "center"
                        text: String(modelData.name).replace(/\.[a-z0-9]+$/i, "").slice(-12)
                        color: Ink.line
                    }
                }
                MatrixText {
                    visible: !(root.ctx.recent ?? []).length
                    x: b.padX
                    y: b.recentY + 10
                    height: 5
                    font: "3x5"
                    text: "NOTHING CAPTURED YET"
                    color: Ink.line
                    opacity: 0.6
                }
                MatrixText {
                    x: b.padX
                    y: b.rows - 7
                    width: b.cols - b.padX * 2
                    height: 5
                    font: "3x5"
                    scroll: true
                    text: "NOTE: OUTPUT TO ~/PICTURES AND ~/VIDEOS."
                    color: Ink.line
                }
            }
        }
    }
}
