import QtQuick
import qs
import qs.tokyo as T

// Clock, VFD: the head unit's clock. The weekdays as annunciators along
// the top (today lit), AM/PM down the side, the time in big spaced digits
// over their unlit 88:88, the date under it and UTC in amber. Expanded, a
// calendar: the time and the day, the month (◂ ▸ page it), the weekdays,
// and the days in cells, the other months' days unlit, today boxed in
// amber.
T.Face {
    id: root

    // Re-read every second with the clock feed.
    readonly property date now: {
        void root.ctx.time;
        return new Date();
    }
    readonly property var dows: ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]
    readonly property bool pm: now.getHours() >= 12
    // 12 hour, the colon blinking with the feed.
    readonly property string time: {
        const h = now.getHours() % 12 || 12;
        const sep = String(root.ctx.time ?? ":").includes(":") ? ":" : " ";
        return h + sep + String(now.getMinutes()).padStart(2, "0");
    }

    // ISO week number.
    readonly property int week: {
        const d = new Date(Date.UTC(now.getFullYear(), now.getMonth(), now.getDate()));
        d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
        return Math.ceil(((d - Date.UTC(d.getUTCFullYear(), 0, 1)) / 86400000 + 1) / 7);
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : clock
    }

    // ── Compact ─────────────────────────────────────────────────────
    Component {
        id: clock
        Unit {
            id: u
            readonly property int padX: 4
            readonly property int size: Math.max(1, Math.min(Math.floor((rows - 18) / 7), Math.floor((cols - padX * 2 - 12) / 30)))

            // SU MO TU WE TH FR SA
            Repeater {
                model: root.dows
                MatrixText {
                    required property string modelData
                    required property int index
                    x: u.padX + Math.round(index * (u.cols - u.padX * 2 - 7) / 6)
                    y: 3
                    width: implicitWidth
                    height: 5
                    font: "3x5"
                    text: modelData
                    color: index === root.now.getDay() ? Ink.cyan : Ink.ghost
                }
            }
            // AM / PM, and the time on its 88:88.
            Item {
                x: u.padX
                y: 9
                width: u.cols - u.padX * 2
                height: u.rows - 18
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    MatrixText {
                        height: 5
                        font: "3x5"
                        text: "AM"
                        color: root.pm ? Ink.ghost : Ink.cyan
                    }
                    MatrixText {
                        height: 5
                        font: "3x5"
                        text: "PM"
                        color: root.pm ? Ink.cyan : Ink.ghost
                    }
                }
                Digits {
                    x: 11
                    anchors.verticalCenter: parent.verticalCenter
                    width: implicitWidth
                    height: implicitHeight
                    size: u.size
                    cells: 5
                    text: root.time
                }
            }
            // 18 OCT 2026                         UTC 16:17
            MatrixText {
                x: u.padX
                y: u.rows - 8
                height: 5
                font: "3x5"
                text: (root.ctx.dd ?? "") + " " + Qt.formatDate(root.now, "MMM").toUpperCase() + " " + (root.ctx.year ?? "")
                color: Ink.cyan
            }
            MatrixText {
                anchors.right: parent.right
                anchors.rightMargin: u.padX
                y: u.rows - 8
                width: implicitWidth
                height: 5
                font: "3x5"
                text: root.words.foot || "UTC " + (root.ctx.utc ?? "")
                color: Ink.amber
            }
        }
    }

    // ── Expanded: the calendar ──────────────────────────────────────
    Component {
        id: board
        Unit {
            id: u
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
                return out;
            }
            readonly property int todayAt: cells.findIndex(c => c.today)
            readonly property int padX: 4
            readonly property int pageW: cols - padX * 2
            readonly property int cellW: Math.floor(pageW / 7)
            readonly property int size: Math.max(2, Math.min(4, Math.floor((pageW - 32) / 29)))
            readonly property int headY: 4 + size * 7 + 5
            readonly property int dowY: headY + 11
            readonly property int gridY: dowY + 8
            readonly property int cellH: Math.max(8, Math.floor((rows - gridY - 11) / 6))

            // 9:47                                PM · SUN
            //                                       18 OCT
            Digits {
                x: u.padX
                y: 4
                width: implicitWidth
                height: implicitHeight
                size: u.size
                cells: 5
                text: root.time
            }
            Column {
                anchors.right: parent.right
                anchors.rightMargin: u.padX
                y: 4 + u.size * 7 - 12
                spacing: 2
                MatrixText {
                    anchors.right: parent.right
                    width: implicitWidth
                    height: 5
                    font: "3x5"
                    text: (root.pm ? "PM" : "AM") + " · " + root.dows[root.now.getDay()]
                    color: Ink.amber
                }
                MatrixText {
                    anchors.right: parent.right
                    width: implicitWidth
                    height: 5
                    font: "3x5"
                    text: (root.ctx.dd ?? "") + " " + Qt.formatDate(root.now, "MMM").toUpperCase()
                    color: Ink.amber
                }
            }

            // ◂          OCTOBER 2026          ▸
            Item {
                x: u.padX
                y: u.headY
                width: u.pageW
                height: 7
                MatrixText {
                    width: implicitWidth
                    height: 7
                    text: "◂"
                    color: Ink.teal
                    T.Hit {
                        anchors.fill: parent
                        anchors.margins: -2
                        onTap: u.offset--
                    }
                }
                MatrixText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: implicitWidth
                    height: 7
                    text: Qt.formatDate(u.month, "MMMM yyyy")
                    color: Ink.cyan
                    T.Hit {
                        anchors.fill: parent
                        onTap: u.offset = 0
                    }
                }
                MatrixText {
                    anchors.right: parent.right
                    width: implicitWidth
                    height: 7
                    text: "▸"
                    color: Ink.teal
                    T.Hit {
                        anchors.fill: parent
                        anchors.margins: -2
                        onTap: u.offset++
                    }
                }
            }

            // SU MO TU WE TH FR SA
            Row {
                x: u.padX
                y: u.dowY
                Repeater {
                    model: root.dows
                    MatrixText {
                        required property string modelData
                        width: u.cellW
                        height: 5
                        font: "3x5"
                        align: "center"
                        text: modelData
                        color: Ink.teal
                    }
                }
            }

            Grid {
                x: u.padX
                y: u.gridY
                columns: 7
                Repeater {
                    model: u.cells
                    Item {
                        required property var modelData
                        width: u.cellW
                        height: u.cellH
                        MatrixText {
                            anchors.centerIn: parent
                            width: parent.width
                            height: 7
                            align: "center"
                            text: modelData.n
                            color: modelData.other ? Ink.ghost : Ink.cyan
                        }
                    }
                }
            }

            MatrixText {
                x: u.padX
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3
                width: u.pageW
                height: 5
                font: "3x5"
                scroll: true
                text: root.words.foot || "• UTC " + (root.ctx.utc ?? "") + " · WEEK " + root.week
                color: Ink.amber
            }

            over: Box {
                visible: u.todayAt >= 0
                dx: u.padX + (u.todayAt % 7) * u.cellW + 1
                dy: u.gridY + Math.floor(u.todayAt / 7) * u.cellH + Math.floor((u.cellH - dh) / 2)
                dw: u.cellW - 2
                dh: Math.min(11, u.cellH)
                border.color: Ink.amber
            }
        }
    }
}
