import QtQuick
import qs
import qs.tokyo as T

// Clock, Blueprint: FIG. 3, the clock drawn on the sheet (its diameter in
// the caption), the time in big Share Tech Mono and a title block with the
// date and the day, all crisp. Expanded, SHEET 2: the time and the day in
// dots, then TABLE 1, the month (◂ ▸ page it) as a ruled table of days in
// dots, today circled, the other months' days faded.
T.Face {
    id: root

    // Re-read every second with the clock feed.
    readonly property date now: {
        void root.ctx.time;
        return new Date();
    }
    readonly property string time: Qt.formatTime(now, "hh:mm")

    // ISO week number.
    readonly property int week: {
        const d = new Date(Date.UTC(now.getFullYear(), now.getMonth(), now.getDate()));
        d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
        return Math.ceil(((d - Date.UTC(d.getUTCFullYear(), 0, 1)) / 86400000 + 1) / 7);
    }

    Paper {
        anchors.fill: parent
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : clock
    }

    // ── Compact: FIG. 3 ─────────────────────────────────────────────
    Component {
        id: clock
        Item {
            id: c
            readonly property real d: Math.min(height - 28, width * 0.45)

            Dial {
                id: dial
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                width: c.d
                height: c.d
                time: root.now
            }

            Item {
                id: slot
                x: dial.x + dial.width + 14
                y: dial.y
                width: parent.width - x - 14
                height: dial.height
                Pen {
                    width: parent.width
                    height: 14
                    text: "FIG. 3 — CLOCK, Ø " + Math.round(116 * c.d / 132)
                }
                Text {
                    y: 12
                    width: parent.width
                    height: big.height
                    text: root.time
                    color: Ink.white
                    font.family: Ink.family
                    font.pixelSize: Math.min(48, Math.floor(slot.width / 2.75), slot.height * 0.45)
                    verticalAlignment: Text.AlignVCenter
                    Text {
                        id: big
                        visible: false
                        text: "0"
                        font: parent.font
                    }
                }
                Table {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    labelW: Math.min(52, parent.width * 0.3)
                    edge: false
                    rows: [["DATE", Qt.formatDate(root.now, "d MMM yyyy").toUpperCase()], ["DAY", Qt.formatDate(root.now, "dddd").toUpperCase()]]
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Ink.line
                    }
                }
            }
        }
    }

    // ── Expanded: SHEET 2 ───────────────────────────────────────────
    Component {
        id: board
        Item {
            id: b
            property int offset: 0
            readonly property date month: new Date(root.now.getFullYear(), root.now.getMonth() + offset, 1)
            // Six weeks, Sunday first.
            readonly property var cells: {
                const first = month.getDay();
                const start = new Date(month.getFullYear(), month.getMonth(), 1 - first);
                const out = [];
                for (let i = 0; i < 42; i++) {
                    const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
                    out.push({
                        n: d.getDate(),
                        other: d.getMonth() !== month.getMonth(),
                        today: d.toDateString() === root.now.toDateString()
                    });
                }
                // Drop a last week that is all next month.
                return out[35].other ? out.slice(0, 35) : out;
            }
            readonly property int todayAt: cells.findIndex(c => c.today)
            readonly property int p: Tokens.pitch
            readonly property int cols: Math.floor(width / p)
            readonly property int rows: Math.floor(height / p)
            readonly property int padX: Math.ceil(16 / p)
            readonly property int pageW: cols - padX * 2
            readonly property int cellW: Math.floor(pageW / 7)
            readonly property int bigPx: Math.max(12, Math.min(22, Math.floor(rows * 0.17)))
            readonly property int topY: Math.ceil(30 / p)
            readonly property int headY: topY + bigPx + 4
            readonly property int dowY: headY + 11
            readonly property int gridY: dowY + 8
            readonly property int cellH: Math.max(9, Math.floor((rows - gridY - 11) / (cells.length / 7)))

            Sheet {
                title: "SHEET 2 — CALENDAR"
            }
            // The table's thin rules and today's circle, crisp.
            Repeater {
                model: b.cells.length
                Rectangle {
                    required property int index
                    x: (b.padX + index % 7 * b.cellW) * b.p
                    y: (b.gridY + Math.floor(index / 7) * b.cellH) * b.p
                    width: b.cellW * b.p + 1
                    height: b.cellH * b.p + 1
                    color: "transparent"
                    border.width: 1
                    border.color: Ink.c(Qt.rgba(169 / 255, 205 / 255, 250 / 255, 0.3), Qt.rgba(58 / 255, 95 / 255, 176 / 255, 0.3))
                }
            }
            Rectangle {
                visible: b.todayAt >= 0
                readonly property int at: b.todayAt
                x: (b.padX + at % 7 * b.cellW) * b.p + 2
                y: (b.gridY + Math.floor(at / 7) * b.cellH) * b.p + 2
                width: b.cellW * b.p - 3
                height: b.cellH * b.p - 3
                radius: height / 2
                color: "transparent"
                border.width: 1.5
                border.color: Ink.white
            }

            Dots {
                anchors.fill: parent

                // 21:47                                   SUNDAY
                //                                     18 OCT 2026
                Say {
                    x: b.padX
                    y: b.topY
                    text: root.time
                    size: b.bigPx
                }
                Column {
                    anchors.right: parent.right
                    anchors.rightMargin: b.padX
                    y: b.topY + b.bigPx - 13
                    spacing: 3
                    Repeater {
                        model: [Qt.formatDate(root.now, "dddd"), Qt.formatDate(root.now, "d MMM yyyy")]
                        MatrixText {
                            required property string modelData
                            anchors.right: parent.right
                            width: implicitWidth
                            height: 5
                            font: "3x5"
                            text: modelData
                            color: Ink.line
                        }
                    }
                }

                // ◂        TABLE 1 - OCTOBER        ▸
                Item {
                    x: b.padX
                    y: b.headY
                    width: b.pageW
                    height: 7
                    MatrixText {
                        width: implicitWidth
                        height: 7
                        text: "◂"
                        color: Ink.ink
                        T.Hit {
                            anchors.fill: parent
                            anchors.margins: -3
                            onTap: b.offset--
                        }
                    }
                    MatrixText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: implicitWidth
                        height: 7
                        text: "TABLE 1 - " + Qt.formatDate(b.month, b.offset ? "MMMM yyyy" : "MMMM")
                        color: Ink.ink
                        T.Hit {
                            anchors.fill: parent
                            onTap: b.offset = 0
                        }
                    }
                    MatrixText {
                        anchors.right: parent.right
                        width: implicitWidth
                        height: 7
                        text: "▸"
                        color: Ink.ink
                        T.Hit {
                            anchors.fill: parent
                            anchors.margins: -3
                            onTap: b.offset++
                        }
                    }
                }

                // S M T W T F S
                Row {
                    x: b.padX
                    y: b.dowY
                    Repeater {
                        model: ["S", "M", "T", "W", "T", "F", "S"]
                        MatrixText {
                            required property string modelData
                            width: b.cellW
                            height: 5
                            font: "3x5"
                            align: "center"
                            text: modelData
                            color: Ink.line
                        }
                    }
                }

                Grid {
                    x: b.padX
                    y: b.gridY
                    columns: 7
                    Repeater {
                        model: b.cells
                        Item {
                            required property var modelData
                            width: b.cellW
                            height: b.cellH
                            MatrixText {
                                anchors.centerIn: parent
                                width: parent.width
                                height: 7
                                align: "center"
                                text: modelData.n
                                color: modelData.today ? Ink.white : modelData.other ? Ink.done : Ink.ink
                            }
                        }
                    }
                }

                MatrixText {
                    x: b.padX
                    y: b.rows - 8
                    width: b.pageW
                    height: 5
                    font: "3x5"
                    scroll: true
                    text: root.words.foot || "NOTE: WEEK " + root.week + " · UTC " + (root.ctx.utc ?? "")
                    color: Ink.line
                }
            }
        }
    }
}
