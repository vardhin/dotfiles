import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services

// Top LED strip: workspaces, window title | clock or ticker | now playing,
// status words, tray glyphs. Everything inside the DotSurface is measured in
// dots, not pixels. Status words open their pane on click; VOL and BRT also
// take the wheel, the now-playing word skips tracks with it.
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

        // ── Left: workspaces ────────────────────────────────────────
        Row {
            id: workspaces
            x: 2
            height: strip.rows
            spacing: 3

            // Always show 1..5, plus any higher workspace that exists.
            readonly property var live: Hyprland.workspaces.values.filter(w => w.id > 0)
            readonly property int count: Math.max(5, ...live.map(w => w.id))

            Repeater {
                model: workspaces.count

                Item {
                    id: cell
                    required property int index
                    readonly property int wsId: index + 1
                    readonly property var ws: workspaces.live.find(w => w.id === wsId) ?? null
                    readonly property bool focused: ws !== null && ws.id === Hyprland.focusedWorkspace?.id
                    readonly property bool shown: ws !== null && ws.active && ws.monitor === strip.monitor

                    width: label.implicitWidth
                    height: strip.rows

                    DotText {
                        id: label
                        text: cell.wsId
                        color: cell.ws?.urgent ? Tokens.slot2 : cell.focused || cell.shown ? Tokens.slot0 : Tokens.slot1
                        // Empty workspaces sit at the dim brightness level.
                        opacity: cell.ws === null ? 0.5 : 1
                    }

                    // Focus underline: one dot row under the digit.
                    Rectangle {
                        visible: cell.focused
                        y: strip.rows - 1
                        width: parent.width
                        height: 1
                        color: Tokens.slot0
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: Hyprland.dispatch("workspace " + cell.wsId)
                    }
                }
            }

            // A new, empty workspace (the first free id).
            StatusWord {
                text: "+"
                color: Tokens.slot2
                onClicked: Hyprland.dispatch("workspace empty")
            }
        }

        // The focused window's title, in whatever room is left before the
        // clock; gone when that is under four letters, and on narrow strips.
        DotText {
            readonly property int room: clockRow.x - x - 8
            x: workspaces.x + workspaces.width + 8
            width: Math.max(0, room)
            visible: Tokens.title && !strip.compact && !ticker.visible && room >= Tokens.charDots * 4 && text !== ""
            elide: Text.ElideRight
            text: (ToplevelManager.activeToplevel?.activated ? ToplevelManager.activeToplevel.title : "").toUpperCase()
            color: Tokens.slot1
            opacity: 0.5
        }

        // ── Center: clock, or the ticker when a message arrives ─────
        SystemClock {
            id: clock
            precision: SystemClock.Seconds
        }

        // Centered, but pushed left when the status words grow into the middle.
        readonly property int centerMin: workspaces.x + workspaces.width + 8
        readonly property int centerMax: right.x - 8

        Row {
            id: clockRow
            x: Math.max(surface.centerMin, Math.min(Math.round((strip.cols - width) / 2), surface.centerMax - width))
            height: strip.rows
            spacing: 4
            visible: !ticker.visible

            DotText {
                text: Qt.formatDateTime(clock.date, strip.compact ? "dd" : "ddd dd MMM").toUpperCase()
                color: Tokens.slot2
            }
            DotText {
                // Blinking colon, like a real LED clock.
                text: Qt.formatDateTime(clock.date, clock.seconds % 2 ? "hh mm" : "hh:mm")
                color: Tokens.slot0
            }
        }

        MouseArea {
            anchors.fill: clockRow
            enabled: clockRow.visible
            onClicked: Ui.toggle("calendar", strip.screen)
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

        // ── Right: status words, then tray glyphs ───────────────────
        Row {
            id: right
            anchors.right: parent.right
            anchors.rightMargin: 2
            height: strip.rows
            spacing: strip.compact ? 4 : 6

            // Now playing: play or pause glyph and the title. Click opens
            // MEDIA, middle click plays or pauses, the wheel skips tracks.
            Item {
                id: nowWord
                visible: Media.active && (Media.title !== "" || Media.isPlaying)
                // A 16-letter window the title runs through when it is longer.
                readonly property int box: strip.compact ? 0 : Math.min(16 * Tokens.charDots, nowTitle.one)
                width: glyph.implicitWidth + (box > 0 ? Tokens.charDots + box : 0)
                height: strip.rows

                DotText {
                    id: glyph
                    text: Media.isPlaying ? "\uf04b" : "\uf04c"
                    color: Tokens.slot2
                    opacity: Media.isPlaying ? 1 : 0.5
                }
                Scroller {
                    id: nowTitle
                    readonly property int one: fit.implicitWidth
                    x: glyph.implicitWidth + Tokens.charDots
                    width: nowWord.box
                    height: strip.rows
                    visible: nowWord.box > 0
                    text: Media.title.toUpperCase()
                    color: Tokens.slot2
                    textOpacity: Media.isPlaying ? 1 : 0.5
                    DotText {
                        id: fit
                        visible: false
                        text: nowTitle.text
                    }
                }
                Rectangle {
                    visible: nowMouse.containsMouse
                    y: strip.rows - 1
                    width: parent.width
                    height: 1
                    color: Tokens.slot2
                }
                MouseArea {
                    id: nowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    onClicked: mouse => mouse.button === Qt.MiddleButton ? Media.toggle() : Ui.toggle("media", strip.screen)
                    onWheel: wheel => wheel.angleDelta.y > 0 ? Media.previous() : Media.next()
                }
            }
            StatusWord {
                visible: Notifs.dnd || Notifs.live.length > 0
                text: Notifs.dnd ? "DND" : strip.word("MSG ", "M") + Notifs.live.length
                color: Notifs.dnd ? Tokens.slot1 : Tokens.slot2
                onClicked: Ui.toggle("notifs", strip.screen)
            }
            StatusWord {
                visible: Idle.caffeine
                text: strip.word("CAF", "C")
                color: Tokens.slot2
                onClicked: Ui.toggle("brightness", strip.screen)
            }
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
            StatusWord {
                visible: Power.present
                text: strip.word("BAT ", "") + Power.percent + (Power.charging ? "+" : "")
                color: Power.discharging && Power.fraction <= 0.15 ? Tokens.slot2 : Tokens.slot0
                onClicked: Ui.toggle("battery", strip.screen)
            }

            Item {
                visible: SystemTray.items.values.length > 0
                width: 1
                height: strip.rows
            }

            Repeater {
                model: SystemTray.items

                Item {
                    id: glyph
                    required property SystemTrayItem modelData
                    readonly property int size: 9

                    width: size
                    height: strip.rows

                    // The icon only supplies a silhouette; the dots take an era color.
                    IconImage {
                        id: icon
                        anchors.centerIn: parent
                        implicitSize: glyph.size
                        source: glyph.modelData.icon
                        layer.enabled: true
                        visible: false
                    }
                    Rectangle {
                        anchors.fill: icon
                        color: glyph.modelData.status === Status.NeedsAttention ? Tokens.slot2 : Tokens.slot1
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: icon
                            maskThresholdMin: 0.4
                            maskSpreadAtMin: 0
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: mouse => {
                            const item = glyph.modelData;
                            if (mouse.button === Qt.MiddleButton) {
                                item.secondaryActivate();
                            } else if (mouse.button === Qt.RightButton || item.onlyMenu) {
                                if (item.hasMenu) {
                                    const p = glyph.mapToItem(null, 0, glyph.height);
                                    item.display(strip, p.x, p.y);
                                }
                            } else {
                                item.activate();
                            }
                        }
                        onWheel: wheel => glyph.modelData.scroll(wheel.angleDelta.y / 120, false)
                    }
                }
            }
        }
    }
}
