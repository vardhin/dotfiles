import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.Mpris
import qs.services
import "Shapes.js" as Shapes

// One desktop panel (see services/Panels.qml) drawn on its own DotSurface.
// Placed in grid units; drag it to move it, it snaps to the grid on release.
Item {
    id: root

    required property var panel
    // World offset of this panel's workspace (World.qml lays workspaces side by side).
    property real originX: 0

    readonly property int unit: Panels.unit
    readonly property int cols: Math.max(1, Math.floor(panel.w * unit / Tokens.pitch))
    readonly property int rows: Math.max(1, Math.floor(panel.h * unit / Tokens.pitch))
    readonly property color tube: [Tokens.slot0, Tokens.slot1, Tokens.slot2][panel.slot] ?? Tokens.slot0
    readonly property bool raw: panel.dot === false
    readonly property bool photo: panel.kind === "image" || panel.kind === "mpris"

    // Live position while dragging, in px; snapped to whole units on release.
    property point drag: Qt.point(0, 0)
    property bool dragging: false

    x: originX + panel.x * unit + drag.x
    y: panel.y * unit + drag.y
    width: panel.w * unit
    height: panel.h * unit
    z: dragging ? 1 : 0

    // Largest whole multiple of the pixel font that fits `chars` on the panel.
    function fit(chars: int): int {
        const byW = Math.floor((cols - 2) / Math.max(1, chars * Tokens.charDots));
        const byH = Math.floor((rows - 2) / Tokens.fontPx);
        return Math.max(1, Math.min(byW, byH));
    }

    SystemClock {
        id: clock
        enabled: root.panel.kind === "clock"
        precision: SystemClock.Seconds
    }

    readonly property MprisPlayer player: {
        if (panel.kind !== "mpris")
            return null;
        const all = Mpris.players.values;
        const want = panel.source.toLowerCase();
        return (want ? all.find(p => (p.identity ?? "").toLowerCase().includes(want) || (p.dbusName ?? "").toLowerCase().includes(want)) : null) ?? all[0] ?? null;
    }

    DotSurface {
        id: surface
        cols: root.cols
        rows: root.rows
        // Fills the panel's px box; at pitch 5 or 8 a unit is not a whole
        // number of dots, so the last partial dot row is left as glass.
        // Raw: images and art get the crisp copy below; drawn content goes flat.
        flat: root.raw
        visible: !(root.raw && root.photo)
        imageMode: root.panel.kind === "image" || root.panel.kind === "mpris"
        dither: root.panel.kind === "mpris"
        shape: Shapes.path(root.panel.shape, root.cols, root.rows)

        // Dots nothing lights stay unlit, so the board's shape shows when dark.

        // ── clock ──
        DotText {
            visible: root.panel.kind === "clock"
            width: root.cols
            height: root.rows
            size: root.fit(5)
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDateTime(clock.date, clock.seconds % 2 ? "hh mm" : "hh:mm")
            color: root.tube
        }

        // ── sign ──
        DotText {
            visible: root.panel.kind === "sign"
            width: root.cols
            height: root.rows
            size: root.fit(Math.max(1, root.panel.text.length))
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.panel.text.toUpperCase()
            color: root.tube
        }

        // ── note: inset from curved edges, centered vertically ──
        DotLabel {
            readonly property int inset: root.panel.shape === "rect" ? 2 : Math.round(Math.min(root.cols, root.rows) * 0.16)
            visible: root.panel.kind === "note"
            x: inset
            y: Math.max(1, Math.round((root.rows - height) / 2))
            width: root.cols - inset * 2
            wrapMode: Text.Wrap
            maximumLineCount: Math.max(1, Math.floor((root.rows - inset * 2) / Tokens.lineDots))
            text: root.panel.text
            color: root.tube
        }

        // ── image (dot mode; raw mode draws the crisp copy below) ──
        Image {
            visible: root.panel.kind === "image"
            width: root.cols
            height: root.rows
            source: root.panel.kind === "image" && root.panel.source ? "file://" + root.panel.source.replace(/^~(?=\/)/, Quickshell.env("HOME")) : ""
            sourceSize: Qt.size(root.cols, root.rows)
            fillMode: Image.PreserveAspectCrop
            smooth: true
            asynchronous: true
        }

        // ── mpris: art on the left when wide, title and artist ──
        Item {
            visible: root.panel.kind === "mpris"
            width: root.cols
            height: root.rows
            readonly property bool wide: root.cols > root.rows * 1.6

            Image {
                id: art
                visible: parent.wide && !!root.player?.trackArtUrl
                width: root.rows
                height: root.rows
                source: root.player?.trackArtUrl ?? ""
                sourceSize: Qt.size(root.rows, root.rows)
                fillMode: Image.PreserveAspectCrop
            }
            Column {
                x: art.visible ? root.rows + 3 : 2
                y: Math.max(0, Math.round((root.rows - Tokens.lineDots * 2) / 2))
                width: root.cols - x - 2

                DotText {
                    width: parent.width
                    height: Tokens.lineDots
                    elide: Text.ElideRight
                    text: (root.player?.trackTitle || (root.player ? "NOTHING PLAYING" : "NO PLAYER")).toUpperCase()
                    color: root.tube
                }
                DotText {
                    width: parent.width
                    height: Tokens.lineDots
                    elide: Text.ElideRight
                    text: (root.player?.trackArtist ?? "").toUpperCase()
                    color: Tokens.slot1
                }
            }
        }

        // ── media: art, title, artist, progress; a spectrum below when tall ──
        Item {
            id: media
            visible: root.panel.kind === "media"
            width: root.cols
            height: root.rows
            readonly property bool wide: root.cols > root.rows * 1.4
            // Wide: art on the left, full height. Otherwise art on top.
            readonly property int artSize: wide ? root.rows - 2 : Math.max(0, Math.min(root.cols - 2, root.rows - Tokens.lineDots * 2 - 4))
            readonly property int textX: wide ? artSize + 4 : 2
            readonly property int textY: wide ? 1 : artSize + 3
            readonly property int textW: root.cols - textX - 2

            DitherArt {
                visible: root.panel.kind === "media" && media.artSize >= 8
                x: 1
                y: 1
                width: media.artSize
                height: media.artSize
                source: visible ? Media.art : ""
            }
            Column {
                x: media.textX
                y: media.textY
                width: media.textW

                Item {
                    width: parent.width
                    height: Tokens.lineDots
                    readonly property string text: (Media.title || (Media.active ? "NOTHING PLAYING" : "NO PLAYER")).toUpperCase()
                    readonly property bool long: fitTitle.implicitWidth > width

                    DotText {
                        id: fitTitle
                        width: parent.width
                        visible: !parent.long
                        text: parent.text
                        color: root.tube
                    }
                    Marquee {
                        width: parent.width
                        height: parent.height
                        visible: parent.long && root.panel.kind === "media"
                        passes: 1000000
                        stepMs: 40
                        text: parent.text
                        color: root.tube
                        onTextChanged: if (visible) run()
                        onVisibleChanged: if (visible) run()
                    }
                }
                DotText {
                    width: parent.width
                    height: Tokens.lineDots
                    elide: Text.ElideRight
                    text: Media.artist.toUpperCase()
                    color: Tokens.slot1
                }
                // Progress: lit up to where the track is.
                Item {
                    width: parent.width
                    height: 4
                    Rectangle {
                        y: 1
                        width: parent.width
                        height: 1
                        color: Tokens.slot1
                        opacity: 0.5
                    }
                    Rectangle {
                        y: 1
                        width: Math.round(parent.width * Media.progress)
                        height: 1
                        color: root.tube
                    }
                }
                Spectrum {
                    readonly property int room: root.rows - 1 - media.textY - Tokens.lineDots * 2 - 4
                    visible: root.panel.kind === "media" && room >= 6
                    width: parent.width
                    height: Math.max(0, room)
                    bars: Math.max(4, Math.min(32, Math.floor(parent.width / 3)))
                }
            }
        }

        // ── vis: a spectrum analyser over the whole board ──
        Spectrum {
            visible: root.panel.kind === "vis"
            x: 1
            y: 1
            width: root.cols - 2
            height: root.rows - 2
            bars: Math.max(4, Math.min(32, Math.floor((root.cols - 2) / 3)))
        }

        // ── pixels: last frame from `dot pixels` (a PPM image, panel resolution) ──
        Image {
            readonly property var frame: Panels.frames[root.panel.id] ?? null
            visible: root.panel.kind === "pixels"
            width: root.cols
            height: root.rows
            source: frame ? "data:image/x-portable-pixmap;base64," + frame.data : ""
            smooth: false
            cache: false
        }
    }

    // ── Raw mode for images and art: full resolution, cut to the shape ──
    Item {
        id: crisp
        anchors.fill: parent
        visible: root.raw && root.photo
        layer.enabled: visible
        layer.effect: MultiEffect {
            maskEnabled: root.panel.shape !== "rect"
            maskSource: crispMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0
        }

        Image {
            anchors.fill: parent
            source: root.panel.kind === "image" ? (root.panel.source ? "file://" + root.panel.source.replace(/^~(?=\/)/, Quickshell.env("HOME")) : "") : (root.player?.trackArtUrl ?? "")
            sourceSize: Qt.size(width, height)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }
    Shape {
        id: crispMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            fillColor: "white"
            PathSvg {
                path: Shapes.path(root.panel.shape, root.width, root.height) || `M 0 0 L ${root.width} 0 L ${root.width} ${root.height} L 0 ${root.height} Z`
            }
        }
    }

    // Drag to move; release snaps to whole grid units.
    MouseArea {
        anchors.fill: parent
        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        property point start

        onPressed: mouse => {
            start = mapToItem(root.parent, mouse.x, mouse.y);
            root.dragging = true;
        }
        onPositionChanged: mouse => {
            if (!root.dragging)
                return;
            const p = mapToItem(root.parent, mouse.x, mouse.y);
            root.drag = Qt.point(p.x - start.x, p.y - start.y);
        }
        onReleased: {
            const dx = Math.round(root.drag.x / root.unit), dy = Math.round(root.drag.y / root.unit);
            // Barely moved: a click. A media board plays or pauses.
            const click = Math.abs(root.drag.x) < 4 && Math.abs(root.drag.y) < 4;
            root.dragging = false;
            root.drag = Qt.point(0, 0);
            if (dx || dy)
                Panels.move(root.panel.id, root.panel.x + dx, root.panel.y + dy);
            else if (click && root.panel.kind === "media")
                Media.toggle();
        }
    }
}
