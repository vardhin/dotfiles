import QtQuick
import qs

// Downloads, Tokyo Night: what is coming in (cyan, with its speed) over
// the last few that landed and the folder each went to. Expanded, the
// active one in a lit card with a dot bar, today's files with OPEN /
// REVEAL / UNDO, and how many landed in each bin.
Face {
    id: root

    readonly property var active: ctx.active ?? []
    readonly property var recent: ctx.recent ?? []
    readonly property var now: active[0] ?? null
    readonly property int today: {
        const t = new Date().toDateString();
        return recent.filter(r => new Date(r.ts).toDateString() === t).length;
    }
    function pct(v: real): int {
        return Math.round(v > 1 ? v : v * 100);
    }
    function where(r: var): string {
        return r.dir ? r.dir : r.bin ? "~/" + String(r.bin).charAt(0) + String(r.bin).slice(1).toLowerCase() : "";
    }
    function size(b: real): string {
        return !b ? "" : b >= 1e9 ? (b / 1e9).toFixed(1) + " GB" : b >= 1e6 ? (b / 1e6).toFixed(1) + " MB" : Math.round(b / 1e3) + " KB";
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : sign
    }

    // ── Compact ─────────────────────────────────────────────────────
    Component {
        id: sign
        Item {
            id: s
            readonly property int padX: 6
            Glass {
                id: glass
                radius: 26
                Words {
                    x: s.padX
                    y: 5
                    small: true
                    room: glass.cols - s.padX * 2 - todayWord.implicitWidth - 4
                    text: "到着 · ↓ " + (root.words.title || "DOWNLOADS")
                    color: Ink.violet
                }
                Words {
                    id: todayWord
                    anchors.right: parent.right
                    anchors.rightMargin: s.padX
                    y: 5
                    small: true
                    text: root.today + " " + (root.words.today || "TODAY")
                    color: Ink.cyan
                }
                Column {
                    x: s.padX
                    y: 15
                    width: glass.cols - s.padX * 2
                    spacing: 3
                    // Coming in: name, then percent and speed.
                    Item {
                        visible: root.now !== null
                        width: parent.width
                        height: 7
                        MatrixText {
                            width: parent.width - rate.implicitWidth - 4
                            height: 5
                            y: 1
                            font: "3x5"
                            text: root.now?.name ?? ""
                            color: Ink.cyan
                            scroll: true
                        }
                        MatrixText {
                            id: rate
                            width: Math.min(implicitWidth, parent.width * 0.55)
                            anchors.right: parent.right
                            y: 1
                            height: 5
                            font: "3x5"
                            text: root.pct(root.now?.pct ?? 0) + "%" + (root.now?.speed ? " · " + root.now.speed : "")
                            color: Ink.pink
                        }
                    }
                    Repeater {
                        model: root.recent.slice(0, Math.max(0, Math.floor((glass.rows - 18 - (root.now ? 10 : 0)) / 8)))
                        Item {
                            required property var modelData
                            width: parent.width
                            height: 5
                            MatrixText {
                                width: parent.width - dest.implicitWidth - 4
                                height: 5
                                font: "3x5"
                                text: modelData.name
                                color: Ink.pink
                            }
                            MatrixText {
                                id: dest
                                anchors.right: parent.right
                                height: 5
                                font: "3x5"
                                text: "→ " + root.where(modelData)
                                color: Ink.violet
                            }
                            Hit {
                                anchors.fill: parent
                                action: "open " + modelData.path
                            }
                        }
                    }
                }
                Words {
                    visible: !root.now && root.recent.length === 0
                    anchors.centerIn: parent
                    text: root.words.none || "NO DOWNLOADS"
                    color: Ink.deep
                }
            }
            Sign {
                radius: 26
            }
        }
    }

    // ── Expanded ────────────────────────────────────────────────────
    Component {
        id: board
        Item {
            id: b
            readonly property var bins: {
                const by = {}, out = [];
                for (const r of root.recent) {
                    const k = String(r.bin || "OTHER").toUpperCase();
                    if (!by[k]) {
                        by[k] = { name: k, n: 0 };
                        out.push(by[k]);
                    }
                    by[k].n++;
                }
                return out.slice(0, 6);
            }
            readonly property int cardH: root.now ? 24 : 0
            readonly property int listY: 5 + (root.now ? cardH + 4 : 0) + 9
            readonly property int rowH: 10
            readonly property int binH: 15
            readonly property int rowsN: Math.max(0, Math.min(root.recent.length, Math.floor((glass.rows - listY - binH - 8 - 10) / rowH)))

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: 30
                color: Ink.glass
            }
            Item {
                anchors.fill: parent
                anchors.margins: 12
                Glass {
                    id: glass
                    radius: 20
                    // The active one.
                    Item {
                        visible: root.now !== null
                        x: 8
                        y: 8
                        width: glass.cols - 16
                        height: b.cardH - 6
                        MatrixText {
                            width: parent.width - pc.implicitWidth - 4
                            height: 5
                            font: "3x5"
                            text: root.now?.name ?? ""
                            color: Ink.cyan
                            scroll: true
                        }
                        MatrixText {
                            id: pc
                            anchors.right: parent.right
                            height: 5
                            font: "3x5"
                            text: root.pct(root.now?.pct ?? 0) + "%"
                            color: Ink.pink
                        }
                        // The bar: one dot every other, lit to the percent.
                        Row {
                            y: 8
                            spacing: 1
                            readonly property int n: Math.floor((parent.width + 1) / 2)
                            Repeater {
                                model: parent.n
                                Rectangle {
                                    required property int index
                                    width: 1
                                    height: 2
                                    color: index / parent.n < root.pct(root.now?.pct ?? 0) / 100 ? Ink.cyan : Ink.violet
                                    opacity: index / parent.n < root.pct(root.now?.pct ?? 0) / 100 ? 1 : 0.35
                                }
                            }
                        }
                        MatrixText {
                            y: 13
                            width: parent.width
                            height: 5
                            font: "3x5"
                            text: root.now?.speed ?? ""
                            color: Ink.violet
                        }
                    }
                    MatrixText {
                        x: 5
                        y: b.listY - 8
                        height: 5
                        font: "3x5"
                        text: root.words.today || "TODAY"
                        color: Ink.violet
                    }
                    Repeater {
                        model: root.recent.slice(0, b.rowsN)
                        Item {
                            required property var modelData
                            required property int index
                            x: 5
                            y: b.listY + index * b.rowH + 2
                            width: glass.cols - 10 - 74
                            height: 5
                            MatrixText {
                                width: parent.width - meta.width - 6
                                height: 5
                                font: "3x5"
                                text: modelData.name
                                color: Ink.pink
                            }
                            MatrixText {
                                id: meta
                                anchors.right: parent.right
                                anchors.rightMargin: 3
                                width: Math.min(implicitWidth, parent.width * 0.4)
                                height: 5
                                font: "3x5"
                                align: "right"
                                text: [root.size(modelData.size), modelData.bin ?? ""].filter(x => x).join(" · ")
                                color: Ink.violet
                            }
                        }
                    }
                    Words {
                        visible: root.recent.length === 0
                        anchors.centerIn: parent
                        text: root.words.none || "NO DOWNLOADS"
                        color: Ink.deep
                    }
                    // The bins.
                    Row {
                        id: binRow
                        x: 5
                        y: glass.rows - 5 - 8 - b.binH - 2
                        spacing: 3
                        readonly property int cardW: Math.floor((glass.cols - 10 - 15) / 6)
                        Repeater {
                            model: b.bins
                            Item {
                                required property var modelData
                                width: binRow.cardW
                                height: b.binH
                                MatrixText {
                                    x: 2
                                    y: 2
                                    width: parent.width - 3
                                    height: 5
                                    font: "3x5"
                                    text: modelData.name
                                    color: Ink.violet
                                }
                                Words {
                                    x: 2
                                    y: 8
                                    room: parent.width - 3
                                    text: modelData.n
                                    color: Ink.cyan
                                }
                            }
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
                        text: "DOTD SORTS FINISHED FILES INTO BINS · UNDO PUTS ONE BACK"
                        color: Ink.violet
                    }
                }

                // Crisp: the active card, the row buttons, the bin rims.
                Tube {
                    visible: root.now !== null
                    x: glass.x + 5 * root.pitch
                    y: glass.y + 5 * root.pitch
                    width: (glass.cols - 10) * root.pitch
                    height: b.cardH * root.pitch
                    radius: 14
                    line: 2
                    tint: Ink.cyan
                    glow: 0.8
                }
                Repeater {
                    model: root.recent.slice(0, b.rowsN)
                    Row {
                        required property var modelData
                        required property int index
                        anchors.right: glass.right
                        anchors.rightMargin: 5 * root.pitch
                        y: glass.y + (b.listY + index * b.rowH) * root.pitch
                        spacing: 4
                        Chip {
                            text: "OPEN"
                            tone: "cyan"
                            size: 9
                            pad: 5
                            action: "open " + modelData.path
                        }
                        Chip {
                            text: "REVEAL"
                            tone: "cyan"
                            size: 9
                            pad: 5
                            action: "reveal " + modelData.path
                        }
                        Chip {
                            visible: !!modelData.undo
                            text: "UNDO"
                            tone: "cyan"
                            size: 9
                            pad: 5
                            action: "dotd undo " + (modelData.id ?? "")
                        }
                    }
                }
                Repeater {
                    model: b.bins.length
                    Tube {
                        required property int index
                        x: glass.x + (5 + index * (binRow.cardW + 3)) * root.pitch
                        y: glass.y + binRow.y * root.pitch
                        width: binRow.cardW * root.pitch
                        height: b.binH * root.pitch
                        radius: 10
                        line: 1.5
                        tint: Ink.deep
                        glow: 0
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
