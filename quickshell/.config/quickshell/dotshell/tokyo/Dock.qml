import QtQuick
import qs

// Dock, Tokyo Night: a tall neon pill. The launcher on top, then the
// running apps in rings (the focused one lit cyan with a bar beside it,
// its workspace on a badge), the pinned ones dim, and a chevron that opens
// the list. Expanded: a search line, running apps with their workspace and
// window count, pinned apps under them.
Face {
    id: root

    readonly property var running: ctx.running ?? []
    readonly property var pinned: ctx.pinned ?? []

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : sign
    }

    // An app in a ring, in dots: `lit` rings it cyan.
    component AppRing: Item {
        id: ring
        property string glyph: ""
        property bool lit: false
        property bool dim: false
        property string badge: ""
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: ring.lit ? Ink.cyan : Ink.violet
            opacity: ring.dim ? 0.45 : 1
        }
        DotText {
            anchors.centerIn: parent
            height: Tokens.fontPx
            text: ring.glyph
            color: ring.lit ? Ink.cyan : Ink.violet
            opacity: ring.dim ? 0.45 : 1
        }
        Rectangle {
            visible: ring.badge !== ""
            x: parent.width - width + 1
            y: parent.height - height + 1
            width: Math.max(5, badgeText.implicitWidth + 2)
            height: 7
            radius: 2
            color: Ink.violet
            MatrixText {
                id: badgeText
                anchors.centerIn: parent
                height: 5
                font: "3x5"
                text: ring.badge
                color: Ink.glass
            }
        }
    }

    // ── Compact: the pill ───────────────────────────────────────────
    Component {
        id: sign
        Item {
            id: s
            readonly property int ringD: Math.min(13, glass.cols - 6)
            readonly property int step: ringD + 3
            readonly property int room: Math.floor((glass.rows - 6 - step - 6 - 12) / step)
            readonly property var runShown: root.running.slice(0, Math.max(0, room))
            readonly property var pinShown: root.pinned.slice(0, Math.max(0, room - runShown.length))

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: width / 2
                color: Ink.glass
            }
            Glass {
                id: glass
                radius: width / 2
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round(glass.cols / 2) - Math.round(s.ringD / 2)
                    spacing: 3
                    AppRing {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: s.ringD
                        height: s.ringD
                        glyph: "◎"
                        Hit {
                            anchors.fill: parent
                            action: "launcher"
                        }
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.round(glass.cols * 0.6)
                        height: 1
                        color: Ink.violet
                        opacity: 0.7
                    }
                    Repeater {
                        model: s.runShown
                        Item {
                            required property var modelData
                            readonly property bool on: modelData.slot === 0
                            width: glass.cols
                            height: s.ringD
                            // Running: a dot at the edge; focused, a cyan bar.
                            Rectangle {
                                x: 1
                                anchors.verticalCenter: parent.verticalCenter
                                width: 1
                                height: parent.on ? 6 : 1
                                color: parent.on ? Ink.cyan : Ink.violet
                            }
                            AppRing {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: s.ringD
                                height: s.ringD
                                glyph: modelData.glyph
                                lit: parent.on
                                badge: modelData.ws ?? ""
                            }
                            Hit {
                                anchors.fill: parent
                                action: "jump " + modelData.cls
                            }
                        }
                    }
                    Rectangle {
                        visible: s.pinShown.length > 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.round(glass.cols * 0.6)
                        height: 1
                        color: Ink.violet
                        opacity: 0.7
                    }
                    Repeater {
                        model: s.pinShown
                        AppRing {
                            required property var modelData
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: s.ringD
                            height: s.ringD
                            glyph: modelData.glyph
                            dim: true
                            Hit {
                                anchors.fill: parent
                                action: "launch " + modelData.id
                            }
                        }
                    }
                }
                // Open the list.
                DotText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Math.round(glass.cols / 2) - 5
                    height: Tokens.fontPx
                    text: "▸"
                    color: Ink.violet
                    opacity: 0.6
                    Hit {
                        anchors.fill: parent
                        anchors.margins: -3
                        action: "panel expand"
                    }
                }
            }
            Sign {
                radius: width / 2
            }
        }
    }

    // ── Expanded: the list ──────────────────────────────────────────
    Component {
        id: board
        Item {
            id: b
            property string query: ""
            readonly property var runShown: root.running.filter(a => !query || (a.name + " " + a.title).toLowerCase().includes(query.toLowerCase()))
            readonly property var pinShown: root.pinned.filter(a => !query || a.name.toLowerCase().includes(query.toLowerCase()))
            readonly property int rowH: 17
            readonly property int runY: 5 + 13 + 4 + 8
            readonly property int runN: Math.max(0, Math.min(runShown.length, Math.floor((glass.rows - runY - 10 - 8) / rowH)))
            readonly property int pinY: runY + runN * rowH + 2 + 8
            readonly property int pinN: Math.max(0, Math.min(pinShown.length, Math.floor((glass.rows - pinY - 10) / rowH)))

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: 30
                color: Ink.glass
            }
            Glass {
                id: glass
                radius: 30
                Item {
                    x: 8
                    y: 5
                    width: glass.cols - 16
                    height: 13
                    DotText {
                        x: 2
                        height: parent.height
                        text: "⌕"
                        color: Ink.violet
                    }
                    Field {
                        x: 11
                        width: parent.width - 13
                        height: parent.height
                        hint: "SEARCH & LAUNCH"
                        action: "launch-query {value}"
                        onTyped: t => b.query = t
                    }
                }
                Words {
                    x: 6
                    y: b.runY - 8
                    small: true
                    text: "起動中 · " + (root.words.title || "RUNNING")
                    color: Ink.violet
                }
                Repeater {
                    model: b.runShown.slice(0, b.runN)
                    Item {
                        id: app
                        required property var modelData
                        readonly property bool on: modelData.slot === 0
                        x: 6
                        y: b.runY + index * b.rowH
                        required property int index
                        width: glass.cols - 12
                        height: b.rowH - 2
                        AppRing {
                            x: 2
                            y: 1
                            width: 13
                            height: 13
                            glyph: app.modelData.glyph
                            lit: app.on
                        }
                        MatrixText {
                            x: 19
                            y: 2
                            width: parent.width - 19 - dots.implicitWidth - 4
                            height: 5
                            font: "3x5"
                            text: app.modelData.name
                            color: app.on ? Ink.cyan : Ink.pink
                        }
                        MatrixText {
                            x: 19
                            y: 9
                            width: parent.width - 23
                            height: 5
                            font: "3x5"
                            text: "WS " + (app.modelData.ws || "-") + " · " + app.modelData.windows + " WIN · " + app.modelData.title
                            color: Ink.violet
                        }
                        MatrixText {
                            id: dots
                            anchors.right: parent.right
                            anchors.rightMargin: 3
                            y: 2
                            height: 5
                            font: "3x5"
                            text: "•".repeat(Math.min(4, app.modelData.windows))
                            color: Ink.pink
                        }
                        Hit {
                            anchors.fill: parent
                            action: "jump " + app.modelData.cls
                        }
                    }
                }
                Words {
                    visible: b.pinN > 0
                    x: 6
                    y: b.pinY - 8
                    small: true
                    text: "ピン · PINNED"
                    color: Ink.violet
                }
                Repeater {
                    model: b.pinShown.slice(0, b.pinN)
                    Item {
                        required property var modelData
                        required property int index
                        x: 6
                        y: b.pinY + index * b.rowH
                        width: glass.cols - 12
                        height: b.rowH - 2
                        AppRing {
                            x: 2
                            y: 1
                            width: 13
                            height: 13
                            glyph: modelData.glyph
                            dim: true
                        }
                        MatrixText {
                            x: 19
                            y: 2
                            width: parent.width - 23
                            height: 5
                            font: "3x5"
                            text: modelData.name
                            color: Ink.pink
                            opacity: 0.7
                        }
                        MatrixText {
                            x: 19
                            y: 9
                            height: 5
                            font: "3x5"
                            text: "PINNED · LAUNCH"
                            color: Ink.violet
                            opacity: 0.7
                        }
                        Hit {
                            anchors.fill: parent
                            action: "launch " + modelData.id
                        }
                    }
                }
                MatrixText {
                    x: 6
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    width: glass.cols - 12
                    height: 5
                    font: "3x5"
                    scroll: true
                    text: "CLICK JUMPS TO ITS WORKSPACE · ENTER SEARCHES THE LAUNCHER"
                    color: Ink.violet
                }
            }
            // Crisp: the search rim, the focused app's slot.
            Tube {
                x: glass.x + 6 * root.pitch
                y: glass.y + 4 * root.pitch
                width: (glass.cols - 12) * root.pitch
                height: 15 * root.pitch
                radius: height / 2
                line: 1.5
                tint: Ink.violet
                glow: 0.3
            }
            Repeater {
                model: b.runShown.slice(0, b.runN)
                Tube {
                    required property var modelData
                    required property int index
                    visible: modelData.slot === 0
                    x: glass.x + 5 * root.pitch
                    y: glass.y + (b.runY + index * b.rowH - 1) * root.pitch
                    width: (glass.cols - 10) * root.pitch
                    height: b.rowH * root.pitch
                    radius: 14
                    line: 1.5
                    tint: Ink.cyan
                    glow: 0.8
                }
            }
            Sign {
                radius: 30
            }
        }
    }
}
