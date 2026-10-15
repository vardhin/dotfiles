pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

// Lock state and the password check. LockScreen.qml draws it; anything that
// wants the screen locked calls Lock.lock() (Super L, idle, logind, sleep).
//
// PAM uses pam/dotshell next to shell.qml (pam_unix only), so a lock screen
// typo never trips pam_faillock for the real login.
Singleton {
    id: root

    property bool locked: false
    property bool secure: false      // set by the lock surface once every screen is covered

    property string buffer: ""
    property string status: ""       // shown under the field: CHECKING, WRONG, PAM errors
    property int attempts: 0
    readonly property bool busy: pam.active

    function lock(): void {
        if (locked)
            return;
        buffer = "";
        status = "";
        attempts = 0;
        locked = true;
    }

    function submit(): void {
        if (pam.active || buffer === "")
            return;
        status = "CHECKING";
        pam.start();
    }

    PamContext {
        id: pam
        configDirectory: "../pam"
        config: "dotshell"

        onPamMessage: {
            if (responseRequired) {
                respond(root.buffer);
            } else if (message !== "") {
                root.status = message.toUpperCase();
            }
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                root.status = "";
                root.buffer = "";
                root.attempts = 0;
                root.locked = false;
            } else {
                root.attempts += 1;
                root.buffer = "";
                root.status = result === PamResult.MaxTries ? "TOO MANY TRIES" : "WRONG";
            }
        }

        onError: err => root.status = "PAM ERROR " + err
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lock();
        }
        function isLocked(): bool {
            return root.locked;
        }
    }
}
