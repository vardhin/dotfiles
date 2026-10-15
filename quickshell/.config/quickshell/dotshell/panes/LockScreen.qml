import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services

// Lock wall: every screen becomes one LED panel. The wallpaper glows faintly
// through the dots; the clock, date and password line sit on top.
// Typing goes straight to the password (no field to click). Enter checks it,
// Escape clears it.
Scope {
    id: root

    WlSessionLock {
        id: lock
        locked: Lock.locked
        onSecureChanged: Lock.secure = secure
        onLockedChanged: {
            if (!locked)
                Lock.secure = false;
        }

        WlSessionLockSurface {
            id: surface
            color: Tokens.glass

            readonly property int cols: Math.floor(width / Tokens.pitch)
            readonly property int rows: Math.floor(height / Tokens.pitch)

            DotSurface {
                anchors.centerIn: parent
                cols: surface.cols
                rows: surface.rows
                // Map everything onto the era ramp: the wallpaper lands on the
                // dim levels, white text on the brightest.
                imageMode: true
                focus: true

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        Lock.submit();
                    } else if (event.key === Qt.Key_Backspace) {
                        if (!Lock.busy)
                            Lock.buffer = (event.modifiers & Qt.ControlModifier) ? "" : Lock.buffer.slice(0, -1);
                    } else if (event.key === Qt.Key_Escape) {
                        if (!Lock.busy)
                            Lock.buffer = "";
                    } else if (event.text && event.text.length === 1 && event.text >= " " && !Lock.busy) {
                        Lock.buffer += event.text;
                        Lock.status = "";
                    }
                    event.accepted = true;
                }

                // Black backing so the faint wallpaper lands on the dim ramp levels.
                Rectangle {
                    width: surface.cols
                    height: surface.rows
                    color: "black"
                }

                Image {
                    width: surface.cols
                    height: surface.rows
                    source: Tokens.wallpaper ? "file://" + Tokens.wallpaper : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(surface.cols * 2, surface.rows * 2)
                    asynchronous: true
                    smooth: true
                    opacity: 0.35
                }

                SystemClock {
                    id: clock
                    precision: SystemClock.Seconds
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 6

                    // Clock at 3x: 21 x 33 dots per digit.
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(clock.date, clock.seconds % 2 ? "hh mm" : "hh:mm")
                        font.family: Tokens.font
                        font.pixelSize: Tokens.fontPx * 3
                        renderType: Text.NativeRendering
                        antialiasing: false
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

                    DotText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: Tokens.lineDots
                        text: "HELLO " + (Quickshell.env("USER") || "").toUpperCase()
                        color: "#c8c8c8"
                    }

                    // Password: one block per character, blinking caret.
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 30 * Tokens.charDots
                        height: Tokens.lineDots

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
                                model: Math.min(Lock.buffer.length, 28)
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
                                visible: caret.lit && !Lock.busy
                                Timer {
                                    id: caret
                                    property bool lit: true
                                    running: Lock.locked
                                    interval: 530
                                    repeat: true
                                    onTriggered: lit = !lit
                                }
                            }
                        }
                    }

                    DotText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: Tokens.lineDots
                        text: Lock.status !== "" ? Lock.status + (Lock.attempts > 1 ? ` (${Lock.attempts})` : "") : root.capsLock ? "CAPS LOCK" : ""
                        color: "white"
                    }
                }
            }
        }
    }

    // Caps Lock LED, polled only while locked.
    property bool capsLock: false
    Process {
        id: caps
        command: ["sh", "-c", "cat /sys/class/leds/input*::capslock/brightness 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.capsLock = /[1-9]/.test(text)
        }
    }
    Timer {
        running: Lock.locked
        interval: 500
        repeat: true
        triggeredOnStart: true
        onTriggered: caps.running = true
    }
}
