import QtQuick
import QtQuick.Effects
import qs
import qs.services
import qs.tokyo as T

// Clipboard, Frutiger Aero: a real clipboard. A honey wooden board with a
// steel clip at its top, and a sheet of paper on it listing the last
// copies in bubble dots, numbered, the newest on a sky highlight; a colour
// shows its swatch and a picture its thumbnail. A click pastes. Expanded,
// a search line and the kind keys over the history, and the picked copy
// in full on a card beside it, with Paste and Delete.
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

    // ── The board, the clip and the paper ───────────────────────────
    Rectangle {
        id: board
        anchors.fill: parent
        radius: 12
        border.width: 2
        border.color: "#e8c08a"
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "#d9a96a"
            }
            GradientStop {
                position: 1
                color: "#b8823e"
            }
        }
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Ink.shadow
            shadowBlur: 0.6
            blurMax: 20
            shadowVerticalOffset: 6
            shadowHorizontalOffset: 0
        }
    }
    Rectangle {
        id: paper
        x: 14
        y: 26
        width: parent.width - 28
        height: parent.height - 40
        radius: 4
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Ink.c("white", "#1f3d5f")
            }
            GradientStop {
                position: 1
                color: Ink.c("#eef8fd", "#12263d")
            }
        }
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.25)
            shadowBlur: 0.2
            blurMax: 8
            shadowVerticalOffset: 2
            shadowHorizontalOffset: 0
        }
    }
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        z: 2
        width: Math.min(90, parent.width * 0.3)
        height: 22
        bottomLeftRadius: 10
        bottomRightRadius: 10
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "#f4f6f8"
            }
            GradientStop {
                position: 0.6
                color: "#9aa6b2"
            }
            GradientStop {
                position: 1
                color: "#dfe5ea"
            }
        }
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Ink.shade(0.4)
            shadowBlur: 0.2
            blurMax: 8
            shadowVerticalOffset: 2
            shadowHorizontalOffset: 0
        }
    }

    Loader {
        x: paper.x
        y: paper.y
        width: paper.width
        height: paper.height
        sourceComponent: root.big ? history : list
    }

    // The sky highlight under the picked row, crisp.
    component Lit: Rectangle {
        radius: 8
        border.width: 1
        border.color: Ink.plate2
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Ink.ice
            }
            GradientStop {
                position: 1
                color: Ink.c("#b8e2f7", "#1d4466")
            }
        }
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
            radius: Math.min(width, height) / 2
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

    // One copy on the paper, in dots: its number, swatch, words and time.
    component Copy: Item {
        id: copy
        property var c: ({})
        property string mark: ""
        readonly property bool pic: ["COLORS", "IMAGES"].includes(root.kind(c.text))
        MatrixText {
            x: 3
            anchors.verticalCenter: parent.verticalCenter
            width: implicitWidth
            height: 5
            font: "3x5"
            text: copy.mark
            color: Ink.mist
        }
        Swatch {
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 11
            height: 7
            text: copy.c.preview ?? ""
        }
        MatrixText {
            x: copy.pic ? 24 : 10
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - age.implicitWidth - 8
            font: String(copy.c.preview ?? "").length * 6 <= width ? "5x7" : "3x5"
            height: font === "5x7" ? 7 : 5
            text: copy.c.preview ?? ""
            color: Ink.navy
        }
        MatrixText {
            id: age
            anchors.right: parent.right
            anchors.rightMargin: 3
            anchors.verticalCenter: parent.verticalCenter
            width: implicitWidth
            height: 5
            font: "3x5"
            text: root.clock(copy.c.at)
            color: Ink.blue
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
            readonly property int padX: 3
            readonly property int rowH: 9
            readonly property int rowsN: Math.max(0, Math.min(root.items.length, Math.floor((rows - 4) / rowH)))
            readonly property int listY: Math.max(2, Math.round((rows - rowsN * rowH) / 2))

            Lit {
                visible: u.rowsN > 0
                x: u.padX * u.p
                y: u.listY * u.p
                width: (u.cols - u.padX * 2) * u.p
                height: u.rowH * u.p
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
                        mark: String(index + 1)
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
                    text: root.words.empty || "Nothing copied"
                    color: Ink.blue
                }
            }
        }
    }

    // ── Expanded: history and preview ───────────────────────────────
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
            readonly property int padX: 4
            readonly property int listW: Math.round(cols * 0.6)
            readonly property int rowH: 10
            readonly property int listY: 28
            readonly property int rowsN: Math.max(0, Math.min(shown.length, Math.floor((rows - listY - 3) / rowH)))
            readonly property int pvX: padX + listW + 4
            readonly property int pvW: cols - pvX - padX
            onKindChanged: picked = 0
            onQueryChanged: picked = 0

            // Crisp: the search pill, the kind keys, the picked row, the
            // preview card and its keys.
            Card {
                x: u.padX * u.p
                y: 3 * u.p
                width: u.listW * u.p
                height: 10 * u.p
                radius: height / 2
                lift: 0
                ring: true
                ringColor: Ink.pale
            }
            Row {
                id: kinds
                x: u.padX * u.p
                y: 15 * u.p
                spacing: 4
                readonly property real w: u.listW * u.p
                Repeater {
                    model: ["All", "Text", "Links", "Images", "Colors"]
                    Key {
                        required property string modelData
                        width: (kinds.w - 16) / 5
                        height: 9 * u.p
                        radius: height / 2
                        textPx: 12
                        text: modelData
                        look: u.kind === modelData.toUpperCase() ? "lit" : "ghost"
                        onTap: u.kind = modelData.toUpperCase()
                    }
                }
            }
            Lit {
                visible: u.rowsN > 0
                x: u.padX * u.p
                y: (u.listY + u.picked * u.rowH) * u.p
                width: u.listW * u.p
                height: u.rowH * u.p
                radius: height / 2
            }
            Card {
                x: u.pvX * u.p
                y: 3 * u.p
                width: u.pvW * u.p
                height: (u.rows - 6) * u.p
                radius: 14
                ring: true
                ringColor: Ink.pale
            }
            Row {
                visible: u.cur !== null
                x: (u.pvX + 4) * u.p
                y: (u.rows - 7) * u.p - height
                spacing: 6
                Key {
                    width: 54
                    height: 22
                    radius: 11
                    textPx: 12
                    text: "Paste"
                    action: u.cur ? "paste " + u.cur.i : ""
                }
                Key {
                    width: 58
                    height: 22
                    radius: 11
                    textPx: 12
                    text: "Delete"
                    action: u.cur ? "clip forget " + u.cur.i : ""
                }
            }

            Dots {
                anchors.fill: parent
                // ◦ pacman▏
                MatrixText {
                    x: u.padX + 4
                    y: 5
                    width: 5
                    height: 5
                    font: "3x5"
                    text: "•"
                    color: Ink.blue
                }
                T.Field {
                    x: u.padX + 10
                    y: 4
                    width: u.listW - 14
                    height: 8
                    hint: "SEARCH COPIES"
                    color: Ink.navy
                    hintColor: Ink.blue
                    onTyped: t => u.query = t
                }
                Repeater {
                    model: u.shown.slice(0, u.rowsN)
                    Copy {
                        required property var modelData
                        required property int index
                        x: u.padX + 1
                        y: u.listY + index * u.rowH
                        width: u.listW - 2
                        height: u.rowH
                        c: modelData
                        mark: index === u.picked ? "*" : "·"
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
                    text: root.items.length ? "No match" : (root.words.empty || "Nothing copied")
                    color: Ink.blue
                }
                // The preview.
                Item {
                    x: u.pvX + 4
                    y: 7
                    width: u.pvW - 8
                    height: u.rows - 14
                    MatrixText {
                        height: 5
                        font: "3x5"
                        text: "PREVIEW"
                        color: Ink.blue
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
                                color: Ink.navy
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
                                color: Ink.blue
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
            }
        }
    }
}
