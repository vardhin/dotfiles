import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.services
import "Hardware.js" as Hardware

// The faceplate of a panel's device (Hardware.js `plate`, `head`, the
// window's `frame`): fills its parent. `win` is where the display window
// sits (for the frame around it), `ctx` the media feed for the head band's
// {pos} and {len}.
Item {
    id: root

    required property var hw
    property rect win: Qt.rect(0, 0, 0, 0)
    property var ctx: null

    readonly property var p: hw.plate
    readonly property string body: Hardware.platePath(hw, width, height, 0)

    // Four gradient stops from a list of [pos, color] (the last repeated).
    function stop(list: var, i: int): var {
        const l = list ?? [];
        return l[Math.min(i, l.length - 1)] ?? [1, "transparent"];
    }
    function say(s: string): string {
        return String(s ?? "").replace("{pos}", Media.clock(root.ctx?.pos ?? 0)).replace("{len}", Media.clock(root.ctx?.len ?? 0));
    }

    // ── The plate ───────────────────────────────────────────────────
    Shape {
        id: plate
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        layer.enabled: !!root.p.shadow
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: root.p.shadow?.color ?? "black"
            shadowBlur: 0.7
            shadowVerticalOffset: root.p.shadow?.y ?? 4
            shadowHorizontalOffset: 0
        }

        // Moulded plastic: the plate in its darker color, the face over
        // it a little shorter.
        ShapePath {
            strokeWidth: -1
            fillColor: root.p.under || "transparent"
            PathSvg {
                path: root.p.under ? root.body : ""
            }
        }
        ShapePath {
            strokeWidth: -1
            fillColor: root.p.color
            fillGradient: root.p.fill ? grad : null
            PathSvg {
                path: root.p.under ? Hardware.platePath(root.hw, root.width, root.height - 3, 0) : root.body
            }
        }
        ShapePath {
            strokeWidth: -1
            fillColor: root.p.inner?.color ?? "transparent"
            PathSvg {
                path: root.p.inner ? Hardware.platePath(root.hw, root.width, root.height, root.p.inner.inset) : ""
            }
        }
    }
    LinearGradient {
        id: grad
        readonly property string dir: root.p.fill?.dir ?? "v"
        x1: 0
        y1: 0
        x2: dir === "v" ? 0 : root.width
        y2: dir === "h" ? 0 : root.height
        GradientStop {
            position: root.stop(root.p.fill?.stops, 0)[0]
            color: root.stop(root.p.fill?.stops, 0)[1]
        }
        GradientStop {
            position: root.stop(root.p.fill?.stops, 1)[0]
            color: root.stop(root.p.fill?.stops, 1)[1]
        }
        GradientStop {
            position: root.stop(root.p.fill?.stops, 2)[0]
            color: root.stop(root.p.fill?.stops, 2)[1]
        }
        GradientStop {
            position: root.stop(root.p.fill?.stops, 3)[0]
            color: root.stop(root.p.fill?.stops, 3)[1]
        }
    }

    // Graph paper.
    Canvas {
        anchors.fill: parent
        anchors.margins: 1
        visible: !!root.p.grid
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const c = getContext("2d");
            c.reset();
            const g = root.p.grid;
            if (!g)
                return;
            c.strokeStyle = g.color;
            c.lineWidth = 1;
            c.beginPath();
            for (let x = g.step; x < width; x += g.step) {
                c.moveTo(x + 0.5, 0);
                c.lineTo(x + 0.5, height);
            }
            for (let y = g.step; y < height; y += g.step) {
                c.moveTo(0, y + 0.5);
                c.lineTo(width, y + 0.5);
            }
            c.stroke();
        }
    }

    // Glass over the top half.
    Rectangle {
        visible: root.p.gloss
        x: 20
        y: 4
        width: parent.width - 40
        height: parent.height * 0.46
        radius: Math.min(height, 34)
        gradient: Gradient {
            GradientStop {
                position: 0
                // A white sheen by day, a faint one on dark glass.
                color: Qt.rgba(1, 1, 1, Tokens.current.light ? 0.9 : 0.12)
            }
            GradientStop {
                position: 1
                color: Qt.rgba(1, 1, 1, 0)
            }
        }
    }

    // Brushed metal catching the light along the top.
    Rectangle {
        visible: !!root.p.edge
        x: (Array.isArray(root.p.radius) ? root.p.radius[0] : root.p.radius) - 2
        y: 1
        width: parent.width - x * 2
        height: 1
        color: root.p.edge || "transparent"
    }

    // ── Rules and tubes along the outline ───────────────────────────
    Repeater {
        model: root.p.strokes

        Shape {
            id: rule
            required property var modelData
            anchors.fill: parent
            opacity: modelData.opacity ?? 1
            preferredRendererType: Shape.CurveRenderer
            layer.enabled: !!modelData.glow
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: rule.modelData.glow ?? "black"
                shadowBlur: 0.5
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }
            ShapePath {
                strokeWidth: rule.modelData.width
                strokeColor: rule.modelData.color
                fillColor: "transparent"
                PathSvg {
                    path: Hardware.platePath(root.hw, root.width, root.height, rule.modelData.inset)
                }
            }
        }
    }

    // Corner brackets.
    Item {
        anchors.fill: parent
        visible: !!root.p.brackets
        layer.enabled: visible && !!root.p.brackets?.glow
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: root.p.brackets?.glow ?? "black"
            shadowBlur: 0.5
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }
        Repeater {
            model: root.p.brackets ? 4 : 0
            Item {
                id: corner
                required property int index
                readonly property var b: root.p.brackets
                x: index % 2 ? root.width - b.inset - b.len : b.inset
                y: index > 1 ? root.height - b.inset - b.len : b.inset
                width: b.len
                height: b.len
                Rectangle {
                    y: corner.index > 1 ? corner.b.len - corner.b.width : 0
                    width: corner.b.len
                    height: corner.b.width
                    color: corner.b.color
                }
                Rectangle {
                    x: corner.index % 2 ? corner.b.len - corner.b.width : 0
                    width: corner.b.width
                    height: corner.b.len
                    color: corner.b.color
                }
            }
        }
    }

    // A raised 95 bevel: light top left, dark bottom right, a mid line in.
    Item {
        anchors.fill: parent
        visible: !!root.p.bevel
        readonly property var b: root.p.bevel ?? ({})
        Rectangle {
            width: parent.width
            height: 2
            color: parent.b.light ?? "transparent"
        }
        Rectangle {
            width: 2
            height: parent.height
            color: parent.b.light ?? "transparent"
        }
        Rectangle {
            x: 2
            y: parent.height - 4
            width: parent.width - 4
            height: 2
            color: parent.b.inner ?? "transparent"
        }
        Rectangle {
            x: parent.width - 4
            y: 2
            width: 2
            height: parent.height - 4
            color: parent.b.inner ?? "transparent"
        }
        Rectangle {
            y: parent.height - 2
            width: parent.width
            height: 2
            color: parent.b.dark ?? "transparent"
        }
        Rectangle {
            x: parent.width - 2
            width: 2
            height: parent.height
            color: parent.b.dark ?? "transparent"
        }
    }

    // Rivets.
    Repeater {
        model: root.p.rivets ? 4 : 0
        Rectangle {
            required property int index
            readonly property var r: root.p.rivets
            x: index % 2 ? root.width - r.inset - r.r * 2 : r.inset
            y: index > 1 ? root.height - r.inset - r.r * 2 : r.inset
            width: r.r * 2
            height: r.r * 2
            radius: r.r
            color: r.color
            Rectangle {
                x: 1
                y: 1
                width: parent.width - 2
                height: 1
                color: Qt.lighter(parent.color, 1.5)
            }
        }
    }

    // Words cut into the top rule.
    Repeater {
        model: root.p.legend ? [root.p.legend.text, root.p.legend.right] : []
        Rectangle {
            id: cut
            required property string modelData
            required property int index
            readonly property var l: root.p.legend
            visible: modelData !== ""
            x: index === 0 ? l.x : root.width - l.x - width
            y: (root.p.strokes[0]?.inset ?? 6) + 1 - height / 2
            width: word.implicitWidth + 10
            height: word.implicitHeight
            color: root.p.color
            Text {
                id: word
                anchors.centerIn: parent
                text: cut.modelData
                color: cut.l.color
                font.family: Tokens.font
                font.pixelSize: 13
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: cut.l.color
                    shadowBlur: 0.4
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                }
            }
        }
    }

    // ── The head band ───────────────────────────────────────────────
    Rectangle {
        id: head
        readonly property var h: root.hw.head
        visible: !!h
        x: h?.inset ?? 0
        y: h?.inset ?? 0
        width: root.width - x * 2
        height: h?.h ?? 0
        color: "transparent"
        gradient: h?.fill ? headGrad : null
        Gradient {
            id: headGrad
            orientation: head.h?.dir === "v" ? Gradient.Vertical : Gradient.Horizontal
            GradientStop {
                position: root.stop(head.h?.fill, 0)[0]
                color: root.stop(head.h?.fill, 0)[1]
            }
            GradientStop {
                position: root.stop(head.h?.fill, 1)[0]
                color: root.stop(head.h?.fill, 1)[1]
            }
            GradientStop {
                position: root.stop(head.h?.fill, 2)[0]
                color: root.stop(head.h?.fill, 2)[1]
            }
        }

        readonly property int pad: h?.fill ? 8 : 0
        Text {
            x: head.pad
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width / 2 - head.pad
            elide: Text.ElideRight
            text: root.say(head.h?.left ?? "")
            color: head.h?.color ?? "white"
            font.family: Tokens.font
            font.pixelSize: head.h?.size ?? 11
            font.letterSpacing: (head.h?.size ?? 11) < 11 ? 2 : 0
        }
        Text {
            anchors.centerIn: parent
            text: root.say(head.h?.center ?? "")
            color: head.h?.colorC || head.h?.color || "white"
            font.family: Tokens.font
            font.pixelSize: head.h?.size ?? 11
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: (head.h?.buttons ?? []).length ? 3 : head.pad
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                visible: text !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: root.say(head.h?.right ?? "")
                color: head.h?.colorR || head.h?.color || "white"
                font.family: Tokens.font
                font.pixelSize: head.h?.size ?? 11
                font.letterSpacing: (head.h?.size ?? 11) < 11 ? 2 : 0
            }
            // The window's own buttons (95): raised boxes.
            Repeater {
                model: head.h?.buttons ?? []
                Rectangle {
                    required property string modelData
                    width: 16
                    height: 14
                    color: root.p.color
                    border.width: 0
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: root.p.bevel?.light ?? "white"
                    }
                    Rectangle {
                        width: 1
                        height: parent.height
                        color: root.p.bevel?.light ?? "white"
                    }
                    Rectangle {
                        y: parent.height - 1
                        width: parent.width
                        height: 1
                        color: root.p.bevel?.dark ?? "black"
                    }
                    Rectangle {
                        x: parent.width - 1
                        width: 1
                        height: parent.height
                        color: root.p.bevel?.dark ?? "black"
                    }
                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData
                        color: Tokens.ink("#130a24")
                        font.family: Tokens.font
                        font.pixelSize: 11
                    }
                }
            }
        }
    }

    // ── The window's surround (a handheld's screen bezel) ───────────
    Shape {
        readonly property var f: root.hw.window.frame
        visible: !!f && root.win.width > 0
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillColor: parent.f?.color ?? "transparent"
            PathSvg {
                readonly property var f: root.hw.window.frame
                path: f ? Hardware.rounded(root.win.x - f.pad, root.win.y - f.pad, root.win.width + f.pad * 2, root.win.height + f.pad + (f.padB ?? f.pad), f.radius) : ""
            }
        }
    }
    Text {
        readonly property var f: root.hw.window.frame
        visible: !!f?.mark && root.win.width > 0
        x: root.win.x + (root.win.width - width) / 2
        y: root.win.y + root.win.height + ((f?.padB ?? 0) - height) / 2 + 1
        text: f?.mark ?? ""
        color: f?.markColor ?? "white"
        font.family: Tokens.font
        font.pixelSize: 8
        font.letterSpacing: 1
    }
}
