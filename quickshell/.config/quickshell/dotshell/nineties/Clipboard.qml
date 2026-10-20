import QtQuick
import qs
import qs.services
import qs.tokyo as T

// Clipboard, 90s Nights: the copies as sticky slips on the dot glass in the
// sunset rim, newest first and yellow, each tilted a hair: its number in
// pink, a colour's swatch or a picture's thumbnail (crisp), its words in
// dark dots and its time in blue. A click pastes. Expanded, HISTORY: the
// search box ruled in the sunset, the kinds as leaning keys (the picked
// one yellow), the history (the picked copy yellow; a second click pastes
// it), and beside it the copy in full on a slip with Paste and Delete tags.
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

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? history : list
    }

    // One copy: its slip (yellow when `lit`), the swatch or picture, and in
    // dots its mark, its words and its time.
    component Copy: Slip {
        id: copy
        property var c: ({})
        property string mark: ""
        readonly property int p: Tokens.pitch
        readonly property string k: root.kind(c.preview)
        readonly property bool pic: k === "Colors" || k === "Images"
        readonly property real picX: 9 * p + 6
        readonly property real picW: k === "Colors" ? height - 8 : Math.round((height - 6) * 1.7)
        Item {
            visible: copy.pic
            x: copy.picX
            anchors.verticalCenter: parent.verticalCenter
            width: copy.picW
            height: copy.k === "Colors" ? copy.height - 8 : copy.height - 6
            Rectangle {
                anchors.fill: parent
                visible: copy.k === "Colors"
                radius: 2
                color: copy.k === "Colors" ? String(copy.c.preview).trim() : "transparent"
                Rectangle {
                    x: 1
                    y: 1
                    z: -1
                    width: parent.width
                    height: parent.height
                    radius: 2
                    color: Ink.shadow
                }
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
                color: Ink.pink
            }
            MatrixText {
                x: copy.pic ? Math.ceil((copy.picX - 6 + copy.picW) / copy.p) + 2 : 9
                width: ink.cols - x - age.implicitWidth - 4
                y: ink.midY
                height: 7
                scroll: copy.lit
                text: copy.c.preview ?? ""
                color: Ink.slipInk
            }
            MatrixText {
                id: age
                x: ink.cols - width
                y: ink.midY + 1
                width: implicitWidth
                height: 5
                font: "3x5"
                text: root.clock(copy.c.at)
                color: Ink.slipTime
            }
        }
    }

    // ── Compact ─────────────────────────────────────────────────────
    Component {
        id: list
        Item {
            id: u
            readonly property int p: Tokens.pitch
            readonly property real rowH: 9 * p
            readonly property real gap: 5
            readonly property int rowsN: Math.max(0, Math.min(root.items.length, Math.floor((height - 22 + gap) / (rowH + gap))))
            // The slips' block, centred top to bottom.
            readonly property real y0: Math.round((height - rowsN * (rowH + gap) + gap) / 2)
            Plate {
                id: plate
                anchors.fill: parent
                MatrixText {
                    visible: root.items.length === 0
                    x: Math.round(plate.leftAt(20) / u.p)
                    y: 4
                    width: implicitWidth
                    height: 7
                    text: root.words.empty || "NOTHING COPIED"
                    color: Ink.pink
                }
            }
            // The slips, each stepped along the sign's slant.
            Repeater {
                model: root.items.slice(0, u.rowsN)
                Copy {
                    required property var modelData
                    required property int index
                    readonly property real rowTop: u.y0 + index * (u.rowH + u.gap)
                    x: plate.leftAt(rowTop) + 8
                    y: rowTop
                    width: plate.rightAt(rowTop + u.rowH) - 10 - x
                    height: u.rowH
                    c: modelData
                    mark: "#" + (index + 1)
                    lit: index === 0
                    T.Hit {
                        anchors.fill: parent
                        action: "paste " + parent.index
                    }
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
            readonly property real listW: Math.round((width - 24) * 0.66)
            readonly property real pvX: 12 + listW + 12
            readonly property real pvW: width - pvX - 12
            readonly property real fieldY: 12
            readonly property real fieldH: 10 * p
            readonly property real keysY: fieldY + fieldH + 8
            readonly property real rowH: 9 * p
            readonly property real gap: 6
            readonly property real listY: keysY + 20 + 10
            readonly property int rowsN: Math.max(0, Math.min(shown.length, Math.floor((height - 12 - listY + gap) / (rowH + gap))))
            onKindChanged: picked = 0
            onQueryChanged: picked = 0

            Plate {
                id: plate
                anchors.fill: parent
                slant: false

                // ⌕ the search, on the glass.
                Item {
                    x: Math.round((12 + 8 - 3) / u.p)
                    y: Math.round((u.fieldY + (u.fieldH - 7 * u.p) / 2 - 3) / u.p)
                    width: Math.floor((u.listW - 16) / u.p)
                    height: 7
                    MatrixText {
                        y: 1
                        width: 16
                        height: 5
                        font: "3x5"
                        text: "FIND"
                        color: Ink.pink
                    }
                    T.Field {
                        x: 20
                        width: parent.width - 20
                        height: 7
                        hint: "SEARCH COPIES"
                        color: Ink.pink
                        hintColor: Ink.dim
                        onTyped: t => u.query = t
                    }
                }
                MatrixText {
                    visible: u.shown.length === 0
                    x: Math.ceil(14 / u.p)
                    y: Math.ceil(u.listY / u.p) + 2
                    width: implicitWidth
                    height: 7
                    text: root.items.length ? "NO MATCH" : (root.words.empty || "NOTHING COPIED")
                    color: Ink.pink
                }
            }
            Rim {
                x: 12
                y: u.fieldY
                width: u.listW
                height: u.fieldH
                thick: 2
                across: true
            }
            Row {
                x: 14
                y: u.keysY
                spacing: 4
                Repeater {
                    model: ["All", "Text", "Links", "Images", "Colors"]
                    Key {
                        required property string modelData
                        width: (u.listW - 4 - 16) / 5
                        height: 20
                        textPx: width < 64 ? 8 : 9
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
            // The contents' slip and its tags.
            Slip {
                id: sheet
                x: u.pvX
                y: u.fieldY
                width: u.pvW
                height: u.height - u.fieldY - 14
                tilt: 0
                drop: 3
                Dots {
                    x: 8
                    y: 8
                    width: parent.width - 16
                    height: parent.height - 40
                    soft: true
                    MatrixText {
                        height: 5
                        font: "3x5"
                        text: "PREVIEW"
                        color: Ink.slipTime
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
                                color: Ink.slipInk
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
                                color: Ink.slipTime
                            }
                        }
                    }
                }
                Row {
                    visible: u.cur !== null
                    x: 8
                    y: sheet.height - 8 - 16
                    spacing: 6
                    Pill {
                        height: 16
                        radius: 0
                        textPx: 8
                        text: "Paste"
                        action: u.cur ? "paste " + u.cur.i : ""
                    }
                    Pill {
                        height: 16
                        radius: 0
                        textPx: 8
                        text: "Delete"
                        action: u.cur ? "clip forget " + u.cur.i : ""
                    }
                }
            }
        }
    }
}
