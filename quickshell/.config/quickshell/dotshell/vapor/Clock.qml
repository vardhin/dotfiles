import QtQuick
import qs
import qs.tokyo as T
import "../Hardware.js" as Hardware

// Clock, Vaporwave: date_time.exe. A round dark dot dial with cyan ticks,
// a pink hour hand, a yellow minute hand and a cyan second hand, the time
// with its seconds in yellow on a dot screen, the day spaced wide and the
// date under it in VT323, and OK (the calendar here) and Calendar (the
// calendar pane). Expanded: one dot screen, the time big in yellow, the
// day and date in pink, the month in cyan (◂ ▸ page it, the name goes
// back to this month), the weekdays in violet and the days in yellow,
// today on a hot pink cell, the other months' days faded; the time zone
// at its foot.
T.Face {
    id: root

    // Re-read every second with the clock feed.
    readonly property date now: {
        void root.ctx.time;
        return new Date();
    }
    readonly property string time: Qt.formatTime(now, "hh:mm:ss")
    readonly property string zone: {
        const m = -now.getTimezoneOffset();
        const a = Math.abs(m);
        return "GMT" + (m < 0 ? "-" : "+") + String(Math.floor(a / 60)).padStart(2, "0") + ":" + String(a % 60).padStart(2, "0");
    }

    Win {
        id: win
        anchors.fill: parent
        icon: "◷"
        title: "date_time.exe"
        big: root.big
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
            readonly property real topY: win.bodyY + 6
            readonly property real dia: Math.floor(Math.min(height - topY - 8, width * 0.4) / Tokens.pitch) * Tokens.pitch

            // The dial: a round dot screen, its rim lit at the bottom right.
            Rectangle {
                x: 9
                y: c.topY - 1
                width: c.dia + 2
                height: c.dia + 2
                radius: width / 2
                color: Ink.shade
            }
            Rectangle {
                x: 11
                y: c.topY + 1
                width: c.dia
                height: c.dia
                radius: width / 2
                color: Ink.hi
            }
            Crt {
                id: dial
                x: 10
                y: c.topY
                width: c.dia
                height: c.dia
                bevel: false
                radius: width / 2
                shape: Hardware.rounded(0, 0, cols, rows, cols / 2)
                // Ticks and hands, drawn in dots.
                Canvas {
                    id: hands
                    width: dial.cols
                    height: dial.rows
                    antialiasing: false
                    renderTarget: Canvas.Image
                    readonly property string sig: [width, Qt.formatTime(root.now, "hh:mm:ss")].join("|")
                    onSigChanged: requestPaint()
                    onPaint: {
                        const g = getContext("2d");
                        g.reset();
                        const r = width / 2, cx = (width - 1) / 2, cy = (height - 1) / 2;
                        const ray = (a, r0, r1, col, w) => {
                            g.fillStyle = col;
                            const n = Math.max(1, Math.ceil(r1 - r0) * 2);
                            for (let k = 0; k <= n; k++) {
                                const t = r0 + (r1 - r0) * k / n;
                                g.fillRect(Math.round(cx + Math.sin(a) * t - (w - 1) / 2), Math.round(cy - Math.cos(a) * t - (w - 1) / 2), w, w);
                            }
                        };
                        for (let i = 0; i < 12; i++)
                            ray(i * Math.PI / 6, r * (i % 3 ? 0.78 : 0.68), r * 0.88, String(Ink.cyan), 1);
                        const d = root.now, s = d.getSeconds(), m = d.getMinutes() + s / 60, h = d.getHours() % 12 + m / 60;
                        ray(h * Math.PI / 6, 0, r * 0.5, String(Ink.pink), 2);
                        ray(m * Math.PI / 30, 0, r * 0.66, String(Ink.yellow), 2);
                        ray(s * Math.PI / 30, -r * 0.1, r * 0.78, String(Ink.cyan), 1);
                    }
                }
            }

            Item {
                id: side
                x: dial.x + dial.width + 12
                y: c.topY
                width: parent.width - x - 10
                height: dial.height
                Crt {
                    id: digits
                    width: parent.width
                    height: Math.round(parent.height * 0.36)
                    Say {
                        anchors.centerIn: parent
                        text: root.time
                        size: Math.min(digits.rows - 2, Math.floor(digits.cols / 4.1))
                        spacing: 0
                    }
                }
                Row {
                    id: date
                    y: digits.height + 4
                    height: 24
                    spacing: 6
                    scale: Math.min(1, side.width / Math.max(1, implicitWidth))
                    transformOrigin: Item.Left
                    Pen {
                        height: parent.height
                        text: Qt.formatDate(root.now, "dddd").toUpperCase()
                        size: 22
                        font.letterSpacing: 3
                    }
                    Pen {
                        height: parent.height
                        text: "· " + Qt.formatDate(root.now, "dd/MM/yyyy")
                        size: 16
                    }
                }
                Row {
                    anchors.bottom: parent.bottom
                    spacing: 6
                    Key {
                        width: 40
                        height: 22
                        text: "OK"
                        action: "panel expand"
                    }
                    Key {
                        width: 70
                        height: 22
                        text: "Calendar"
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
            readonly property real wellY: win.bodyY + 8

            Well {
                x: 10
                y: b.wellY
                width: parent.width - 20
                height: parent.height - b.wellY - 10
            }
            Crt {
                id: sheet
                x: 12
                y: b.wellY + 2
                width: parent.width - 24
                height: parent.height - b.wellY - 14
                bevel: false
                readonly property int padX: 5
                readonly property int pageW: cols - padX * 2
                readonly property int cellW: Math.floor(pageW / 7)
                readonly property int bigSize: (8 * 12 - 2) <= pageW - 26 ? 2 : 1
                readonly property int topY: 5
                readonly property int headY: topY + 7 * bigSize + 8
                readonly property int dowY: headY + 12
                readonly property int gridY: dowY + 8
                readonly property int cellH: Math.max(8, Math.floor((rows - gridY - 10) / (b.cells.length / 7)))

                // 21:47:09                                     SUN
                //                                         18/10/26
                MatrixText {
                    x: sheet.padX
                    y: sheet.topY
                    width: implicitWidth
                    height: 7 * size
                    size: sheet.bigSize
                    dot: sheet.bigSize
                    text: root.time
                    color: Ink.yellow
                }
                MatrixText {
                    x: sheet.cols - sheet.padX - width
                    y: sheet.topY
                    width: implicitWidth
                    height: 7
                    text: Qt.formatDate(root.now, "ddd").toUpperCase()
                    color: Ink.pink
                }
                MatrixText {
                    x: sheet.cols - sheet.padX - width
                    y: sheet.topY + 9
                    width: implicitWidth
                    height: 5
                    font: "3x5"
                    text: Qt.formatDate(root.now, "dd/MM/yy")
                    color: Ink.pink
                }

                // ◂         October 2026         ▸
                MatrixText {
                    x: sheet.padX
                    y: sheet.headY
                    width: implicitWidth
                    height: 7
                    text: "◂"
                    color: Ink.cyan
                    T.Hit {
                        anchors.fill: parent
                        anchors.margins: -3
                        onTap: b.offset--
                    }
                }
                MatrixText {
                    x: Math.round((sheet.cols - width) / 2)
                    y: sheet.headY
                    width: implicitWidth
                    height: 7
                    text: Qt.formatDate(b.month, "MMMM yyyy")
                    color: Ink.cyan
                    T.Hit {
                        anchors.fill: parent
                        onTap: b.offset = 0
                    }
                }
                MatrixText {
                    x: sheet.cols - sheet.padX - width
                    y: sheet.headY
                    width: implicitWidth
                    height: 7
                    text: "▸"
                    color: Ink.cyan
                    T.Hit {
                        anchors.fill: parent
                        anchors.margins: -3
                        onTap: b.offset++
                    }
                }

                // S M T W T F S
                Row {
                    x: sheet.padX
                    y: sheet.dowY
                    Repeater {
                        model: ["S", "M", "T", "W", "T", "F", "S"]
                        MatrixText {
                            required property string modelData
                            width: sheet.cellW
                            height: 5
                            font: "3x5"
                            align: "center"
                            text: modelData
                            color: Ink.violet
                        }
                    }
                }
                Grid {
                    x: sheet.padX
                    y: sheet.gridY
                    columns: 7
                    Repeater {
                        model: b.cells
                        Item {
                            required property var modelData
                            width: sheet.cellW
                            height: sheet.cellH
                            Rectangle {
                                visible: modelData.today
                                anchors.fill: parent
                                anchors.margins: 1
                                color: Ink.pink
                            }
                            MatrixText {
                                anchors.centerIn: parent
                                width: parent.width
                                height: 7
                                align: "center"
                                font: sheet.cellW >= 13 ? "5x7" : "3x5"
                                text: modelData.n
                                color: modelData.today ? Ink.hi : modelData.other ? Ink.mid : Ink.yellow
                            }
                        }
                    }
                }

                MatrixText {
                    x: sheet.padX
                    y: sheet.rows - 7
                    width: sheet.pageW
                    height: 5
                    font: "3x5"
                    scroll: true
                    text: root.words.foot || "Time zone: (" + root.zone + ") · UTC " + (root.ctx.utc ?? "")
                    color: Ink.cyan
                }
            }
        }
    }
}
