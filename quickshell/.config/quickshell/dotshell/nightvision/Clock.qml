import QtQuick
import qs
import qs.tokyo as T

// Clock, Night Vision: the scope's time stamp. Inside four white reticle
// corners, LOCAL · E 05:30 (the zone's offset) in dim small print, the
// time big in bright Share Tech Mono dots (24 h, no colon: 2147), and the
// zulu time and date under it (1617Z · 18.10.26; a click opens the
// calendar pane). Expanded, OPS CALENDAR on the CRT: the time big, zulu
// and date at the right, the month (◂ ▸ page it, its name goes back to
// this month), the days lit with today ringed in white and the other
// months' days faint, the week and NO TASKING · STANDBY at the foot.
T.Face {
    id: root

    // Re-read every second with the clock feed.
    readonly property date now: {
        void root.ctx.time;
        return new Date();
    }
    readonly property string hm: Qt.formatTime(now, "HHmm")
    readonly property string zulu: String(ctx.utc ?? Qt.formatTime(new Date(now.getTime() + now.getTimezoneOffset() * 60000), "HH:mm")).replace(":", "") + "Z"
    readonly property string zone: {
        const m = -now.getTimezoneOffset();
        const a = Math.abs(m);
        return (m >= 0 ? "E " : "W ") + String(Math.floor(a / 60)).padStart(2, "0") + ":" + String(a % 60).padStart(2, "0");
    }

    // How wide the time is in Share Tech Mono, per px of font size.
    TextMetrics {
        id: tm
        font.family: Ink.family
        font.pixelSize: 100
        text: "0000"
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : stamp
    }

    // ── Compact ─────────────────────────────────────────────────────
    Component {
        id: stamp
        Scope {
            id: s
            // The reticle box: inside the pill's curve.
            readonly property real bx: (Math.max(18, rx * 0.42) + 6)
            readonly property real by: Math.max(8, height * 0.13) + 3
            readonly property int l: dx(bx + 16)
            readonly property int w: dx(width - bx - 16) - l
            readonly property int t: dy(by + 6)
            readonly property int h: dy(height - by - 6) - t
            readonly property bool roomy: h >= 34
            readonly property int smallH: roomy ? 7 : 5
            // The time's room between the two small lines.
            readonly property int room: h - smallH - 6 - 3
            readonly property int timeDots: Math.max(8, Math.min(Math.round(room * 1.05), Math.floor(w * 0.7 / (tm.width / 100))))

            MatrixText {
                x: s.l
                y: s.t
                width: s.w
                height: 5
                font: "3x5"
                align: "center"
                text: "LOCAL · " + root.zone
                color: Ink.dim
            }
            Say {
                x: s.l
                y: s.t + 6 + Math.round(s.timeDots * 0.08)
                width: s.w
                height: s.room
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                size: Math.round(s.timeDots * 1.32)
                text: root.hm
                elide: Text.ElideNone
            }
            MatrixText {
                id: date
                readonly property string full: root.zulu + " · " + Qt.formatDate(root.now, "dd.MM.yy")
                x: s.l
                y: s.t + s.h - s.smallH
                width: s.w
                height: s.smallH
                font: s.roomy && full.length * 6 <= s.w ? "5x7" : "3x5"
                align: "center"
                text: full
                color: Ink.lit
                T.Hit {
                    anchors.fill: parent
                    anchors.margins: -2
                    action: "pane calendar"
                }
            }
            Brackets {
                parent: s.over
                x: s.bx
                y: s.by
                width: s.width - s.bx * 2
                height: s.height - s.by * 2
            }
        }
    }

    // ── Expanded: the calendar ──────────────────────────────────────
    Component {
        id: board
        Scope {
            id: b
            crt: true
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
            readonly property int x0: dx((Math.max(16, rx * 0.36) + 10))
            readonly property int w0: dx(width - (Math.max(16, rx * 0.36) + 10)) - x0
            readonly property int timeY: dy((Math.max(12, ry * 0.7) + 8))
            readonly property int timeH: Math.max(12, Math.min(26, Math.floor(rows * 0.2), Math.floor(w0 * 0.5 / (tm.width / 100 * 1.3))))
            readonly property string navFont: w0 >= 22 * 6 + 20 ? "5x7" : "3x5"
            readonly property int navY: timeY + timeH + 6
            readonly property int dowY: navY + 12
            readonly property int gridY: dowY + 8
            readonly property int footY: dy(height - (Math.max(12, ry * 0.7) + 8)) - 5
            readonly property real cellW: w0 / 7
            readonly property int cellH: Math.max(7, Math.floor((footY - 4 - gridY) / weeks))
            readonly property string dayFont: cellH >= 9 && cellW >= 14 ? "5x7" : "3x5"
            readonly property int week: {
                const d = new Date(Date.UTC(root.now.getFullYear(), root.now.getMonth(), root.now.getDate()));
                const day = d.getUTCDay() || 7;
                d.setUTCDate(d.getUTCDate() + 4 - day);
                return Math.ceil(((d - new Date(Date.UTC(d.getUTCFullYear(), 0, 1))) / 86400000 + 1) / 7);
            }

            // 2147                                  1617Z
            //                                    18.10.26
            Say {
                x: b.x0
                y: b.timeY - Math.round(b.timeH * 0.15)
                width: Math.ceil(implicitWidth) + 2
                height: Math.round(b.timeH * 1.3)
                verticalAlignment: Text.AlignVCenter
                size: Math.round(b.timeH * 1.32)
                text: root.hm
                elide: Text.ElideNone
            }
            Column {
                x: b.x0 + b.w0 - width
                y: b.timeY + b.timeH - height
                spacing: 3
                Repeater {
                    model: [root.zulu, Qt.formatDate(root.now, "dd.MM.yy")]
                    MatrixText {
                        required property string modelData
                        required property int index
                        anchors.right: parent.right
                        width: implicitWidth
                        readonly property bool roomy: b.w0 >= 120
                        height: roomy ? 7 : 5
                        font: roomy ? "5x7" : "3x5"
                        text: modelData
                        color: index === 0 ? Ink.lit : Ink.bright
                    }
                }
            }
            // ◂        OPS CALENDAR · OCT        ▸
            MatrixText {
                x: b.x0
                y: b.navY
                width: implicitWidth
                font: b.navFont
                height: font === "5x7" ? 7 : 5
                text: "◂"
                color: Ink.dim
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
                text: "OPS CALENDAR · " + Qt.formatDate(b.month, b.offset === 0 ? "MMM" : "MMM yyyy").toUpperCase()
                color: Ink.lit
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
                color: Ink.dim
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
                    color: Ink.dim
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
                    font: b.dayFont
                    height: font === "5x7" ? 7 : 5
                    align: "center"
                    text: modelData.n
                    color: modelData.today ? Ink.bright : Ink.lit
                    opacity: modelData.other ? 0.3 : 1
                }
            }
            MatrixText {
                x: b.x0
                y: b.footY
                width: b.w0
                height: 5
                font: "3x5"
                scroll: true
                text: "NO TASKING · STANDBY · WEEK " + b.week + " · " + Qt.formatDate(root.now, "dddd d MMMM").toUpperCase()
                color: Ink.dim
            }
            // Today ringed in white.
            Repeater {
                parent: b.over
                model: b.cells
                Rectangle {
                    required property var modelData
                    required property int index
                    visible: modelData.today
                    x: b.px(b.x0 + index % 7 * b.cellW) + 2
                    y: b.py(b.gridY + Math.floor(index / 7) * b.cellH) + 1
                    width: b.cellW * b.p - 4
                    height: b.cellH * b.p - 2
                    radius: height / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Ink.bright
                    antialiasing: true
                }
            }
        }
    }
}
