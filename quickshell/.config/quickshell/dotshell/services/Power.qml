pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Battery, power profile and the battery monitor.
//
// Monitor thresholds (carried over from AGS):
//   charger plug / unplug  low-urgency toast
//   15 % on battery        warning
//   10 % on battery        critical warning
//    5 % on battery        60 s grace, then systemctl poweroff
// Each threshold fires once per discharge and re-arms above 20 / 15 / 8 %
// or when the charger is plugged in.
Singleton {
    id: root

    readonly property UPowerDevice battery: UPower.displayDevice
    readonly property bool present: battery.ready && battery.isLaptopBattery
    // Quickshell reports 0..1; tolerate 0..100 in case that ever changes.
    readonly property real fraction: battery.percentage > 1 ? battery.percentage / 100 : battery.percentage
    readonly property int percent: Math.round(fraction * 100)
    readonly property int batteryState: battery.state
    readonly property bool charging: batteryState === UPowerDeviceState.Charging || batteryState === UPowerDeviceState.PendingCharge
    readonly property bool full: batteryState === UPowerDeviceState.FullyCharged
    readonly property bool discharging: batteryState === UPowerDeviceState.Discharging || (UPower.onBattery && !charging)
    readonly property real watts: Math.abs(battery.changeRate)
    readonly property real health: battery.healthSupported ? battery.healthPercentage : -1

    readonly property string stateText: full ? "FULL" : charging ? "CHARGING" : discharging ? "ON BATTERY" : "IDLE"
    readonly property string timeText: {
        const s = charging ? battery.timeToFull : discharging ? battery.timeToEmpty : 0;
        if (!s || s <= 0)
            return full ? "" : "ESTIMATING";
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        const t = h > 0 ? `${h}H ${m}M` : `${m}M`;
        return charging ? `FULL IN ${t}` : `${t} LEFT`;
    }

    // PowerProfile: PowerSaver, Balanced, Performance.
    readonly property int profile: PowerProfiles.profile
    readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile
    function setProfile(p: int): void {
        PowerProfiles.profile = p;
    }
    function profileName(p: int): string {
        return p === PowerProfile.PowerSaver ? "SAVER" : p === PowerProfile.Performance ? "PERFORMANCE" : "BALANCED";
    }

    // ── Monitor ─────────────────────────────────────────────────────
    readonly property real warnAt: 0.15
    readonly property real criticalAt: 0.10
    readonly property real shutdownAt: 0.05

    property bool warnLatched: false
    property bool criticalLatched: false
    property bool shutdownLatched: false
    property bool armed: false
    property bool lastCharging: false

    // Wait for UPower to report real values before judging anything, and
    // don't re-warn about a level that was already low at login.
    Timer {
        running: root.present && !root.armed
        interval: 2000
        onTriggered: {
            root.lastCharging = root.charging;
            if (root.discharging) {
                root.warnLatched = root.fraction <= root.warnAt;
                root.criticalLatched = root.fraction <= root.criticalAt;
                // Shutdown is deliberately not latched: booting at 5 % still protects the cell.
            }
            root.armed = true;
            root.check();
        }
    }

    onFractionChanged: check()
    onBatteryStateChanged: check()

    function check(): void {
        if (!armed)
            return;

        if (charging !== lastCharging) {
            lastCharging = charging;
            Notify.send(charging ? "Charger connected" : "Charger disconnected", `Battery at ${percent}%`, {
                app: "dotshell-battery",
                urgency: "low",
                expire: 3000,
                tag: "dotshell-charger",
                transient: true
            });
        }

        if (fraction > 0.20)
            warnLatched = false;
        if (fraction > 0.15)
            criticalLatched = false;
        if (fraction > 0.08)
            shutdownLatched = false;

        if (!discharging) {
            cancelShutdown("Charger connected.");
            return;
        }

        if (fraction <= shutdownAt && !shutdownLatched) {
            shutdownLatched = criticalLatched = warnLatched = true;
            Notify.send("Battery critically low", "Plug in now. Shutting down in 60 seconds to protect the battery.", {
                app: "dotshell-battery",
                urgency: "critical",
                tag: "dotshell-shutdown"
            });
            shutdownTimer.restart();
        } else if (fraction <= criticalAt && !criticalLatched) {
            criticalLatched = warnLatched = true;
            Notify.send("Battery critically low", `${percent}% remaining. Plug in soon.`, {
                app: "dotshell-battery",
                urgency: "critical",
                tag: "dotshell-low"
            });
        } else if (fraction <= warnAt && !warnLatched) {
            warnLatched = true;
            Notify.send("Battery low", `${percent}% remaining. Consider plugging in.`, {
                app: "dotshell-battery",
                urgency: "normal",
                expire: 8000,
                tag: "dotshell-low"
            });
        }
    }

    function cancelShutdown(reason: string): void {
        if (!shutdownTimer.running)
            return;
        shutdownTimer.stop();
        Notify.send("Shutdown cancelled", reason, {
            app: "dotshell-battery",
            expire: 4000,
            tag: "dotshell-shutdown"
        });
    }

    Timer {
        id: shutdownTimer
        interval: 60000
        onTriggered: {
            // Re-check at fire time in case a signal was missed.
            if (root.discharging && root.fraction <= root.shutdownAt)
                Quickshell.execDetached(["systemctl", "poweroff"]);
        }
    }
}
