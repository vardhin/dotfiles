import QtQuick
import QtQuick.Effects
import qs

// Files, Tokyo Night: the pinned places as neon folders, then the files
// used last, each tagged with its kind. Expanded, a search line (Enter
// searches names, text and meaning in the launcher), kind filters, and the
// recent files as cards with OPEN and REVEAL.
Face {
    id: root

    readonly property var places: (ctx.pinned ?? []).filter(p => p.name !== "HOME")
    readonly property var recent: ctx.recent ?? []
    readonly property var kinds: ({
            DOCS: /\.(pdf|docx?|odt|txt|md|epub|rtf|tex)$/i,
            IMAGES: /\.(png|jpe?g|webp|gif|svg|avif|heic)$/i,
            VIDEO: /\.(mp4|mkv|webm|mov|avi)$/i,
            AUDIO: /\.(mp3|flac|ogg|opus|wav|m4a)$/i,
            CODE: /\.(js|ts|py|qml|c|h|cpp|rs|go|sh|lua|json|toml|ya?ml|html|css)$/i
        })
    function tag(name: string): string {
        const m = /\.([a-z0-9]{1,4})$/i.exec(name);
        return m ? m[1].toUpperCase() : "DIR";
    }
    function when(ts: real): string {
        const d = new Date(ts), now = new Date();
        if (d.toDateString() === now.toDateString())
            return Qt.formatTime(d, "hh:mm");
        const y = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);
        return d.toDateString() === y.toDateString() ? "YEST" : Qt.formatDate(d, "dd MMM").toUpperCase();
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.big ? board : sign
    }

    // ── Compact ─────────────────────────────────────────────────────
    Component {
        id: sign
        Item {
            id: s
            readonly property real padX: 18
            readonly property bool roomy: height >= 140
            readonly property int n: Math.min(4, root.places.length)
            readonly property real cell: (width - padX * 2) / Math.max(1, n)
            readonly property real fw: Math.min(cell * 0.6, height * 0.24 * 1.3)
            readonly property real fh: fw * 0.72
            readonly property real fy: roomy ? 16 : 12
            readonly property int listY: root.d(fy + fh) + (roomy ? 10 : 3)
            readonly property int rowH: 8
            readonly property int rowsN: Math.max(0, Math.min(root.recent.length, Math.floor((glass.rows - listY - 3) / rowH)))

            Glass {
                id: glass
                radius: 28
                // The places' names, under their folders.
                Repeater {
                    model: s.roomy ? root.places.slice(0, s.n) : []
                    MatrixText {
                        required property var modelData
                        required property int index
                        x: root.d(s.padX + index * s.cell)
                        y: root.d(s.fy + s.fh) + 2
                        width: root.d(s.cell)
                        height: 5
                        font: "3x5"
                        align: "center"
                        text: String(modelData.name).slice(0, Math.max(1, Math.floor((width + 1) / 4)))
                        color: Ink.pink
                    }
                }
                // The recent files: kind, name, when.
                Repeater {
                    model: root.recent.slice(0, s.rowsN)
                    Item {
                        required property var modelData
                        required property int index
                        x: root.d(s.padX) + 16
                        y: s.listY + index * s.rowH + 1
                        width: glass.cols - x - root.d(s.padX)
                        height: 5
                        MatrixText {
                            width: parent.width - ago.implicitWidth - 4
                            height: 5
                            font: "3x5"
                            text: modelData.name
                            color: Ink.pink
                        }
                        MatrixText {
                            id: ago
                            anchors.right: parent.right
                            height: 5
                            font: "3x5"
                            text: root.when(modelData.ts)
                            color: Ink.violet
                        }
                        Hit {
                            anchors.fill: parent
                            anchors.leftMargin: -16
                            action: "open " + modelData.path
                        }
                    }
                }
            }
            // Folders.
            Repeater {
                model: root.places.slice(0, s.n)
                Item {
                    required property var modelData
                    required property int index
                    x: s.padX + index * s.cell
                    y: s.fy
                    width: s.cell
                    height: s.fh
                    Folder {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: s.fw
                        height: s.fh
                        tint: index % 2 ? Ink.pink : Ink.cyan
                    }
                    Hit {
                        anchors.fill: parent
                        action: "open " + modelData.path
                    }
                }
            }
            // Kind tags in front of the rows.
            Repeater {
                model: root.recent.slice(0, s.rowsN)
                Rectangle {
                    required property var modelData
                    required property int index
                    x: glass.x + (root.d(s.padX) - 1) * root.pitch
                    y: glass.y + (s.listY + index * s.rowH) * root.pitch
                    width: 15 * root.pitch
                    height: 7 * root.pitch
                    radius: height / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Ink.violet
                    Text {
                        anchors.centerIn: parent
                        text: root.tag(modelData.name)
                        color: Ink.violet
                        font.family: Ink.family
                        font.pixelSize: 9
                    }
                }
            }
            Sign {
                radius: 28
            }
        }
    }

    // ── Expanded: search ────────────────────────────────────────────
    Component {
        id: board
        Item {
            id: b
            property string kind: "ALL"
            readonly property var shown: kind === "ALL" ? root.recent : root.recent.filter(f => root.kinds[kind].test(f.name))
            readonly property int chipY: 5 + 13 + 4
            readonly property int cardsY: chipY + 9 + 4
            readonly property int cardH: 18
            readonly property int cardsN: Math.min(3, shown.length, Math.max(0, Math.floor((glass.rows - cardsY - 30) / (cardH + 3))))
            readonly property int restY: cardsY + cardsN * (cardH + 3) + 3
            readonly property int restN: Math.max(0, Math.min(shown.length - cardsN, Math.floor((glass.rows - restY - 9 - 8) / 8)))

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: 30
                color: Ink.glass
            }
            Glass {
                id: glass
                radius: 28
                // f> the search line
                Item {
                    x: 9
                    y: 5
                    width: glass.cols - 18
                    height: 13
                    DotText {
                        x: 2
                        height: parent.height
                        text: "f>"
                        color: Ink.pink
                    }
                    Field {
                        x: 18
                        width: parent.width - 20 - hits.implicitWidth
                        height: parent.height
                        hint: root.words.find === "FIND" ? "NAME, TEXT OR MEANING" : root.words.find
                        action: "find {value}"
                        color: Ink.pink
                    }
                    MatrixText {
                        id: hits
                        anchors.right: parent.right
                        anchors.rightMargin: 2
                        y: 4
                        height: 5
                        font: "3x5"
                        text: b.shown.length + " FILES"
                        color: Ink.violet
                    }
                }
                // Cards: name, where it is.
                Repeater {
                    model: b.shown.slice(0, b.cardsN)
                    Item {
                        required property var modelData
                        required property int index
                        x: 5 + 26
                        y: b.cardsY + index * (b.cardH + 3) + 4
                        width: glass.cols - 10 - 26 - 50
                        height: b.cardH - 8
                        MatrixText {
                            width: parent.width
                            height: 5
                            font: "3x5"
                            text: modelData.name
                            color: Ink.pink
                        }
                        MatrixText {
                            y: 7
                            width: parent.width
                            height: 5
                            font: "3x5"
                            text: (modelData.dir ?? "") + " · " + root.when(modelData.ts)
                            color: Ink.violet
                        }
                    }
                }
                MatrixText {
                    x: 5
                    y: b.restY
                    height: 5
                    font: "3x5"
                    visible: b.restN > 0
                    text: "R E C E N T"
                    color: Ink.violet
                }
                Repeater {
                    model: b.shown.slice(b.cardsN, b.cardsN + b.restN)
                    Item {
                        required property var modelData
                        required property int index
                        x: 5 + 17
                        y: b.restY + 8 + index * 8 + 1
                        width: glass.cols - 10 - 17
                        height: 5
                        MatrixText {
                            width: parent.width - t.implicitWidth - 4
                            height: 5
                            font: "3x5"
                            text: (modelData.dir ?? "") + "/" + modelData.name
                            color: Ink.pink
                        }
                        MatrixText {
                            id: t
                            anchors.right: parent.right
                            height: 5
                            font: "3x5"
                            text: root.when(modelData.ts)
                            color: Ink.violet
                        }
                        Hit {
                            anchors.fill: parent
                            action: "open " + modelData.path
                        }
                    }
                }
                MatrixText {
                    x: 5
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    width: glass.cols - 10
                    height: 5
                    font: "3x5"
                    scroll: true
                    text: "ENTER SEARCHES NAMES, TEXT AND MEANING · CLICK TO OPEN"
                    color: Ink.violet
                }
            }

            // Crisp: the search rim, the kind chips, the cards.
            Tube {
                x: glass.x + 5 * root.pitch
                y: glass.y + 4 * root.pitch
                width: (glass.cols - 10) * root.pitch
                height: 15 * root.pitch
                radius: height / 2
                line: 2
                tint: Ink.cyan
                glow: 0.8
            }
            Row {
                x: glass.x + 5 * root.pitch
                y: glass.y + b.chipY * root.pitch
                spacing: 5
                readonly property real w: (glass.cols - 10) * root.pitch
                Repeater {
                    model: ["ALL", "DOCS", "IMAGES", "VIDEO", "AUDIO", "CODE"]
                    Chip {
                        required property string modelData
                        width: (parent.w - 25) / 6
                        height: 9 * root.pitch
                        size: 10
                        text: modelData
                        tone: b.kind === modelData ? "on" : "pink"
                        onTap: b.kind = modelData
                    }
                }
            }
            Repeater {
                model: b.shown.slice(0, b.cardsN)
                Item {
                    id: card
                    required property var modelData
                    required property int index
                    x: glass.x + 5 * root.pitch
                    y: glass.y + (b.cardsY + index * (b.cardH + 3)) * root.pitch
                    width: (glass.cols - 10) * root.pitch
                    height: b.cardH * root.pitch
                    Tube {
                        anchors.fill: parent
                        radius: 12
                        line: 1.5
                        tint: Ink.deep
                        glow: 0
                    }
                    // A thumbnail for pictures, the kind for the rest.
                    Item {
                        id: thumb
                        x: 6
                        y: 6
                        width: 22 * root.pitch - 12
                        height: parent.height - 12
                        Image {
                            id: pic
                            anchors.fill: parent
                            visible: false
                            source: root.kinds.IMAGES.test(card.modelData.name) ? "file://" + card.modelData.path : ""
                            sourceSize: Qt.size(width * 2, height * 2)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        Rectangle {
                            id: mask
                            anchors.fill: parent
                            radius: 6
                            visible: false
                            layer.enabled: true
                        }
                        MultiEffect {
                            anchors.fill: parent
                            visible: pic.status === Image.Ready
                            source: pic
                            maskEnabled: true
                            maskSource: mask
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1
                        }
                        Tube {
                            anchors.fill: parent
                            radius: 6
                            line: 1.5
                            tint: Ink.pink
                            glow: 0.4
                            Text {
                                visible: pic.status !== Image.Ready
                                anchors.centerIn: parent
                                text: root.tag(card.modelData.name)
                                color: Ink.pink
                                font.family: Ink.family
                                font.pixelSize: 11
                            }
                        }
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Chip {
                            text: "Open"
                            tone: "cyan"
                            size: 9
                            pad: 5
                            action: "open " + card.modelData.path
                        }
                        Chip {
                            text: "Reveal"
                            tone: "cyan"
                            size: 9
                            pad: 5
                            action: "reveal " + card.modelData.path
                        }
                    }
                }
            }
            Repeater {
                model: b.shown.slice(b.cardsN, b.cardsN + b.restN)
                Rectangle {
                    required property var modelData
                    required property int index
                    x: glass.x + 5 * root.pitch
                    y: glass.y + (b.restY + 8 + index * 8) * root.pitch
                    width: 15 * root.pitch
                    height: 7 * root.pitch
                    radius: height / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Ink.violet
                    Text {
                        anchors.centerIn: parent
                        text: root.tag(modelData.name)
                        color: Ink.violet
                        font.family: Ink.family
                        font.pixelSize: 9
                    }
                }
            }
            Sign {
                radius: 30
            }
        }
    }
}
