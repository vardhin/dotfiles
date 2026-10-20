import QtQuick
import qs
import qs.services
import qs.tokyo as T

// Clipboard, Night Vision: the intercepts. A copy a line, newest first and
// boxed in white: its number dim, a colour as a phosphor disc or a picture
// in green dots, its words bright, its time dim at the right; a click
// pastes it. INTERCEPTS · SELECT TO RELAY under them. Expanded, HISTORY on
// the CRT: the QRY line boxed in white, the kinds as keys (the picked one
// lit), the history (the picked copy boxed; a second click pastes it), and
// beside it the INTERCEPT in full with PASTE and DEL keys.
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
    // A colour seen through the scope: its lightness on the phosphor.
    function phosphor(c: string): color {
        const q = Qt.color(String(c).trim());
        const l = Math.max(0, Math.min(1, q.hslLightness));
        return Qt.tint(Ink.deep, Qt.rgba(Ink.bright.r, Ink.bright.g, Ink.bright.b, 0.25 + l * 0.75));
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? history : list
    }

    // One copy on its line, in dots: its mark, room for its picture, its
    // words and its time.
    component Copy: Item {
        id: copy
        property var c: ({})
        property string mark: ""
        property bool lit: false
        property bool roomy: true
        property int markW: 16
        readonly property string k: root.kind(c.preview)
        readonly property bool pic: k === "Colors" || k === "Images"
        readonly property int faceH: roomy ? 7 : 5
        readonly property int picW: pic ? (k === "Colors" ? height - 2 : Math.round((height - 2) * 1.6)) + 3 : 0
        readonly property int midY: Math.floor((height - faceH) / 2)
        MatrixText {
            y: copy.midY + (copy.roomy ? 1 : 0)
            width: copy.markW
            height: 5
            font: "3x5"
            text: copy.mark
            color: Ink.dim
        }
        MatrixText {
            x: copy.markW + copy.picW
            width: copy.width - x - age.implicitWidth - 4
            y: copy.midY
            height: copy.faceH
            font: copy.roomy ? "5x7" : "3x5"
            scroll: copy.lit
            text: String(copy.c.preview ?? "").toUpperCase()
            color: Ink.bright
        }
        MatrixText {
            id: age
            x: copy.width - width
            y: copy.midY + (copy.roomy ? 1 : 0)
            width: implicitWidth
            height: 5
            font: "3x5"
            text: root.clock(copy.c.at)
            color: Ink.dim
        }
    }
    // A copy's picture, crisp over the dots: a phosphor disc or green dots.
    component Thumb: Item {
        id: th
        property var c: ({})
        readonly property string k: root.kind(c.preview)
        visible: k === "Colors" || k === "Images"
        Rectangle {
            visible: th.k === "Colors"
            anchors.verticalCenter: parent.verticalCenter
            width: parent.height
            height: parent.height
            radius: width / 2
            color: th.k === "Colors" ? root.phosphor(th.c.preview) : "transparent"
            antialiasing: true
        }
        Pic {
            visible: th.k === "Images"
            anchors.fill: parent
            source: th.k === "Images" ? "file://" + root.path(th.c.preview) : ""
        }
    }

    // ── Compact ─────────────────────────────────────────────────────
    Component {
        id: list
        Scope {
            id: s
            readonly property int l: dx((Math.max(18, rx * 0.5) + 8))
            readonly property int w: dx(width - (Math.max(18, rx * 0.5) + 8)) - l
            readonly property int t: (Math.max(2, Math.round(rows * 0.12)) + 2)
            readonly property bool roomy: w >= 150
            readonly property int rowH: roomy ? 11 : 9
            readonly property int rowsN: Math.max(0, Math.min(root.items.length, Math.floor((rows - t * 2 - 7) / rowH)))

            Repeater {
                model: root.items.slice(0, s.rowsN)
                Copy {
                    required property var modelData
                    required property int index
                    x: s.l
                    y: s.t + index * s.rowH
                    width: s.w
                    height: s.rowH
                    roomy: s.roomy
                    c: modelData
                    mark: "#" + (root.items.length - index)
                    markW: s.roomy ? 18 : 15
                    lit: index === 0
                }
            }
            MatrixText {
                x: s.l
                y: s.t + s.rowsN * s.rowH + 2
                width: s.w
                height: 5
                font: "3x5"
                scroll: true
                text: root.items.length === 0 ? (root.words.empty || "NO INTERCEPTS") : "INTERCEPTS · SELECT TO RELAY"
                color: Ink.dim
            }
            Repeater {
                parent: s.over
                model: root.items.slice(0, s.rowsN)
                Item {
                    required property var modelData
                    required property int index
                    x: s.px(s.l) - 4
                    y: s.py(s.t + index * s.rowH)
                    width: s.w * Tokens.pitch + 8
                    height: s.rowH * Tokens.pitch
                    Box {
                        anchors.fill: parent
                        visible: parent.index === 0
                        tone: "bright"
                    }
                    Thumb {
                        x: 4 + (s.roomy ? 18 : 15) * Tokens.pitch
                        y: 3
                        width: (root.kind(parent.modelData.preview) === "Colors" ? parent.height - 6 : Math.round((parent.height - 6) * 1.6))
                        height: parent.height - 6
                        c: parent.modelData
                    }
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
        Scope {
            id: u
            crt: true
            property string query: ""
            property string kind: "All"
            property int picked: 0
            readonly property var shown: root.items.map((it, i) => Object.assign({ i: i }, it)).filter(it => (kind === "All" || root.kind(it.text) === kind) && (!query || String(it.text).toLowerCase().includes(query.toLowerCase())))
            readonly property var cur: shown[Math.min(picked, shown.length - 1)] ?? null
            readonly property int p: Tokens.pitch
            readonly property real padX: (Math.max(16, rx * 0.36) + 10)
            readonly property real padY: (Math.max(12, ry * 0.6) + 8)
            readonly property real listW: Math.round((width - padX * 2 - 14) * 0.62)
            readonly property real pvX: padX + listW + 14
            readonly property real pvW: width - pvX - padX
            readonly property real fieldH: 10 * p
            readonly property real keysY: padY + fieldH + 8
            readonly property bool roomy: listW / p >= 150
            readonly property real rowH: (roomy ? 11 : 9) * p
            readonly property real listY: keysY + 20 + 8
            readonly property int rowsN: Math.max(0, Math.min(shown.length, Math.floor((height - padY - listY) / rowH)))
            onKindChanged: picked = 0
            onQueryChanged: picked = 0

            // QRY the search.
            Item {
                x: u.dx(u.padX + 8)
                y: u.dy(u.padY + u.fieldH / 2) - 3
                width: u.dx(u.padX + u.listW - 8) - x
                height: 7
                MatrixText {
                    y: 1
                    width: 14
                    height: 5
                    font: "3x5"
                    text: "QRY"
                    color: Ink.dim
                }
                T.Field {
                    x: 16
                    width: parent.width - 16
                    height: 7
                    hint: "SEARCH INTERCEPTS"
                    color: Ink.bright
                    hintColor: Ink.dim
                    onTyped: t => u.query = t
                }
            }
            Repeater {
                model: u.shown.slice(0, u.rowsN)
                Copy {
                    required property var modelData
                    required property int index
                    x: u.dx(u.padX) + 1
                    y: u.dy(u.listY + index * u.rowH)
                    width: u.dx(u.padX + u.listW) - x - 1
                    height: Math.round(u.rowH / u.p)
                    roomy: u.roomy
                    c: modelData
                    mark: index === u.picked ? "▸" : "·"
                    markW: 12
                    lit: index === u.picked
                }
            }
            MatrixText {
                visible: u.shown.length === 0
                x: u.dx(u.padX) + 2
                y: u.dy(u.listY) + 2
                width: implicitWidth
                height: 7
                text: root.items.length ? "NO MATCH" : (root.words.empty || "NO INTERCEPTS")
                color: Ink.dim
            }
            // The intercept, in full.
            Item {
                id: pv
                x: u.dx(u.pvX + 8)
                y: u.dy(u.padY + 8)
                width: u.dx(u.pvX + u.pvW - 8) - x
                height: u.dy(u.height - u.padY - 30) - y
                MatrixText {
                    height: 5
                    font: "3x5"
                    text: "INTERCEPT"
                    color: Ink.dim
                }
                Column {
                    id: body
                    y: 9
                    width: parent.width
                    spacing: 2
                    Repeater {
                        // The copy wrapped to the width, as many lines as fit.
                        model: {
                            const per = Math.max(4, Math.floor((body.width + 1) / 6));
                            const t = String(u.cur?.text ?? "").replace(/\s+/g, " ");
                            const out = [];
                            const most = Math.max(1, Math.floor((pv.height - 9 - 16) / 9));
                            for (let i = 0; i < t.length && out.length < most; i += per)
                                out.push(t.slice(i, i + per));
                            return out;
                        }
                        MatrixText {
                            required property string modelData
                            width: body.width
                            height: 7
                            text: modelData
                            color: Ink.bright
                        }
                    }
                }
                Column {
                    id: meta
                    y: body.y + body.height + 5
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
                            color: Ink.dim
                        }
                    }
                }
            }

            Box {
                parent: u.over
                x: u.padX
                y: u.padY
                width: u.listW
                height: u.fieldH
                tone: "bright"
            }
            Row {
                parent: u.over
                x: u.padX
                y: u.keysY
                spacing: 4
                Repeater {
                    model: ["All", "Text", "Links", "Images", "Colors"]
                    Key {
                        required property string modelData
                        width: (u.listW - 16) / 5
                        height: 20
                        textPx: width < 60 ? 9 : 11
                        text: modelData.toUpperCase()
                        on: u.kind === modelData
                        onTap: u.kind = modelData
                    }
                }
            }
            Repeater {
                parent: u.over
                model: u.shown.slice(0, u.rowsN)
                Item {
                    required property var modelData
                    required property int index
                    x: u.padX
                    y: u.py(u.dy(u.listY + index * u.rowH))
                    width: u.listW
                    height: u.rowH - 2
                    Box {
                        anchors.fill: parent
                        visible: parent.index === u.picked
                        tone: "bright"
                    }
                    Thumb {
                        x: u.px(u.dx(u.padX) + 1 + 12) - u.padX
                        y: 3
                        width: root.kind(parent.modelData.preview) === "Colors" ? parent.height - 6 : Math.round((parent.height - 6) * 1.6)
                        height: parent.height - 6
                        c: parent.modelData
                    }
                    T.Hit {
                        anchors.fill: parent
                        onTap: u.picked === parent.index ? root.run("paste " + parent.modelData.i) : u.picked = parent.index
                    }
                }
            }
            Box {
                parent: u.over
                x: u.pvX
                y: u.padY
                width: u.pvW
                height: u.height - u.padY * 2
            }
            Row {
                parent: u.over
                visible: u.cur !== null
                x: u.pvX + 8
                y: u.height - u.padY - 8 - 20
                spacing: 6
                Key {
                    height: 20
                    tone: "bright"
                    text: "PASTE"
                    action: u.cur ? "paste " + u.cur.i : ""
                }
                Key {
                    height: 20
                    tone: "bright"
                    text: "DEL"
                    action: u.cur ? "clip forget " + u.cur.i : ""
                }
            }
        }
    }
}
