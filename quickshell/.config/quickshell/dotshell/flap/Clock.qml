import QtQuick
import qs
import qs.tokyo as T

// Clock, Split-Flap: the station clock. The hours and minutes on four big
// flap tiles in off-white dots, and the date on a row of small ones, the
// day in yellow (a click opens the calendar pane). Expanded, DEPARTURES:
// the time big on a dot screen with the hinge across it, the day and
// date in yellow beside it, the month (◂ ▸ page it, its name goes back
// to this month) and its days as flap tiles, today yellow, the other
// months' days faded; the week and UTC at the foot.
T.Face {
    id: root

    // Re-read every second with the clock feed.
    readonly property date now: {
        void root.ctx.time;
        return new Date();
    }
    readonly property string hhmm: Qt.formatTime(now, "hhmm")

    Housing {
        id: box
        anchors.fill: parent
        label: root.big ? "DEPARTURES · " + Qt.formatDate(root.now, "MMMM").toUpperCase() : ""
        status: root.big ? "LIVE" : ""
        statusInk: Ink.label
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
            readonly property int p: Tokens.pitch
            // The date row: 3x5 tiles when 5x7 ones leave the digits too little.
            readonly property string dateFont: height >= 26 * p + 50 ? "5x7" : "3x5"
            readonly property real dateH: (dateFont === "5x7" ? 9 : 7) * p
            readonly property real gap: 8
            readonly property real digitsH: height - 14 - gap - dateH - 12
            readonly property real tileW: Math.min(Math.round(digitsH * 0.66), (width - 28 - 12 - 18) / 4)
            readonly property int room: Math.floor((width - 28) / ((dateFont === "5x7" ? 7 : 5) * p))
            // The year goes first when the row is short.
            readonly property string date: Qt.formatDate(root.now, room >= 15 ? "ddd dd MMM yyyy" : "ddd dd MMM").toUpperCase()

            Row {
                id: digits
                anchors.horizontalCenter: parent.horizontalCenter
                y: 12
                spacing: 4
                Repeater {
                    model: 4
                    Item {
                        required property int index
                        width: c.tileW + (index === 1 ? 10 : 0)
                        height: c.digitsH
                        Big {
                            width: c.tileW
                            height: parent.height
                            text: root.hhmm[parent.index]
                        }
                    }
                }
            }
            Flaps {
                id: date
                anchors.horizontalCenter: parent.horizontalCenter
                y: digits.y + digits.height + c.gap
                font: c.dateFont
                cells: Math.min(c.date.length, c.room)
                spans: [[c.date.slice(0, 3), Ink.yellow], [c.date.slice(3), Ink.white]]
                T.Hit {
                    anchors.fill: parent
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
            readonly property real padX: 14
            // The month's name in 5x7 when it fits between the arrows.
            readonly property string navFont: 14 * 6 + 20 <= Math.floor((width - padX * 2) / p) ? "5x7" : "3x5"
            readonly property real timeY: box.bodyY + 4
            readonly property real timeH: Math.max(48, Math.min(90, height * 0.17))
            readonly property real navY: timeY + timeH + 14
            readonly property real dowY: navY + (navFont === "5x7" ? 7 : 5) * p + 8
            readonly property real gridY: dowY + 5 * p + 6
            readonly property real footY: height - 12 - 6 * p
            readonly property real cellW: (width - padX * 2 - 6 * 6) / 7
            readonly property real cellH: Math.min(cellW * 0.6, (footY - 8 - gridY - 6 * (cells.length / 7 - 1)) / (cells.length / 7))
            readonly property int week: {
                const d = new Date(Date.UTC(root.now.getFullYear(), root.now.getMonth(), root.now.getDate()));
                const day = d.getUTCDay() || 7;
                d.setUTCDate(d.getUTCDate() + 4 - day);
                return Math.ceil(((d - new Date(Date.UTC(d.getUTCFullYear(), 0, 1))) / 86400000 + 1) / 7);
            }

            // 21:47 on its dot screen, the hinge across it.
            Glass {
                id: time
                x: b.padX
                y: b.timeY
                width: Math.min(b.width * 0.45, b.timeH * 2.9)
                height: b.timeH
                Say {
                    width: time.cols
                    height: time.rows
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: Qt.formatTime(root.now, "hh:mm")
                    size: Math.round(Math.min(time.rows * 1.2, time.cols / 2.2))
                }
            }
            Rectangle {
                x: time.x
                y: time.y + Math.floor(time.height / 2)
                width: time.width
                height: 1
                color: Ink.seam
            }

            Dots {
                id: ink
                anchors.fill: parent

                //                                   SUN
                //                                18 OCT
                Repeater {
                    model: [Qt.formatDate(root.now, "ddd").toUpperCase(), Qt.formatDate(root.now, "dd MMM").toUpperCase()]
                    MatrixText {
                        required property string modelData
                        required property int index
                        x: ink.cols - Math.ceil(b.padX / b.p) - width
                        y: Math.round((b.timeY + b.timeH / 2) / b.p) + (index ? 1 : -1 - height)
                        width: implicitWidth
                        font: (ink.cols - Math.ceil((time.x + time.width) / b.p)) >= 40 && b.timeH / b.p >= 18 ? "5x7" : "3x5"
                        height: font === "5x7" ? 7 : 5
                        text: modelData
                        color: Ink.yellow
                    }
                }
                // ◂         OCTOBER 2026         ▸
                MatrixText {
                    x: Math.ceil(b.padX / b.p)
                    y: Math.round(b.navY / b.p)
                    width: implicitWidth
                    font: b.navFont
                    height: font === "5x7" ? 7 : 5
                    text: "◂"
                    color: Ink.white
                    T.Hit {
                        anchors.fill: parent
                        anchors.margins: -3
                        onTap: b.offset--
                    }
                }
                MatrixText {
                    x: Math.round((ink.cols - width) / 2)
                    y: Math.round(b.navY / b.p)
                    width: implicitWidth
                    font: b.navFont
                    height: font === "5x7" ? 7 : 5
                    text: Qt.formatDate(b.month, "MMMM yyyy").toUpperCase()
                    color: Ink.white
                    T.Hit {
                        anchors.fill: parent
                        onTap: b.offset = 0
                    }
                }
                MatrixText {
                    x: ink.cols - Math.ceil(b.padX / b.p) - width
                    y: Math.round(b.navY / b.p)
                    width: implicitWidth
                    font: b.navFont
                    height: font === "5x7" ? 7 : 5
                    text: "▸"
                    color: Ink.white
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
                        x: Math.round((b.padX + index * (b.cellW + 6)) / b.p)
                        y: Math.round(b.dowY / b.p)
                        width: Math.floor(b.cellW / b.p)
                        height: 5
                        font: "3x5"
                        align: "center"
                        text: modelData
                        color: Ink.label
                    }
                }
                MatrixText {
                    x: Math.ceil(b.padX / b.p)
                    y: Math.floor(b.footY / b.p)
                    width: ink.cols - Math.ceil(b.padX / b.p) * 2
                    height: 5
                    font: "3x5"
                    scroll: true
                    text: "WEEK " + b.week + " · UTC " + (root.ctx.utc ?? "") + " · " + Qt.formatDate(root.now, "dddd d MMMM").toUpperCase()
                    color: Ink.label
                }
            }

            // The days, a flap tile each.
            Repeater {
                model: b.cells
                Item {
                    id: day
                    required property var modelData
                    required property int index
                    x: b.padX + index % 7 * (b.cellW + 6)
                    y: b.gridY + Math.floor(index / 7) * (b.cellH + 6)
                    width: b.cellW
                    height: b.cellH
                    opacity: modelData.other ? 0.45 : 1
                    Tile {
                        anchors.fill: parent
                        lit: day.modelData.today
                    }
                    Dots {
                        id: num
                        anchors.fill: parent
                        MatrixText {
                            x: Math.round((num.cols - width) / 2)
                            y: Math.round((num.rows - height) / 2)
                            width: implicitWidth
                            font: num.cols >= 13 ? "5x7" : "3x5"
                            height: font === "5x7" ? 7 : 5
                            text: day.modelData.n
                            color: day.modelData.today ? Ink.housing : Ink.white
                        }
                    }
                    Rectangle {
                        y: Math.floor(parent.height / 2)
                        width: parent.width
                        height: 1
                        color: Ink.seam
                        opacity: 0.8
                    }
                }
            }
        }
    }
}
