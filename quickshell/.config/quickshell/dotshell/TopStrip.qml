import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Wayland
import qs.services
import qs.vfd as Vfd
import qs.tokyo as Tokyo
import qs.vapor as Vw
import qs.flap as Fl

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
    // VFD: the dots sit in a window sunk into a gunmetal plate (vfd/Dash.qml),
    // this much plate round it, in px.
    readonly property bool vfd: Tokens.era === "vfd"
    readonly property int pad: vfd ? Math.max(3, Math.round(Tokens.pitch * 1.5)) : 0
    // Tokyo Night: a pink neon tube along the bottom (tokyo/Edge.qml), this
    // many px under the dots.
    readonly property bool tokyo: Tokens.era === "tokyo"
    readonly property int edge: tokyo ? 4 : 0
    readonly property int cols: Math.floor((width - pad * 2) / Tokens.pitch)
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
        let h = rows * Tokens.pitch + pad * 2 + edge;
        while (Math.abs(h * dpr - Math.round(h * dpr)) > 0.01 && h < rows * Tokens.pitch + pad * 2 + edge + 10)
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

    // Where the zones meet, in screen px, so a drop aims at the zone it is
    // over (services/Dock.qml): l|c halfway between the left run and the
    // center, c|r halfway between the center and the right run, r|e at the
    // middle of the settings words.
    function publishZones(): void {
        const px = (item, dx) => item.mapToItem(null, dx, 0).x;
        const leftEnd = px(left, left.width);
        const centerStart = center.visible && center.width > 0 ? px(center, 0) : strip.width / 2;
        const centerEnd = center.visible && center.width > 0 ? px(center, center.width) : strip.width / 2;
        const rightStart = px(right, 0);
        const s = Object.assign({}, Panels.slots);
        s["_zones"] = {
            place: "strip",
            lc: (leftEnd + centerStart) / 2,
            cr: (centerEnd + rightStart) / 2,
            re: px(settings, settings.width / 2)
        };
        Panels.slots = s;
    }
    Timer {
        id: zonesLater
        interval: 50
        onTriggered: strip.publishZones()
    }

    // Frutiger Aero: the strip is sky glass with only its lit dots on it.
    BarChrome {
        anchors.fill: parent
        visible: Tokens.era === "aero"
        place: "strip"
    }

    // Vaporwave: the Windows 95 taskbar, lit dots only on the lilac.
    Vw.Taskbar {
        anchors.fill: parent
        visible: Tokens.era === "vapor"
        place: "strip"
    }

    // Split-Flap: one long departure board housing, lit square dots on it.
    Fl.Rack {
        anchors.fill: parent
        visible: Tokens.era === "flap"
        place: "strip"
    }

    // VFD: a gunmetal head unit, the dots in one long sunken window.
    Vfd.Dash {
        anchors.fill: parent
        visible: strip.vfd
        place: "strip"
        win: Qt.rect(surface.x, surface.y, surface.width, surface.height)
    }

    DotSurface {
        id: surface
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -strip.edge / 2
        cols: strip.cols
        rows: strip.rows
        bare: Tokens.era === "aero" || Tokens.era === "vapor" || Tokens.era === "flap"

        // ── Left ────────────────────────────────────────────────────
        DockRow {
            id: left
            x: 2
            place: "strip"
            zone: "l"
            screenW: strip.width
            screenH: strip.screen.height
            onWidthChanged: zonesLater.restart()
        }

        // The focused window's title, in whatever room is left before the
        // center; gone when that is under four letters, and on narrow strips.
        DotText {
            readonly property int room: center.x - x - 8
            x: left.x + left.width + 8
            width: Math.max(0, room)
            visible: !strip.vfd && !strip.tokyo && Tokens.era !== "vapor" && Tokens.era !== "flap" && Tokens.title && !strip.compact && !ticker.visible && room >= Tokens.charDots * 4 && text !== ""
            elide: Text.ElideRight
            text: (ToplevelManager.activeToplevel?.activated ? ToplevelManager.activeToplevel.title : "").toUpperCase()
            color: Tokens.slot1
            opacity: 0.5
        }
        MatrixText {
            readonly property int room: center.x - x - 8
            x: left.x + left.width + 8
            y: 2
            width: Math.max(0, room)
            height: 7
            visible: (strip.vfd || strip.tokyo || Tokens.era === "vapor" || Tokens.era === "flap") && Tokens.title && !strip.compact && !ticker.visible && room >= 6 * 4 && text !== ""
            text: (ToplevelManager.activeToplevel?.activated ? ToplevelManager.activeToplevel.title : "").toUpperCase()
            color: strip.tokyo ? Tokyo.Ink.violet : Tokens.era === "vapor" ? Vw.Ink.label : Tokens.era === "flap" ? Fl.Ink.label : Vfd.Ink.teal
            opacity: strip.tokyo ? 0.6 : 1
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
            onXChanged: zonesLater.restart()
            onWidthChanged: zonesLater.restart()
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
            onXChanged: zonesLater.restart()

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

    // Tokyo Night: the bar's one neon tube, at the desktop.
    Tokyo.Edge {
        anchors.fill: parent
        visible: strip.tokyo
        place: "strip"
    }

    Vfd.Smoke {
        visible: strip.vfd
        x: surface.x
        y: surface.y
        width: surface.width
        height: surface.height
    }
}
