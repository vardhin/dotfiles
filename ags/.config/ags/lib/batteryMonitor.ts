// Battery monitor: lives inside AGS, watches AstalBattery, fires
// notifications and an emergency shutdown.
//
// Thresholds (spec'd by the user):
//   - charger plug/unplug → low-urgency toast
//   - 15% on battery     → normal warning
//   - 10% on battery     → critical warning
//   -  5% on battery     → 60s grace period, then `systemctl poweroff`
//
// Each threshold latches once per discharge cycle; latches re-arm when
// percentage rises above the threshold + a hysteresis margin OR when
// the charger is plugged in.

import GLib from "gi://GLib"
import AstalBattery from "gi://AstalBattery"
import { execAsync } from "ags/process"
import { notify } from "./notify"

const WARN_PCT     = 0.15  // 15%
const CRITICAL_PCT = 0.10  // 10%
const SHUTDOWN_PCT = 0.05  // 5%

// Re-arm thresholds (hysteresis): latch resets when percentage rises above
// these values. Avoids flicker if the reading wobbles around the threshold.
const REARM_WARN     = 0.20
const REARM_CRITICAL = 0.15
const REARM_SHUTDOWN = 0.08

// 60s grace period before emergency shutdown.
const SHUTDOWN_GRACE_MS = 60_000

const APP_NAME = "ags-battery"

interface MonitorState {
  warnLatched: boolean
  criticalLatched: boolean
  shutdownLatched: boolean
  shutdownTimerSource: number  // 0 = no timer pending
  // Track previous values so we only fire on actual transitions.
  previousState: AstalBattery.State | null
  previousCharging: boolean | null
  initialized: boolean
}

function isDischarging(s: AstalBattery.State): boolean {
  return s === AstalBattery.State.DISCHARGING
}

function cancelShutdown(state: MonitorState, reason: string) {
  if (state.shutdownTimerSource !== 0) {
    GLib.source_remove(state.shutdownTimerSource)
    state.shutdownTimerSource = 0
    notify({
      summary: "Shutdown cancelled",
      body: reason,
      urgency: "normal",
      appName: APP_NAME,
      icon: "battery-good-charging-symbolic",
      replaceTag: "ags-battery-shutdown",
      expireTime: 4000,
    })
  }
}

function scheduleShutdown(state: MonitorState, battery: AstalBattery.Device) {
  if (state.shutdownTimerSource !== 0) return  // already scheduled

  notify({
    summary: "Battery critically low",
    body: "Plug in now — shutting down in 60 seconds to protect the battery.",
    urgency: "critical",
    appName: APP_NAME,
    icon: "battery-empty-symbolic",
    replaceTag: "ags-battery-shutdown",
    expireTime: SHUTDOWN_GRACE_MS,
  })

  state.shutdownTimerSource = GLib.timeout_add(
    GLib.PRIORITY_DEFAULT,
    SHUTDOWN_GRACE_MS,
    () => {
      state.shutdownTimerSource = 0
      // Re-check at fire time: only proceed if still discharging and still
      // below shutdown threshold. (User may have plugged in during the
      // grace window — we also clear via cancelShutdown, but this is
      // belt-and-suspenders against missed signals.)
      if (
        isDischarging(battery.state)
        && battery.percentage <= SHUTDOWN_PCT
      ) {
        execAsync(["systemctl", "poweroff"]).catch((e) => {
          console.error("Battery shutdown failed:", e)
          notify({
            summary: "Shutdown failed",
            body: "Could not run systemctl poweroff. Save your work and shut down manually.",
            urgency: "critical",
            appName: APP_NAME,
            replaceTag: "ags-battery-shutdown",
          })
        })
      }
      return GLib.SOURCE_REMOVE
    },
  )
}

