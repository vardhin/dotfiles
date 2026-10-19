import QtQuick
import qs
import qs.tokyo as T

// Capture, Vaporwave: capture.exe, the Sound Recorder. "Position:" and
// "Length:" over a dark dot screen with the signal in cyan (a flat line
// while idle, a moving wave while it records), and push buttons: ✂ takes
// a shot of the target, ● records, region and window pick the target (hot
// pink); recording, ■ stops and mic turns the microphone on or off.
// Expanded, capture.exe — Options: the target, the audio and what to take
// as rows of push buttons (labels in dots), then the recent captures as
// pictures in dots with their names.
T.Face {
    id: root

    readonly property bool recording: !!ctx.recording
    // What ✂ and ● take, picked here or on the expanded board.
    property string target: "area"
    readonly property string elapsed: recording ? String(ctx.elapsed ?? "00:00") : "00:00"

    Win {
        id: win
        anchors.fill: parent
        icon: "◉"
        title: root.big ? "capture.exe — Options" : "capture.exe"
        big: root.big
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : recorder
    }

    // ── Compact: the recorder ───────────────────────────────────────
    Component {
        id: recorder
        Item {
            id: c
            readonly property real topY: win.bodyY + 4
            readonly property real keyH: 24
            property real phase: 0
            NumberAnimation on phase {
                running: root.recording
                from: 0
                to: Math.PI * 2
                duration: 1600
                loops: Animation.Infinite
            }

            Pen {
                x: 10
                y: c.topY
                height: 18
                text: "Position: " + root.elapsed
                size: 16
            }
            Pen {
                anchors.right: parent.right
                anchors.rightMargin: 10
                y: c.topY
                height: 18
                text: "Length: " + root.elapsed
                size: 16
            }
            Crt {
                id: wave
                x: 10
                y: c.topY + 20
                width: parent.width - 20
                height: parent.height - y - c.keyH - 12
                // The signal: dashed and flat while idle, a wave recording.
                Repeater {
                    model: Math.floor((wave.cols - 4) / 2)
                    Rectangle {
                        required property int index
                        readonly property real t: index / Math.max(1, wave.cols / 2)
                        x: 2 + index * 2
                        y: Math.round((wave.rows - 1) / 2 + (root.recording ? Math.sin(t * 13 + c.phase) * Math.sin(t * 3.1 + c.phase * 0.5) * (wave.rows / 2 - 2) : 0))
                        width: 1
                        height: 1
                        color: Ink.cyan
                    }
                }
            }
            Row {
                x: 10
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                spacing: 4
                readonly property real w: c.width - 20
                Repeater {
                    model: root.recording ? [
                        { g: "stop", t: "", a: "capture stop", on: false },
                        { g: "", t: "mic", a: "capture audio", on: !!root.ctx.audio }
                    ] : [
                        { g: "", t: "✂", a: "capture shot " + root.target, on: false },
                        { g: "rec", t: "", a: "capture rec " + (root.target === "area" ? "area" : "screen"), on: false },
                        { g: "", t: "region", a: "", on: root.target === "area", pick: "area" },
                        { g: "", t: "window", a: "", on: root.target === "window", pick: "window" }
                    ]
                    Key {
                        required property var modelData
                        width: (parent.w - 4 * (root.recording ? 1 : 3)) / (root.recording ? 2 : 4)
                        height: c.keyH
                        glyph: modelData.g
                        text: modelData.t
                        on: modelData.on
                        action: modelData.a
                        onTap: if (modelData.pick)
                            root.target = modelData.pick
                    }
                }
            }
        }
    }

    // ── Expanded: Options ───────────────────────────────────────────
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
            readonly property real wellY: win.bodyY + 8
            readonly property real wellH: height - wellY - 10
            readonly property real padX: 22
            readonly property real labW: 84
            readonly property real rowH: 24
            readonly property real rowY: wellY + 12
            readonly property real recentY: rowY + opts.length * (rowH + 8) + 4
            readonly property real thumbW: (width - padX * 2 - 24) / 4
            readonly property real thumbH: Math.max(24, Math.min(thumbW * 0.56, wellY + wellH - recentY - 20 - 24 - 20))
            readonly property int x0: Math.ceil(padX / p)
            readonly property int w0: Math.floor((width - padX * 2) / p)

            Well {
                x: 10
                y: b.wellY
                width: parent.width - 20
                height: b.wellH
            }
            Repeater {
                model: b.opts
                Row {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property real w: b.width - b.padX * 2 - b.labW
                    x: b.padX + b.labW
                    y: b.rowY + index * (b.rowH + 8)
                    spacing: 8
                    Repeater {
                        model: row.modelData.keys
                        Key {
                            required property var modelData
                            width: (row.w - 16) / 3
                            height: b.rowH
                            text: modelData[0]
                            on: modelData[1]
                            onTap: modelData[2]()
                        }
                    }
                }
            }
            Row {
                x: b.padX
                y: b.recentY + 20
                spacing: 8
                Repeater {
                    model: (root.ctx.recent ?? []).slice(0, 4)
                    Item {
                        required property var modelData
                        width: b.thumbW
                        height: b.thumbH
                        T.DotPic {
                            anchors.fill: parent
                            anchors.margins: 1
                            radius: 0
                            source: "file://" + parent.modelData.path
                        }
                        Bevel {
                            anchors.fill: parent
                            sunk: true
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
                        x: b.x0
                        y: Math.round((b.rowY + index * (b.rowH + 8) + b.rowH / 2) / b.p) - 2
                        height: 5
                        font: "3x5"
                        text: modelData.name
                        color: Ink.ink
                    }
                }
                MatrixText {
                    x: b.x0
                    y: Math.ceil(b.recentY / b.p)
                    height: 5
                    font: "3x5"
                    text: "RECENT"
                    color: Ink.ink
                }
                Repeater {
                    model: (root.ctx.recent ?? []).slice(0, 4)
                    MatrixText {
                        required property var modelData
                        required property int index
                        x: Math.round((b.padX + index * (b.thumbW + 8)) / b.p)
                        y: Math.ceil((b.recentY + 20 + b.thumbH + 4) / b.p)
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
                    y: Math.ceil((b.recentY + 24) / b.p)
                    height: 5
                    font: "3x5"
                    text: "nothing captured yet"
                    color: Ink.label
                    opacity: 0.6
                }
                MatrixText {
                    x: b.x0
                    y: Math.floor((b.wellY + b.wellH - 10) / b.p) - 5
                    width: b.w0
                    height: 5
                    font: "3x5"
                    scroll: true
                    text: "Shots → ~/Pictures · recordings → ~/Videos"
                    color: Ink.label
                }
            }
        }
    }
}
