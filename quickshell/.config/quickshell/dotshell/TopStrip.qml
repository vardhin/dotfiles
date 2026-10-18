import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Wayland
import qs.services

// Top LED strip. Since part 2 most of it is docked panels (services/Panels.qml),
// each in its strip form, in four zones:
//   left (l)  workspaces, then the focused window's title
//   center (c) the clock; the notification ticker runs over it
//   right (r)  now playing, capture, messages, caffeine
//   end (e)    battery and tray, after the settings words
// Any of them can be pulled off onto home, and any home panel docked here
// (Drag & dock, DeskPanel.qml / DockItem.qml). The settings words (VOL, BRT,
// network, BT) stay put: there is no settings panel. Everything inside the
// DotSurface is measured in dots, not pixels.
PanelWindow {
    id: strip

    required property ShellScreen modelData
    screen: modelData

    readonly property int rows: 11
    readonly property int cols: Math.floor(width / Tokens.pitch)
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    // Narrow strips (coarse pitch) drop words and keep numbers.
    readonly property bool compact: cols < 420

    anchors {
        top: true
        left: true
        right: true
    }
    // Whole physical pixels: at scale 1.2, 11 x 3 = 33 px is 39.6 device px,
    // and the fractional exclusive zone leaves a sliver between the strip and
    // the windows below it (and makes Hyprland re-round it as windows map).
    readonly property real dpr: devicePixelRatio > 0 ? devicePixelRatio : 1
    implicitHeight: {
        // Layer sizes are whole logical px; also want whole device px.
        let h = rows * Tokens.pitch;
        while (Math.abs(h * dpr - Math.round(h * dpr)) > 0.01 && h < rows * Tokens.pitch + 10)
            h++;
        return h;
    }
    color: Tokens.glass

    WlrLayershell.namespace: "dotshell-strip"
    WlrLayershell.layer: WlrLayer.Top

    Component.onCompleted: Ui.addStrip(strip)
    Component.onDestruction: Ui.removeStrip(strip)

    function word(full: string, short: string): string {
        return compact ? short : full;
    }

    DotSurface {
        id: surface
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        cols: strip.cols
        rows: strip.rows

        // ── Left ────────────────────────────────────────────────────
        DockRow {
            id: left
            x: 2
            place: "strip"
            zone: "l"
            screenW: strip.width
            screenH: strip.screen.height
        }

        // The focused window's title, in whatever room is left before the
        // center; gone when that is under four letters, and on narrow strips.
        DotText {
            readonly property int room: center.x - x - 8
            x: left.x + left.width + 8
            width: Math.max(0, room)
            visible: Tokens.title && !strip.compact && !ticker.visible && room >= Tokens.charDots * 4 && text !== ""
            elide: Text.ElideRight
            text: (ToplevelManager.activeToplevel?.activated ? ToplevelManager.activeToplevel.title : "").toUpperCase()
            color: Tokens.slot1
            opacity: 0.5
        }

        // ── Center: the clock, or the ticker when a message arrives ─
        // Centered, but pushed left when the right side grows into the middle.
        readonly property int centerMin: left.x + left.width + 8
        readonly property int centerMax: right.x - 8

        DockRow {
            id: center
            place: "strip"
            zone: "c"
            screenW: strip.width
            screenH: strip.screen.height
            x: Math.max(surface.centerMin, Math.min(Math.round((strip.cols - width) / 2), surface.centerMax - width))
            visible: !ticker.visible
        }

        Marquee {
            id: ticker
            x: surface.centerMin
            width: Math.max(0, surface.centerMax - surface.centerMin)
            height: strip.rows
            visible: false
            onFinished: visible = false

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    ticker.visible = false;
                    Ui.toggle("notifs", strip.screen);
                }
            }
        }

        Connections {
            target: Notifs
            function onArrived(n) {
                // Only the focused screen's strip runs the ticker.
                if (strip.screen !== Ui.focusedScreen())
                    return;
                const parts = [n.appName, n.summary, n.body].filter(s => s && s.trim() !== "");
                ticker.text = parts.join(" · ").replace(/\s+/g, " ").toUpperCase();
                ticker.color = n.urgency === NotificationUrgency.Critical ? Tokens.slot2 : Tokens.slot0;
                ticker.visible = true;
                ticker.run();
            }
        }

        // ── Right: docked panels, the settings words, more panels ───
        Row {
            id: right
            anchors.right: parent.right
            anchors.rightMargin: 2
            height: strip.rows
            spacing: strip.compact ? 4 : 6

            DockRow {
                place: "strip"
                zone: "r"
                screenW: strip.width
                screenH: strip.screen.height
            }

            Row {
                id: settings
                height: strip.rows
                spacing: strip.compact ? 4 : 6

                // Where the settings words sit, so a drop right of them lands
                // in the end zone (services/Dock.qml).
                function publish(): void {
                    const a = mapToItem(null, 0, 0), b = mapToItem(null, width, height);
                    const s = Object.assign({}, Panels.slots);
                    s["_settings"] = { place: "strip", x: a.x, y: a.y, w: b.x - a.x, h: b.y - a.y };
                    Panels.slots = s;
                }
                onXChanged: Qt.callLater(publish)
                onWidthChanged: Qt.callLater(publish)
                Component.onCompleted: Qt.callLater(publish)

                StatusWord {
                    text: strip.word("VOL ", "V") + (Audio.muted ? "--" : Math.round(Audio.volume * 100))
                    dim: Audio.muted
                    onClicked: Ui.toggle("audio", strip.screen)
                    onWheel: up => Audio.setVolume(Audio.volume + (up ? 0.05 : -0.05))
                }
                StatusWord {
                    visible: Brightness.available
                    text: strip.word("BRT ", "B") + Math.round(Brightness.value * 100)
                    onClicked: Ui.toggle("brightness", strip.screen)
                    onWheel: up => Brightness.set(Brightness.value + (up ? 0.05 : -0.05))
                }
                StatusWord {
                    text: {
                        if (Net.wiredUp)
                            return strip.word("WIRED", "W");
                        if (Net.active)
                            return strip.compact ? "W" : Net.active.name.toUpperCase().slice(0, 12);
                        return strip.word("OFFLINE", "W");
                    }
                    dim: !Net.wiredUp && !Net.active
                    onClicked: Ui.toggle("wifi", strip.screen)
                }
                StatusWord {
                    visible: Bt.present
                    text: strip.word("BT", "") + (Bt.connected.length > 0 ? (strip.compact ? "B" : " ") + Bt.connected.length : strip.compact ? "B" : "")
                    dim: !Bt.powered || Bt.connected.length === 0
                    onClicked: Ui.toggle("bluetooth", strip.screen)
                }
            }

            DockRow {
                place: "strip"
                zone: "e"
                screenW: strip.width
                screenH: strip.screen.height
            }
        }
    }
}
