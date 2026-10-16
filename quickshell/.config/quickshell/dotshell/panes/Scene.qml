import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import "Scenes.js" as Scenes

// The era's scene: the whole screen becomes the era's own dot board and
// plays its signature piece (panes/Scenes.js): a terminal typing in
// Phosphor, rain over the city in Tokyo Night, green rain in Matrix, Life on
// the Game Boy, a split-flap board, a radar, invaders...
//
// Plays after a minute idle (the `scene` token), before the screen dims at
// five; any key or a real mouse move ends it. Super Shift S plays it now.
// Caffeine holds it off like the rest of idle.
//
//   dotshell ipc call scene toggle | show | hide | get
Scope {
    id: root

    property bool shown: false
    // Opened by hand: the overlay takes the keyboard so a key ends it.
    property bool manual: false
    readonly property string era: Tokens.current.id ?? Tokens.era

    function show(byHand: bool): void {
        manual = byHand;
        shown = true;
    }
    function hide(): void {
        shown = false;
        manual = false;
    }

    IdleMonitor {
        enabled: Tokens.scene && !Idle.caffeine
        timeout: 60
        onIsIdleChanged: {
            if (isIdle && !root.shown)
                root.show(false);
            else if (!isIdle && !root.manual)
                root.hide();
        }
    }

    // The lock wall replaces the scene.
    Connections {
        target: Lock
        function onLockedChanged() {
            if (Lock.locked)
                root.hide();
        }
    }

    Variants {
        model: root.shown ? Quickshell.screens : []

        PanelWindow {
            id: win

            required property ShellScreen modelData
            screen: modelData

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: Tokens.glass

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "dotshell-scene"
            WlrLayershell.keyboardFocus: root.manual ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            readonly property int cols: Math.ceil(width / Tokens.pitch)
            readonly property int rows: Math.ceil(height / Tokens.pitch)

            // The board's state is made again whenever its size or era changes.
            property var sceneState: null
            function remake(): void {
                sceneState = cols > 0 && rows > 0 ? Scenes.make(root.era, cols, rows) : null;
            }
            onColsChanged: remake()
            onRowsChanged: remake()
            Connections {
                target: root
                function onEraChanged() {
                    win.remake();
                }
            }
            Component.onCompleted: remake()

            readonly property var pal: ({
                    s0: String(Tokens.slot0),
                    s1: String(Tokens.slot1),
                    s2: String(Tokens.slot2)
                })

            DotSurface {
                id: board
                anchors.fill: parent
                cols: win.cols
                rows: win.rows
                focus: true

                Keys.onPressed: event => {
                    root.hide();
                    event.accepted = true;
                }

                Canvas {
                    id: canvas
                    width: win.cols
                    height: win.rows
                    // One pixel per dot: no smoothing between them.
                    antialiasing: false
                    renderStrategy: Canvas.Cooperative
                    property real last: 0

                    onPaint: {
                        if (!win.sceneState)
                            return;
                        const ctx = getContext("2d");
                        const now = Date.now();
                        const dt = last ? (now - last) / 1000 : 0;
                        last = now;
                        Scenes.draw(win.sceneState, ctx, dt, win.pal, new Date(now));
                    }
                }

                // The scene's name, bottom left, lit for a few seconds.
                Text {
                    x: 3
                    y: win.rows - Tokens.lineDots - 2
                    text: Scenes.title(root.era)
                    color: Tokens.slot1
                    font.family: Tokens.font
                    font.pixelSize: Tokens.fontPx
                    opacity: 0
                    SequentialAnimation on opacity {
                        running: root.shown
                        NumberAnimation {
                            to: 1
                            duration: 300
                        }
                        PauseAnimation {
                            duration: 3500
                        }
                        NumberAnimation {
                            to: 0
                            duration: 600
                        }
                    }
                }
            }

            // ~25 fps is plenty for a dot board.
            Timer {
                running: root.shown
                interval: 40
                repeat: true
                onTriggered: canvas.requestPaint()
            }

            // A real move ends it (a nudge of the desk does not).
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                property point from: Qt.point(-1, -1)
                onPositionChanged: mouse => {
                    if (from.x < 0) {
                        from = Qt.point(mouse.x, mouse.y);
                        return;
                    }
                    if (Math.abs(mouse.x - from.x) + Math.abs(mouse.y - from.y) > 24)
                        root.hide();
                }
                onPressed: root.hide()
                onWheel: root.hide()
            }
        }
    }

    IpcHandler {
        target: "scene"

        function toggle(): string {
            if (root.shown)
                root.hide();
            else
                root.show(true);
            return root.shown ? "on" : "off";
        }
        function show(): string {
            root.show(true);
            return Scenes.title(root.era);
        }
        function hide(): void {
            root.hide();
        }
        function get(): string {
            return (root.shown ? "on " : "off ") + Scenes.title(root.era);
        }
    }
}
