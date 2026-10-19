import QtQuick
import QtQuick.Effects
import qs
import qs.services

// Clipboard, Tokyo Night: the last few copies in numbered neon slots (the
// newest rimmed cyan; a colour shows its swatch, a picture its thumbnail),
// a click pastes. Expanded, a search line and kind filters over the
// history, and the picked copy in full beside it with PASTE and DELETE.
Face {
    id: root

    readonly property var items: ctx.items ?? []
    function kind(t: string): string {
        const s = String(t ?? "").trim();
        if (/^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(s) || /^rgba?\(/i.test(s))
            return "COLORS";
        if (/^(https?|ftp):\/\//i.test(s))
            return "LINKS";
        if (/^(\/|~\/|file:\/\/).+\.(png|jpe?g|webp|gif|avif)$/i.test(s))
            return "IMAGES";
        return "TEXT";
    }
    function path(t: string): string {
        return String(t).trim().replace(/^file:\/\//, "").replace(/^~(?=\/)/, Feeds.home);
    }
    function ago(at: real): string {
        const s = Math.max(0, (Date.now() - at) / 1000);
        return s < 60 ? "NOW" : s < 3600 ? Math.floor(s / 60) + "M" : s < 86400 ? Math.floor(s / 3600) + "H" : Math.floor(s / 86400) + "D";
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : sign
    }

    // A copy's swatch or thumbnail, crisp: nothing for plain text.
    component Swatch: Item {
        id: sw
        property string text: ""
        readonly property string k: root.kind(text)
        visible: k === "COLORS" || k === "IMAGES"
        Tube {
            visible: sw.k === "COLORS"
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height)
            height: width
            radius: width / 2
            line: 0
            fill: sw.k === "COLORS" ? sw.text.trim() : "transparent"
            tint: fill
            glow: 0.6
        }
        Image {
            id: pic
            anchors.fill: parent
            visible: false
            source: sw.k === "IMAGES" ? "file://" + root.path(sw.text) : ""
            sourceSize: Qt.size(width * 2, height * 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        Rectangle {
            id: mask
            anchors.fill: parent
            radius: 4
            visible: false
            layer.enabled: true
        }
        MultiEffect {
            anchors.fill: parent
            visible: sw.k === "IMAGES" && pic.status === Image.Ready
            source: pic
            maskEnabled: true
            maskSource: mask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
    }

    // ── Compact ─────────────────────────────────────────────────────
    Component {
        id: sign
        Item {
            id: s
            readonly property int padX: 13
            readonly property int rowH: 10
            readonly property int listY: Math.max(4, Math.round((glass.rows - rowsN * (rowH + 2) + 2) / 2))
            readonly property bool foot: glass.rows >= 64
            readonly property int rowsN: Math.max(0, Math.min(root.items.length, Math.floor((glass.rows - 14 - (foot ? 11 : 0)) / (rowH + 2))))

            Glass {
                id: glass
                radius: Ink.curve
                Repeater {
                    model: root.items.slice(0, s.rowsN)
                    Item {
                        required property var modelData
                        required property int index
                        readonly property bool pic: ["COLORS", "IMAGES"].includes(root.kind(modelData.text))
                        x: s.padX
                        y: s.listY + index * (s.rowH + 2)
                        width: glass.cols - s.padX * 2
                        height: s.rowH
                        MatrixText {
                            x: 5
                            y: 3
                            height: 5
                            font: "3x5"
                            text: String(index + 1).padStart(2, "0")
                            color: Ink.violet
                        }
                        MatrixText {
                            x: parent.pic ? 31 : 15
                            y: 3
                            width: parent.width - x - age.implicitWidth - 8
                            height: 5
                            font: "3x5"
                            text: modelData.preview
                            color: index === 0 ? Ink.cyan : Ink.pink
                        }
                        MatrixText {
                            id: age
                            anchors.right: parent.right
                            anchors.rightMargin: 5
                            y: 3
                            height: 5
                            font: "3x5"
                            text: root.ago(modelData.at)
                            color: Ink.violet
                        }
                        Hit {
                            anchors.fill: parent
                            action: "paste " + index
                        }
                    }
                }
                Words {
                    visible: s.foot
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 5
                    small: true
                    text: "コピー · CLICK TO PASTE"
                    color: Ink.violet
                }
                Words {
                    visible: root.items.length === 0
                    anchors.centerIn: parent
                    text: root.words.empty || "NOTHING COPIED"
                    color: Ink.deep
                }
            }
            Repeater {
                model: root.items.slice(0, s.rowsN)
                Item {
                    required property var modelData
                    required property int index
                    x: glass.x + s.padX * root.pitch
                    y: glass.y + (s.listY + index * (s.rowH + 2)) * root.pitch
                    width: (glass.cols - s.padX * 2) * root.pitch
                    height: s.rowH * root.pitch
                    Tube {
                        anchors.fill: parent
                        radius: height / 2
                        line: 1.5
                        tint: index === 0 ? Ink.cyan : Ink.deep
                        glow: index === 0 ? 0.6 : 0
                    }
                    Swatch {
                        x: 15 * root.pitch
                        y: 3
                        width: 14 * root.pitch
                        height: parent.height - 6
                        text: modelData.text
                    }
                }
            }
            Sign {
                radius: Ink.curve
                inner: true
            }
        }
    }

    // ── Expanded: history and preview ───────────────────────────────
    Component {
        id: board
        Item {
            id: b
            property string query: ""
            property string kind: "ALL"
            property int picked: 0
            readonly property var shown: root.items.map((it, i) => Object.assign({ i: i }, it)).filter(it => (kind === "ALL" || root.kind(it.text) === kind) && (!query || String(it.text).toLowerCase().includes(query.toLowerCase())))
            readonly property var cur: shown[Math.min(picked, shown.length - 1)] ?? null
            readonly property int listW: Math.round(glass.cols * 0.6)
            readonly property int rowH: 10
            readonly property int listY: 5 + 13 + 3 + 9 + 3
            readonly property int rowsN: Math.max(0, Math.min(shown.length, Math.floor((glass.rows - listY - 4) / (rowH + 2))))
            onKindChanged: picked = 0
            onQueryChanged: picked = 0

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: 28
                color: Ink.glass
            }
            // Inside the cyan tube.
            Item {
                anchors.fill: parent
                anchors.margins: 8
                Glass {
                    id: glass
                    radius: 20
                    Item {
                        x: 9
                        y: 5
                        width: b.listW - 13
                        height: 13
                        DotText {
                            x: 1
                            height: parent.height
                            text: "⌕"
                            color: Ink.pink
                        }
                        Field {
                            x: 10
                            width: parent.width - 12
                            height: parent.height
                            hint: "SEARCH COPIES"
                            onTyped: t => b.query = t
                        }
                    }
                    Repeater {
                        model: b.shown.slice(0, b.rowsN)
                        Item {
                            required property var modelData
                            required property int index
                            x: 5
                            y: b.listY + index * (b.rowH + 2)
                            width: b.listW - 5
                            height: b.rowH
                            MatrixText {
                                x: 5
                                y: 3
                                width: parent.width - 10 - t.implicitWidth - 3
                                height: 5
                                font: "3x5"
                                text: modelData.preview
                                color: index === b.picked ? Ink.cyan : Ink.pink
                            }
                            MatrixText {
                                id: t
                                anchors.right: parent.right
                                anchors.rightMargin: 5
                                y: 3
                                height: 5
                                font: "3x5"
                                text: root.ago(modelData.at)
                                color: Ink.violet
                            }
                            Hit {
                                anchors.fill: parent
                                onTap: b.picked === index ? root.run("paste " + modelData.i) : b.picked = index
                            }
                        }
                    }
                    Words {
                        visible: b.shown.length === 0
                        x: 5
                        y: b.listY + 4
                        text: root.items.length ? "NO MATCH" : (root.words.empty || "NOTHING COPIED")
                        color: Ink.deep
                    }
                    // The preview, in full.
                    Item {
                        x: b.listW + 6
                        y: 7
                        width: glass.cols - b.listW - 6 - 8
                        height: glass.rows - 14
                        MatrixText {
                            height: 5
                            font: "3x5"
                            text: "PREVIEW"
                            color: Ink.violet
                        }
                        Column {
                            y: 9
                            width: parent.width
                            spacing: 2
                            Repeater {
                                // The copy wrapped to the width, as many lines as fit.
                                model: {
                                    const per = Math.max(4, Math.floor((parent.width + 1) / 4));
                                    const t = String(b.cur?.text ?? "").replace(/\s+/g, " ");
                                    const out = [];
                                    for (let i = 0; i < t.length && out.length < 5; i += per)
                                        out.push(t.slice(i, i + per));
                                    return out;
                                }
                                MatrixText {
                                    required property string modelData
                                    width: parent.width
                                    height: 5
                                    font: "3x5"
                                    text: modelData
                                    color: Ink.pink
                                }
                            }
                        }
                        MatrixText {
                            y: 9 + 5 * 7 + 3
                            width: parent.width
                            height: 5
                            font: "3x5"
                            visible: b.cur !== null
                            text: root.kind(b.cur?.text) + " · " + String(b.cur?.text ?? "").length + " CHARS · " + (b.cur ? Qt.formatTime(new Date(b.cur.at), "hh:mm") : "")
                            color: Ink.violet
                        }
                    }
                }

                // Crisp: search rim, kind chips, row slots, preview rim and keys.
                Tube {
                    x: glass.x + 5 * root.pitch
                    y: glass.y + 4 * root.pitch
                    width: (b.listW - 5) * root.pitch
                    height: 15 * root.pitch
                    radius: height / 2
                    line: 2
                    tint: Ink.cyan
                    glow: 0.8
                }
                Row {
                    x: glass.x + 5 * root.pitch
                    y: glass.y + (5 + 13 + 3) * root.pitch
                    spacing: 4
                    readonly property real w: (b.listW - 5) * root.pitch
                    Repeater {
                        model: ["ALL", "TEXT", "LINKS", "IMAGES", "COLORS"]
                        Chip {
                            required property string modelData
                            width: (parent.w - 16) / 5
                            height: 9 * root.pitch
                            size: 10
                            pad: 3
                            text: modelData
                            tone: b.kind === modelData ? "on" : "pink"
                            onTap: b.kind = modelData
                        }
                    }
                }
                Repeater {
                    model: b.shown.slice(0, b.rowsN)
                    Tube {
                        required property int index
                        x: glass.x + 5 * root.pitch
                        y: glass.y + (b.listY + index * (b.rowH + 2)) * root.pitch
                        width: (b.listW - 5) * root.pitch
                        height: b.rowH * root.pitch
                        radius: height / 2
                        line: 1.5
                        tint: index === b.picked ? Ink.cyan : Ink.deep
                        glow: index === b.picked ? 0.6 : 0
                    }
                }
                Item {
                    id: pv
                    x: glass.x + (b.listW + 3) * root.pitch
                    y: glass.y + 4 * root.pitch
                    width: (glass.cols - b.listW - 3 - 5) * root.pitch
                    height: (glass.rows - 8) * root.pitch
                    Tube {
                        anchors.fill: parent
                        radius: 14
                        line: 1.5
                        tint: Ink.cyan
                        glow: 0.5
                    }
                    Swatch {
                        x: 10
                        y: (9 + 5 * 7 + 12) * root.pitch
                        width: 36
                        height: 26
                        text: b.cur?.text ?? ""
                    }
                    Row {
                        visible: b.cur !== null
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 8
                        x: 8
                        spacing: 4
                        Chip {
                            text: "Paste"
                            tone: "cyan"
                            size: 9
                            pad: 5
                            action: "paste " + (b.cur?.i ?? 0)
                        }
                        Chip {
                            text: "Delete"
                            tone: "cyan"
                            size: 9
                            pad: 5
                            action: "clip forget " + (b.cur?.i ?? 0)
                        }
                    }
                }
            }
            Sign {
                radius: 28
                inner: true
            }
        }
    }
}
