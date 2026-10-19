import QtQuick
import qs.services
import "Hardware.js" as Hardware

// The media panel, compact, in the VFD era: a car-stereo faceplate (panel
// design canvas, "Now playing", VFD). A brushed bezel holds a smoked display
// window, the only part made of dots, with rubber keys under it. Drawn in
// place of the generic board by DeskPanel.qml.
//
//   display   VfdReadout: annunciators, title, time, segment bar
//   keys      DeviceKeys: |<   ||   >|
Item {
    id: root

    required property var ctx
    required property var sink
    required property var panel
    required property var words

    // The device (Hardware.js): faceplate, display window, keys.
    readonly property var hw: Hardware.get("vfd", Tokens.flipped)
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

    // ── Display window ──────────────────────────────────────────────
    Rectangle {
        id: glass
        x: root.at.window.x
        y: root.at.window.y
        width: root.at.window.w
        height: root.at.window.h
        radius: root.hw.window.radius
        color: Tokens.glass
        clip: true

        DotSurface {
            id: screen
            anchors.centerIn: parent
            cols: Math.floor(parent.width / pitch)
            rows: Math.floor(parent.height / pitch)

            VfdReadout {
                width: screen.cols
                height: screen.rows
                ctx: root.ctx
                idle: root.words.idle
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
