import QtQuick
import qs
import qs.services
import qs.tokyo as T

// Clipboard, VFD: the last copies on the head unit's display, numbered in
// amber (#1 the newest, outlined), a colour showing its swatch and a
// picture its thumbnail in dots; a click pastes. Expanded, a FIND line and
// the kind keys over the history, and the picked copy in full in a ruled
// card beside it, with PASTE and DEL keys.
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

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : list
    }

    // A copy's swatch (a colour) or thumbnail (a picture), in dots.
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
    }

    // ── Compact ─────────────────────────────────────────────────────
    Component {
        id: list
        Unit {
            id: u
            readonly property int padX: 4
            readonly property int rowH: 9
            readonly property int rowsN: Math.max(0, Math.min(root.items.length, Math.floor((rows - 4) / rowH)))
            readonly property int listY: Math.max(2, Math.round((rows - rowsN * rowH) / 2))

            Repeater {
                model: root.items.slice(0, u.rowsN)
                Item {
                    required property var modelData
                    required property int index
                    readonly property bool pic: ["COLORS", "IMAGES"].includes(root.kind(modelData.text))
                    x: u.padX
                    y: u.listY + index * u.rowH
                    width: u.cols - u.padX * 2
                    height: u.rowH
                    MatrixText {
                        x: 3
                        y: 2
                        height: 5
                        font: "3x5"
                        text: "#" + (index + 1)
                        color: Ink.amber
                    }
                    Swatch {
                        x: 13
                        y: 1
                        width: 11
                        height: 7
                        text: modelData.preview
                    }
                    MatrixText {
                        x: parent.pic ? 27 : 13
                        y: 2
                        width: parent.width - x - age.implicitWidth - 9
                        height: 5
                        font: "3x5"
                        text: modelData.preview
                        color: Ink.cyan
                    }
                    MatrixText {
                        id: age
                        anchors.right: parent.right
                        anchors.rightMargin: 3
                        y: 2
                        height: 5
                        font: "3x5"
                        text: root.clock(modelData.at)
                        color: Ink.teal
                    }
                    T.Hit {
                        anchors.fill: parent
                        action: "paste " + index
                    }
                }
            }
            MatrixText {
                visible: root.items.length === 0
                anchors.centerIn: parent
                width: implicitWidth
                height: implicitHeight
                text: root.words.empty || "NOTHING COPIED"
                color: Ink.teal
            }

            over: Box {
                visible: u.rowsN > 0
                dx: u.padX
                dy: u.listY
                dw: u.cols - u.padX * 2
                dh: u.rowH
                color: "transparent"
                border.color: Ink.amber
            }
        }
    }

    // ── Expanded: history and preview ───────────────────────────────
    Component {
        id: board
        Unit {
            id: u
            property string query: ""
            property string kind: "ALL"
            property int picked: 0
            readonly property var shown: root.items.map((it, i) => Object.assign({ i: i }, it)).filter(it => (kind === "ALL" || root.kind(it.text) === kind) && (!query || String(it.text).toLowerCase().includes(query.toLowerCase())))
            readonly property var cur: shown[Math.min(picked, shown.length - 1)] ?? null
            readonly property int padX: 4
            readonly property int listW: Math.round(cols * 0.63)
            readonly property int rowH: 9
            readonly property int listY: 30
            readonly property int rowsN: Math.max(0, Math.min(shown.length, Math.floor((rows - listY - 3) / rowH)))
            readonly property int pvX: padX + listW + 4
            readonly property int pvW: cols - pvX - padX
            onKindChanged: picked = 0
            onQueryChanged: picked = 0

            // FIND pacman▏
            MatrixText {
                x: u.padX + 3
                y: 6
                height: 5
                font: "3x5"
                text: "FIND"
                color: Ink.amber
            }
            T.Field {
                x: u.padX + 20
                y: 3
                width: u.listW - 23
                height: 11
                hint: "SEARCH COPIES"
                hintColor: Ink.teal
                onTyped: t => u.query = t
            }

            Repeater {
                model: u.shown.slice(0, u.rowsN)
                Item {
                    required property var modelData
                    required property int index
                    x: u.padX
                    y: u.listY + index * u.rowH
                    width: u.listW
                    height: u.rowH
                    MatrixText {
                        x: 3
                        y: 2
                        height: 5
                        font: "3x5"
                        text: index === u.picked ? "*" : "·"
                        color: Ink.amber
                    }
                    MatrixText {
                        x: 11
                        y: 2
                        width: parent.width - x - t.implicitWidth - 9
                        height: 5
                        font: "3x5"
                        text: modelData.preview
                        color: Ink.cyan
                    }
                    MatrixText {
                        id: t
                        anchors.right: parent.right
                        anchors.rightMargin: 3
                        y: 2
                        height: 5
                        font: "3x5"
                        text: root.clock(modelData.at)
                        color: Ink.teal
                    }
                    T.Hit {
                        anchors.fill: parent
                        onTap: u.picked === index ? root.run("paste " + modelData.i) : u.picked = index
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
                color: Ink.teal
            }

            // The preview card.
            Item {
                x: u.pvX + 4
                y: 7
                width: u.pvW - 8
                height: u.rows - 14
                MatrixText {
                    height: 5
                    font: "3x5"
                    text: "PREVIEW"
                    color: Ink.teal
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
                            for (let i = 0; i < t.length && out.length < 6; i += per)
                                out.push(t.slice(i, i + per));
                            return out;
                        }
                        MatrixText {
                            required property string modelData
                            width: copy.width
                            height: 5
                            font: "3x5"
                            text: modelData
                            color: Ink.cyan
                        }
                    }
                }
                Column {
                    id: meta
                    y: copy.y + copy.height + 4
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
                            color: Ink.teal
                        }
                    }
                }
                Swatch {
                    y: meta.y + meta.height + 4
                    width: 20
                    height: 12
                    text: u.cur?.text ?? ""
                }
            }

            // Crisp: the field's rule, the kind keys, the picked row, the
            // preview card and its keys.
            over: [
                Box {
                    dx: u.padX
                    dy: 3
                    dw: u.listW
                    dh: 11
                    border.color: Ink.cyan
                },
                Row {
                    x: u.px(u.padX)
                    y: u.px(17)
                    spacing: 3
                    readonly property real w: u.px(u.listW)
                    Repeater {
                        model: ["ALL", "TEXT", "LINKS", "IMAGES", "COLORS"]
                        Key {
                            required property string modelData
                            width: (parent.w - 12) / 5
                            height: u.px(10)
                            size: 8
                            pad: 2
                            text: modelData
                            on: u.kind === modelData
                            dim: true
                            onTap: u.kind = modelData
                        }
                    }
                },
                Box {
                    visible: u.rowsN > 0
                    dx: u.padX
                    dy: u.listY + u.picked * u.rowH
                    dw: u.listW
                    dh: u.rowH
                    border.color: Ink.amber
                },
                Box {
                    dx: u.pvX
                    dy: 3
                    dw: u.pvW
                    dh: u.rows - 6
                },
                Row {
                    visible: u.cur !== null
                    x: u.px(u.pvX + 4)
                    y: u.px(u.rows - 7) - height
                    spacing: 4
                    Key {
                        text: "PASTE"
                        size: 8
                        action: "paste " + (u.cur?.i ?? 0)
                    }
                    Key {
                        text: "DEL"
                        size: 8
                        action: "clip forget " + (u.cur?.i ?? 0)
                    }
                }
            ]
        }
    }
}
