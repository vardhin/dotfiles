import QtQuick
import qs
import qs.tokyo as T

// Capture, Frutiger Aero: "Snip & Record" on the sky glass with a row of
// glossy keys, SHOT, a red REC bubble, REGION and WINDOW (the picked one
// lit); recording, a blinking red counter, STOP and MIC. Under them the
// last capture. Expanded, the options as rows of keys (labels in bubble
// dots) and the recent captures as pictures in dots.
T.Face {
    id: root

    readonly property bool recording: !!ctx.recording
    // What SHOT and REC take, picked here or on the expanded board.
    property string target: "area"
    readonly property string targetWord: ({ area: "region", window: "window", screen: "screen" })[target]
    readonly property var last: (ctx.recent ?? [])[0] ?? null

    Sky {
        anchors.fill: parent
        radius: root.big ? 28 : Math.min(24, height * 0.2)
        gloss: false
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : snip
    }

    // ── Compact ─────────────────────────────────────────────────────
    Component {
        id: snip
        Item {
            id: c
            readonly property real padX: 16
            readonly property real keyH: Math.max(30, Math.min(44, height - 70))

            Item {
                x: c.padX
                y: 10
                width: parent.width - c.padX * 2
                height: 20
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.recording ? "Recording…" : "Snip & Record"
                    color: Ink.navy
                    font.family: Ink.family
                    font.pixelSize: 15
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.recording ? "● " + (root.ctx.elapsed ?? "") : "Ready"
                    color: root.recording ? Ink.c("#c8323c", "#ff5a64") : Ink.blue
                    opacity: root.recording ? (root.ctx.blink ?? 1) : 1
                    font.family: Ink.family
                    font.pixelSize: 13
                }
            }

            Row {
                id: keys
                x: c.padX
                y: 36
                width: parent.width - c.padX * 2
                spacing: 6
                Repeater {
                    model: root.recording ? [
                        { t: "STOP", g: "■", look: "red", a: "capture stop" },
                        { t: "MIC", g: "◖", look: root.ctx.audio ? "lit" : "plain", a: "capture audio" }
                    ] : [
                        { t: "SHOT", g: "✂", look: "plain", a: "capture shot " + root.target },
                        { t: "REC", g: "●", look: "red", a: "capture rec " + (root.target === "area" ? "area" : "screen") },
                        { t: "REGION", g: "▭", look: root.target === "area" ? "lit" : "plain", a: "", pick: "area" },
                        { t: "WINDOW", g: "▢", look: root.target === "window" ? "lit" : "plain", a: "", pick: "window" }
                    ]
                    Key {
                        required property var modelData
                        width: (keys.width - keys.spacing * (root.recording ? 1 : 3)) / (root.recording ? 2 : 4)
                        height: c.keyH
                        textPx: c.keyH < 38 ? 10 : 12
                        glyph: c.keyH >= 36 ? modelData.g : ""
                        text: modelData.t
                        look: modelData.look
                        action: modelData.a
                        onTap: if (modelData.pick)
                            root.target = modelData.pick
                    }
                }
            }

            Text {
                x: c.padX
                y: keys.y + c.keyH + 6
                width: parent.width - c.padX * 2
                elide: Text.ElideMiddle
                text: root.recording ? "Recording " + (root.target === "area" ? "a region" : "the screen") + " · microphone " + (root.ctx.audio ? "on" : "off") : root.last ? "Last: " + root.last.name + " · " + Qt.formatTime(new Date(root.last.ts), "hh:mm") : "Nothing captured yet"
                color: Ink.blue
                font.family: Ink.family
                font.pixelSize: 11
            }
        }
    }

    // ── Expanded: options and recent ────────────────────────────────
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
            readonly property int padX: 6
            readonly property int cols: Math.floor(width / p)
            readonly property int rows: Math.floor(height / p)
            readonly property int labW: 30
            readonly property int rowH: 10
            readonly property int recentY: 5 + opts.length * (rowH + 3) + 2
            readonly property int thumbW: Math.floor((cols - padX * 2 - 9) / 4)
            readonly property int thumbH: Math.max(8, Math.min(Math.round(thumbW * 0.56), rows - recentY - 8 - 8 - 10))

            Repeater {
                model: b.opts
                Row {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property real w: (b.cols - b.padX * 2 - b.labW) * b.p
                    x: (b.padX + b.labW) * b.p
                    y: (5 + index * (b.rowH + 3)) * b.p
                    spacing: 6
                    Repeater {
                        model: row.modelData.keys
                        Key {
                            required property var modelData
                            width: (row.w - 12) / 3
                            height: b.rowH * b.p
                            radius: height / 2
                            textPx: 12
                            text: modelData[0]
                            look: row.modelData.name === "TAKE" && modelData[1] ? "red" : modelData[1] ? "lit" : "ghost"
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
                    T.DotPic {
                        required property var modelData
                        width: b.thumbW * b.p
                        height: b.thumbH * b.p
                        radius: 12
                        source: "file://" + modelData.path
                        T.Hit {
                            anchors.fill: parent
                            action: "open " + modelData.path
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
                        y: 5 + index * (b.rowH + 3) + 3
                        height: 5
                        font: "3x5"
                        text: modelData.name
                        color: Ink.blue
                    }
                }
                MatrixText {
                    x: b.padX
                    y: b.recentY
                    height: 7
                    text: "Recent captures"
                    color: Ink.blue
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
                        color: Ink.blue
                    }
                }
                MatrixText {
                    visible: !(root.ctx.recent ?? []).length
                    x: b.padX
                    y: b.recentY + 10
                    height: 5
                    font: "3x5"
                    text: "NOTHING CAPTURED YET"
                    color: Ink.navy
                    opacity: 0.4
                }
                MatrixText {
                    x: b.padX
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 5
                    width: b.cols - b.padX * 2
                    height: 5
                    font: "3x5"
                    scroll: true
                    text: "SCREENSHOTS GO TO PICTURES, RECORDINGS TO VIDEOS"
                    color: Ink.blue
                }
            }
        }
    }
}
