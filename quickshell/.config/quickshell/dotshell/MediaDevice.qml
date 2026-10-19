import QtQuick
import QtQuick.Shapes
import qs.services
import "Hardware.js" as Hardware

// The media panel, compact, as the era's own device (panel design canvas,
// "Now playing", one hand-drawn skin per era): a faceplate (Hardware.js) holds
// a display window, the only part made of dots, with the era's keys under or
// beside it. Drawn in place of the generic board by DeskPanel.qml.
//
//   head      a title band (a 95 title bar, a marquee, a caption)
//   side      nixie tubes, left of the window
//   display   MediaReadout: the track, in the era's look
//   keys      DeviceKeys: |<   ||   >|
Item {
    id: root

    required property var ctx
    required property var sink
    required property var panel
    required property var words

    // The device (Hardware.js): faceplate, display window, keys.
    readonly property var hw: Hardware.get(Tokens.era, Tokens.flipped) ?? Hardware.get("vfd", Tokens.flipped)
    readonly property var at: Hardware.layout(hw, width, height)

    // Clicks and drags from a key: a hold or a drag still lifts the panel.
    function grip(kind: string, area: Item, mouse: var): bool {
        const p = area.mapToItem(null, mouse?.x ?? 0, mouse?.y ?? 0);
        return sink.grip(kind, p.x, p.y);
    }

    // ── Faceplate ───────────────────────────────────────────────────
    Faceplate {
        anchors.fill: parent
        hw: root.hw
        ctx: root.ctx
        win: Qt.rect(root.at.window.x, root.at.window.y, root.at.window.w, root.at.window.h)
    }

    // ── Tubes ───────────────────────────────────────────────────────
    Loader {
        active: root.hw.side?.kind === "tubes"
        x: root.at.side?.x ?? 0
        y: root.at.side?.y ?? 0
        width: root.at.side?.w ?? 0
        height: root.at.side?.h ?? 0
        source: "NixieTubes.qml"
        onLoaded: item.ctx = Qt.binding(() => root.ctx)
    }

    // ── Display window ──────────────────────────────────────────────
    Item {
        id: glass
        x: root.at.window.x
        y: root.at.window.y
        width: root.at.window.w
        height: root.at.window.h
        clip: true

        // Round ends and a lean cut the dots, not just the glass.
        readonly property bool shaped: root.hw.window.radius === "pill" || root.hw.plate.shape === "skew"
        readonly property string outline: Hardware.windowPath(root.hw, width, height, 1) || `M 0 0 L ${width} 0 L ${width} ${height} L 0 ${height} Z`

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillColor: Tokens.glass
                PathSvg {
                    path: glass.outline
                }
            }
        }

        DotSurface {
            id: screen
            anchors.centerIn: parent
            cols: Math.floor(parent.width / pitch)
            rows: Math.floor(parent.height / pitch)
            shape: glass.shaped ? Hardware.windowPath(root.hw, cols, rows, pitch) : ""

            MediaReadout {
                width: screen.cols
                height: screen.rows
                hw: root.hw
                ctx: root.ctx
                idle: root.words.idle
                // Clear of the round ends, or of the lean at top and bottom.
                inL: root.hw.window.radius === "pill" ? Math.round(screen.rows * 0.3) : root.hw.plate.shape === "skew" ? Math.ceil(root.hw.plate.slant * screen.rows) : 0
                inR: inL
            }
        }

        WindowGlass {
            anchors.fill: parent
            hw: root.hw
        }
    }

    // ── Keys ────────────────────────────────────────────────────────
    DeviceKeys {
        x: root.at.keys.x
        y: root.at.keys.y
        width: root.at.keys.w
        height: root.at.keys.h
        hw: root.hw
        grip: root.grip
    }
}
