import app from "ags/gtk4/app"
import GLib from "gi://GLib"
import Astal from "gi://Astal?version=4.0"
import Gtk from "gi://Gtk?version=4.0"
import Gdk from "gi://Gdk?version=4.0"
import AstalWp from "gi://AstalWp"
import { onCleanup } from "ags"

// ━━━━━━━━━━━━━━ ON-SCREEN DISPLAY (Volume + Brightness) ━━━━━━━━━━━━━━

export function OSD({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
  const wp = AstalWp.get_default()!
  const speaker = wp.defaultSpeaker

  let win: Astal.Window | null = null
  let hideTimeout: ReturnType<typeof setTimeout> | null = null
  let osdIcon: Gtk.Image | null = null
  let osdLevel: Gtk.LevelBar | null = null
  let osdPercent: Gtk.Label | null = null
  let osdLabel: Gtk.Label | null = null
  const { BOTTOM } = Astal.WindowAnchor

  // Track last brightness so we can detect changes
  let lastBrightness = -1
  let brightnessCheckInterval: ReturnType<typeof setInterval> | null = null

  const readBrightness = (): number => {
    const paths = [
      "/sys/class/backlight/intel_backlight",
      "/sys/class/backlight/amdgpu_bl0",
      "/sys/class/backlight/amdgpu_bl1",
      "/sys/class/backlight/acpi_video0",
    ]
    for (const base of paths) {
      try {
        const cur = Number(String.fromCharCode(...GLib.file_get_contents(`${base}/brightness`)[1]).trim())
        const max = Number(String.fromCharCode(...GLib.file_get_contents(`${base}/max_brightness`)[1]).trim())
        if (max > 0) return cur / max
      } catch { /* skip */ }
    }
    return -1
  }

  onCleanup(() => {
    if (hideTimeout) clearTimeout(hideTimeout)
    if (brightnessCheckInterval) clearInterval(brightnessCheckInterval)
    win?.destroy()
  })

  const showOSD = (type: "volume" | "brightness") => {
    if (!win || !osdIcon || !osdLevel || !osdPercent || !osdLabel) return

    if (type === "volume") {
      const v = speaker.volume
      const muted = speaker.mute
      if (muted) {
        osdIcon.iconName = "audio-volume-muted-symbolic"
      } else if (v <= 0) {
        osdIcon.iconName = "audio-volume-muted-symbolic"
      } else if (v < 0.33) {
        osdIcon.iconName = "audio-volume-low-symbolic"
      } else if (v < 0.66) {
        osdIcon.iconName = "audio-volume-medium-symbolic"
      } else {
        osdIcon.iconName = "audio-volume-high-symbolic"
      }
      osdLevel.value = muted ? 0 : v
      osdPercent.label = muted ? "Muted" : `${Math.round(v * 100)}%`
      osdLabel.label = "Volume"
    } else {
      const b = readBrightness()
      if (b < 0) return
      if (b < 0.33) {
        osdIcon.iconName = "display-brightness-low-symbolic"
      } else if (b < 0.66) {
        osdIcon.iconName = "display-brightness-medium-symbolic"
      } else {
        osdIcon.iconName = "display-brightness-symbolic"
      }
      osdLevel.value = b
      osdPercent.label = `${Math.round(b * 100)}%`
      osdLabel.label = "Brightness"
    }

    win.visible = true
    if (hideTimeout) clearTimeout(hideTimeout)
    hideTimeout = setTimeout(() => {
      if (win) win.visible = false
    }, 1800)
  }

  return (
    <window
      $={(self) => {
        win = self
        // Volume signals
        speaker.connect("notify::volume", () => showOSD("volume"))
        speaker.connect("notify::mute", () => showOSD("volume"))

        // Poll brightness for changes (sysfs doesn't have inotify-friendly signals)
        lastBrightness = readBrightness()
        brightnessCheckInterval = setInterval(() => {
          const b = readBrightness()
          if (b >= 0 && Math.abs(b - lastBrightness) > 0.005) {
            lastBrightness = b
            showOSD("brightness")
          }
        }, 200)
      }}
      visible={false}
      namespace="ags-osd"
      name={`osd-${gdkmonitor.connector}`}
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.NORMAL}
      anchor={BOTTOM}
      application={app}
    >
      <box class="osd" spacing={12} halign={Gtk.Align.CENTER}>
        <image
          $={(self) => { osdIcon = self }}
          iconName="audio-volume-high-symbolic"
          pixelSize={28}
          class="osd-icon"
        />
        <box orientation={Gtk.Orientation.VERTICAL} valign={Gtk.Align.CENTER} hexpand spacing={4}>
          <label
            $={(self) => { osdLabel = self }}
            class="osd-label"
            label="Volume"
            xalign={0}
          />
          <levelbar
            $={(self) => { osdLevel = self }}
            class="osd-level"
            widthRequest={220}
            value={0.5}
            maxValue={1}
          />
        </box>
        <label
          $={(self) => { osdPercent = self }}
          class="osd-percent"
          label="50%"
        />
      </box>
    </window>
  )
}
