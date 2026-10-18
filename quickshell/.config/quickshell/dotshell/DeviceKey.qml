import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.services
import "Hardware.js" as Hardware

// One key of a device (Hardware.js `keys` item, its `style` resolved): a
// rubber key, a neon ring, a chrome wedge, a glass orb, a 95 button, a
// handheld's d-pad, or just a lit word. Sized by its owner. `grip(kind,
// area, mouse)`, when set, also gets the presses, so a panel can still be
// held or dragged from its keys; a press it turned into a drag is no click.
Item {
    id: key

    required property var spec
    property var grip: null
    property bool dragged: false

    readonly property var s: spec.style
    readonly property bool pressed: hit.pressed || left.pressed || right.pressed
    readonly property bool hovered: hit.containsMouse || left.containsMouse || right.containsMouse
    readonly property color ink: Hardware.ink(s.ink, [Tokens.slot0, Tokens.slot1, Tokens.slot2]) || "white"
    readonly property bool round: s.shape === "round"
    readonly property string label: {
        const l = spec.label;
        if (Array.isArray(l))
            return l[Media.isPlaying ? 1 : 0];
        return l ?? "";
    }
    readonly property string icon: label !== "" || spec.label === "" ? "" : spec.act === "prev" ? Hardware.icons.prev : spec.act === "next" ? Hardware.icons.next : spec.act === "toggle" ? (Media.isPlaying ? Hardware.icons.pause : Hardware.icons.play) : ""

    signal act(string what)

    // The fill's two stops, as the key is now (pressed, hovered, at rest).
    readonly property color topColor: pressed && s.down ? s.down[0] : hovered && s.hover ? s.hover : s.fill ? s.fill[0] : "transparent"
    readonly property color bottomColor: pressed && s.down ? s.down[1] : s.fill ? (s.fill[1] ?? s.fill[0]) : "transparent"
    function outline(w: real, h: real): string {
        if (key.round)
            return `M 0 ${h / 2} A ${w / 2} ${h / 2} 0 1 0 ${w} ${h / 2} A ${w / 2} ${h / 2} 0 1 0 0 ${h / 2} Z`;
        if (s.shape === "skew")
            return Hardware.skewed(w, h, s.slant, 0);
        return Hardware.rounded(0, 0, w, h, s.radius);
    }

    // A drop under the key (cabinet buttons, moulded keys).
    Shape {
        visible: !!key.s.under && key.s.shape !== "none" && key.s.shape !== "dpad"
        y: key.pressed ? 1 : 2
        width: key.width
        height: key.height
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillColor: key.s.under || "transparent"
            PathSvg {
                path: key.outline(key.width, key.height)
            }
        }
    }

    // The key's body.
    Item {
        id: cap
        y: key.pressed ? 1 : 0
        width: key.width
        height: key.height
        layer.enabled: !!key.s.glow && key.s.shape !== "none"
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: key.s.glow || "black"
            shadowBlur: key.hovered ? 0.6 : 0.4
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }

        Shape {
            visible: ["rect", "round", "skew"].includes(key.s.shape)
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: key.s.border?.w ?? -1
                strokeColor: key.s.border?.color ?? "transparent"
                fillColor: key.s.orb || key.s.fill ? "white" : key.hovered && key.s.hover ? key.s.hover : "transparent"
                fillGradient: key.s.orb ? orb : key.s.fill ? lin : null
                PathSvg {
                    path: key.outline(key.width, key.height)
                }
            }
        }
        LinearGradient {
            id: lin
            x1: 0
            y1: 0
            x2: 0
            y2: key.height
            GradientStop {
                position: 0
                color: key.topColor
            }
            GradientStop {
                position: 1
                color: key.bottomColor
            }
        }
        RadialGradient {
            id: orb
            centerX: key.width * 0.42
            centerY: key.height * 0.3
            centerRadius: key.width * 0.75
            focalX: centerX
            focalY: centerY
            GradientStop {
                position: 0
                color: key.pressed ? key.s.orb?.[1] ?? "white" : key.s.orb?.[0] ?? "white"
            }
            GradientStop {
                position: 0.55
                color: key.s.orb?.[1] ?? "white"
            }
            GradientStop {
                position: 1
                color: key.s.orb?.[2] ?? "white"
            }
        }

        // Lit along the top.
        Rectangle {
            visible: !!key.s.edge && !key.pressed
            x: 3
            y: 1
            width: parent.width - 6
            height: 1
            color: key.s.edge || "transparent"
        }

        // 95: raised, sunk while pressed.
        Item {
            anchors.fill: parent
            visible: !!key.s.bevel
            readonly property color hi: key.pressed ? key.s.bevel?.dark ?? "black" : key.s.bevel?.light ?? "white"
            readonly property color lo: key.pressed ? key.s.bevel?.light ?? "white" : key.s.bevel?.dark ?? "black"
            Rectangle {
                width: parent.width
                height: 1
                color: parent.hi
            }
            Rectangle {
                width: 1
                height: parent.height
                color: parent.hi
            }
            Rectangle {
                y: parent.height - 1
                width: parent.width
                height: 1
                color: parent.lo
            }
            Rectangle {
                x: parent.width - 1
                width: 1
                height: parent.height
                color: parent.lo
            }
        }

        // A d-pad: the cross, its two live arms marked.
        Item {
            anchors.fill: parent
            visible: key.s.shape === "dpad"
            readonly property real arm: Math.round(Math.min(width, height) / 3)
            Rectangle {
                x: (parent.width - parent.arm) / 2
                width: parent.arm
                height: parent.height
                radius: 3
                color: key.topColor
            }
            Rectangle {
                y: (parent.height - parent.arm) / 2
                width: parent.width
                height: parent.arm
                radius: 3
                color: key.topColor
            }
            Rectangle {
                visible: left.pressed || right.pressed
                x: left.pressed ? 0 : parent.width - parent.arm
                y: (parent.height - parent.arm) / 2
                width: parent.arm
                height: parent.arm
                radius: 3
                color: Qt.darker(key.topColor, 1.4)
            }
            Text {
                x: (parent.arm - width) / 2
                anchors.verticalCenter: parent.verticalCenter
                text: "◂"
                color: left.containsMouse ? Qt.lighter(key.ink, 1.4) : key.ink
                font.pixelSize: 11
            }
            Text {
                x: parent.width - parent.arm + (parent.arm - width) / 2
                anchors.verticalCenter: parent.verticalCenter
                text: "▸"
                color: right.containsMouse ? Qt.lighter(key.ink, 1.4) : key.ink
                font.pixelSize: 11
            }
        }

        Shape {
            visible: key.icon !== ""
            anchors.centerIn: parent
            width: 16
            height: 14
            scale: Math.max(0.55, Math.min(0.9, Math.min(key.width, key.height) / 34))
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: key.s.hollow ? 1.4 : -1
                strokeColor: key.ink
                fillColor: key.s.hollow ? "transparent" : key.ink
                PathSvg {
                    path: key.icon
                }
            }
        }
        Text {
            visible: key.label !== ""
            anchors.centerIn: parent
            text: key.label
            color: key.hovered && key.s.shape === "none" ? Qt.lighter(key.ink, 1.25) : key.ink
            font.family: Tokens.font
            font.pixelSize: key.s.size
            layer.enabled: key.s.shape === "none" && !!key.s.glow
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: key.s.glow || "black"
                shadowBlur: key.hovered ? 0.7 : 0.45
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }
        }
    }

    // Printed under the key (a handheld's A and B).
    Text {
        visible: !!key.spec.caption
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height + 4
        text: key.spec.caption ?? ""
        color: key.s.caption || key.ink
        font.family: Tokens.font
        font.pixelSize: 9
    }

    // ── Input ───────────────────────────────────────────────────────
    function press(area: Item, mouse: var): void {
        dragged = false;
        if (grip)
            grip("press", area, mouse);
    }
    function moved(area: Item, mouse: var): void {
        if (grip && area.pressed)
            grip("move", area, mouse);
    }
    function release(area: Item, mouse: var): void {
        if (grip)
            dragged = grip("release", area, mouse);
    }
    function cancel(area: Item): void {
        if (grip)
            grip("cancel", area, null);
    }

    MouseArea {
        id: hit
        anchors.fill: parent
        enabled: key.spec.act !== "dpad"
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => key.press(hit, mouse)
        onPositionChanged: mouse => key.moved(hit, mouse)
        onReleased: mouse => key.release(hit, mouse)
        onCanceled: key.cancel(hit)
        onClicked: if (!key.dragged) key.act(key.spec.act)
    }
    MouseArea {
        id: left
        width: parent.width / 2
        height: parent.height
        enabled: key.spec.act === "dpad"
        hoverEnabled: enabled
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => key.press(left, mouse)
        onPositionChanged: mouse => key.moved(left, mouse)
        onReleased: mouse => key.release(left, mouse)
        onCanceled: key.cancel(left)
        onClicked: if (!key.dragged) key.act("prev")
    }
    MouseArea {
        id: right
        x: parent.width / 2
        width: parent.width / 2
        height: parent.height
        enabled: key.spec.act === "dpad"
        hoverEnabled: enabled
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => key.press(right, mouse)
        onPositionChanged: mouse => key.moved(right, mouse)
        onReleased: mouse => key.release(right, mouse)
        onCanceled: key.cancel(right)
        onClicked: if (!key.dragged) key.act("next")
    }
}
