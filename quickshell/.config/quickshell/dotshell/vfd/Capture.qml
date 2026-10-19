import QtQuick
import qs
import qs.tokyo as T

// Capture, VFD: a tape deck. REC SP LP down the side (REC lit red while
// recording), the tape counter in big dots (red while it runs), what it
// takes and whether the mic is on at the right; under the display the
// deck's keys: SHOT REC REGION WINDOW, or STOP and MIC while recording.
// Expanded, the options as rows of keys (the picked one ringed) and the
// last captures as pictures in dots.
T.Face {
    id: root

    readonly property bool recording: !!ctx.recording
    // What SHOT and REC take, picked on the expanded board.
    property string target: "area"
    readonly property string counter: {
        const e = String(ctx.elapsed ?? "");
        return recording && e ? (e.split(":").length < 3 ? "0:" : "") + e : "0:00:00";
    }
    readonly property string targetWord: ({ area: "REGION", window: "WINDOW", screen: "SCREEN" })[target]

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : deck
    }

    // ── Compact: the deck ───────────────────────────────────────────
    Component {
        id: deck
        Unit {
            id: u
            foot: root.height >= 140 ? 34 : 26
            readonly property int padX: 4
            readonly property int sideW: 23
            // Narrow: what it takes goes under the counter, not beside it.
            readonly property bool narrow: cols < 120
            readonly property int infoW: narrow ? 0 : 34
            readonly property int size: Math.max(1, Math.min(Math.floor((rows - 4 - (narrow ? 8 : 0)) / 7), Math.floor((cols - padX * 2 - sideW - infoW) / 42)))

            // • REC / SP / LP
            Column {
                x: u.padX
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Repeater {
                    model: [["• REC", root.recording, Ink.red], ["SP", true, root.recording ? Ink.red : Ink.cyan], ["LP", false, Ink.cyan]]
                    MatrixText {
                        required property var modelData
                        height: 5
                        font: "3x5"
                        text: modelData[0]
                        color: modelData[1] ? modelData[2] : Ink.ghost
                    }
                }
            }
            // 0:01:23
            Digits {
                id: counter
                x: u.padX + u.sideW + Math.max(0, Math.floor((u.cols - u.padX * 2 - u.sideW - u.infoW - width) / 2))
                y: Math.floor((u.rows - height - (u.narrow ? 8 : 0)) / 2)
                width: implicitWidth
                height: implicitHeight
                size: u.size
                text: root.counter
                color: root.recording ? Ink.red : Ink.cyan
            }
            // REGION / MIC OFF, beside the counter or under it.
            Grid {
                x: u.narrow ? counter.x : u.cols - u.padX - u.infoW + 2
                y: u.narrow ? counter.y + counter.height + 3 : Math.floor((u.rows - height) / 2)
                columns: u.narrow ? 2 : 1
                columnSpacing: 4
                rowSpacing: 3
                MatrixText {
                    height: 5
                    font: "3x5"
                    text: root.targetWord
                    color: Ink.cyan
                }
                MatrixText {
                    height: 5
                    font: "3x5"
                    text: root.ctx.audio ? "MIC ON" : "MIC OFF"
                    color: Ink.amber
                }
            }

            deck: Row {
                anchors.fill: parent
                spacing: 5
                Repeater {
                    model: root.recording ? [
                        { t: "STOP", ink: Ink.red, a: "capture stop" },
                        { t: "MIC", ink: root.ctx.audio ? Ink.cyan : "transparent", a: "capture audio" }
                    ] : [
                        { t: "SHOT", ink: "transparent", a: "capture shot " + root.target },
                        { t: "REC", ink: Ink.red, a: "capture rec " + (root.target === "area" ? "area" : "screen") },
                        { t: "REGION", ink: root.target === "area" ? Ink.cyan : "transparent", a: "", pick: "area" },
                        { t: "WINDOW", ink: root.target === "window" ? Ink.cyan : "transparent", a: "", pick: "window" }
                    ]
                    Key {
                        required property var modelData
                        required property int index
                        width: (parent.width - parent.spacing * (root.recording ? 1 : 3)) / (root.recording ? 2 : 4)
                        height: parent.height
                        size: 9
                        pad: 2
                        text: modelData.t
                        ink: modelData.ink
                        action: modelData.a
                        onTap: if (modelData.pick) root.target = modelData.pick
                    }
                }
            }
        }
    }

    // ── Expanded: options and recent ────────────────────────────────
    Component {
        id: board
        Unit {
            id: u
            readonly property var opts: [
                { name: "TARGET", keys: [["REGION", root.target === "area", () => root.target = "area"], ["WINDOW", root.target === "window", () => root.target = "window"], ["SCREEN", root.target === "screen", () => root.target = "screen"]] },
                { name: "AUDIO", keys: [["NONE", !root.ctx.audio, () => { if (root.ctx.audio) root.run("capture audio"); }], ["MIC", !!root.ctx.audio, () => { if (!root.ctx.audio) root.run("capture audio"); }]] },
                { name: "TAKE", keys: [["SHOT", false, () => root.run("capture shot " + root.target)], [root.recording ? "STOP " + (root.ctx.elapsed ?? "") : "RECORD", root.recording, () => root.run(root.recording ? "capture stop" : "capture rec " + (root.target === "area" ? "area" : "screen"))], ["PICK COLOR", false, () => root.run("capture pick")]] }
            ]
            readonly property int padX: 4
            readonly property int labW: 30
            readonly property int rowH: 10
            readonly property int recentY: 4 + opts.length * (rowH + 3) + 2
            readonly property int thumbW: Math.floor((cols - padX * 2 - 9) / 4)
            readonly property int thumbH: Math.max(8, Math.min(Math.round(thumbW * 0.56), rows - recentY - 8 - 8 - 9))

            Repeater {
                model: u.opts
                MatrixText {
                    required property var modelData
                    required property int index
                    x: u.padX
                    y: 4 + index * (u.rowH + 3) + 3
                    height: 5
                    font: "3x5"
                    text: modelData.name
                    color: Ink.teal
                }
            }
            MatrixText {
                x: u.padX
                y: u.recentY
                height: 5
                font: "3x5"
                text: "RECENT"
                color: Ink.teal
            }
            Repeater {
                model: (root.ctx.recent ?? []).slice(0, 4)
                MatrixText {
                    required property var modelData
                    required property int index
                    x: u.padX + index * (u.thumbW + 3)
                    y: u.recentY + 8 + u.thumbH + 2
                    width: u.thumbW
                    height: 5
                    font: "3x5"
                    align: "center"
                    text: String(modelData.name).replace(/\.[a-z0-9]+$/i, "").slice(-12)
                    color: Ink.teal
                }
            }
            MatrixText {
                x: u.padX
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3
                width: u.cols - u.padX * 2
                height: 5
                font: "3x5"
                scroll: true
                text: "SHOTS GO TO ~/PICTURES/SCREENSHOTS · RECORDINGS TO ~/VIDEOS/RECORDINGS"
                color: Ink.teal
            }

            over: [
                Repeater {
                    model: u.opts
                    Row {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property real w: u.px(u.cols - u.padX * 2 - u.labW)
                        x: u.px(u.padX + u.labW)
                        y: u.px(4 + index * (u.rowH + 3))
                        spacing: 6
                        Repeater {
                            model: row.modelData.keys
                            Key {
                                required property var modelData
                                width: (row.w - 12) / 3
                                height: u.px(u.rowH)
                                size: 9
                                text: modelData[0]
                                on: modelData[1]
                                ink: row.modelData.name === "TAKE" && modelData[1] ? Ink.red : "transparent"
                                dim: true
                                onTap: modelData[2]()
                            }
                        }
                    }
                },
                Row {
                    x: u.px(u.padX)
                    y: u.px(u.recentY + 8)
                    spacing: u.px(3)
                    Repeater {
                        model: (root.ctx.recent ?? []).slice(0, 4)
                        T.DotPic {
                            required property var modelData
                            width: u.px(u.thumbW)
                            height: u.px(u.thumbH)
                            radius: 0
                            source: "file://" + modelData.path
                            T.Hit {
                                anchors.fill: parent
                                action: "open " + modelData.path
                            }
                        }
                    }
                }
            ]
        }
    }
}
