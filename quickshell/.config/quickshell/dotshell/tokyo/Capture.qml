import QtQuick
import QtQuick.Effects
import qs
import qs.services

// Capture, Tokyo Night: a neon camera (its lens a pink ring; a red light,
// blinking, while recording), the state in big letters and a row of neon
// buttons. Expanded, the options as switch rows and the last captures.
Face {
    id: root

    readonly property bool recording: !!ctx.recording
    // What SHOT and REC take, picked on the expanded board.
    property string target: "area"

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : sign
    }

    // The camera: a cyan body, a hump on top, the lens.
    component Camera: Item {
        id: cam
        property bool rec: false
        property real blink: 1
        readonly property real line: Math.max(2, Math.round(height * 0.05))
        Tube {
            y: cam.height * 0.15
            width: cam.width
            height: cam.height * 0.85
            radius: Math.round(height * 0.2)
            line: cam.line
            tint: Ink.cyan
            glow: 0.8
        }
        Rectangle {
            x: cam.width * 0.16
            width: cam.width * 0.27
            height: cam.height * 0.15 + cam.line
            radius: 4
            color: "transparent"
            border.width: cam.line
            border.color: Ink.cyan
            Rectangle {
                anchors.bottom: parent.bottom
                x: cam.line
                width: parent.width - cam.line * 2
                height: cam.line
                color: Ink.glass
            }
        }
        Tube {
            readonly property real dia: cam.height * 0.48
            x: (cam.width - dia) / 2
            y: cam.height * 0.15 + (cam.height * 0.85 - dia) / 2
            width: dia
            height: dia
            radius: dia / 2
            line: cam.line
            tint: cam.rec ? Ink.red : Ink.pink
            fill: cam.rec ? Ink.red : "transparent"
            opacity: cam.rec ? cam.blink : 1
            glow: 0.8
        }
    }

    // ── Compact ─────────────────────────────────────────────────────
    Component {
        id: sign
        Item {
            id: s
            readonly property real camH: Math.round(height * 0.44)
            readonly property real camW: Math.round(camH * 1.4)
            readonly property real padX: Math.round(height * 0.15)
            readonly property real textX: padX + camW + Math.round(height * 0.12)

            Glass {
                id: glass
                radius: 26
                Column {
                    id: says
                    x: root.d(s.textX)
                    y: root.d(s.height * 0.16)
                    spacing: 1
                    Neon {
                        text: root.recording ? "REC " + (root.ctx.elapsed ?? "") : "READY"
                        size: Math.round(glass.rows * 0.27)
                        height: Math.round(size * 0.9)
                        color: root.recording ? Ink.red : Ink.cyan
                        halo: true
                    }
                    Words {
                        small: true
                        text: root.recording ? "録画中 · RECORDING" : "撮影 · CAPTURE"
                        color: Ink.violet
                    }
                }
            }
            Camera {
                x: s.padX
                y: (s.height - height) / 2
                width: s.camW
                height: s.camH
                rec: root.recording
                blink: root.ctx.blink ?? 1
            }
            Flow {
                x: s.textX
                y: glass.y + (says.y + says.height) * root.pitch + 5
                width: s.width - s.textX - s.padX * 0.6
                spacing: 4
                Repeater {
                    // Four keys when there is room, the three most used when not.
                    model: root.recording ? [
                        { t: "STOP", tone: "red", a: "capture stop" },
                        { t: "MIC", tone: root.ctx.audio ? "cyan" : "dim", a: "capture audio" }
                    ] : [
                        { t: "SHOT", tone: "dim", a: "capture shot screen" },
                        { t: "REC", tone: "red", a: "capture rec screen" },
                        { t: "REGION", tone: "cyan", a: "capture shot area" },
                        { t: "WINDOW", tone: "dim", a: "capture shot window" }
                    ].filter((k, i) => s.width >= 330 || i > 0)
                    Chip {
                        required property var modelData
                        text: modelData.t
                        tone: modelData.tone
                        action: modelData.a
                        size: 9
                        pad: 5
                    }
                }
            }
            Sign {
                radius: 26
            }
        }
    }

    // ── Expanded: options and recent ────────────────────────────────
    Component {
        id: board
        Item {
            id: b
            readonly property var rows: [
                { name: "TARGET", opts: [["REGION", root.target === "area", () => root.target = "area"], ["WINDOW", root.target === "window", () => root.target = "window"], ["SCREEN", root.target === "screen", () => root.target = "screen"]] },
                { name: "AUDIO", opts: [["NONE", !root.ctx.audio, () => { if (root.ctx.audio) root.run("capture audio"); }], ["MIC", !!root.ctx.audio, () => { if (!root.ctx.audio) root.run("capture audio"); }]] },
                { name: "TAKE", opts: [["SHOT", false, () => root.run("capture shot " + root.target)], [root.recording ? "STOP " + (root.ctx.elapsed ?? "") : "RECORD", root.recording, () => root.run(root.recording ? "capture stop" : "capture rec " + (root.target === "area" ? "area" : "screen"))], ["PICK COLOR", false, () => root.run("capture pick")]] }
            ]
            readonly property int rowH: 9

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: 30
                color: Ink.glass
            }
            Item {
                id: well
                anchors.fill: parent
                anchors.margins: 12

                Glass {
                    id: glass
                    radius: 20
                    Repeater {
                        model: b.rows
                        MatrixText {
                            required property var modelData
                            required property int index
                            x: 5
                            y: 5 + index * (b.rowH + 2) + 2
                            height: 5
                            font: "3x5"
                            text: modelData.name
                            color: Ink.violet
                        }
                    }
                    MatrixText {
                        id: recentWord
                        x: 5
                        y: 5 + b.rows.length * (b.rowH + 2) + 2
                        height: 5
                        font: "3x5"
                        text: "RECENT"
                        color: Ink.violet
                    }
                    // The names under the thumbnails.
                    Repeater {
                        model: (root.ctx.recent ?? []).slice(0, 4)
                        MatrixText {
                            required property var modelData
                            required property int index
                            readonly property int cw: Math.floor((glass.cols - 10 - 9) / 4)
                            x: 5 + index * (cw + 3)
                            y: recentWord.y + 8 + Math.ceil(thumbs.height / root.pitch) + 2
                            width: cw
                            height: 5
                            font: "3x5"
                            align: "center"
                            text: String(modelData.name).replace(/\.[a-z0-9]+$/i, "").slice(-12)
                            color: Ink.violet
                        }
                    }
                    MatrixText {
                        x: 5
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 4
                        width: glass.cols - 10
                        height: 5
                        font: "3x5"
                        scroll: true
                        text: "SHOTS GO TO ~/PICTURES/SCREENSHOTS · RECORDINGS TO ~/VIDEOS/RECORDINGS"
                        color: Ink.violet
                    }
                }

                // The switches, crisp: three to a row, the picked one lit.
                Repeater {
                    model: b.rows
                    Row {
                        id: opts
                        required property var modelData
                        required property int index
                        readonly property real w: (glass.cols - 10 - 32) * root.pitch
                        x: glass.x + (5 + 32) * root.pitch
                        y: glass.y + (5 + index * (b.rowH + 2)) * root.pitch
                        spacing: 6
                        Repeater {
                            model: opts.modelData.opts
                            Chip {
                                required property var modelData
                                width: (opts.w - 12) / 3
                                height: b.rowH * root.pitch - 2
                                size: 11
                                text: modelData[0]
                                tone: modelData[1] ? (opts.modelData.name === "TAKE" ? "red" : "on") : "pink"
                                onTap: modelData[2]()
                            }
                        }
                    }
                }
                // The last captures, as they are.
                Row {
                    id: thumbs
                    x: glass.x + 5 * root.pitch
                    y: glass.y + (recentWord.y + 8) * root.pitch
                    spacing: 3 * root.pitch
                    readonly property real cw: Math.floor((glass.cols - 10 - 9) / 4) * root.pitch
                    height: Math.round(cw * 0.56)
                    Repeater {
                        model: (root.ctx.recent ?? []).slice(0, 4)
                        Item {
                            required property var modelData
                            width: thumbs.cw
                            height: thumbs.height
                            Image {
                                id: pic
                                anchors.fill: parent
                                anchors.margins: 2
                                source: "file://" + modelData.path
                                sourceSize: Qt.size(width * 2, height * 2)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: false
                            }
                            Rectangle {
                                id: mask
                                anchors.fill: pic
                                radius: 8
                                visible: false
                                layer.enabled: true
                            }
                            MultiEffect {
                                anchors.fill: pic
                                source: pic
                                maskEnabled: true
                                maskSource: mask
                                maskThresholdMin: 0.5
                                maskSpreadAtMin: 1
                            }
                            Tube {
                                anchors.fill: parent
                                radius: 10
                                line: 2
                                tint: Ink.pink
                                glow: 0.5
                            }
                            Hit {
                                anchors.fill: parent
                                action: "open " + modelData.path
                            }
                        }
                    }
                }
            }
            Sign {
                radius: 30
                inner: true
                innerInset: 12
            }
        }
    }
}
