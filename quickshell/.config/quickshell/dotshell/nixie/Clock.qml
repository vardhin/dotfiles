import QtQuick
import qs
import qs.tokyo as T

// Clock, Nixie: the tube clock. Hours and minutes on four big tubes, the
// seconds on two small ones, glowing colons between, and the date under
// them in brass small print (a click on it opens the calendar pane).
// Expanded, CALENDAR: the case's dot screen with the time big in Nixie One
// dots, the day and date at the right, the month (◂ ▸ page it, its name
// goes back to this month) and its days, today ringed in a glowing card,
// the other months' days dim; the week and UTC at the foot.
T.Face {
    id: root

    // Re-read every second with the clock feed.
    readonly property date now: {
        void root.ctx.time;
        return new Date();
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : clock
    }

    // ── Compact ─────────────────────────────────────────────────────
    Component {
        id: clock
        Item {
            id: c
            readonly property real dateH: 12
            readonly property real tubeH: Math.max(24, height - 24 - dateH - 10)
            // Big tubes, then the seconds at two thirds; shrunk to fit across.
            readonly property real tubeW: Math.min(tubeH * 0.54, (width - 28 - 60) / (secs ? 5.6 : 4.2))
            readonly property bool secs: width >= 200

            Wood {
                anchors.fill: parent
            }
            Row {
                id: digits
                anchors.horizontalCenter: parent.horizontalCenter
                y: 14
                spacing: 5
                Tubes {
                    height: c.tubeH
                    tubeW: c.tubeW
                    text: Qt.formatTime(root.now, "hh:mm")
                }
                Tubes {
                    visible: c.secs
                    anchors.bottom: parent.bottom
                    height: Math.round(c.tubeH * 0.65)
                    tubeW: c.tubeW * 0.65
                    text: ":" + Qt.formatTime(root.now, "ss")
                }
            }
            Print {
                anchors.horizontalCenter: parent.horizontalCenter
                y: digits.y + digits.height + 6
                height: c.dateH
                text: Qt.formatDate(root.now, c.width >= 220 ? "ddd · d MMM yyyy" : "ddd d MMM").toUpperCase()
                size: 9
                spacing: 3
                T.Hit {
                    anchors.fill: parent
                    anchors.margins: -3
                    action: "pane calendar"
                }
            }
        }
    }

    // ── Expanded: the calendar ──────────────────────────────────────
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
            readonly property int p: Tokens.pitch
            readonly property int weeks: cells.length / 7
            // In the screen's dots.
            readonly property int cols: box.screen.cols
            readonly property int rows: box.screen.rows
            readonly property int x0: Math.ceil(12 / p)
            readonly property int w0: cols - x0 * 2
            readonly property int timeY: Math.ceil(10 / p)
            readonly property int timeH: Math.max(12, Math.min(26, Math.floor(rows * 0.2)))
            readonly property string navFont: w0 >= 14 * 6 + 20 ? "5x7" : "3x5"
            readonly property int navY: timeY + timeH + 4
            readonly property int dowY: navY + 11
            readonly property int gridY: dowY + 8
            readonly property int footY: rows - Math.ceil(10 / p) - 5
            readonly property real cellW: w0 / 7
            readonly property int cellH: Math.max(7, Math.floor((footY - 4 - gridY) / weeks))
            readonly property int week: {
                const d = new Date(Date.UTC(root.now.getFullYear(), root.now.getMonth(), root.now.getDate()));
                const day = d.getUTCDay() || 7;
                d.setUTCDate(d.getUTCDate() + 4 - day);
                return Math.ceil(((d - new Date(Date.UTC(d.getUTCFullYear(), 0, 1))) / 86400000 + 1) / 7);
            }

            Case {
                id: box
                anchors.fill: parent

                // 21:47                                   SUN
                //                                       18 OCT
                Word {
                    x: b.x0
                    y: b.timeY
                    width: implicitWidth
                    height: b.timeH
                    dots: b.timeH
                    text: Qt.formatTime(root.now, "hh:mm")
                }
                Column {
                    x: b.x0 + b.w0 - width
                    y: b.timeY + b.timeH - height
                    spacing: 2
                    Repeater {
                        model: [Qt.formatDate(root.now, "ddd").toUpperCase(), Qt.formatDate(root.now, "dd MMM").toUpperCase()]
                        MatrixText {
                            required property string modelData
                            anchors.right: parent.right
                            width: implicitWidth
                            height: 5
                            font: "3x5"
                            text: modelData
                            color: Ink.amber
                        }
                    }
                }
                // ◂         October 2026         ▸
                MatrixText {
                    x: b.x0
                    y: b.navY
                    width: implicitWidth
                    font: b.navFont
                    height: font === "5x7" ? 7 : 5
                    text: "◂"
                    color: Ink.orange
                    T.Hit {
                        anchors.fill: parent
                        anchors.margins: -3
                        onTap: b.offset--
                    }
                }
                MatrixText {
                    x: Math.round(b.x0 + (b.w0 - width) / 2)
                    y: b.navY
                    width: implicitWidth
                    font: b.navFont
                    height: font === "5x7" ? 7 : 5
                    text: Qt.formatDate(b.month, "MMMM yyyy").toUpperCase()
                    color: Ink.orange
                    T.Hit {
                        anchors.fill: parent
                        onTap: b.offset = 0
                    }
                }
                MatrixText {
                    x: b.x0 + b.w0 - width
                    y: b.navY
                    width: implicitWidth
                    font: b.navFont
                    height: font === "5x7" ? 7 : 5
                    text: "▸"
                    color: Ink.orange
                    T.Hit {
                        anchors.fill: parent
                        anchors.margins: -3
                        onTap: b.offset++
                    }
                }
                // S M T W T F S
                Repeater {
                    model: ["S", "M", "T", "W", "T", "F", "S"]
                    MatrixText {
                        required property string modelData
                        required property int index
                        x: Math.round(b.x0 + index * b.cellW)
                        y: b.dowY
                        width: Math.floor(b.cellW)
                        height: 5
                        font: "3x5"
                        align: "center"
                        text: modelData
                        color: Ink.brass
                    }
                }
                Repeater {
                    model: b.cells
                    MatrixText {
                        required property var modelData
                        required property int index
                        x: Math.round(b.x0 + index % 7 * b.cellW)
                        y: b.gridY + Math.floor(index / 7) * b.cellH + Math.floor((b.cellH - height) / 2)
                        width: Math.floor(b.cellW)
                        font: b.cellH >= 9 && b.cellW >= 14 ? "5x7" : "3x5"
                        height: font === "5x7" ? 7 : 5
                        align: "center"
                        text: modelData.n
                        color: modelData.today ? Ink.digit : modelData.other ? Ink.deep : Ink.orange
                        opacity: modelData.other ? 0.55 : 1
                    }
                }
                MatrixText {
                    x: b.x0
                    y: b.footY
                    width: b.w0
                    height: 5
                    font: "3x5"
                    scroll: true
                    text: "WEEK " + b.week + " · UTC " + (root.ctx.utc ?? "") + " · " + Qt.formatDate(root.now, "dddd d MMMM").toUpperCase()
                    color: Ink.brass
                }
            }
            // Today's glowing card, over the screen.
            Repeater {
                model: b.cells
                Card {
                    required property var modelData
                    required property int index
                    visible: modelData.today
                    x: box.sx + box.screen.surface.x + (b.x0 + index % 7 * b.cellW) * b.p + 2
                    y: box.sy + box.screen.surface.y + (b.gridY + Math.floor(index / 7) * b.cellH) * b.p - 1
                    width: b.cellW * b.p - 4
                    height: b.cellH * b.p
                    on: true
                }
            }
        }
    }
}
