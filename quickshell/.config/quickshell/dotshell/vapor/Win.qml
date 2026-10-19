import QtQuick
import qs.tokyo as T

// The window every Vaporwave panel is (the design's Windows 95 frame): a
// lilac face with its double bevel, and the sunset title bar (violet, hot
// pink, cyan) with an icon, the program's name and its buttons, all crisp.
// Faces lay their contents out under `bodyY`. The title bar's buttons
// work: □ expands or folds the panel, _ and × fold it again. `dim` greys
// the whole window (do not disturb). `boxed` draws the buttons as little
// raised keys (the media player's).
//   Win { anchors.fill: parent; icon: "▤"; title: "taskmgr.exe — Performance" }
Item {
    id: win

    property string icon: ""
    property string title: ""
    // "max": _ □ ×, "help": ? ×, "close": ×
    property string controls: "max"
    property bool boxed: false
    property bool dim: false
    property bool big: false
    readonly property int edge: 4
    readonly property int barH: 22
    readonly property int bodyY: edge + barH
    // × was clicked (a pane closes on it).
    signal closed

    Rectangle {
        anchors.fill: parent
        color: win.dim ? Ink.dimFace : Ink.face
    }
    Bevel {
        anchors.fill: parent
        line: 2
        dark: win.dim ? Ink.c("#3a3740", "#a29fab") : Ink.shade
        outer: win.dim ? Ink.c("#5a5664", "#c3c0ca") : Ink.mid
    }

    // ── The title bar ───────────────────────────────────────────────
    Rectangle {
        id: bar
        x: win.edge
        y: win.edge
        width: win.width - win.edge * 2
        height: win.barH
        opacity: win.dim ? 0.45 : 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: Ink.violet
            }
            GradientStop {
                position: 0.6
                color: Ink.pink
            }
            GradientStop {
                position: 1
                color: Ink.cyan
            }
        }
        Pen {
            id: name
            x: 7
            width: buttons.x - x - 6
            height: parent.height
            text: (win.icon ? win.icon + "  " : "") + win.title
            size: 18
            color: Ink.hi
        }
        Row {
            id: buttons
            anchors.right: parent.right
            anchors.rightMargin: win.boxed ? 3 : 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: win.boxed ? 2 : 6
            Repeater {
                model: win.controls === "help" ? ["?", "×"] : win.controls === "close" ? ["×"] : ["_", "□", "×"]
                Item {
                    id: b
                    required property string modelData
                    width: win.boxed ? 18 : glyph.implicitWidth
                    height: win.boxed ? 16 : win.barH
                    Rectangle {
                        visible: win.boxed
                        anchors.fill: parent
                        color: Ink.face
                    }
                    Bevel {
                        visible: win.boxed
                        anchors.fill: parent
                        sunk: hit.pressed
                    }
                    Pen {
                        id: glyph
                        anchors.centerIn: parent
                        text: b.modelData === "×" ? "X" : b.modelData
                        size: win.boxed ? 14 : 18
                        color: win.boxed ? Ink.ink : Ink.hi
                    }
                    T.Hit {
                        id: hit
                        anchors.fill: parent
                        anchors.margins: -2
                        enabled: b.modelData !== "?"
                        action: b.modelData === "□" ? (win.big ? "panel fold" : "panel expand") : win.big ? "panel fold" : ""
                        onTap: if (b.modelData === "×")
                            win.closed()
                    }
                }
            }
        }
    }
}
