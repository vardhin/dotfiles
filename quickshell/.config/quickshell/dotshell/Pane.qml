import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.services
import qs.aero as Aero
import qs.blueprint as Bp
import qs.vapor as Vw
import qs.flap as Fl
import qs.nixie as Nx
import qs.nineties as Ni
import "Hardware.js" as Hardware

// A floating LED pane: one layer-shell window holding one DotSurface.
// Children are authored in dots (1 px = 1 dot), like any DotSurface.
//
//   Pane {
//       name: "wifi"                       // Ui.pane id; open when Ui.pane === name
//       cols: 40; rows: 30                 // size in dots
//       anchors { top: true; right: true } // no anchors = centered on screen
//       DotText { text: "HELLO" }
//   }
//
// With `hardware` (Hardware.js, the era's device) the dots sit in a display
// window on a faceplate, with `keys` in a row under it. With `from` (a rect
// in screen px, the panel it belongs to) it opens over that rect and grows
// out of it, and shrinks back into it on close; the owner places the window
// at `growX`, `growY` (margins, anchored top left).
//
// With `skyGlass`, in Frutiger Aero (and no hardware) the pane is the
// era's sky glass (aero/Sky.qml) with only its lit dots on it, as glossy
// bubbles (DotSurface.bare), like the aero desktop panels. `eraFrame` does
// that and, in Tokyo Night and VFD, frames the dots as the era's device
// (PaneFrame.qml: a neon sign; a gunmetal unit).
//
// Escape closes it. Clicking outside closes it unless `grab` is false.
// Keyboard: on demand. The focus grab hands the pane the keyboard; Exclusive
// would also keep Hyprland from ever clearing the grab, so clicking outside
// would not close the pane (kept only by the polkit prompt, which has no grab).
PanelWindow {
    id: pane

    required property string name
    property int cols: 40
    property int rows: 20
    property bool grab: true
    property int keyboard: WlrKeyboardFocus.OnDemand
    // Set false for panes that show themselves (toasts, OSD).
    property bool managed: true
    property bool shown: managed && Ui.pane === name

    default property alias content: surface.content
    readonly property alias surface: surface
    // Above the dots, in screen px rather than dots (video, crisp images).
    property alias overlay: overlayLayer.data

    property var hardware: null
    property bool skyGlass: false
    property bool eraFrame: false
    // "aero", "tokyo", "vfd", "blueprint" or "" (plain). Blueprint: the
    // drafting paper (blueprint/Paper.qml) with only the lit dots on it.
    readonly property string frame: hardware ? "" : (Tokens.era === "aero" || Tokens.era === "blueprint" || Tokens.era === "vapor" || Tokens.era === "flap" || Tokens.era === "nixie" || Tokens.era === "nineties") && (skyGlass || eraFrame) ? Tokens.era : eraFrame && (Tokens.era === "tokyo" || Tokens.era === "vfd") ? Tokens.era : ""
    // Vaporwave: the pane is a Windows 95 window (vapor/Win.qml) named
    // `title`, its dots on a dark dot screen sunk into it, or, an `eraFrame`
    // pane without `skyGlass` (the message centre, the toasts), lit dots
    // only on a white sheet.
    property string title: name + ".exe"
    property string icon: ""
    readonly property bool vaporSheet: frame === "vapor" && !skyGlass
    // Split-Flap: the pane is a departure board's housing (flap/Housing.qml)
    // with `caption` and "● `captionStatus`" across its top; a `skyGlass`
    // pane (MEDIA) keeps its dot screen, an `eraFrame`-only one shows lit
    // square dots straight on the housing.
    property string caption: name.toUpperCase()
    property string captionStatus: ""
    readonly property bool flapSheet: frame === "flap" && !skyGlass
    // Nixie: the pane is the walnut case (nixie/Wood.qml); a `skyGlass` pane
    // (MEDIA) keeps its dot screen, ruled in brass, an `eraFrame`-only one
    // shows its lit dots straight on the wood (the message centre's ivory
    // cards, the toasts).
    readonly property bool nixieSheet: frame === "nixie" && !skyGlass
    // The title bar's height above the dots (Vaporwave).
    readonly property int head: frame === "vapor" || frame === "flap" ? 22 : 0
    readonly property bool sky: frame === "aero"
    // The key row under the display window (with `hardware`).
    property alias keys: keyRow.data
    property var from: null
    readonly property bool grows: !!from && from.width > 0
    readonly property int bezel: hardware ? hardware.bezel.l : sky ? 16 : frame === "vapor" ? 8 : frame === "flap" || frame === "nixie" ? 12 : frame === "nineties" ? 9 : frame ? 14 : 0
    readonly property int keysH: hardware && keyRow.children.length > 0 ? hardware.keys.h + hardware.keys.gap : 0
    // Where the window goes when it grows: from's corner, kept on screen
    // (margins under the strip, left of the side bar).
    readonly property int growX: grows ? Math.max(0, Math.min(from.x, (screen?.width ?? 1920) - sideW - implicitWidth)) : 0
    readonly property int growY: grows ? Math.max(0, Math.min(from.y - stripH, (screen?.height ?? 1080) - stripH - implicitHeight)) : 0
    // 0 = folded into `from`, 1 = open.
    property real grown: 0

    // Fires every time the pane appears; focus a TextInput here.
    signal opened
    // Keys the focused item did not take (Escape is handled already).
    signal keyPressed(var event)

    screen: Ui.screen
    // Kept up while it shrinks back into its panel.
    visible: shown || (grows && grown > 0.001)
    color: "transparent"
    // Sit below the strip's exclusive zone without reserving space of our own.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    implicitWidth: surface.implicitWidth + bezel * 2
    implicitHeight: surface.implicitHeight + bezel * 2 + head + keysH

    WlrLayershell.namespace: "dotshell-" + name
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? keyboard : WlrKeyboardFocus.None

    // Never wider or taller than the screen at the current pitch.
    // The side bar's columns are taken too when it reserves space (side on;
    // SideBar.qml's Tokens.railDots cols): the compositor already narrows the window.
    readonly property int sideW: Tokens.side === "on" ? Tokens.railDots * Tokens.pitch : 0
    readonly property int maxCols: screen ? Math.floor((screen.width - sideW - bezel * 2) / Tokens.pitch) : cols
    // The strip's rows are taken (the pane sits under it): its real height,
    // which TopStrip rounds to whole device px.
    readonly property int stripH: !Tokens.top ? 0 : Ui.strips.find(w => w.screen === screen)?.height ?? 11 * Tokens.pitch
    readonly property int maxRows: screen ? Math.floor((screen.height - stripH - bezel * 2 - head - keysH) / Tokens.pitch) : rows

    // What shows: all of it, or while growing the part inside a rect moving
    // from `from` out to the whole window, the faceplate drawn at that rect.
    readonly property rect origin: grows ? Qt.rect(from.x - growX, from.y - stripH - growY, from.width, from.height) : Qt.rect(0, 0, 0, 0)
    Item {
        id: reveal
        readonly property real t: pane.grows ? pane.grown : 1
        x: pane.origin.x * (1 - t)
        y: pane.origin.y * (1 - t)
        width: pane.origin.width + (pane.implicitWidth - pane.origin.width) * t
        height: pane.origin.height + (pane.implicitHeight - pane.origin.height) * t
        clip: pane.grows && t < 1

        Loader {
            anchors.fill: parent
            anchors.margins: 4
            active: pane.sky
            sourceComponent: Aero.Sky {
                radius: 28
                glossInset: 24
                glossHeight: Math.min(60, height * 0.2)
            }
        }
        Loader {
            anchors.fill: parent
            active: pane.frame === "blueprint"
            sourceComponent: Bp.Paper {}
        }
        Loader {
            anchors.fill: parent
            active: pane.frame === "vapor"
            sourceComponent: Item {
                Vw.Win {
                    anchors.fill: parent
                    icon: pane.icon
                    title: pane.title
                    controls: "close"
                    onClosed: if (pane.managed)
                        Ui.close()
                }
                // The sunken screen or sheet round the dots.
                Rectangle {
                    x: surface.x - 2
                    y: surface.y - 2
                    width: surface.width + 4
                    height: surface.height + 4
                    color: pane.vaporSheet ? Vw.Ink.hi : Vw.Ink.glass
                }
                Vw.Bevel {
                    x: surface.x - 2
                    y: surface.y - 2
                    width: surface.width + 4
                    height: surface.height + 4
                    line: 2
                    sunk: true
                }
            }
        }
        Loader {
            anchors.fill: parent
            active: pane.frame === "flap"
            sourceComponent: Fl.Housing {
                label: pane.caption
                status: pane.captionStatus
                screws: pane.skyGlass
                padX: pane.bezel + 2
            }
        }
        Loader {
            anchors.fill: parent
            active: pane.frame === "nixie"
            sourceComponent: Item {
                Nx.Wood {
                    anchors.fill: parent
                }
                // The screen's brass rule, just outside the dots.
                Rectangle {
                    visible: !pane.nixieSheet
                    x: pane.bezel - 2
                    y: pane.bezel + pane.head - 2
                    width: surface.width + 4
                    height: surface.height + 4
                    radius: 4
                    color: Nx.Ink.glass
                    border.width: 1
                    border.color: Nx.Ink.brass
                }
            }
        }
        // 90s Nights: the pane is an upright neon sign (nineties/Plate.qml),
        // its sunset rim round the dot glass, like the expanded panels.
        Loader {
            anchors.fill: parent
            active: pane.frame === "nineties"
            sourceComponent: Ni.Plate {
                slant: false
                radius: 4
                dots: false
            }
        }
        Loader {
            anchors.fill: parent
            active: pane.frame === "tokyo" || pane.frame === "vfd"
            sourceComponent: PaneFrame {
                kind: pane.frame
                win: Qt.rect(pane.bezel, pane.bezel, surface.width, surface.height)
            }
        }
        Loader {
            anchors.fill: parent
            active: !!pane.hardware
            sourceComponent: Faceplate {
                hw: pane.hardware
                win: Qt.rect(pane.bezel, pane.bezel, surface.width, surface.height)
            }
        }

        Item {
            x: -reveal.x
            y: -reveal.y
            width: pane.implicitWidth
            height: pane.implicitHeight
            opacity: pane.grows ? Math.min(1, reveal.t * 1.6) : 1

            DotSurface {
                id: surface
                x: pane.bezel
                y: pane.bezel + pane.head
                cols: Math.min(pane.cols, pane.maxCols)
                rows: Math.min(pane.rows, pane.maxRows)
                // A well rounded display window cuts the dots to its corners.
                shape: pane.hardware && typeof pane.hardware.window.radius === "number" && pane.hardware.window.radius >= 8 ? Hardware.windowPath(pane.hardware, cols, rows, Tokens.pitch) : pane.frame === "tokyo" ? Hardware.rounded(0, 0, cols, rows, 15 / Tokens.pitch) : pane.frame === "vfd" ? Hardware.rounded(0, 0, cols, rows, 4 / Tokens.pitch) : ""
                focus: true
                bare: pane.sky || pane.frame === "blueprint" || pane.vaporSheet || pane.flapSheet || pane.nixieSheet
                // Frosted: LEDs on blurred glass (Hyprland blurs dotshell-* panes).
                // With hardware: smoked glass, opaque.
                glassAlpha: Tokens.frosted && !pane.hardware && !pane.frame ? (Tokens.current.light ? 0.7 : 0.55) : 1

                // LED border: the outermost ring of dots, at the dim level, animated
                // by LedFx.
                LedRing {
                    z: -1
                    visible: Tokens.borders && !pane.hardware && !pane.frame
                    width: surface.cols
                    height: surface.rows
                    color: Tokens.slot1
                    gain: LedFx.on ? 0.8 : 0.6
                    offset: 0.25
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        if (pane.managed)
                            Ui.close();
                        event.accepted = true;
                    } else {
                        pane.keyPressed(event);
                    }
                }
            }

            Item {
                id: overlayLayer
                x: surface.x
                y: surface.y
                width: surface.width
                height: surface.height
            }
            Loader {
                anchors.fill: parent
                active: pane.frame === "vfd"
                sourceComponent: PaneFrame {
                    kind: pane.frame
                    over: true
                    win: Qt.rect(surface.x, surface.y, surface.width, surface.height)
                }
            }
            Loader {
                x: surface.x
                y: surface.y
                width: surface.width
                height: surface.height
                active: !!pane.hardware
                sourceComponent: WindowGlass {
                    hw: pane.hardware
                }
            }
            Item {
                id: keyRow
                x: pane.bezel
                y: pane.bezel + pane.head + surface.height + (pane.hardware?.keys.gap ?? 0)
                width: surface.width
                height: pane.hardware?.keys.h ?? 0
            }
        }
    }

    NumberAnimation {
        id: growAnim
        target: pane
        property: "grown"
        duration: 150
        easing.type: Easing.OutCubic
    }
    onShownChanged: {
        if (!grows) {
            grown = shown ? 1 : 0;
            return;
        }
        growAnim.to = shown ? 1 : 0;
        growAnim.duration = shown ? 150 : 120;
        // Opened again while still shrinking: the window never went away.
        if (shown && grown > 0.001) {
            focusGrab.active = grab && managed;
            surface.forceActiveFocus();
            opened();
        }
        growAnim.restart();
        if (!shown)
            focusGrab.active = false;
    }

    HyprlandFocusGrab {
        id: focusGrab
        windows: [pane, ...Ui.strips]
        onCleared: {
            if (pane.managed && Ui.pane === pane.name)
                Ui.close();
        }
    }

    onVisibleChanged: {
        if (grows)
            Ui.grown = visible ? name : Ui.grown === name ? "" : Ui.grown;
        else if (!visible && Ui.grown === name)
            Ui.grown = "";
        if (visible) {
            focusGrab.active = grab && managed;
            surface.forceActiveFocus();
            opened();
        } else {
            focusGrab.active = false;
        }
    }
}
