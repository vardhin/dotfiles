// Dot Shell greeter: the login screen, run by greetd in a bare Hyprland
// (system/greetd/). It looks like the lock screen: every screen one LED
// panel, the wallpaper faint behind the dots, the clock, the user and the
// password line on top, all in the era on screen when the user last left.
//
// It runs as the `greeter` user, which cannot read ~, so system/install.sh
// copies this folder to /usr/local/share/dotshell, and Dot Shell's Export
// keeps /var/lib/dotshell-greeter/dotshell up to date: tokens.json (era,
// display tokens), the wallpaper and the user name. The greeter points
// XDG_STATE_HOME there, so Tokens reads that tokens.json as its own.
//
// Keys: type the password, Enter logs in. Tab edits the user name.
// Escape clears. F11 reboots, F12 powers off.
//
//   qs -p /usr/local/share/dotshell/greeter.qml        (greetd starts it)
// Lower-case file name: not a type in the `qs` module, so the desktop shell
// (shell.qml) never sees it.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd
import qs

ShellRoot {
    id: root

    readonly property string stateDir: Tokens.dir
    // The session to start: Hyprland under its watchdog, as from a TTY.
    readonly property var session: (Quickshell.env("DOTSHELL_SESSION") || "start-hyprland").split(" ")

    property string user: ""
    property string buffer: ""
    property string status: ""
    property int attempts: 0
    property bool editingUser: false
    // The password waiting for greetd to ask for it.
    property string pending: ""
    readonly property bool busy: Greetd.state !== GreetdState.Inactive

    FileView {
        path: root.stateDir + "/user"
        onLoaded: {
            if (root.user === "")
                root.user = text().trim();
            if (root.user === "")
                root.editingUser = true;
        }
        onLoadFailed: root.editingUser = true
    }

    function submit(): void {
        if (busy)
            return;
        if (editingUser) {
            editingUser = user === "";
            return;
        }
        status = "CHECKING";
        pending = buffer;
        Greetd.createSession(user);
    }

    Connections {
        target: Greetd

        function onAuthMessage(message: string, error: bool, responseRequired: bool, echoResponse: bool): void {
            if (responseRequired) {
                Greetd.respond(root.pending);
                root.pending = "";
            } else if (error) {
                root.status = message.toUpperCase();
            }
        }
        function onReadyToLaunch(): void {
            root.status = "WELCOME";
            Greetd.launch(root.session, ["XDG_SESSION_TYPE=wayland"], true);
        }
        function onAuthFailure(message: string): void {
            root.attempts++;
            root.buffer = "";
            root.pending = "";
            root.status = "WRONG PASSWORD";
        }
        function onError(error: string): void {
            root.buffer = "";
            root.pending = "";
            root.status = error.toUpperCase();
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property ShellScreen modelData
            screen: modelData
            // One screen takes the keyboard; the rest only show.
            readonly property bool main: modelData === Quickshell.screens[0]

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: Tokens.glass
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "dotshell-greeter"
            WlrLayershell.keyboardFocus: main ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            readonly property int cols: Math.floor(width / Tokens.pitch)
            readonly property int rows: Math.floor(height / Tokens.pitch)

            DotSurface {
                anchors.centerIn: parent
                cols: win.cols
                rows: win.rows
                // Everything onto the era ramp: the wallpaper lands on the dim
                // levels, white text on the brightest.
                imageMode: true
                focus: win.main

                Keys.onPressed: event => {
                    const k = event.key;
                    if (k === Qt.Key_F12) {
                        Quickshell.execDetached(["systemctl", "poweroff"]);
                    } else if (k === Qt.Key_F11) {
                        Quickshell.execDetached(["systemctl", "reboot"]);
                    } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                        root.submit();
                    } else if (k === Qt.Key_Tab || k === Qt.Key_Backtab) {
                        if (!root.busy)
                            root.editingUser = !root.editingUser || root.user === "";
                    } else if (k === Qt.Key_Escape) {
                        if (!root.busy) {
                            root.buffer = "";
                            root.status = "";
                        }
                    } else if (k === Qt.Key_Backspace && !root.busy) {
                        const all = event.modifiers & Qt.ControlModifier;
                        if (root.editingUser)
                            root.user = all ? "" : root.user.slice(0, -1);
                        else
                            root.buffer = all ? "" : root.buffer.slice(0, -1);
                    } else if (event.text && event.text.length === 1 && event.text >= " " && !root.busy) {
                        if (root.editingUser) {
                            if (/[a-z0-9_.-]/i.test(event.text))
                                root.user += event.text;
                        } else {
                            root.buffer += event.text;
                        }
                        root.status = "";
                    }
                    event.accepted = true;
                }

                // Black backing so the faint wallpaper lands on the dim ramp levels.
                Rectangle {
                    width: win.cols
                    height: win.rows
                    color: "black"
                }

                Image {
                    width: win.cols
                    height: win.rows
                    source: Tokens.wallpaper ? "file://" + Tokens.wallpaper : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(win.cols * 2, win.rows * 2)
                    asynchronous: true
                    smooth: true
                    opacity: 0.35
                }

                SystemClock {
                    id: clock
                    precision: SystemClock.Seconds
                }

                // A darker plate under the text, so it reads on any wallpaper.
                Rectangle {
                    anchors.centerIn: block
                    width: block.width + 24
                    height: block.height + 16
                    color: "black"
                    opacity: 0.7
                }

                Column {
                    id: block
                    anchors.centerIn: parent
                    spacing: 6

                    // Clock at 3x: 21 x 33 dots per digit.
                    DotText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        size: 3
                        height: implicitHeight
                        text: Qt.formatDateTime(clock.date, clock.seconds % 2 ? "hh mm" : "hh:mm")
                        color: "white"
                    }

                    DotText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: Tokens.lineDots
                        text: Qt.formatDateTime(clock.date, "dddd dd MMMM yyyy").toUpperCase()
                        color: "white"
                    }

                    Item {
                        width: 1
                        height: 10
                    }

                    // The user: a greeting, or the name being typed.
                    DotText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: Tokens.lineDots
                        text: root.editingUser ? "USER " + root.user.toUpperCase() + (caret.lit ? "_" : " ") : "HELLO " + root.user.toUpperCase()
                        color: root.editingUser ? "white" : "#c8c8c8"
                    }

                    // Password: one block per character, blinking caret.
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 30 * Tokens.charDots
                        height: Tokens.lineDots
                        opacity: root.editingUser ? 0.4 : 1

                        Rectangle {
                            y: parent.height - 1
                            width: parent.width
                            height: 1
                            color: "#909090"
                        }
                        Row {
                            anchors.centerIn: parent
                            spacing: 2
                            Repeater {
                                model: Math.min(root.buffer.length, 28)
                                Rectangle {
                                    width: 5
                                    height: 5
                                    color: "white"
                                }
                            }
                            Rectangle {
                                width: 5
                                height: 7
                                color: "white"
                                visible: caret.lit && !root.busy && !root.editingUser
                            }
                        }
                    }

                    DotText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: Tokens.lineDots
                        text: root.status !== "" ? root.status + (root.attempts > 1 && root.status === "WRONG PASSWORD" ? ` (${root.attempts})` : "") : ""
                        color: "white"
                    }
                }

                DotText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: win.rows - Tokens.lineDots - 4
                    height: Tokens.lineDots
                    text: "ENTER LOG IN   TAB USER   F11 REBOOT   F12 POWER OFF"
                    color: "#909090"
                }
            }
        }
    }

    Timer {
        id: caret
        property bool lit: true
        running: true
        interval: 530
        repeat: true
        onTriggered: lit = !lit
    }
}
