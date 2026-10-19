import QtQuick
import qs
import qs.services
import qs.tokyo as T

// Clipboard, Vaporwave: clipbrd.exe. The last copies in dots on the white
// page, numbered, the newest on the sunset bar; a colour shows its swatch
// and a picture its thumbnail beside the words, crisp; each with its time.
// A click pastes. Expanded: a search line in its box, the kinds as push
// buttons (the picked one hot pink), the history (the picked copy on the
// bar; a second click pastes it), and beside it the copy in full on its
// own page with Paste and Delete.
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

    Win {
        id: win
        anchors.fill: parent
        icon: "▤"
        title: "clipbrd.exe"
        big: root.big
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? history : list
    }

    // The sunset bar behind the picked copy, crisp.
    component Glow: Rectangle {
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: Ink.violet
            }
            GradientStop {
                position: 1
                color: Ink.pink
            }
        }
    }

    // A copy's swatch (a colour) or thumbnail (a picture), crisp.
    component Swatch: Item {
        id: sw
        property string text: ""
        readonly property string k: root.kind(text)
        visible: k === "Colors" || k === "Images"
        Rectangle {
            visible: sw.k === "Colors"
            anchors.fill: parent
            color: sw.k === "Colors" ? sw.text.trim() : "transparent"
        }
        T.DotPic {
            visible: sw.k === "Images"
            anchors.fill: parent
            radius: 0
            source: sw.k === "Images" ? "file://" + root.path(sw.text) : ""
        }
        Bevel {
            anchors.fill: parent
            dark: Ink.ink
        }
    }

    // One copy in dots: its mark, its words and its time; the swatch goes
    // in the gap, crisp (see the swatches).
    component Copy: Item {
        id: copy
        property var c: ({})
        property string mark: ""
        property bool lit: false
        readonly property bool pic: ["Colors", "Images"].includes(root.kind(c.preview))
        MatrixText {
            x: 2
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 5
            font: "3x5"
            text: copy.mark
            color: copy.lit ? Ink.hi : Ink.violet
        }
        MatrixText {
            x: copy.pic ? 30 : 12
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - age.implicitWidth - 6
            font: String(copy.c.preview ?? "").length * 6 <= width ? "5x7" : "3x5"
            height: font === "5x7" ? 7 : 5
            text: copy.c.preview ?? ""
            color: copy.lit ? Ink.hi : Ink.ink
        }
        MatrixText {
            id: age
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: implicitWidth
            height: 5
            font: "3x5"
            text: root.clock(copy.c.at)
            color: copy.lit ? Ink.hi : Ink.violet
        }
    }

    // ── Compact ─────────────────────────────────────────────────────
    Component {
        id: list
        Item {
            id: u
            readonly property int p: Tokens.pitch
            readonly property real wellY: win.bodyY + 6
            readonly property real wellH: height - wellY - 8
            readonly property int x0: Math.ceil(16 / p)
            readonly property int w0: Math.floor((width - 32) / p)
            readonly property int listY: Math.ceil((wellY + 6) / p)
            readonly property int rowH: 11
            readonly property int rowsN: Math.max(0, Math.min(root.items.length, Math.floor((Math.floor((wellY + wellH - 4) / p) - listY) / rowH)))

            Well {
                x: 8
                y: u.wellY
                width: parent.width - 16
                height: u.wellH
                paper: true
            }
            Repeater {
                model: root.items.slice(0, u.rowsN)
                Item {
                    required property var modelData
                    required property int index
                    x: u.x0 * u.p - 4
                    y: (u.listY + index * u.rowH) * u.p
                    width: u.w0 * u.p + 8
                    height: u.rowH * u.p
                    Glow {
                        visible: parent.index === 0
                        anchors.fill: parent
                        anchors.topMargin: 1
                        anchors.bottomMargin: 1
                    }
                    Swatch {
                        x: 12 * u.p + 4
                        anchors.verticalCenter: parent.verticalCenter
                        width: 15 * u.p
                        height: 8 * u.p
                        text: parent.modelData.preview ?? ""
                    }
                }
            }
            Dots {
                anchors.fill: parent
                Repeater {
                    model: root.items.slice(0, u.rowsN)
                    Copy {
                        required property var modelData
                        required property int index
                        x: u.x0
                        y: u.listY + index * u.rowH
                        width: u.w0
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
                MatrixText {
                    visible: root.items.length === 0
                    x: u.x0
                    y: u.listY + 2
                    width: implicitWidth
                    height: 7
                    text: root.words.empty || "NOTHING COPIED"
                    color: Ink.violet
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
            readonly property real wellY: win.bodyY + 6
            readonly property real wellH: height - wellY - 8
            readonly property real listW: Math.round((width - 16) * 0.62)
            readonly property real pvX: 8 + listW + 8
            readonly property real pvW: width - pvX - 14
            readonly property real fieldY: wellY + 10
            readonly property real keysY: fieldY + 34
            readonly property int x0: Math.ceil(18 / p)
            readonly property int w0: Math.floor((listW - 18) / p)
            readonly property int rowH: 11
            readonly property int listY: Math.ceil((keysY + 30) / p)
            readonly property int rowsN: Math.max(0, Math.min(shown.length, Math.floor((Math.floor((wellY + wellH - 4) / p) - listY) / rowH)))
            onKindChanged: picked = 0
            onQueryChanged: picked = 0

            Well {
                x: 8
                y: u.wellY
                width: parent.width - 16
                height: u.wellH
            }
            // The search box and the list's page.
            Rectangle {
                x: 12
                y: u.wellY + 4
                width: u.listW - 8
                height: u.wellH - 8
                color: Ink.face
            }
            Rectangle {
                x: u.x0 * u.p - 4
                y: u.fieldY
                width: u.w0 * u.p + 8
                height: 26
                color: Ink.hi
                border.width: 1
                border.color: Ink.mid
            }
            Row {
                id: kinds
                x: u.x0 * u.p - 4
                y: u.keysY
                spacing: 4
                readonly property real w: u.w0 * u.p + 8
                Repeater {
                    model: ["All", "Text", "Links", "Images", "Colors"]
                    Key {
                        required property string modelData
                        width: (kinds.w - 16) / 5
                        height: 22
                        text: modelData
                        on: u.kind === modelData
                        onTap: u.kind = modelData
                    }
                }
            }
            Repeater {
                model: u.shown.slice(0, u.rowsN)
                Item {
                    required property var modelData
                    required property int index
                    x: u.x0 * u.p - 4
                    y: (u.listY + index * u.rowH) * u.p
                    width: u.w0 * u.p + 8
                    height: u.rowH * u.p
                    Glow {
                        visible: parent.index === u.picked
                        anchors.fill: parent
                        anchors.topMargin: 1
                        anchors.bottomMargin: 1
                    }
                    Swatch {
                        x: 12 * u.p + 4
                        anchors.verticalCenter: parent.verticalCenter
                        width: 15 * u.p
                        height: 8 * u.p
                        text: parent.modelData.preview ?? ""
                    }
                }
            }
            // The contents' page and its buttons.
            Well {
                x: u.pvX
                y: u.wellY + 6
                width: u.pvW
                height: u.wellH - 12
                paper: true
            }
            Row {
                visible: u.cur !== null
                x: u.pvX + 10
                y: u.wellY + u.wellH - 14 - 22
                spacing: 6
                Key {
                    width: 64
                    height: 22
                    text: "Paste"
                    action: u.cur ? "paste " + u.cur.i : ""
                }
                Key {
                    width: 64
                    height: 22
                    text: "Delete"
                    action: u.cur ? "clip forget " + u.cur.i : ""
                }
            }

            Dots {
                anchors.fill: parent
                // Fir pacman▏
                MatrixText {
                    x: u.x0
                    y: Math.round((u.fieldY + 13) / u.p) - 3
                    width: 16
                    height: 5
                    font: "3x5"
                    text: "Find"
                    color: Ink.violet
                }
                T.Field {
                    x: u.x0 + 18
                    y: Math.round((u.fieldY + 13) / u.p) - 4
                    width: u.w0 - 20
                    height: 8
                    hint: "SEARCH COPIES"
                    color: Ink.ink
                    hintColor: Ink.violet
                    onTyped: t => u.query = t
                }
                Repeater {
                    model: u.shown.slice(0, u.rowsN)
                    Copy {
                        required property var modelData
                        required property int index
                        x: u.x0
                        y: u.listY + index * u.rowH
                        width: u.w0
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
                MatrixText {
                    visible: u.shown.length === 0
                    x: u.x0
                    y: u.listY + 2
                    width: implicitWidth
                    height: 7
                    text: root.items.length ? "NO MATCH" : (root.words.empty || "NOTHING COPIED")
                    color: Ink.violet
                }
                // The contents.
                Item {
                    x: Math.ceil((u.pvX + 8) / u.p)
                    y: Math.ceil((u.wellY + 14) / u.p)
                    width: Math.floor((u.pvW - 16) / u.p)
                    height: Math.floor((u.wellH - 60) / u.p)
                    MatrixText {
                        height: 5
                        font: "3x5"
                        text: "Contents:"
                        color: Ink.violet
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
                                color: Ink.ink
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
                                color: Ink.violet
                            }
                        }
                    }
                }
            }
        }
    }
}
