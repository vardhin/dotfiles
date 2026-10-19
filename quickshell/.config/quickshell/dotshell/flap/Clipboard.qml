import QtQuick
import qs
import qs.services
import qs.tokyo as T

// Clipboard, Split-Flap: COPIED · RECENT FIRST. Each copy a long flap row:
// its number in yellow, a colour's swatch or a picture's thumbnail
// (crisp), its words in off-white dots and its time; the newest on a
// yellow row. A click pastes. Expanded: the search line ruled yellow,
// the kinds as keys (the picked one yellow), the history (the picked
// copy yellow; a second click pastes it), and beside it the copy in full
// on its card with PASTE and DEL tags.
T.Face {
    id: root

    readonly property var items: ctx.items ?? []
    function kind(t: string): string {
        const s = String(t ?? "").trim();
        if (/^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(s) || /^rgba?\(/i.test(s))
            return "Colors";
        if (/^(https?|ftp):\/\//i.test(s))
            return "Links";
        if (/^(\/|~\/|file:\/\/).+\.(png|jpe?g|webp|gif|avif)$/i.test(s))
            return "Images";
        return "Text";
    }
    function path(t: string): string {
        return String(t).trim().replace(/^file:\/\//, "").replace(/^~(?=\/)/, Feeds.home);
    }
    function clock(at: real): string {
        const d = new Date(at);
        const s = Math.max(0, (Date.now() - at) / 1000);
        return s < 86400 && d.getDate() === new Date().getDate() ? Qt.formatTime(d, "hh:mm") : s < 172800 ? "YEST" : Math.floor(s / 86400) + "D";
    }

    Housing {
        id: box
        anchors.fill: parent
        label: "COPIED · RECENT FIRST"
        status: String(root.items.length)
        statusInk: Ink.label
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? history : list
    }

    // One copy: its row (yellow when `lit`), the swatch, and in dots its
    // mark, its words and its time.
    component Copy: Item {
        id: copy
        property var c: ({})
        property string mark: ""
        property bool lit: false
        readonly property int p: Tokens.pitch
        readonly property string k: root.kind(c.preview)
        readonly property bool pic: k === "Colors" || k === "Images"
        readonly property color ink: lit ? Ink.housing : Ink.white
        Tile {
            anchors.fill: parent
            lit: copy.lit
        }
        Item {
            visible: copy.pic
            x: 9 * copy.p
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(parent.height * 1.3)
            height: parent.height - 6
            Rectangle {
                anchors.fill: parent
                visible: copy.k === "Colors"
                color: copy.k === "Colors" ? String(copy.c.preview).trim() : "transparent"
                radius: 2
            }
            T.DotPic {
                visible: copy.k === "Images"
                anchors.fill: parent
                radius: 0
                source: copy.k === "Images" ? "file://" + root.path(copy.c.preview) : ""
            }
        }
        Dots {
            id: ink
            anchors.fill: parent
            readonly property int midY: Math.floor((rows - 7) / 2)
            MatrixText {
                x: 2
                y: ink.midY
                width: 6
                height: 7
                text: copy.mark
                color: copy.lit ? Ink.housing : Ink.yellow
            }
            MatrixText {
                x: copy.pic ? 9 + Math.ceil(copy.height * 1.3 / copy.p) + 3 : 9
                width: ink.cols - x - age.implicitWidth - 5
                y: ink.midY
                height: 7
                scroll: copy.lit
                text: copy.c.preview ?? ""
                color: copy.ink
            }
            MatrixText {
                id: age
                x: ink.cols - width - 2
                y: ink.midY + 1
                width: implicitWidth
                height: 5
                font: "3x5"
                text: root.clock(copy.c.at)
                color: copy.lit ? Ink.housing : Ink.label
            }
        }
        Rectangle {
            y: Math.floor(parent.height / 2)
            width: parent.width
            height: 1
            color: Ink.seam
            opacity: 0.85
        }
    }

    // ── Compact ─────────────────────────────────────────────────────
    Component {
        id: list
        Item {
            id: u
            readonly property int p: Tokens.pitch
            readonly property real rowH: 11 * p
            readonly property real gap: 4
            readonly property int rowsN: Math.max(0, Math.min(root.items.length, Math.floor((height - box.bodyY - 10 + gap) / (rowH + gap))))
            Column {
                x: 12
                y: box.bodyY + 2
                spacing: u.gap
                Repeater {
                    model: root.items.slice(0, u.rowsN)
                    Copy {
                        required property var modelData
                        required property int index
                        width: u.width - 24
                        height: u.rowH
                        c: modelData
                        mark: index + 1
                        lit: index === 0
                        T.Hit {
                            anchors.fill: parent
                            action: "paste " + parent.index
                        }
                    }
                }
            }
            Dots {
                anchors.fill: parent
                MatrixText {
                    visible: root.items.length === 0
                    x: Math.ceil(14 / u.p)
                    y: Math.ceil(box.bodyY / u.p) + 2
                    width: implicitWidth
                    height: 7
                    text: root.words.empty || "NOTHING COPIED"
                    color: Ink.dim
                }
            }
        }
    }

    // ── Expanded: history and contents ──────────────────────────────
    Component {
        id: history
        Item {
            id: u
            property string query: ""
            property string kind: "All"
            property int picked: 0
            readonly property var shown: root.items.map((it, i) => Object.assign({ i: i }, it)).filter(it => (kind === "All" || root.kind(it.text) === kind) && (!query || String(it.text).toLowerCase().includes(query.toLowerCase())))
            readonly property var cur: shown[Math.min(picked, shown.length - 1)] ?? null
            readonly property int p: Tokens.pitch
            readonly property real listW: Math.round((width - 28) * 0.62)
            readonly property real pvX: 14 + listW + 12
            readonly property real pvW: width - pvX - 14
            readonly property real fieldY: box.bodyY + 2
            readonly property real fieldH: 11 * p
            readonly property real keysY: fieldY + fieldH + 8
            readonly property real rowH: 11 * p
            readonly property real gap: 4
            readonly property real listY: keysY + 22 + 10
            readonly property int rowsN: Math.max(0, Math.min(shown.length, Math.floor((height - 12 - listY + gap) / (rowH + gap))))
            onKindChanged: picked = 0
            onQueryChanged: picked = 0

            // The search line, ruled yellow.
            Rectangle {
                x: 14
                y: u.fieldY
                width: u.listW
                height: u.fieldH
                radius: 2
                color: Ink.lower
                border.width: 2
                border.color: Ink.yellow
            }
            Dots {
                x: 20
                y: u.fieldY + Math.round((u.fieldH - 7 * u.p) / 2)
                width: u.listW - 12
                height: 7 * u.p
                MatrixText {
                    y: 1
                    width: 16
                    height: 5
                    font: "3x5"
                    text: "FIND"
                    color: Ink.yellow
                }
                T.Field {
                    x: 20
                    width: Math.floor((u.listW - 12) / u.p) - 18
                    height: 7
                    hint: "SEARCH COPIES"
                    color: Ink.white
                    hintColor: Ink.label
                    onTyped: t => u.query = t
                }
            }
            Row {
                id: kinds
                x: 14
                y: u.keysY
                spacing: 4
                Repeater {
                    model: ["All", "Text", "Links", "Images", "Colors"]
                    Key {
                        required property string modelData
                        width: (u.listW - 16) / 5
                        height: 22
                        text: modelData.toUpperCase()
                        on: u.kind === modelData
                        onTap: u.kind = modelData
                    }
                }
            }
            Column {
                x: 14
                y: u.listY
                spacing: u.gap
                Repeater {
                    model: u.shown.slice(0, u.rowsN)
                    Copy {
                        required property var modelData
                        required property int index
                        width: u.listW
                        height: u.rowH
                        c: modelData
                        mark: index === u.picked ? "▸" : "·"
                        lit: index === u.picked
                        T.Hit {
                            anchors.fill: parent
                            onTap: u.picked === parent.index ? root.run("paste " + parent.modelData.i) : u.picked = parent.index
                        }
                    }
                }
            }
            // The contents' card and its tags.
            Card {
                x: u.pvX
                y: u.fieldY
                width: u.pvW
                height: u.height - u.fieldY - 12
            }
            Row {
                visible: u.cur !== null
                x: u.pvX + 10
                y: u.height - 12 - 10 - 14
                spacing: 6
                Tag {
                    text: "PASTE"
                    action: u.cur ? "paste " + u.cur.i : ""
                }
                Tag {
                    text: "DEL"
                    action: u.cur ? "clip forget " + u.cur.i : ""
                }
            }

            Dots {
                anchors.fill: parent
                MatrixText {
                    visible: u.shown.length === 0
                    x: Math.ceil(14 / u.p)
                    y: Math.ceil(u.listY / u.p) + 2
                    width: implicitWidth
                    height: 7
                    text: root.items.length ? "NO MATCH" : (root.words.empty || "NOTHING COPIED")
                    color: Ink.dim
                }
                // The contents.
                Item {
                    x: Math.ceil((u.pvX + 8) / u.p)
                    y: Math.ceil((u.fieldY + 8) / u.p)
                    width: Math.floor((u.pvW - 16) / u.p)
                    height: Math.floor((u.height - u.fieldY - 60) / u.p)
                    MatrixText {
                        height: 5
                        font: "3x5"
                        text: "PREVIEW"
                        color: Ink.label
                    }
                    Column {
                        id: copy
                        y: 9
                        width: parent.width
                        spacing: 2
                        Repeater {
                            // The copy wrapped to the width, as many lines as fit.
                            model: {
                                const per = Math.max(4, Math.floor((copy.width + 1) / 6));
                                const t = String(u.cur?.text ?? "").replace(/\s+/g, " ");
                                const out = [];
                                for (let i = 0; i < t.length && out.length < 4; i += per)
                                    out.push(t.slice(i, i + per));
                                return out;
                            }
                            MatrixText {
                                required property string modelData
                                width: copy.width
                                height: 7
                                text: modelData
                                color: Ink.white
                            }
                        }
                    }
                    Column {
                        id: meta
                        y: copy.y + copy.height + 6
                        width: parent.width
                        spacing: 2
                        visible: u.cur !== null
                        Repeater {
                            model: [root.kind(u.cur?.text).toUpperCase() + " · " + String(u.cur?.text ?? "").length + " CHARS", u.cur ? "COPIED " + Qt.formatTime(new Date(u.cur.at), "hh:mm") : ""]
                            MatrixText {
                                required property string modelData
                                width: meta.width
                                height: 5
                                font: "3x5"
                                text: modelData
                                color: Ink.label
                            }
                        }
                    }
                }
            }
        }
    }
}
