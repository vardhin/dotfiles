import QtQuick
import qs
import qs.tokyo as T

// Capture, Nixie: a plate camera's lens in its brass mount, the plates
// taken today on four tubes and a dark ON AIR lamp, and brass keys: SHOT
// takes the target, REC (the hot key) records, REGION and WINDOW pick the
// target (polished). Recording, the lamp glows and blinks, the tubes count
// the seconds on air, and STOP and MIC take over. Expanded, OPTIONS: the
// case's dot screen with the target, the audio and what to take as rows of
// keys, then the latest plates in ivory frames with their names.
T.Face {
    id: root

    readonly property bool recording: !!ctx.recording
    // What SHOT and REC take, picked here or on the expanded board.
    property string target: "area"
    readonly property string elapsed: recording ? String(ctx.elapsed ?? "00:00") : "00:00"
    readonly property int today: (ctx.recent ?? []).filter(r => new Date(r.ts).toDateString() === new Date().toDateString()).length

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : desk
    }

    // ── Compact ─────────────────────────────────────────────────────
    Component {
        id: desk
        Item {
            id: c
            readonly property real lensD: Math.min(height - 24, width * 0.26)
            readonly property real keyH: 18
            readonly property real tubeH: Math.max(22, Math.min(height - 24 - keyH - 30, 52))

            Wood {
                anchors.fill: parent
            }
            Lens {
                id: lens
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                width: c.lensD
                height: c.lensD
                live: root.recording
            }
            Column {
                x: lens.x + lens.width + 14
                anchors.verticalCenter: parent.verticalCenter
                width: c.width - x - 14
                spacing: 6
                Row {
                    spacing: 10
                    Tubes {
                        id: count
                        height: c.tubeH
                        tubeW: c.tubeH * 0.57
                        gap: 2
                        text: root.recording ? root.elapsed.replace(":", "").padStart(4, "0").slice(-4) : String(Math.min(9999, root.today)).padStart(4, "0")
                    }
                    // ON AIR: dark until it records, then glowing and blinking.
                    Item {
                        anchors.verticalCenter: count.verticalCenter
                        width: air.implicitWidth + 12
                        height: 16
                        Glow {
                            anchors.fill: parent
                            radius: 3
                            color: root.recording ? Ink.deep : Ink.woodA
                            halo: root.recording ? 5 : 0
                            property real blink: 1
                            opacity: root.recording ? blink : 1
                            SequentialAnimation on blink {
                                running: root.recording
                                loops: Animation.Infinite
                                NumberAnimation {
                                    to: 0.55
                                    duration: 600
                                }
                                NumberAnimation {
                                    to: 1
                                    duration: 600
                                }
                            }
                        }
                        Print {
                            id: air
                            anchors.centerIn: parent
                            text: "ON AIR"
                            size: 8
                            spacing: 1
                            color: root.recording ? Ink.digit : Ink.woodB
                        }
                    }
                }
                Print {
                    width: parent.width
                    text: root.recording ? "SECONDS ON AIR · " + root.elapsed : "PLATES TAKEN TODAY"
                    size: 7
                }
                Row {
                    spacing: 6
                    readonly property real w: c.width - lens.x - lens.width - 28
                    Repeater {
                        model: root.recording ? [
                            { t: "STOP", a: "capture stop", on: false, tone: "hot" },
                            { t: "MIC", a: "capture audio", on: !!root.ctx.audio, tone: "" }
                        ] : [
                            { t: "SHOT", a: "capture shot " + root.target, on: false, tone: "" },
                            { t: "REC", a: "capture rec " + (root.target === "area" ? "area" : "screen"), on: false, tone: "hot" },
                            { t: "REGION", a: "", on: root.target === "area", pick: "area", tone: "" },
                            { t: "WINDOW", a: "", on: root.target === "window", pick: "window", tone: "" }
                        ]
                        Key {
                            required property var modelData
                            width: Math.min(64, (parent.w - 6 * 3) / 4)
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
    }

    // ── Expanded: the options ───────────────────────────────────────
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
            readonly property real padX: 24
            readonly property real labW: Math.max(60, width * 0.2)
            readonly property real rowH: 22
            readonly property real rowY: 26
            readonly property real recentY: rowY + opts.length * (rowH + 10) + 4
            readonly property real thumbW: (width - padX * 2 - 24) / 4
            readonly property real thumbH: Math.max(24, Math.min(thumbW * 0.56, height - recentY - 9 * p - 24 - 8 * p - 14))
            function dx(px: real): int {
                return Math.round((px - box.sx - box.screen.surface.x) / p);
            }
            function dy(px: real): int {
                return Math.round((px - box.sy - box.screen.surface.y) / p);
            }
            readonly property int x0: dx(padX)
            readonly property int w0: dx(width - padX) - x0

            Case {
                id: box
                anchors.fill: parent
                Repeater {
                    model: b.opts
                    MatrixText {
                        required property var modelData
                        required property int index
                        x: b.x0
                        y: b.dy(b.rowY + index * (b.rowH + 10) + b.rowH / 2) - 2
                        height: 5
                        font: "3x5"
                        text: modelData.name
                        color: Ink.brass
                    }
                }
                MatrixText {
                    x: b.x0
                    y: b.dy(b.recentY) + 1
                    height: 5
                    font: "3x5"
                    text: "PLATES"
                    color: Ink.brass
                }
                Repeater {
                    model: (root.ctx.recent ?? []).slice(0, 4)
                    MatrixText {
                        required property var modelData
                        required property int index
                        x: b.dx(b.padX + index * (b.thumbW + 8))
                        y: b.dy(b.recentY + 9 * b.p + b.thumbH + 4)
                        width: Math.floor(b.thumbW / b.p)
                        height: 5
                        font: "3x5"
                        align: "center"
                        text: String(modelData.name).replace(/\.[a-z0-9]+$/i, "").slice(-12)
                        color: Ink.amber
                    }
                }
                MatrixText {
                    visible: !(root.ctx.recent ?? []).length
                    x: b.x0
                    y: b.dy(b.recentY) + 10
                    height: 5
                    font: "3x5"
                    text: "NO PLATES YET"
                    color: Ink.deep
                }
                MatrixText {
                    x: b.x0
                    y: box.screen.rows - Math.ceil(10 / b.p) - 5
                    width: b.w0
                    height: 5
                    font: "3x5"
                    scroll: true
                    text: "SHOTS GO TO ~/PICTURES · RECORDINGS TO ~/VIDEOS"
                    color: Ink.brass
                }
            }
            Repeater {
                model: b.opts
                Row {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property real w: b.width - b.padX * 2 - b.labW
                    x: b.padX + b.labW
                    y: b.rowY + index * (b.rowH + 10)
                    spacing: 8
                    Repeater {
                        model: row.modelData.keys
                        Key {
                            required property var modelData
                            width: (row.w - 16) / 3
                            height: b.rowH
                            text: modelData[0]
                            on: modelData[1] && modelData[0].indexOf("STOP") < 0
                            tone: modelData[0] === "RECORD" || modelData[0].indexOf("STOP") === 0 ? "hot" : ""
                            onTap: modelData[2]()
                        }
                    }
                }
            }
            // The plates, in ivory frames.
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
                            color: Ink.paper
                        }
                        T.DotPic {
                            anchors.fill: parent
                            anchors.margins: 3
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
        }
    }
}
