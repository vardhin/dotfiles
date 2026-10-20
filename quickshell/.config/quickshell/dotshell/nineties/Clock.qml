import QtQuick
import qs
import qs.tokyo as T

// Clock, 90s Nights: the outrun sign. The time big in chrome dots (white,
// sky, a dark horizon, pink, yellow) in Audiowide italic, AM/PM small
// beside it, the day and date spaced wide in electric blue under it (a
// click opens the calendar pane), and the striped sun setting behind on
// the right. Expanded, CALENDAR: the time in chrome, the day and date in
// yellow at the right, the month in blue (◂ ▸ page it, its name goes back
// to this month), the days yellow with today on a leaning sunset slab, the
// other months' days faint; the week and UTC at the foot.
T.Face {
    id: root

    // Re-read every second with the clock feed.
    readonly property date now: {
        void root.ctx.time;
        return new Date();
    }
    readonly property string hm: Qt.formatTime(now, "h:mm AP").split(" ")[0]
    readonly property string ap: now.getHours() < 12 ? "AM" : "PM"

    // How wide the time is in Audiowide italic, per px of font size.
    TextMetrics {
        id: tm
        font.family: Ink.family
        font.italic: true
        font.pixelSize: 100
        text: root.hm
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : sign
    }

    // ── Compact ─────────────────────────────────────────────────────
    Component {
        id: sign
        Item {
            id: c
            readonly property int p: Tokens.pitch
            // Room for the time across: the glass less the AM/PM.
            readonly property real room: width - plate.lean - 24 - 12 * p - 20
            readonly property int timeDots: Math.max(9, Math.min(Math.floor(height * 0.37 / p), Math.floor(room / p / (tm.width / 100 * 1.3))))
            readonly property int dateK: 1
            readonly property real blockH: (timeDots + 4 + 7) * p
            readonly property real y0: Math.round((height - blockH) / 2)

            Plate {
                id: plate
                anchors.fill: parent

                // The sun, setting behind the words.
                Sun {
                    width: Math.round(c.height * 1.1 / c.p)
                    height: width
                    x: plate.cols - Math.round(width * 0.86)
                    y: plate.rows - Math.round(width * 0.72)
                }
                Word {
                    id: time
                    x: Math.round((plate.leftAt(c.y0 + c.timeDots * c.p / 2) + 20 - plate.rim) / c.p)
                    y: Math.round((c.y0 - plate.rim) / c.p)
                    width: implicitWidth
                    height: c.timeDots
                    dots: c.timeDots
                    text: root.hm
                    stops: Ink.chrome
                }
                Word {
                    x: time.x + time.width + 1
                    y: time.y + time.height - 8
                    width: implicitWidth
                    height: 7
                    dots: 7
                    text: root.ap
                    stops: [[0, Ink.pink], [1, Ink.yellow]]
                }
                MatrixText {
                    id: date
                    x: Math.round((plate.leftAt(c.y0 + c.blockH - 10) + 20 - plate.rim) / c.p) + 1
                    y: time.y + c.timeDots + 4
                    width: Math.min(implicitWidth, plate.cols - x - 4)
                    height: 7
                    gap: 2
                    font: implicitWidthFor5x7 <= plate.cols - x - 6 ? "5x7" : "3x5"
                    readonly property int implicitWidthFor5x7: text.length * 7
                    text: Qt.formatDate(root.now, c.width >= 300 ? "dddd · MM.dd.yy" : "ddd · MM.dd").toUpperCase()
                    color: Ink.blue
                    T.Hit {
                        anchors.fill: parent
                        anchors.margins: -2
                        action: "pane calendar"
                    }
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
            // In the glass's dots.
            readonly property int cols: plate.cols
            readonly property int rows: plate.rows
            readonly property int x0: Math.ceil(12 / p)
            readonly property int w0: cols - x0 * 2
            readonly property int timeY: Math.ceil(10 / p)
            readonly property int timeH: Math.max(12, Math.min(26, Math.floor(rows * 0.2), Math.floor(w0 * 0.55 / (tm.width / 100 * 1.3))))
            readonly property string navFont: w0 >= 16 * 7 + 20 ? "5x7" : "3x5"
            readonly property int navY: timeY + timeH + 5
            readonly property int dowY: navY + 12
            readonly property int gridY: dowY + 8
            readonly property int footY: rows - Math.ceil(10 / p) - 5
            readonly property real cellW: w0 / 7
            readonly property int cellH: Math.max(7, Math.floor((footY - 4 - gridY) / weeks))
            readonly property string dayFont: cellH >= 9 && cellW >= 14 ? "5x7" : "3x5"
            readonly property int week: {
                const d = new Date(Date.UTC(root.now.getFullYear(), root.now.getMonth(), root.now.getDate()));
                const day = d.getUTCDay() || 7;
                d.setUTCDate(d.getUTCDate() + 4 - day);
                return Math.ceil(((d - new Date(Date.UTC(d.getUTCFullYear(), 0, 1))) / 86400000 + 1) / 7);
            }

            Plate {
                id: plate
                anchors.fill: parent
                slant: false
                radius: 4

                // 9:47                                PM · SUNDAY
                //                                        10.18.26
                Word {
                    x: b.x0
                    y: b.timeY
                    width: implicitWidth
                    height: b.timeH
                    dots: b.timeH
                    text: root.hm
                    stops: Ink.chrome
                }
                Column {
                    x: b.x0 + b.w0 - width
                    y: b.timeY + b.timeH - height
                    spacing: 2
                    Repeater {
                        model: [root.ap + " · " + Qt.formatDate(root.now, "dddd").toUpperCase(), Qt.formatDate(root.now, "MM.dd.yy")]
                        MatrixText {
                            required property string modelData
                            anchors.right: parent.right
                            width: implicitWidth
                            readonly property bool roomy: modelData.length * 6 <= b.w0 * 0.45
                            height: roomy ? 7 : 5
                            font: roomy ? "5x7" : "3x5"
                            text: modelData
                            color: Ink.yellow
                        }
                    }
                }
                // ◂        OCTOBER 2026        ▸
                MatrixText {
                    x: b.x0
                    y: b.navY
                    width: implicitWidth
                    font: b.navFont
                    height: font === "5x7" ? 7 : 5
                    text: "◂"
                    color: Ink.blue
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
                    gap: 2
                    height: font === "5x7" ? 7 : 5
                    text: Qt.formatDate(b.month, "MMMM yyyy").toUpperCase()
                    color: Ink.blue
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
                    color: Ink.blue
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
                        color: Ink.pink
                    }
                }
                Repeater {
                    model: b.cells
                    MatrixText {
                        required property var modelData
                        required property int index
                        visible: !modelData.today
                        x: Math.round(b.x0 + index % 7 * b.cellW)
                        y: b.gridY + Math.floor(index / 7) * b.cellH + Math.floor((b.cellH - height) / 2)
                        width: Math.floor(b.cellW)
                        font: b.dayFont
                        height: font === "5x7" ? 7 : 5
                        align: "center"
                        text: modelData.n
                        color: Ink.yellow
                        opacity: modelData.other ? 0.25 : 1
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
                    color: Ink.blue
                }
            }
            // Today on its leaning sunset slab, over the glass.
            Repeater {
                model: b.cells
                Item {
                    id: today
                    required property var modelData
                    required property int index
                    visible: modelData.today
                    x: plate.surface.x + (b.x0 + index % 7 * b.cellW) * b.p + 2
                    y: plate.surface.y + (b.gridY + Math.floor(index / 7) * b.cellH) * b.p
                    width: b.cellW * b.p - 4
                    height: b.cellH * b.p - 1
                    Rectangle {
                        id: slab
                        anchors.fill: parent
                        antialiasing: true
                        transform: Lean {
                            item: slab
                        }
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0
                                color: Ink.yellow
                            }
                            GradientStop {
                                position: 1
                                color: Ink.pink
                            }
                        }
                    }
                    Pen {
                        anchors.fill: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: today.modelData.n
                        size: Math.min(14, height * 0.75)
                        slanted: true
                        color: Ink.night
                    }
                }
            }
        }
    }
}
