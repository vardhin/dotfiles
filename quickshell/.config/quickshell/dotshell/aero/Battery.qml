import QtQuick
import QtQuick.Effects
import Quickshell.Io
import qs
import qs.services
import qs.tokyo as T

// Battery, Frutiger Aero: a glossy glass battery on the sky, filled with
// green (red when low), and beside it the percent, the state and the time
// left. Expanded, the last 24 hours as bubble-dot columns on a white card
// (blue where it was charging, red under 15%) with the warning lines, and
// four readings on white cards.
T.Face {
    id: root

    readonly property real frac: ctx.fraction ?? 0
    readonly property bool charging: !!ctx.charging
    readonly property bool low: ctx.level === "bad"
    readonly property string status: {
        const w = String(ctx.stateWord ?? "");
        return low ? "Low — plug in" : charging ? "Charging" : w ? w.charAt(0) + w.slice(1).toLowerCase() : "";
    }
    readonly property string remain: {
        const t = String(ctx.time ?? "");
        return !t ? "" : charging ? t + " TO FULL" : t + " LEFT";
    }

    Sky {
        anchors.fill: parent
        radius: root.big ? 28 : Math.min(30, height * 0.22)
        gloss: !root.big
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : cell
    }

    // ── Compact: the battery ────────────────────────────────────────
    Component {
        id: cell
        Item {
            id: c
            readonly property real s: Math.min(1, height / 140, width / 340)
            readonly property real padX: 20 * s

            Row {
                id: battery
                x: c.padX
                anchors.verticalCenter: parent.verticalCenter
                Item {
                    width: 120 * c.s
                    height: 62 * c.s
                    Rectangle {
                        anchors.fill: parent
                        radius: 16 * c.s
                        border.width: 2
                        border.color: Ink.c("white", Qt.rgba(1, 1, 1, 0.16))
                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: Ink.c("white", "#1f3d5f")
                            }
                            GradientStop {
                                position: 1
                                color: Ink.pale
                            }
                        }
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: Ink.shadow
                            shadowBlur: 0.25
                            blurMax: 8
                            shadowVerticalOffset: 2
                            shadowHorizontalOffset: 0
                        }
                    }
                    // The charge.
                    Rectangle {
                        x: 6 * c.s
                        y: 6 * c.s
                        height: parent.height - 12 * c.s
                        width: Math.max(height * 0.3, (parent.width - 12 * c.s) * Math.max(0, Math.min(1, root.frac)))
                        radius: 10 * c.s
                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: root.low ? "#ffb3b3" : "#b9f0a8"
                            }
                            GradientStop {
                                position: 1
                                color: root.low ? Ink.c("#c8323c", "#ff5a64") : Ink.green
                            }
                        }
                        Rectangle {
                            width: parent.width
                            height: 3 * c.s
                            radius: parent.radius
                            color: Ink.gloss(0.6)
                        }
                    }
                    // Its shine.
                    Rectangle {
                        x: 6 * c.s
                        y: 6 * c.s
                        width: parent.width - 12 * c.s
                        height: parent.height * 0.4
                        topLeftRadius: 10 * c.s
                        topRightRadius: 10 * c.s
                        bottomLeftRadius: 30 * c.s
                        bottomRightRadius: 30 * c.s
                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: Ink.gloss(0.7)
                            }
                            GradientStop {
                                position: 1
                                color: Ink.gloss(0)
                            }
                        }
                    }
                    // Charging: a bolt on the glass.
                    Text {
                        anchors.centerIn: parent
                        visible: root.charging
                        text: "⚡"
                        color: "white"
                        style: Text.Outline
                        styleColor: Ink.green
                        font.pixelSize: 26 * c.s
                    }
                }
                // The nub.
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7 * c.s
                    height: 22 * c.s
                    topRightRadius: 4 * c.s
                    bottomRightRadius: 4 * c.s
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0
                            color: Ink.pale
                        }
                        GradientStop {
                            position: 1
                            color: Ink.plate2
                        }
                    }
                }
            }

            Item {
                id: slot
                x: battery.x + battery.width + 16 * c.s
                width: parent.width - x - c.padX + 4
                height: parent.height
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    scale: Math.min(1, slot.width / Math.max(1, implicitWidth))
                    transformOrigin: Item.Left
                    spacing: 1
                    Text {
                        text: (root.ctx.pct ?? 0) + "%"
                        color: root.low ? Ink.c("#c8323c", "#ff5a64") : Ink.navy
                        font.family: Ink.family
                        font.pixelSize: Math.round(34 * Math.max(0.85, c.s))
                    }
                    Text {
                        text: root.status
                        color: Ink.blue
                        font.family: Ink.family
                        font.pixelSize: 14
                    }
                    Text {
                        visible: text !== ""
                        text: root.remain
                        color: Ink.green
                        font.family: Ink.family
                        font.pixelSize: 13
                    }
                }
            }
        }
    }

    // ── Expanded: 24 hours ──────────────────────────────────────────
    Component {
        id: board
        Item {
            id: b
            property string cycles: "--"
            Process {
                running: true
                command: ["sh", "-c", "cat /sys/class/power_supply/BAT*/cycle_count 2>/dev/null | head -1"]
                stdout: StdioCollector {
                    onStreamFinished: b.cycles = text.trim() && text.trim() !== "0" ? text.trim() : "--"
                }
            }
            readonly property var cards: [
                { name: "RATE", text: ((root.charging ? "+" : root.ctx.stateWord === "ON BATTERY" ? "-" : "") + (root.ctx.watts ?? 0).toFixed(1) + " W"), act: "" },
                { name: "HEALTH", text: root.ctx.health || "--", act: "" },
                { name: "CYCLES", text: b.cycles, act: "" },
                { name: "PROFILE", text: Power.profileName(Power.profile), act: "power profile " + ((Power.profile + 1) % (Power.hasPerformance ? 3 : 2)) }
            ]
            readonly property int p: Tokens.pitch
            readonly property int padX: 6
            readonly property int pageW: Math.floor(width / p) - padX * 2
            readonly property int bigPx: Math.max(12, Math.min(16, Math.floor(height / p * 0.16)))
            readonly property int graphY: 4 + bigPx + 3
            readonly property int cardH: 16
            readonly property int cardY: Math.floor(height / p) - 11 - cardH
            readonly property int graphH: cardY - 10 - graphY
            readonly property int cardW: Math.floor((pageW - 9) / 4)

            // Crisp under the dots: the graph's card and its warning lines,
            // the readings' cards.
            Card {
                x: b.padX * b.p
                y: b.graphY * b.p
                width: b.pageW * b.p
                height: b.graphH * b.p
                radius: 12
            }
            Repeater {
                model: [0.15, 0.10, 0.05]
                Row {
                    required property real modelData
                    x: b.padX * b.p + 3
                    y: (b.graphY + 2 + (b.graphH - 4) * (1 - modelData)) * b.p
                    spacing: 3
                    Repeater {
                        model: Math.max(0, Math.floor((b.pageW * b.p - 6) / 7))
                        Rectangle {
                            width: 4
                            height: 1
                            color: Ink.c("#c8323c", "#ff5a64")
                            opacity: 0.7
                        }
                    }
                }
            }
            Repeater {
                model: 4
                Card {
                    required property int index
                    x: (b.padX + index * (b.cardW + 3)) * b.p
                    y: b.cardY * b.p
                    width: b.cardW * b.p
                    height: b.cardH * b.p
                }
            }

            Dots {
                id: u
                anchors.fill: parent

                // 72%                                      ON BATTERY
                //                                           3:41 LEFT
                Say {
                    x: b.padX
                    y: 3
                    text: (root.ctx.pct ?? 0) + "%"
                    size: b.bigPx
                    color: root.low ? Ink.c("#c8323c", "#ff5a64") : Ink.navy
                }
                Column {
                    anchors.right: parent.right
                    anchors.rightMargin: b.padX
                    y: 3 + b.bigPx - 13
                    spacing: 2
                    Repeater {
                        model: [String(root.ctx.stateWord ?? ""), root.remain]
                        MatrixText {
                            required property string modelData
                            anchors.right: parent.right
                            width: implicitWidth
                            height: 5
                            font: "3x5"
                            text: modelData
                            color: Ink.blue
                        }
                    }
                }

                // The day, oldest on the left: blue where it was charging.
                Canvas {
                    id: graph
                    x: b.padX + 2
                    y: b.graphY + 2
                    width: b.pageW - 4
                    height: b.graphH - 4
                    readonly property var hist: root.ctx.hist ?? []
                    readonly property int n: Math.max(1, Math.floor((width + 1) / 3))
                    readonly property var shown: hist.length > n ? hist.filter((v, i) => i % Math.ceil(hist.length / n) === 0) : hist
                    antialiasing: false
                    renderTarget: Canvas.Image
                    onShownChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        const c = getContext("2d");
                        c.reset();
                        const h = Math.floor(height), s = shown;
                        for (let i = 0; i < s.length; i++) {
                            const up = i > 0 && s[i] > s[i - 1] + 0.001;
                            c.fillStyle = String(up ? Ink.blue : s[i] <= 0.15 ? Ink.c("#c8323c", "#ff5a64") : Ink.green);
                            const lit = Math.max(1, Math.round(Math.max(0, Math.min(1, s[i])) * h));
                            c.fillRect(i * 3, h - lit, 2, lit);
                        }
                    }
                }
                MatrixText {
                    visible: graph.shown.length < 2
                    x: b.padX + Math.round((b.pageW - width) / 2)
                    y: b.graphY + Math.round((b.graphH - 5) / 2)
                    width: implicitWidth
                    height: 5
                    font: "3x5"
                    text: "HISTORY FILLS IN EVERY 5 MIN"
                    color: Ink.blue
                }
                // -24 H              -12 H              NOW
                Repeater {
                    model: [["-24 H", "left"], ["-12 H", "center"], ["NOW", "right"]]
                    MatrixText {
                        required property var modelData
                        x: b.padX
                        y: b.graphY + b.graphH + 3
                        width: b.pageW
                        height: 5
                        font: "3x5"
                        align: modelData[1]
                        text: modelData[0]
                        color: Ink.blue
                    }
                }
                // RATE   HEALTH   CYCLES   PROFILE
                Repeater {
                    model: b.cards
                    Item {
                        required property var modelData
                        required property int index
                        x: b.padX + index * (b.cardW + 3)
                        y: b.cardY
                        width: b.cardW
                        height: b.cardH
                        MatrixText {
                            x: 3
                            y: 2
                            height: 5
                            font: "3x5"
                            text: modelData.name
                            color: Ink.blue
                        }
                        MatrixText {
                            x: 3
                            y: 8
                            width: parent.width - 5
                            height: 7
                            font: modelData.text.length * 6 <= parent.width - 5 ? "5x7" : "3x5"
                            scroll: true
                            text: modelData.text
                            color: Ink.navy
                        }
                        T.Hit {
                            anchors.fill: parent
                            visible: modelData.act !== ""
                            action: modelData.act
                        }
                    }
                }
                MatrixText {
                    x: b.padX
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 5
                    width: b.pageW
                    height: 5
                    font: "3x5"
                    scroll: true
                    text: "YOU WILL BE WARNED AT 15%, 10% AND 5%"
                    color: Ink.blue
                }
            }
        }
    }
}
