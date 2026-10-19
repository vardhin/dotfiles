import QtQuick
import qs
import qs.tokyo as T

// Clock, Frutiger Aero: an analog clock on the sky glass, and beside it
// the time in Varela Round with its AM/PM, the weekday and the date in
// grass green. Expanded, a calendar in bubble dots: the time and the day,
// the month (◂ ▸ page it), the weekdays and the days, the other months'
// days faded and today on a glossy green bubble.
T.Face {
    id: root

    // Re-read every second with the clock feed.
    readonly property date now: {
        void root.ctx.time;
        return new Date();
    }
    readonly property bool pm: now.getHours() >= 12
    readonly property string time: (now.getHours() % 12 || 12) + ":" + String(now.getMinutes()).padStart(2, "0")

    // ISO week number.
    readonly property int week: {
        const d = new Date(Date.UTC(now.getFullYear(), now.getMonth(), now.getDate()));
        d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
        return Math.ceil(((d - Date.UTC(d.getUTCFullYear(), 0, 1)) / 86400000 + 1) / 7);
    }

    Sky {
        anchors.fill: parent
        radius: root.big ? 28 : Math.min(34, height * 0.22)
        glossInset: root.big ? 14 : 24
        glossHeight: root.big ? 70 : height * 0.44
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
            readonly property real padX: 18
            readonly property real gap: 14
            readonly property real dialD: Math.min(height * 0.82, width * 0.42)

            Clockface {
                id: face
                x: c.padX
                anchors.verticalCenter: parent.verticalCenter
                width: c.dialD
                height: c.dialD
                time: root.now
            }

            Item {
                id: slot
                x: face.x + face.width + c.gap
                width: parent.width - x - c.padX + 6
                height: parent.height
                Column {
                    id: words
                    anchors.verticalCenter: parent.verticalCenter
                    scale: Math.min(1, slot.width / Math.max(1, implicitWidth))
                    transformOrigin: Item.Left
                    spacing: 2
                    Row {
                        Text {
                            text: root.time
                            color: Ink.navy
                            font.family: Ink.family
                            font.pixelSize: 40
                        }
                        Text {
                            anchors.baseline: parent.children[0].baseline
                            text: root.pm ? " PM" : " AM"
                            color: Ink.blue
                            font.family: Ink.family
                            font.pixelSize: 17
                        }
                    }
                    Text {
                        text: Qt.formatDate(root.now, "dddd")
                        color: Ink.blue
                        font.family: Ink.family
                        font.pixelSize: 16
                    }
                    Text {
                        text: Qt.formatDate(root.now, "d MMMM yyyy")
                        color: Ink.green
                        font.family: Ink.family
                        font.pixelSize: 14
                    }
                }
            }
        }
    }

    // ── Expanded: the calendar ──────────────────────────────────────
    Component {
        id: board
        Dots {
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
            readonly property int padX: 6
            readonly property int pageW: cols - padX * 2
            readonly property int cellW: Math.floor(pageW / 7)
            readonly property int bigPx: Math.max(12, Math.min(18, Math.floor(rows * 0.15)))
            readonly property int headY: 4 + bigPx + 4
            readonly property int dowY: headY + 11
            readonly property int gridY: dowY + 8
            readonly property int cellH: Math.max(8, Math.floor((rows - gridY - 12) / 6))

            // Today's bubble: crisp, under its digits (outside the canvas).
            Rectangle {
                parent: u
                z: -1
                visible: u.todayAt >= 0
                readonly property int at: u.todayAt
                width: Math.min(u.cellW * u.pitch - 4, 21 * u.pitch)
                height: Math.min(u.cellH * u.pitch - 2, 11 * u.pitch)
                x: (u.padX + (at % 7) * u.cellW) * u.pitch + (u.cellW * u.pitch - width) / 2
                y: (u.gridY + Math.floor(at / 7) * u.cellH) * u.pitch + (u.cellH * u.pitch - height) / 2
                radius: height / 2
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: "#b9f0a8"
                    }
                    GradientStop {
                        position: 0.7
                        color: Ink.green
                    }
                }
            }

            // 9:47                                 Sunday
            //                                    18 October
            Say {
                x: u.padX
                y: 3
                text: root.time
                size: u.bigPx
            }
            Column {
                anchors.right: parent.right
                anchors.rightMargin: u.padX
                y: 3 + u.bigPx - 15
                spacing: 2
                MatrixText {
                    anchors.right: parent.right
                    width: implicitWidth
                    height: 7
                    text: Qt.formatDate(root.now, "dddd")
                    color: Ink.blue
                }
                MatrixText {
                    anchors.right: parent.right
                    width: implicitWidth
                    height: 7
                    text: Qt.formatDate(root.now, "d MMMM")
                    color: Ink.blue
                }
            }

            // ◂          October 2026          ▸
            Item {
                x: u.padX
                y: u.headY
                width: u.pageW
                height: 7
                MatrixText {
                    width: implicitWidth
                    height: 7
                    text: "◂"
                    color: Ink.navy
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
                    color: Ink.navy
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
                    color: Ink.navy
                    T.Hit {
                        anchors.fill: parent
                        anchors.margins: -2
                        onTap: u.offset++
                    }
                }
            }

            // S M T W T F S
            Row {
                x: u.padX
                y: u.dowY
                Repeater {
                    model: ["S", "M", "T", "W", "T", "F", "S"]
                    MatrixText {
                        required property string modelData
                        width: u.cellW
                        height: 5
                        font: "3x5"
                        align: "center"
                        text: modelData
                        color: Ink.blue
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
                            color: modelData.today ? "white" : Ink.navy
                            opacity: modelData.other ? 0.3 : 1
                        }
                    }
                }
            }

            MatrixText {
                x: u.padX
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                width: u.pageW
                height: 5
                font: "3x5"
                scroll: true
                text: root.words.foot || "WEEK " + root.week + " · UTC " + (root.ctx.utc ?? "")
                color: Ink.blue
            }
        }
    }
}
