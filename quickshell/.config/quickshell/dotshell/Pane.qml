import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.services

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

    // Fires every time the pane appears; focus a TextInput here.
    signal opened
    // Keys the focused item did not take (Escape is handled already).
    signal keyPressed(var event)

    screen: Ui.screen
    visible: shown
    color: "transparent"
    // Sit below the strip's exclusive zone without reserving space of our own.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    implicitWidth: surface.implicitWidth
    implicitHeight: surface.implicitHeight

    WlrLayershell.namespace: "dotshell-" + name
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? keyboard : WlrKeyboardFocus.None

    // Never wider or taller than the screen at the current pitch.
    // The side bar's columns are taken too when it reserves space (side on;
    // SideBar.qml's Tokens.railDots cols): the compositor already narrows the window.
    readonly property int sideW: Tokens.side === "on" ? Tokens.railDots * Tokens.pitch : 0
    readonly property int maxCols: screen ? Math.floor((screen.width - sideW) / Tokens.pitch) : cols
    // The strip's rows are taken (the pane sits under it): its real height,
    // which TopStrip rounds to whole device px.
    readonly property int stripH: !Tokens.top ? 0 : Ui.strips.find(w => w.screen === screen)?.height ?? 11 * Tokens.pitch
    readonly property int maxRows: screen ? Math.floor((screen.height - stripH) / Tokens.pitch) : rows

    DotSurface {
        id: surface
        cols: Math.min(pane.cols, pane.maxCols)
        rows: Math.min(pane.rows, pane.maxRows)
        focus: true
        // Frosted: LEDs on blurred glass (Hyprland blurs dotshell-* panes).
        glassAlpha: Tokens.frosted ? (Tokens.current.light ? 0.7 : 0.55) : 1

        // LED border: the outermost ring of dots, at the dim level, animated
        // by LedFx.
        LedRing {
            z: -1
            visible: Tokens.borders
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
        anchors.fill: surface
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
        if (visible) {
            focusGrab.active = grab && managed;
            surface.forceActiveFocus();
            opened();
        } else {
            focusGrab.active = false;
        }
    }
}
