import QtQuick
import qs
import qs.services
import qs.tokyo as T

// Clipboard, Nixie: the copies as ivory slips on the wood, newest first and
// warmer: its number, a colour's swatch in a brass ring or a picture's
// thumbnail (crisp), its words in dark dots and its time. A click pastes.
// Expanded, HISTORY: the search slip, the kinds as brass keys (the picked
// one polished), the history (the picked copy warm; a second click pastes
// it), and beside it the copy in full on a sheet with PASTE and DELETE.
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

    Wood {
        anchors.fill: parent
    }
    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? history : list
    }

    // One copy: its slip (warm when `lit`), the swatch or picture, and in
    // dots its mark, its words and its time.
    component Copy: Paper {
        id: copy
        property var c: ({})
        property string mark: ""
        property bool lit: false
        readonly property int p: Tokens.pitch
        readonly property string k: root.kind(c.preview)
        readonly property bool pic: k === "Colors" || k === "Images"
        readonly property real picX: 14 * p + 6
        tone: lit ? "hi" : ""
        Item {
            visible: copy.pic
            x: copy.picX
            anchors.verticalCenter: parent.verticalCenter
            width: copy.k === "Colors" ? parent.height - 6 : Math.round(parent.height * 1.4)
            height: parent.height - 6
            Rectangle {
                anchors.fill: parent
                visible: copy.k === "Colors"
                radius: width / 2
                color: copy.k === "Colors" ? String(copy.c.preview).trim() : "transparent"
                border.width: 2
                border.color: Ink.brass
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
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            soft: true
            readonly property int midY: Math.floor((rows - 7) / 2)
            MatrixText {
                y: ink.midY + 1
                width: 8
                height: 5
                font: "3x5"
                text: copy.mark
                color: Ink.paperSoft
            }
            MatrixText {
                x: copy.pic ? Math.ceil((copy.picX - 6 + (copy.k === "Colors" ? copy.height : copy.height * 1.4)) / copy.p) + 2 : 14
                width: ink.cols - x - age.implicitWidth - 4
                y: ink.midY
                height: 7
                scroll: copy.lit
                text: copy.c.preview ?? ""
                color: Ink.paperInk
            }
            MatrixText {
                id: age
                x: ink.cols - width
                y: ink.midY + 1
                width: implicitWidth
                height: 5
                font: "3x5"
                text: root.clock(copy.c.at)
                color: Ink.paperSoft
            }
        }
    }

    // ── Compact ─────────────────────────────────────────────────────
    Component {
        id: list
        Item {
            id: u
            readonly property int p: Tokens.pitch
            readonly property real rowH: 11 * p
            readonly property real gap: 6
            readonly property int rowsN: Math.max(0, Math.min(root.items.length, Math.floor((height - 24 + gap) / (rowH + gap))))
            Column {
                x: 12
                y: 12
                spacing: u.gap
                Repeater {
                    model: root.items.slice(0, u.rowsN)
                    Copy {
                        required property var modelData
                        required property int index
                        width: u.width - 24
                        height: u.rowH
                        c: modelData
                        mark: "(" + (index + 1) + ")"
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
                    y: Math.ceil(14 / u.p)
                    width: implicitWidth
                    height: 7
                    text: root.words.empty || "NOTHING COPIED"
                    color: Ink.digit
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
            readonly property real listW: Math.round((width - 24) * 0.62)
            readonly property real pvX: 12 + listW + 14
            readonly property real pvW: width - pvX - 12
            readonly property real fieldY: 12
            readonly property real fieldH: 11 * p
            readonly property real keysY: fieldY + fieldH + 8
            readonly property real rowH: 11 * p
            readonly property real gap: 6
            readonly property real listY: keysY + 20 + 10
            readonly property int rowsN: Math.max(0, Math.min(shown.length, Math.floor((height - 12 - listY + gap) / (rowH + gap))))
            onKindChanged: picked = 0
            onQueryChanged: picked = 0

            // The search slip.
            Paper {
                x: 12
                y: u.fieldY
                width: u.listW
                height: u.fieldH
                Dots {
                    x: 8
                    y: Math.round((u.fieldH - 7 * u.p) / 2)
                    width: parent.width - 16
                    height: 7 * u.p
                    soft: true
                    MatrixText {
                        y: 1
                        width: 16
                        height: 5
                        font: "3x5"
                        text: "FIND"
                        color: Ink.paperSoft
                    }
                    T.Field {
                        x: 20
                        width: parent.cols - 20
                        height: 7
                        hint: "SEARCH COPIES"
                        color: Ink.paperInk
                        hintColor: Ink.paperSoft
                        onTyped: t => u.query = t
                    }
                }
            }
            Row {
                x: 12
                y: u.keysY
                spacing: 6
                Repeater {
                    model: ["All", "Text", "Links", "Images", "Colors"]
                    Key {
                        required property string modelData
                        width: (u.listW - 24) / 5
                        height: 20
                        text: modelData.toUpperCase()
                        on: u.kind === modelData
                        onTap: u.kind = modelData
                    }
                }
            }
            Column {
                x: 12
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
                        mark: index === u.picked ? "*" : "·"
                        lit: index === u.picked
                        T.Hit {
                            anchors.fill: parent
                            onTap: u.picked === parent.index ? root.run("paste " + parent.modelData.i) : u.picked = parent.index
                        }
                    }
                }
            }
            // The contents' sheet and its keys.
            Paper {
                id: sheet
                x: u.pvX
                y: u.fieldY
                width: u.pvW
                height: u.height - u.fieldY - 12
                Dots {
                    x: 10
                    y: 10
                    width: parent.width - 20
                    height: parent.height - 44
                    soft: true
                    MatrixText {
                        height: 5
                        font: "3x5"
                        text: "STRIP"
                        color: Ink.paperSoft
                    }
                    Column {
                        id: copy
                        y: 9
                        width: parent.cols
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
                                color: Ink.paperInk
                            }
                        }
                    }
                    Column {
                        id: meta
                        y: copy.y + copy.height + 6
                        width: parent.cols
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
                                color: Ink.deep
                            }
                        }
                    }
                }
                Row {
                    visible: u.cur !== null
                    x: 10
                    y: sheet.height - 10 - 16
                    spacing: 6
                    Key {
                        width: 52
                        height: 16
                        text: "PASTE"
                        on: true
                        action: u.cur ? "paste " + u.cur.i : ""
                    }
                    Key {
                        width: 56
                        height: 16
                        text: "DELETE"
                        on: true
                        action: u.cur ? "clip forget " + u.cur.i : ""
                    }
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
                    color: Ink.digit
                }
            }
        }
    }
}