function checkThresholds(
  state: MonitorState,
  battery: AstalBattery.Device,
) {
  const pct = battery.percentage
  const discharging = isDischarging(battery.state)

  // Re-arm latches when we go above the rearm threshold. This way we get
  // exactly one notification per discharge crossing.
  if (pct > REARM_WARN)     state.warnLatched = false
  if (pct > REARM_CRITICAL) state.criticalLatched = false
  if (pct > REARM_SHUTDOWN) state.shutdownLatched = false

  // If we're not discharging, also clear any pending shutdown.
  if (!discharging) {
    cancelShutdown(state, "Charger connected.")
    return
  }

  // Fire each threshold once per cycle, lower → higher severity.
  if (pct <= SHUTDOWN_PCT && !state.shutdownLatched) {
    state.shutdownLatched = true
    state.criticalLatched = true
    state.warnLatched = true
    scheduleShutdown(state, battery)
    return
  }

  if (pct <= CRITICAL_PCT && !state.criticalLatched) {
    state.criticalLatched = true
    state.warnLatched = true
    notify({
      summary: "Battery critically low",
      body: `${Math.round(pct * 100)}% remaining. Plug in soon.`,
      urgency: "critical",
      appName: APP_NAME,
      icon: "battery-caution-symbolic",
      replaceTag: "ags-battery-low",
    })
    return
  }

  if (pct <= WARN_PCT && !state.warnLatched) {
    state.warnLatched = true
    notify({
      summary: "Battery low",
      body: `${Math.round(pct * 100)}% remaining. Consider plugging in.`,
      urgency: "normal",
      appName: APP_NAME,
      icon: "battery-low-symbolic",
      replaceTag: "ags-battery-low",
      expireTime: 8000,
    })
  }
}

function checkChargerEvents(
  state: MonitorState,
  battery: AstalBattery.Device,
) {
  const charging = battery.charging
  const isInitial = state.previousCharging === null

  if (isInitial) {
    state.previousCharging = charging
    return
  }

  if (charging === state.previousCharging) return  // no change
  state.previousCharging = charging

  if (charging) {
    notify({
      summary: "Charger connected",
      body: `Battery at ${Math.round(battery.percentage * 100)}%`,
      urgency: "low",
      appName: APP_NAME,
      icon: "battery-good-charging-symbolic",
      replaceTag: "ags-charger-state",
      expireTime: 3000,
    })
  } else {
    notify({
      summary: "Charger disconnected",
      body: `Running on battery — ${Math.round(battery.percentage * 100)}%`,
      urgency: "low",
      appName: APP_NAME,
      icon: "battery-good-symbolic",
      replaceTag: "ags-charger-state",
      expireTime: 3000,
    })
  }
}

export function startBatteryMonitor(): () => void {
  const battery = AstalBattery.get_default()
  if (!battery || !battery.isPresent) {
    return () => { /* no-op */ }
  }

  const state: MonitorState = {
    warnLatched: false,
    criticalLatched: false,
    shutdownLatched: false,
    shutdownTimerSource: 0,
    previousState: null,
    previousCharging: null,
    initialized: false,
  }

  // Prime the previous-charging value so we don't notify on startup.
  state.previousCharging = battery.charging
  state.previousState = battery.state
  state.initialized = true

  // If we boot at low battery already discharging, latch the appropriate
  // levels so we don't immediately re-fire on the first tick. The user
  // will already know — they're looking at the screen.
  const startPct = battery.percentage
  if (isDischarging(battery.state)) {
    if (startPct <= WARN_PCT)     state.warnLatched = true
    if (startPct <= CRITICAL_PCT) state.criticalLatched = true
    // Don't latch shutdown — if we boot at <=5% discharging, we DO want
    // to fire the grace-then-shutdown to protect the battery.
  }

  const onChange = () => {
    if (!state.initialized) return
    checkChargerEvents(state, battery)
    checkThresholds(state, battery)
  }

  const handlerIds = [
    battery.connect("notify::percentage", onChange),
    battery.connect("notify::state", onChange),
    battery.connect("notify::charging", onChange),
  ]

  return () => {
    for (const id of handlerIds) battery.disconnect(id)
    if (state.shutdownTimerSource !== 0) {
      GLib.source_remove(state.shutdownTimerSource)
      state.shutdownTimerSource = 0
    }
  }
}
