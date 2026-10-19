import QtQuick
import QtQuick.Shapes
import "Hardware.js" as Hardware

// Over a display window's dots (Hardware.js `window`): what the glass does to
// them. Smoked glass shading from the top, scanlines, a glassy highlight,
// goggles darkening toward the edges, a sunken 95 bevel, and the window's
// edge (following its outline: rounded, pill, leaning). Fills its parent;
// lay it above the DotSurface.
Item {
    id: root

    required property var hw
    readonly property var w: hw.window
    readonly property string outline: Hardware.windowPath(hw, width, height, 1)
    readonly property bool light: Tokens.current.light

    Rectangle {
        visible: root.w.shade > 0
        anchors.left: parent.left
        anchors.right: parent.right
        height: 14
        gradient: Gradient {
            GradientStop {
                position: 0
                // Smoked glass by night; on light glass only a faint tint.
                color: Tokens.current.light ? Qt.rgba(0.1, 0.13, 0.13, root.w.shade * 0.2) : Qt.rgba(0, 0, 0, root.w.shade)
            }
            GradientStop {
                position: 1
                color: "transparent"
            }
        }
    }

    // Scanlines: a dark line every third px.
    Canvas {
        anchors.fill: parent
        visible: root.w.scan
        readonly property bool tone: root.light
        onToneChanged: requestPaint()
        onHeightChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            const c = getContext("2d");
            c.reset();
            c.fillStyle = Qt.rgba(0, 0, 0, root.light ? 0.07 : 0.32);
            for (let y = 0; y < height; y += 3)
                c.fillRect(0, y, width, 1);
        }
    }

    // Goggles: dark toward the rim.
    Shape {
        visible: root.w.vignette
        anchors.fill: parent
        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: root.width / 2
                centerY: root.height / 2
                centerRadius: Math.max(root.width, root.height) * 0.6
                focalX: centerX
                focalY: centerY
                GradientStop {
                    position: 0.35
                    color: "transparent"
                }
                GradientStop {
                    position: 1
                    color: Qt.rgba(0, 0, 0, Tokens.current.light ? 0.22 : 0.75)
                }
            }
            PathSvg {
                path: root.outline || `M 0 0 L ${root.width} 0 L ${root.width} ${root.height} L 0 ${root.height} Z`
            }
        }
    }

    // Glass catching the light.
    Rectangle {
        visible: root.w.gloss
        x: 10
        y: 3
        width: parent.width - 20
        height: Math.min(parent.height * 0.3, 40)
        radius: Math.min(height / 2, typeof root.w.radius === "number" ? root.w.radius : 20)
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(1, 1, 1, Tokens.current.light ? 0.3 : 0.06)
            }
            GradientStop {
                position: 1
                color: Qt.rgba(1, 1, 1, 0)
            }
        }
    }

    // Sunk into the plate: dark top left, light bottom right.
    Item {
        anchors.fill: parent
        visible: !!root.w.sunken
        Rectangle {
            width: parent.width
            height: 2
            color: root.w.sunken?.dark ?? "transparent"
        }
        Rectangle {
            width: 2
            height: parent.height
            color: root.w.sunken?.dark ?? "transparent"
        }
        Rectangle {
            y: parent.height - 2
            width: parent.width
            height: 2
            color: root.w.sunken?.light ?? "transparent"
        }
        Rectangle {
            x: parent.width - 2
            width: 2
            height: parent.height
            color: root.w.sunken?.light ?? "transparent"
        }
    }

    // The edge.
    Shape {
        visible: !!root.w.edge
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: root.w.edgeW
            strokeColor: root.w.edge || "transparent"
            fillColor: "transparent"
            PathSvg {
                path: root.outline || `M 0 0 L ${root.width} 0 L ${root.width} ${root.height} L 0 ${root.height} Z`
            }
        }
    }
}
