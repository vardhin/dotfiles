import QtQuick
import qs.services

// The media panel, compact, in the Phosphor era: a TUI box on an amber CRT
// (panel design canvas, "Now playing", sk.phosphor). All of it is dots, the
// rule and its legend too, with scanlines over the glass.
//
//   ┤ MPV · NOW PLAYING ├═══════════════════════ TTY1 ═╗
//   ║ ┌──────┐ > TRACK TITLE█                          ║
//   ║ │ art  │   ARTIST · ALBUM                         ║
//   ║ │      │ [########------------] 01:38/03:54       ║
//   ║ └──────┘ [|<] [||] [>|]                          ║
//   ╚═══════════════════════════════════════════════════╝
//
// The keys are words in dots that click.
Item {
    id: root

    required property var ctx
    required property var sink
    required property var panel
    required property var words

    readonly property bool active: !!ctx.active
    readonly property bool playing: !!ctx.playing
    readonly property real progress: active ? (ctx.progress ?? 0) : 0

    // Clicks and drags from a key: a hold or a drag still lifts the panel.
    function grip(kind: string, area: Item, mouse: var): bool {
        const p = area.mapToItem(null, mouse?.x ?? 0, mouse?.y ?? 0);
        return sink.grip(kind, p.x, p.y);
    }

    DotSurface {
        id: screen
        anchors.centerIn: parent
        cols: Math.floor(parent.width / pitch)
        rows: Math.floor(parent.height / pitch)

        Item {
            id: tty
            width: screen.cols
            height: screen.rows

            // ── The double rule, the legend cut into its top ────────
            readonly property int r0: 1
            readonly property int r1: 3
            readonly property string legend: "┤ MPV · NOW PLAYING ├"
            readonly property int legendX: 6
            readonly property int legendW: legendText.implicitWidth + 2
            readonly property int ttyW: ttyText.implicitWidth + 2

            Repeater {
                model: [tty.r0, tty.r1]
                Item {
                    id: rule
                    required property int modelData
                    readonly property int i: modelData
                    // Top: broken where the words are.
                    Rectangle {
                        x: rule.i
                        y: rule.i
                        width: tty.legendX - 1 - rule.i
                        height: 1
                        color: Tokens.slot2
                    }
                    Rectangle {
                        x: tty.legendX + tty.legendW
                        y: rule.i
                        width: tty.width - rule.i - 6 - tty.ttyW - 1 - x
                        height: 1
                        color: Tokens.slot2
                    }
                    Rectangle {
                        x: tty.width - rule.i - 6
                        y: rule.i
                        width: 6 - rule.i
                        height: 1
                        color: Tokens.slot2
                    }
                    Rectangle {
                        x: rule.i
                        y: tty.height - 1 - rule.i
                        width: tty.width - rule.i * 2
                        height: 1
                        color: Tokens.slot2
                    }
                    Rectangle {
                        x: rule.i
                        y: rule.i
                        width: 1
                        height: tty.height - rule.i * 2
                        color: Tokens.slot2
                    }
                    Rectangle {
                        x: tty.width - 1 - rule.i
                        y: rule.i
                        width: 1
                        height: tty.height - rule.i * 2
                        color: Tokens.slot2
                    }
                }
            }
            MatrixText {
                id: legendText
                font: "3x5"
                x: tty.legendX
                y: 0
                width: implicitWidth
                height: implicitHeight
                text: tty.legend
                color: Tokens.slot2
            }
            MatrixText {
                id: ttyText
                font: "3x5"
                x: tty.width - 6 - tty.ttyW + 1
                y: 0
                width: implicitWidth
                height: implicitHeight
                text: "TTY1"
                color: Tokens.slot2
            }

            // ── Inside the box ──────────────────────────────────────
            readonly property int padX: 6
            readonly property int boxTop: 7
            readonly property int boxBottom: height - 6
            // Four lines, as tight as the room lets them sit.
            readonly property int lineGap: Math.max(2, Math.min(3, Math.floor((boxBottom - boxTop - 28) / 3)))
            readonly property int blockH: 28 + lineGap * 3
            readonly property int blockY: boxTop + Math.max(0, Math.floor((boxBottom - boxTop - blockH) / 2))
            readonly property int lineStep: 7 + lineGap
            readonly property bool artOn: width - padX * 2 - blockH - 5 >= 60
            readonly property int textX: padX + (artOn ? blockH + 5 : 0)
            readonly property int textW: width - padX - textX

            MediaArt {
                visible: tty.artOn
                x: tty.padX
                y: tty.blockY
                width: tty.blockH
                height: tty.blockH
                src: root.active ? (root.ctx.art ?? "") : ""
                stripe: Tokens.slot2
                sun: Tokens.slot1
                ground: Tokens.unlit
            }

            // > TRACK TITLE█
            MatrixText {
                id: title
                x: tty.textX
                y: tty.blockY
                width: tty.textW
                height: implicitHeight
                scroll: true
                text: "> " + (root.active ? (root.ctx.title || root.words.idle) : root.words.idle)
                color: Tokens.slot1
            }
            Rectangle {
                property bool on: true
                visible: on && title.shown.length < title.capacity
                x: tty.textX + title.shown.length * title.advance
                y: tty.blockY
                width: 5
                height: 7
                color: Tokens.slot1
                Timer {
                    interval: 530
                    repeat: true
                    running: root.visible
                    onTriggered: parent.on = !parent.on
                }
            }

            //   ARTIST · ALBUM
            MatrixText {
                x: tty.textX
                y: tty.blockY + tty.lineStep
                width: tty.textW
                height: implicitHeight
                scroll: true
                text: "  " + (root.active ? [root.ctx.artist, root.ctx.album].filter(s => !!s).join(" · ") : (root.ctx.count ?? 0) + " IN THE LIBRARY")
                color: Tokens.slot0
            }

            // [########------------] 01:38/03:54 (click to seek)
            MatrixText {
                id: bar
                x: tty.textX
                y: tty.blockY + tty.lineStep * 2
                width: tty.textW
                height: implicitHeight
                color: Tokens.slot0
                readonly property int cap: Math.max(0, Math.floor((width + 1) / 6))
                readonly property string pos: root.active ? Media.clock(root.ctx.pos) : "-:--"
                // The time and length, or just the time, or none: whatever
                // leaves the bar six cells.
                readonly property string time: [pos + "/" + (root.active ? Media.clock(root.ctx.len) : "-:--"), pos].find(s => cap - 3 - s.length >= 6) ?? ""
                readonly property int n: Math.max(0, cap - 2 - (time ? time.length + 1 : 0))
                readonly property int lit: Math.round(root.progress * n)
                text: "[" + "#".repeat(lit) + "-".repeat(n - lit) + "]" + (time ? " " + time : "")
                MouseArea {
                    width: (bar.n + 2) * 6
                    height: parent.height
                    enabled: root.active
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => Media.seekTo(Math.max(0, Math.min(1, (mouse.x - 6) / (bar.n * 6))))
                }
            }

            // [|<] [||] [>|]
            Row {
                id: keys
                x: tty.textX
                y: tty.blockY + tty.lineStep * 3
                spacing: 6
                DotKey {
                    text: "[|<]"
                    color: Tokens.slot0
                    grip: root.grip
                    onAct: Media.previous()
                }
                DotKey {
                    text: root.playing ? "[||]" : "[>]"
                    color: Tokens.slot1
                    grip: root.grip
                    onAct: Media.toggle()
                }
                DotKey {
                    text: "[>|]"
                    color: Tokens.slot0
                    grip: root.grip
                    onAct: Media.next()
                }
            }

        }
    }

    // A CRT's scanlines over the glass.
    Canvas {
        anchors.fill: parent
        onHeightChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            const c = getContext("2d");
            c.reset();
            c.fillStyle = Qt.rgba(0, 0, 0, 0.35);
            for (let y = 0; y < height; y += 3)
                c.fillRect(0, y, width, 1);
        }
    }
}
