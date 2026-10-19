import QtQuick
import qs
import qs.tokyo as T

// Capture, Split-Flap: the STUDIO · CAPTURE board. READY and the target,
// the last shot's time in yellow on flap tiles, and keys: SHOT takes the
// target, REC (red) records, REGION and WINDOW pick the target (yellow).
// Recording, it goes ON AIR: RECORDING and the time in red, the mic in
// yellow, STOP (red) and MIC. Expanded, the CAPTURE DESK: the target, the
// audio and what to take as rows of keys, then the recent captures as
// pictures in dots with their names.
T.Face {
    id: root

    readonly property bool recording: !!ctx.recording
    // What SHOT and REC take, picked here or on the expanded board.
    property string target: "area"
    readonly property string targetWord: ({ area: "REGION", window: "WINDOW", screen: "SCREEN" })[target]
    readonly property string elapsed: recording ? String(ctx.elapsed ?? "00:00") : "00:00"
    readonly property var last: (ctx.recent ?? [])[0] ?? null

    Housing {
        id: box
        anchors.fill: parent
        label: root.big ? "STUDIO · CAPTURE DESK" : "STUDIO · CAPTURE"
        status: root.recording ? "ON AIR" : "READY"
        statusInk: root.recording ? Ink.red : Ink.label
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : desk
    }

    // ── Compact ─────────────────────────────────────────────────────
    Component {
        id: desk
        Item {
            id: c
            readonly property real keyH: 22
            Rows {
                x: 14
                y: box.bodyY + 2
                width: parent.width - 28
                height: parent.height - y - c.keyH - 18
                lines: root.recording ? [
                    [["REC ", Ink.red], [root.elapsed, Ink.red]],
                    { spans: [["MIC " + (root.ctx.audio ? "ON" : "OFF"), Ink.yellow]], action: "capture audio" }
                ] : [
                    [["READY · ", Ink.white], [root.targetWord, Ink.white]],
                    [["LAST ", Ink.yellow], [root.last ? Qt.formatTime(new Date(root.last.ts), "hh:mm") : "NONE", Ink.yellow]]
                ]
            }
            Row {
                x: 14
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                spacing: 6
                readonly property real w: c.width - 28
                Repeater {
                    model: root.recording ? [
                        { t: "STOP", a: "capture stop", on: false, tone: Ink.red },
                        { t: "MIC", a: "capture audio", on: !!root.ctx.audio, tone: "transparent" }
                    ] : [
                        { t: "SHOT", a: "capture shot " + root.target, on: false, tone: "transparent" },
                        { t: "REC", a: "capture rec " + (root.target === "area" ? "area" : "screen"), on: false, tone: Ink.red },
                        { t: "REGION", a: "", on: root.target === "area", pick: "area", tone: "transparent" },
                        { t: "WINDOW", a: "", on: root.target === "window", pick: "window", tone: "transparent" }
                    ]
                    Key {
                        required property var modelData
                        width: (parent.w - 6 * (root.recording ? 1 : 3)) / (root.recording ? 2 : 4)
                        height: c.keyH
                        text: modelData.t
                        on: modelData.on
                        tone: modelData.tone
                        action: modelData.a
                        onTap: if (modelData.pick)
                            root.target = modelData.pick
                    }
                }
            }
        }
    }

    // ── Expanded: the desk ──────────────────────────────────────────
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
            readonly property real padX: 14
            readonly property real labW: 7 * 4 * p + 10
            readonly property real rowH: 22
            readonly property real rowY: box.bodyY + 4
            readonly property real recentY: rowY + opts.length * (rowH + 8) + 4
            readonly property real thumbW: (width - padX * 2 - 24) / 4
            readonly property real thumbH: Math.max(24, Math.min(thumbW * 0.56, height - recentY - 8 * p - 14 - 5 * p - 18))
            readonly property int x0: Math.ceil(padX / p)
            readonly property int w0: Math.floor((width - padX * 2) / p)

            Repeater {
                model: b.opts
                Row {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property real w: b.width - b.padX * 2 - b.labW
                    x: b.padX + b.labW
                    y: b.rowY + index * (b.rowH + 8)
                    spacing: 6
                    Repeater {
                        model: row.modelData.keys
                        Key {
                            required property var modelData
                            width: (row.w - 12) / 3
                            height: b.rowH
                            text: modelData[0]
                            on: modelData[1]
                            tone: modelData[0] === "RECORD" ? Ink.red : "transparent"
                            onTap: modelData[2]()
                        }
                    }
                }
            }
            Row {
                x: b.padX
                y: b.recentY + 9 * b.p
                spacing: 8
                Repeater {
                    model: (root.ctx.recent ?? []).slice(0, 4)
                    Item {
                        required property var modelData
                        width: b.thumbW
                        height: b.thumbH
                        Rectangle {
                            anchors.fill: parent
                            color: Ink.rim
                        }
                        T.DotPic {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 0
                            source: "file://" + parent.modelData.path
                        }
                        T.Hit {
                            anchors.fill: parent
                            action: "open " + parent.modelData.path
                        }
                    }
                }
            }

            Dots {
                id: ink
                anchors.fill: parent
                Repeater {
                    model: b.opts
                    MatrixText {
                        required property var modelData
                        required property int index
                        x: b.x0
                        y: Math.round((b.rowY + index * (b.rowH + 8) + b.rowH / 2) / b.p) - 2
                        height: 5
                        font: "3x5"
                        text: modelData.name
                        color: Ink.white
                    }
                }
                MatrixText {
                    x: b.x0
                    y: Math.ceil(b.recentY / b.p) + 1
                    height: 5
                    font: "3x5"
                    text: "RECENT"
                    color: Ink.white
                }
                Repeater {
                    model: (root.ctx.recent ?? []).slice(0, 4)
                    MatrixText {
                        required property var modelData
                        required property int index
                        x: Math.round((b.padX + index * (b.thumbW + 8)) / b.p)
                        y: Math.ceil((b.recentY + 9 * b.p + b.thumbH + 4) / b.p)
                        width: Math.floor(b.thumbW / b.p)
                        height: 5
                        font: "3x5"
                        align: "center"
                        text: String(modelData.name).replace(/\.[a-z0-9]+$/i, "").slice(-12)
                        color: Ink.label
                    }
                }
                MatrixText {
                    visible: !(root.ctx.recent ?? []).length
                    x: b.x0
                    y: Math.ceil(b.recentY / b.p) + 10
                    height: 5
                    font: "3x5"
                    text: "NOTHING CAPTURED YET"
                    color: Ink.label
                }
                MatrixText {
                    x: b.x0
                    y: ink.rows - Math.ceil(12 / b.p) - 5
                    width: b.w0
                    height: 5
                    font: "3x5"
                    scroll: true
                    text: "SHOTS GO TO ~/PICTURES · RECORDINGS TO ~/VIDEOS"
                    color: Ink.label
                }
            }
        }
    }
}
