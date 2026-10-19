import QtQuick
import qs

// Screenshots, Tokyo Night: the latest shot big, as dots in a pink rim,
// the next four under it, and copy / edit / ocr / delete. Expanded, a
// gallery by day; a click picks a shot, its OCR text and keys below.
Face {
    id: root

    readonly property var items: ctx.items ?? []
    readonly property string latest: ctx.latest ?? ""
    function caption(s: var): string {
        return s ? Qt.formatTime(new Date(s.ts), "hh:mm") + " · " + String(s.name).replace(/\.[a-z]+$/i, "") : "";
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : sign
    }

    // A shot in a pink rim (cyan when picked), as dots.
    component Shot: Item {
        id: shot
        property var shot: null
        property bool picked: false
        property real radius: 10
        DotPic {
            anchors.fill: parent
            anchors.margins: 2
            radius: shot.radius - 2
            source: shot.shot ? "file://" + shot.shot.path : ""
        }
        Tube {
            anchors.fill: parent
            radius: shot.radius
            line: 2
            tint: shot.picked ? Ink.cyan : Ink.pink
            glow: shot.picked ? 0.9 : 0.5
        }
    }

    // ── Compact ─────────────────────────────────────────────────────
    Component {
        id: sign
        Item {
            id: s
            readonly property real padX: 18
            readonly property real innerW: width - padX * 2
            readonly property real keysH: 18
            readonly property real thumbH: Math.round((innerW - 24) / 4 * 0.56)
            readonly property real headH: 12 * root.pitch + 2
            readonly property real bigH: Math.max(30, height - headH - 6 - thumbH - 6 - keysH - 12 - 8)

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: 22
                color: Ink.glass
            }
            Glass {
                id: glass
                radius: 22
                Words {
                    x: root.d(s.padX)
                    y: 4
                    small: true
                    text: "スクショ · " + (root.words.title || "SHOTS")
                    color: Ink.violet
                }
                Words {
                    anchors.right: parent.right
                    anchors.rightMargin: root.d(s.padX)
                    y: 4
                    small: true
                    text: root.ctx.count ?? 0
                    color: Ink.violet
                }
                MatrixText {
                    x: root.d(s.padX) + 2
                    y: root.d(s.headH + s.bigH) - 7
                    width: root.d(s.innerW) - 4
                    height: 5
                    font: "3x5"
                    text: root.caption(root.items[0])
                    color: Ink.violet
                }
                Words {
                    visible: root.items.length === 0
                    anchors.centerIn: parent
                    text: "NO SHOTS YET"
                    color: Ink.deep
                }
            }
            Shot {
                visible: root.items.length > 0
                x: s.padX
                y: s.headH
                width: s.innerW
                height: s.bigH - 8 * root.pitch
                shot: root.items[0] ?? null
                radius: 12
                Hit {
                    anchors.fill: parent
                    action: "open " + root.latest
                }
            }
            Row {
                x: s.padX
                y: s.headH + s.bigH + 6
                spacing: 8
                Repeater {
                    model: root.items.slice(1, 5)
                    Shot {
                        required property var modelData
                        width: (s.innerW - 24) / 4
                        height: s.thumbH
                        shot: modelData
                        radius: 8
                        Hit {
                            anchors.fill: parent
                            action: "open " + modelData.path
                        }
                    }
                }
            }
            Row {
                x: s.padX
                y: s.height - 12 - s.keysH - 2
                spacing: 6
                Repeater {
                    model: [["copy", "copyimg "], ["edit", "edit "], ["ocr", "ocr "], ["delete", "trash "]]
                    Chip {
                        required property var modelData
                        visible: root.latest !== ""
                        text: modelData[0]
                        tone: "cyan"
                        size: 10
                        pad: 7
                        action: modelData[1] + root.latest
                    }
                }
            }
            Sign {
                radius: 22
            }
        }
    }

    // ── Expanded: the gallery ───────────────────────────────────────
    Component {
        id: board
        Item {
            id: b
            property string range: "ALL"
            property string pickedPath: root.latest
            readonly property var pick: root.items.find(x => x.path === pickedPath) ?? root.items[0] ?? null
            readonly property var days: {
                const weekAgo = Date.now() - 7 * 86400000;
                return (root.ctx.days ?? []).filter(d => range === "ALL" || (range === "TODAY" ? d.day === "Today" : d.shots[0].ts >= weekAgo));
            }
            readonly property real padX: 16
            readonly property real cellW: (width - padX * 2 - 3 * 10) / 4
            readonly property real cellH: Math.round(cellW * 0.62)
            readonly property real labelH: 20
            readonly property real footH: 76
            // The days, laid out: a label, then rows of four, until the room runs out.
            readonly property var laid: {
                const out = [];
                let y = 44;
                const max = height - footH - 10;
                for (const d of days) {
                    if (y + labelH + cellH > max)
                        break;
                    const rows = Math.min(Math.ceil(d.shots.length / 4), Math.floor((max - y - labelH) / (cellH + 10)));
                    out.push({ day: d.day, n: d.shots.length, shots: d.shots.slice(0, rows * 4), y: y });
                    y += labelH + rows * (cellH + 10);
                }
                return out;
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: 24
                color: Ink.glass
            }
            Glass {
                id: glass
                radius: 24
                MatrixText {
                    anchors.right: parent.right
                    anchors.rightMargin: root.d(b.padX)
                    y: root.d(16)
                    height: 5
                    font: "3x5"
                    text: (root.ctx.count ?? 0) + " SHOTS"
                    color: Ink.violet
                }
                Repeater {
                    model: b.laid
                    Words {
                        required property var modelData
                        x: root.d(b.padX)
                        y: root.d(modelData.y) + 1
                        small: true
                        text: String(modelData.day).toUpperCase() + " · " + modelData.n
                        color: Ink.violet
                    }
                }
                Repeater {
                    model: b.laid
                    Repeater {
                        id: dayRep
                        required property var modelData
                        model: modelData.shots
                        MatrixText {
                            required property var modelData
                            required property int index
                            x: root.d(b.padX + index % 4 * (b.cellW + 10)) + 2
                            y: root.d(dayRep.modelData.y + b.labelH + Math.floor(index / 4) * (b.cellH + 10) + b.cellH) - 7
                            width: root.d(b.cellW) - 4
                            height: 5
                            font: "3x5"
                            text: Qt.formatTime(new Date(modelData.ts), "hh:mm")
                            color: Ink.violet
                        }
                    }
                }
                // The picked shot: its name, its words.
                MatrixText {
                    x: root.d(b.padX)
                    y: root.d(b.height - b.footH)
                    width: root.d(b.width - b.padX * 2)
                    height: 5
                    font: "3x5"
                    text: b.pick ? b.pick.name + "   " + Qt.formatDateTime(new Date(b.pick.ts), "ddd hh:mm") : "NO SHOTS YET"
                    color: Ink.pink
                }
                MatrixText {
                    x: root.d(b.padX)
                    y: root.d(b.height - b.footH) + 8
                    width: root.d(b.width - b.padX * 2)
                    height: 5
                    font: "3x5"
                    scroll: true
                    text: root.ctx.ocr ? "OCR · " + root.ctx.ocr : "OCR · PRESS OCR TO READ THE TEXT IN IT"
                    color: Ink.violet
                }
            }
            // Range chips.
            Row {
                x: b.padX
                y: 14
                spacing: 6
                Repeater {
                    model: ["ALL", "TODAY", "WEEK"]
                    Chip {
                        required property string modelData
                        text: modelData.charAt(0) + modelData.slice(1).toLowerCase()
                        tone: b.range === modelData ? "on" : "pink"
                        size: 10
                        pad: 8
                        onTap: b.range = modelData
                    }
                }
            }
            Repeater {
                model: b.laid
                Repeater {
                    id: shotsRep
                    required property var modelData
                    model: modelData.shots
                    Shot {
                        required property var modelData
                        required property int index
                        x: b.padX + index % 4 * (b.cellW + 10)
                        y: shotsRep.modelData.y + b.labelH + Math.floor(index / 4) * (b.cellH + 10)
                        width: b.cellW
                        height: b.cellH - 8 * root.pitch
                        shot: modelData
                        picked: b.pick?.path === modelData.path
                        Hit {
                            anchors.fill: parent
                            onTap: b.pickedPath === modelData.path ? root.run("open " + modelData.path) : b.pickedPath = modelData.path
                        }
                    }
                }
            }
            Row {
                visible: b.pick !== null
                x: b.padX
                y: b.height - 36
                spacing: 6
                Repeater {
                    model: [["copy", "copyimg "], ["edit", "edit "], ["ocr", "ocr "], ["open", "open "], ["delete", "trash "]]
                    Chip {
                        required property var modelData
                        text: modelData[0]
                        tone: "cyan"
                        size: 10
                        pad: 8
                        action: modelData[1] + (b.pick?.path ?? "")
                    }
                }
            }
            Sign {
                radius: 24
            }
        }
    }
}
