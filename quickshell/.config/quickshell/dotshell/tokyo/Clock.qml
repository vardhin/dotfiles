import QtQuick
import qs

// Clock, Tokyo Night: a neon sign with the time in cyan tubes and the day
// in pink under it; expanded, a calendar board (Sunday first, the other
// months' days dim, today on a pink pill; < > page the month).
Face {
    id: root

    // Re-read every second with the clock feed.
    readonly property date now: {
        void root.ctx.time;
        return new Date();
    }
    readonly property var kanji: ["日", "月", "火", "水", "木", "金", "土"]
    readonly property var kanjiMonth: ["一月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "十一月", "十二月"]

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : sign
    }

    // ── Compact: the sign ───────────────────────────────────────────
    Component {
        id: sign
        Item {
            Glass {
                id: glass
                radius: 30

                Column {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 1
                    spacing: 1
                    Neon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.ctx.time ?? ""
                        size: Math.round(glass.rows * 0.6)
                        height: Math.round(size * 0.82)
                        color: Ink.cyan
                        halo: true
                    }
                    DotText {
                        readonly property string date: String(root.ctx.date ?? "").toUpperCase()
                        readonly property string full: root.kanji[root.now.getDay()] + " · " + date
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: Tokens.fontPx
                        // The kanji day goes first when there is no room.
                        text: (full.length + 1) * Tokens.charDots <= glass.cols - 8 ? full : date
                        color: Ink.pink
                    }
                }
            }
            Sign {
                radius: 30
                inner: true
            }
        }
    }

    // ── Expanded: the calendar board ────────────────────────────────
    Component {
        id: board
        Item {
            id: cal
            property int offset: 0
            readonly property date month: new Date(root.now.getFullYear(), root.now.getMonth() + offset, 1)
            // Six weeks, Sunday first, the neighbouring months' days dim.
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
                return out;
            }

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

                    Item {
                        id: page
                        x: 4
                        y: 4
                        width: glass.cols - 8
                        height: glass.rows - 8
                        readonly property int cellW: Math.floor(width / 7)
                        readonly property int timeSize: Math.round(Math.min(height * 0.19, width * 0.24))

                        // 21:47            日曜日
                        //                  18 OCT
                        Neon {
                            id: time
                            text: root.ctx.time ?? ""
                            size: page.timeSize
                            height: Math.round(size * 0.85)
                            color: Ink.cyan
                            halo: true
                        }
                        Column {
                            anchors.right: parent.right
                            anchors.verticalCenter: time.verticalCenter
                            DotText {
                                anchors.right: parent.right
                                height: Tokens.lineDots
                                text: root.kanji[root.now.getDay()] + "曜日"
                                color: Ink.orange
                            }
                            DotText {
                                anchors.right: parent.right
                                height: Tokens.lineDots
                                text: (root.ctx.dd ?? "") + " " + Qt.formatDate(root.now, "MMM").toUpperCase()
                                color: Ink.pink
                            }
                        }

                        // ◂   十月 · OCTOBER   ▸
                        Item {
                            id: head
                            y: time.height + 3
                            width: parent.width
                            height: Tokens.fontPx
                            DotText {
                                text: "◂"
                                color: Ink.pink
                                Hit {
                                    anchors.fill: parent
                                    anchors.margins: -2
                                    onTap: cal.offset--
                                }
                            }
                            DotText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.kanjiMonth[cal.month.getMonth()] + " · " + Qt.formatDate(cal.month, "MMMM").toUpperCase() + (cal.month.getFullYear() !== root.now.getFullYear() ? " " + cal.month.getFullYear() : "")
                                color: Ink.pink
                                Hit {
                                    anchors.fill: parent
                                    onTap: cal.offset = 0
                                }
                            }
                            DotText {
                                anchors.right: parent.right
                                text: "▸"
                                color: Ink.pink
                                Hit {
                                    anchors.fill: parent
                                    anchors.margins: -2
                                    onTap: cal.offset++
                                }
                            }
                        }

                        // 日 月 火 水 木 金 土
                        Row {
                            id: dow
                            y: head.y + head.height + 1
                            Repeater {
                                model: root.kanji
                                DotText {
                                    required property string modelData
                                    width: page.cellW
                                    height: Tokens.fontPx
                                    horizontalAlignment: Text.AlignHCenter
                                    text: modelData
                                    color: Ink.violet
                                }
                            }
                        }

                        Grid {
                            id: days
                            y: dow.y + dow.height + 1
                            columns: 7
                            readonly property int cellH: Math.max(6, Math.floor((page.height - y - 8) / 6))
                            Repeater {
                                model: cal.cells
                                Item {
                                    required property var modelData
                                    width: page.cellW
                                    height: days.cellH
                                    MatrixText {
                                        anchors.centerIn: parent
                                        width: parent.width
                                        height: implicitHeight
                                        font: "3x5"
                                        align: "center"
                                        text: modelData.n
                                        color: Ink.cyan
                                        opacity: modelData.other ? 0.25 : 1
                                        visible: !modelData.today
                                    }
                                }
                            }
                        }

                        MatrixText {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 1
                            width: parent.width
                            height: implicitHeight
                            font: "3x5"
                            scroll: true
                            text: root.words.foot || "NEXT · NOTHING SCHEDULED"
                            color: Ink.violet
                        }
                    }
                }

                // Today: a pink pill over the glass, its number dark on it.
                Repeater {
                    model: cal.cells
                    Rectangle {
                        required property var modelData
                        required property int index
                        visible: modelData.today
                        readonly property real cw: page.cellW * root.pitch
                        readonly property real ch: days.cellH * root.pitch
                        x: glass.x + (page.x + days.x + index % 7 * page.cellW) * root.pitch + 1
                        y: glass.y + (page.y + days.y + Math.floor(index / 7) * days.cellH) * root.pitch + (ch - height) / 2
                        width: cw - 2
                        height: Math.min(ch + 2, 5 * root.pitch + 8)
                        radius: height / 2
                        color: Ink.pink
                        Text {
                            anchors.centerIn: parent
                            text: modelData.n
                            color: Ink.glass
                            font.family: Ink.family
                            font.pixelSize: Math.round(parent.height * 0.72)
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
