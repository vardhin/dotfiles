import QtQuick
import qs
import qs.services
import qs.tokyo as T

// Capture, 90s Nights: a camcorder's viewfinder. Its on-screen display in
// VT323 white with a hard shadow: STBY SP (● REC SP in red, blinking, while
// recording), the battery as four bars, the framing box in the middle, the
// tape counter, the date and time in yellow, and OSD keys: SHOT takes the
// target, REC (red) records, REGION and WINDOW pick the target (yellow).
// Recording: STOP and MIC. Expanded, MENU · CAMERA: TARGET, AUDIO and TAKE
// as rows of keys (the picked one yellow), labels in lit dots, then the
// latest shots in white frames with their names, and where tapes go.
T.Face {
    id: root

    readonly property bool recording: !!ctx.recording
    // What SHOT and REC take, picked here or on the expanded board.
    property string target: "area"
    readonly property string elapsed: recording ? String(ctx.elapsed ?? "00:00") : "00:00"
    // The tape counter, H:MM:SS.
    readonly property string counter: {
        const p = elapsed.split(":");
        return p.length >= 3 ? elapsed : "0:" + (p[0] ?? "00").padStart(2, "0") + ":" + (p[1] ?? "00").padStart(2, "0");
    }
    readonly property date now: {
        void root.ctx.elapsed;
        void clock.tick;
        return new Date();
    }
    readonly property string stamp: Qt.formatDate(now, "MMM.dd yyyy").toUpperCase() + " · " + Qt.formatTime(now, "hh:mm")
    readonly property int bars: Math.max(0, Math.min(4, Math.ceil((Power.fraction ?? 1) * 4)))
    property bool blink: true

    Timer {
        id: clock
        property int tick: 0
        interval: 600
        repeat: true
        running: root.visible
        onTriggered: {
            tick++;
            root.blink = !root.blink;
        }
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : leanFinder
    }

    // Compact, leaning with the signs.
    Component {
        id: leanFinder
        Item {
            Plate {
                anchors.fill: parent
            }
            Leaning {
                anchors.fill: parent
                anchors.margins: 9
                Loader {
                    anchors.fill: parent
                    sourceComponent: finder
                }
            }
        }
    }

    // ── Compact: the viewfinder ─────────────────────────────────────
    Component {
        id: finder
        Item {
            id: c
            readonly property real big: Math.max(16, Math.min(22, height * 0.17))

            Cam {
                id: cam
                anchors.fill: parent
                bare: true
                pad: 0
            }
            Item {
                x: cam.sx
                y: cam.sy
                width: cam.sw
                height: cam.sh

                // STBY SP / ● REC SP
                Row {
                    x: 12
                    y: 6
                    spacing: 8
                    Mono {
                        visible: !root.recording || root.blink
                        text: root.recording ? "● REC" : "STBY"
                        size: c.big
                        shade: true
                        color: root.recording ? Ink.red : Ink.c("#ffffff", "#ffffff")
                    }
                    Mono {
                        text: "SP"
                        size: c.big
                        shade: true
                        color: Ink.c("#ffffff", "#ffffff")
                    }
                }
                // The battery's four bars.
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    y: 8
                    spacing: 3
                    Repeater {
                        model: 4
                        Rectangle {
                            required property int index
                            width: Math.round(c.big * 0.32)
                            height: Math.round(c.big * 0.8)
                            color: index < root.bars ? Ink.c("#ffffff", "#ffffff") : "transparent"
                            border.width: 1
                            border.color: Ink.c("#ffffff", "#ffffff")
                        }
                    }
                }
                // The framing box.
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.round(parent.width * 0.14)
                    height: Math.round(width * 0.65)
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.6)
                }
                Mono {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.counter
                    size: c.big
                    shade: true
                    color: Ink.c("#ffffff", "#ffffff")
                }
                // The date, and the keys.
                Mono {
                    x: 12
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    visible: keys.x > x + implicitWidth + 6
                    text: root.stamp
                    size: Math.round(c.big * 0.8)
                    shade: true
                    color: Ink.c("#ffe600", "#ffe600")
                }
                Row {
                    id: keys
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    spacing: 6
                    Repeater {
                        model: root.recording ? [
                            { t: "STOP", a: "capture stop", tone: "red" },
                            { t: "MIC", a: "capture audio", tone: root.ctx.audio ? "yellow" : "" }
                        ] : [
                            { t: "SHOT", a: "capture shot " + root.target, tone: "" },
                            { t: "REC", a: "capture rec " + (root.target === "area" ? "area" : "screen"), tone: "red" },
                            { t: "REGION", a: "", pick: "area", tone: root.target === "area" ? "yellow" : "" },
                            { t: "WINDOW", a: "", pick: "window", tone: root.target === "window" ? "yellow" : "" }
                        ]
                        Osd {
                            required property var modelData
                            text: modelData.t
                            tone: modelData.tone
                            action: modelData.a
                            textPx: Math.round(c.big * 0.7)
                            onTap: if (modelData.pick)
                                root.target = modelData.pick
                        }
                    }
                }
            }
        }
    }

    // ── Expanded: the menu ──────────────────────────────────────────
    Component {
        id: board
        Item {
            id: b
            readonly property var opts: [
                { name: "TARGET", keys: [["REGION", root.target === "area", () => root.target = "area"], ["WINDOW", root.target === "window", () => root.target = "window"], ["SCREEN", root.target === "screen", () => root.target = "screen"]] },
                { name: "AUDIO", keys: [["NONE", !root.ctx.audio, () => { if (root.ctx.audio) root.run("capture audio"); }], ["MIC", !!root.ctx.audio, () => { if (!root.ctx.audio) root.run("capture audio"); }]] },
                { name: "TAKE", keys: [["SHOT", false, () => root.run("capture shot " + root.target)], [root.recording ? "STOP " + (root.ctx.elapsed ?? "") : "RECORD", false, () => root.run(root.recording ? "capture stop" : "capture rec " + (root.target === "area" ? "area" : "screen"))], ["PICK COLOR", false, () => root.run("capture pick")]] }
            ]
            readonly property int p: Tokens.pitch
            readonly property real padX: 12
            readonly property real labW: 6 * 6 * p + 12
            readonly property real rowH: 22
            readonly property real rowY: 12
            readonly property real recentY: rowY + opts.length * (rowH + 9) + 4
            readonly property real thumbW: (cam.sw - padX * 2 - 24) / 4
            readonly property real thumbH: Math.max(24, Math.min(thumbW * 0.56, cam.sh - recentY - 9 * p - 9 * p - 22))

            Plate {
                anchors.fill: parent
                slant: false
            }
            Cam {
                id: cam
                anchors.fill: parent
                bare: true
                pad: 10
                head: 22
            }
            // MENU · CAMERA                                       SP
            Mono {
                x: 14
                y: 6
                height: 20
                text: "MENU · CAMERA"
                size: 18
                shade: true
                color: Ink.yellow
            }
            Mono {
                anchors.right: parent.right
                anchors.rightMargin: 14
                y: 6
                height: 20
                text: root.recording ? "● REC " + root.elapsed : "SP"
                size: 18
                shade: true
                color: root.recording ? Ink.red : Ink.blue
            }
            Item {
                id: screen
                x: cam.sx
                y: cam.sy
                width: cam.sw
                height: cam.sh

                // The labels and names, lit dots on the screen.
                Dots {
                    anchors.fill: parent
                    Repeater {
                        model: b.opts
                        MatrixText {
                            required property var modelData
                            required property int index
                            x: Math.round(b.padX / b.p)
                            y: Math.round((b.rowY + index * (b.rowH + 9) + b.rowH / 2) / b.p) - 3
                            height: 7
                            text: modelData.name
                            color: Ink.c("#ffffff", "#ffffff")
                        }
                    }
                    MatrixText {
                        x: Math.round(b.padX / b.p)
                        y: Math.round(b.recentY / b.p) + 1
                        height: 7
                        text: "RECENT"
                        color: Ink.c("#ffffff", "#ffffff")
                    }
                    Repeater {
                        model: (root.ctx.recent ?? []).slice(0, 4)
                        MatrixText {
                            required property var modelData
                            required property int index
                            x: Math.round((b.padX + index * (b.thumbW + 8)) / b.p)
                            y: Math.round((b.recentY + 9 * b.p + b.thumbH + 4) / b.p)
                            width: Math.floor(b.thumbW / b.p)
                            height: 5
                            font: "3x5"
                            align: "center"
                            text: String(modelData.name).replace(/\.[a-z0-9]+$/i, "").slice(-12)
                            color: Ink.c("#ffe600", "#ffe600")
                        }
                    }
                    MatrixText {
                        visible: !(root.ctx.recent ?? []).length
                        x: Math.round(b.padX / b.p)
                        y: Math.round(b.recentY / b.p) + 11
                        height: 5
                        font: "3x5"
                        text: "NO TAPES YET"
                        color: Ink.dim
                    }
                    MatrixText {
                        x: Math.round(b.padX / b.p)
                        y: Math.floor((screen.height - 8) / b.p) - 5
                        width: Math.floor((screen.width - b.padX * 2) / b.p)
                        height: 5
                        font: "3x5"
                        scroll: true
                        text: Qt.formatDate(root.now, "MMM.dd yyyy").toUpperCase() + " · SHOTS GO TO ~/PICTURES · TAPES TO ~/VIDEOS"
                        color: Ink.c("#ffe600", "#ffe600")
                    }
                }
                Repeater {
                    model: b.opts
                    Row {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property real w: screen.width - b.padX * 2 - b.labW
                        x: b.padX + b.labW
                        y: b.rowY + index * (b.rowH + 9)
                        spacing: 4
                        Repeater {
                            model: row.modelData.keys
                            Osd {
                                required property var modelData
                                width: (row.w - 8) / 3
                                height: b.rowH
                                textPx: 17
                                text: modelData[0]
                                on: modelData[1]
                                tone: modelData[0] === "RECORD" || modelData[0].indexOf("STOP") === 0 ? "red" : ""
                                onTap: modelData[2]()
                            }
                        }
                    }
                }
                // The latest shots, in white frames.
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
                                color: Ink.c("#ffffff", "#ffffff")
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
            }
        }
    }
}
