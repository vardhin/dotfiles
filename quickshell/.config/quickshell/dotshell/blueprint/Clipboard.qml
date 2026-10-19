import QtQuick
import qs
import qs.services
import qs.tokyo as T

// Clipboard, Blueprint: CLIPPINGS — NOTES. The last copies as numbered
// notes in dots (N-1, N-2 …), each on a faint rule, the newest marked by a
// white bar at its left; a colour shows its swatch and a picture its
// thumbnail, framed. A click pastes. Expanded, a framed REF search line
// and the kind keys over the history, and the picked copy in full in a
// DETAIL frame beside it, with Paste and Delete.
T.Face {
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
    function clock(at: real): string {
        const d = new Date(at);
        const s = Math.max(0, (Date.now() - at) / 1000);
        return s < 86400 && d.getDate() === new Date().getDate() ? Qt.formatTime(d, "hh:mm") : s < 172800 ? "YEST" : Math.floor(s / 86400) + "D";
    }

    Paper {
        anchors.fill: parent
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? history : list
    }

    // A copy's swatch (a colour) or thumbnail (a picture), framed.
    component Swatch: Item {
        id: sw
        property string text: ""
        readonly property string k: root.kind(text)
        visible: k === "COLORS" || k === "IMAGES"
        Rectangle {
            visible: sw.k === "COLORS"
            anchors.fill: parent
            color: sw.k === "COLORS" ? sw.text.trim() : "transparent"
        }
        Image {
            visible: sw.k === "IMAGES"
            anchors.fill: parent
            source: sw.k === "IMAGES" ? "file://" + root.path(sw.text) : ""
            sourceSize: Qt.size(width * 2, height * 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: Ink.ink
        }
    }

    // The faint rule under a row and the picked one's white bar, crisp.
    component Rule: Item {
        id: rule
        property bool lit: false
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Ink.faint
        }
        Rectangle {
            visible: rule.lit
            y: 2
            width: 2
            height: parent.height - 4
            color: Ink.white
        }
    }

    // One copy in dots: its mark, its words and its time; the swatch goes
    // in the gap, crisp (see swatches).
    component Copy: Item {
        id: copy
        property var c: ({})
        property string mark: ""
        property bool lit: false
        readonly property bool pic: ["COLORS", "IMAGES"].includes(root.kind(c.preview))
        MatrixText {
            x: 3
            anchors.verticalCenter: parent.verticalCenter
            width: 12
            height: 5
            font: "3x5"
            text: copy.mark
            color: Ink.line
        }
        MatrixText {
            x: copy.pic ? 32 : 17
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - age.implicitWidth - 6
            font: String(copy.c.preview ?? "").length * 6 <= width ? "5x7" : "3x5"
            height: font === "5x7" ? 7 : 5
            text: copy.c.preview ?? ""
            color: copy.lit ? Ink.white : Ink.ink
        }
        MatrixText {
            id: age
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: implicitWidth
            height: 5
            font: "3x5"
            text: root.clock(copy.c.at)
            color: Ink.line
        }
    }

    // ── Compact ─────────────────────────────────────────────────────
    Component {
        id: list
        Item {
            id: u
            readonly property int p: Tokens.pitch
            readonly property int cols: Math.floor(width / p)
            readonly property int rows: Math.floor(height / p)
            readonly property int padX: Math.ceil(14 / p)
            readonly property int listY: Math.ceil(28 / p)
            readonly property int rowH: 11
            readonly property int rowsN: Math.max(0, Math.min(root.items.length, Math.floor((rows - listY - 2) / rowH)))

            Sheet {
                y: 8
                title: "CLIPPINGS — NOTES"
                rev: "SHT 12"
            }
            Repeater {
                model: root.items.slice(0, u.rowsN)
                Item {
                    required property var modelData
                    required property int index
                    x: u.padX * u.p
                    y: (u.listY + index * u.rowH) * u.p
                    width: (u.cols - u.padX * 2) * u.p
                    height: u.rowH * u.p
                    Rule {
                        anchors.fill: parent
                        lit: parent.index === 0
                    }
                    Swatch {
                        x: 17 * u.p
                        anchors.verticalCenter: parent.verticalCenter
                        width: 13 * u.p
                        height: 7 * u.p
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
                        x: u.padX
                        y: u.listY + index * u.rowH
                        width: u.cols - u.padX * 2
                        height: u.rowH
                        c: modelData
                        mark: "N-" + (index + 1)
                        lit: index === 0
                        T.Hit {
                            anchors.fill: parent
                            action: "paste " + parent.index
                        }
                    }
                }
                MatrixText {
                    visible: root.items.length === 0
                    anchors.centerIn: parent
                    width: implicitWidth
                    height: implicitHeight
                    text: root.words.empty || "NOTHING COPIED"
                    color: Ink.line
                }
            }
        }
    }

    // ── Expanded: history and detail ────────────────────────────────
    Component {
        id: history
        Item {
            id: u
            property string query: ""
            property string kind: "ALL"
            property int picked: 0
            readonly property var shown: root.items.map((it, i) => Object.assign({ i: i }, it)).filter(it => (kind === "ALL" || root.kind(it.text) === kind) && (!query || String(it.text).toLowerCase().includes(query.toLowerCase())))
            readonly property var cur: shown[Math.min(picked, shown.length - 1)] ?? null
            readonly property int p: Tokens.pitch
            readonly property int cols: Math.floor(width / p)
            readonly property int rows: Math.floor(height / p)
            readonly property int padX: Math.ceil(16 / p)
            readonly property int topY: Math.ceil(30 / p)
            readonly property int listW: Math.round(cols * 0.6)
            readonly property int rowH: 11
            readonly property int listY: topY + 25
            readonly property int rowsN: Math.max(0, Math.min(shown.length, Math.floor((rows - listY - 3) / rowH)))
            readonly property int pvX: padX + listW + 4
            readonly property int pvW: cols - pvX - padX
            onKindChanged: picked = 0
            onQueryChanged: picked = 0

            Sheet {
                title: "CLIPPINGS — NOTES"
                rev: "SHT 12"
            }
            // Crisp: the search frame, the kind keys, the rules and
            // swatches, the detail frame and its words that do something.
            Rectangle {
                x: u.padX * u.p
                y: u.topY * u.p
                width: u.listW * u.p
                height: 10 * u.p
                color: "transparent"
                border.width: 1
                border.color: Ink.white
            }
            Row {
                id: kinds
                x: u.padX * u.p
                y: (u.topY + 13) * u.p
                spacing: 4
                readonly property real w: u.listW * u.p
                Repeater {
                    model: ["ALL", "TEXT", "LINKS", "IMAGES", "COLORS"]
                    Key {
                        required property string modelData
                        width: (kinds.w - 16) / 5
                        height: 9 * u.p
                        textPx: 10
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
                    x: u.padX * u.p
                    y: (u.listY + index * u.rowH) * u.p
                    width: u.listW * u.p
                    height: u.rowH * u.p
                    Rule {
                        anchors.fill: parent
                        lit: parent.index === u.picked
                    }
                    Swatch {
                        x: 17 * u.p
                        anchors.verticalCenter: parent.verticalCenter
                        width: 13 * u.p
                        height: 7 * u.p
                        text: parent.modelData.preview ?? ""
                    }
                }
            }
            Rectangle {
                x: u.pvX * u.p
                y: u.topY * u.p
                width: u.pvW * u.p
                height: (u.rows - u.topY - 4) * u.p
                color: "transparent"
                border.width: 1
                border.color: Ink.line
            }
            Row {
                visible: u.cur !== null
                x: (u.pvX + 4) * u.p
                y: (u.rows - 7) * u.p - height
                spacing: 6
                Tag {
                    text: "Paste"
                    action: u.cur ? "paste " + u.cur.i : ""
                }
                Tag {
                    text: "Delete"
                    action: u.cur ? "clip forget " + u.cur.i : ""
                }
            }

            Dots {
                anchors.fill: parent
                // REF pacman▏
                MatrixText {
                    x: u.padX + 3
                    y: u.topY + 3
                    width: 12
                    height: 5
                    font: "3x5"
                    text: "REF"
                    color: Ink.line
                }
                T.Field {
                    x: u.padX + 17
                    y: u.topY + 1
                    width: u.listW - 20
                    height: 8
                    hint: "SEARCH COPIES"
                    color: Ink.ink
                    hintColor: Ink.line
                    onTyped: t => u.query = t
                }
                Repeater {
                    model: u.shown.slice(0, u.rowsN)
                    Copy {
                        required property var modelData
                        required property int index
                        x: u.padX
                        y: u.listY + index * u.rowH
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
                MatrixText {
                    visible: u.shown.length === 0
                    x: u.padX + 3
                    y: u.listY + 2
                    width: implicitWidth
                    height: implicitHeight
                    text: root.items.length ? "NO MATCH" : (root.words.empty || "NOTHING COPIED")
                    color: Ink.line
                }
                // The detail.
                Item {
                    x: u.pvX + 4
                    y: u.topY + 4
                    width: u.pvW - 8
                    height: u.rows - u.topY - 12
                    MatrixText {
                        height: 5
                        font: "3x5"
                        text: "DETAIL"
                        color: Ink.line
                    }
                    Column {
                        id: copy
                        y: 9
                        width: parent.width
                        spacing: 2
                        Repeater {
                            // The copy wrapped to the width, as many lines as fit.
                            model: {
                                const per = Math.max(4, Math.floor((copy.width + 1) / 4));
                                const t = String(u.cur?.text ?? "").replace(/\s+/g, " ");
                                const out = [];
                                for (let i = 0; i < t.length && out.length < 5; i += per)
                                    out.push(t.slice(i, i + per));
                                return out;
                            }
                            MatrixText {
                                required property string modelData
                                width: copy.width
                                height: 5
                                font: "3x5"
                                text: modelData
                                color: Ink.ink
                            }
                        }
                    }
                    Column {
                        id: meta
                        y: copy.y + copy.height + 5
                        width: parent.width
                        spacing: 2
                        visible: u.cur !== null
                        Repeater {
                            model: [root.kind(u.cur?.text) + " · " + String(u.cur?.text ?? "").length + " CHARS", u.cur ? "COPIED " + Qt.formatTime(new Date(u.cur.at), "hh:mm") : ""]
                            MatrixText {
                                required property string modelData
                                width: meta.width
                                height: 5
                                font: "3x5"
                                text: modelData
                                color: Ink.line
                            }
                        }
                    }
                }
            }
        }
    }
}
