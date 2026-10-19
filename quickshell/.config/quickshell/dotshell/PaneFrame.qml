import QtQuick
import qs.tokyo as Tk
import qs.vfd as Vf

// A pane's frame in Tokyo Night and VFD (Pane.qml `eraFrame`), from the
// design's Messages boards: Tokyo, the dot glass as a neon sign, a pink
// tube round it and a cyan one just inside; VFD, a brushed gunmetal plate
// with the dot window sunk into it (`over`: the smoke falling in from the
// top and the black lip, drawn above the dots). `win` is the dot window
// in px.
//   PaneFrame { anchors.fill: parent; kind: "tokyo"; win: Qt.rect(12, 12, w, h) }
Item {
    id: frame

    property string kind: ""
    property rect win
    property bool over: false

    // ── Tokyo Night ─────────────────────────────────────────────────
    Rectangle {
        visible: frame.kind === "tokyo" && !frame.over
        anchors.fill: parent
        anchors.margins: 3
        radius: 26
        color: Tk.Ink.glass
    }
    Tk.Tube {
        visible: frame.kind === "tokyo" && !frame.over
        anchors.fill: parent
        anchors.margins: 4
        radius: 25
        line: 3
        tint: Tk.Ink.pink
    }
    Tk.Tube {
        visible: frame.kind === "tokyo" && !frame.over
        x: frame.win.x - 3
        y: frame.win.y - 3
        width: frame.win.width + 6
        height: frame.win.height + 6
        radius: 18
        line: 2
        tint: Tk.Ink.cyan
        glow: 0.6
    }

    // ── VFD ─────────────────────────────────────────────────────────
    Rectangle {
        visible: frame.kind === "vfd" && !frame.over
        anchors.fill: parent
        radius: 10
        color: Vf.Ink.plateEdge
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 1
            radius: parent.radius
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Vf.Ink.plateTop
                }
                GradientStop {
                    position: 1
                    color: Vf.Ink.plateBottom
                }
            }
        }
    }
    Item {
        visible: frame.kind === "vfd" && frame.over
        x: frame.win.x
        y: frame.win.y
        width: frame.win.width
        height: frame.win.height
        Rectangle {
            anchors.fill: parent
            radius: 4
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.rgba(0, 0, 0, 0.8)
                }
                GradientStop {
                    position: Math.min(0.5, 16 / Math.max(1, frame.win.height))
                    color: "transparent"
                }
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: 4
            color: "transparent"
            border.width: 1
            border.color: "black"
        }
    }
}
