import app from "ags/gtk4/app"
import { createBinding, For, This } from "ags"
import style from "./style.scss"
import Bar, {
  BatteryPopover,
  BluetoothPopover,
  BrightnessPopover,
  ClockPopover,
  MediaPopover,
  VolumePopover,
  WifiPopover,
} from "./widget/Bar"
import { NotificationPopups, NotificationCenter } from "./widget/Notifications"
import { OSD } from "./widget/OSD"
import { AppLauncher } from "./widget/AppLauncher"
import { SessionMenu } from "./widget/Session"
import { DesktopWidgets } from "./widget/DesktopWidgets"
import { ThemeSwitcher, applyGeneratedThemeCSS } from "./widget/ThemeSwitcher"
import { startBatteryMonitor } from "./lib/batteryMonitor"
import GLib from "gi://GLib"
import Gtk from "gi://Gtk?version=4.0"
import Gdk from "gi://Gdk?version=4.0"

const THEMES_DIR = `${GLib.get_home_dir()}/.config/ags/themes`

// Load and apply the saved theme CSS on startup
function loadSavedThemePreset(): unknown | null {
  try {
    const currentFile = `${THEMES_DIR}/current.json`
    const [ok, bytes] = GLib.file_get_contents(currentFile)
    if (!ok) return null
    return JSON.parse(new TextDecoder().decode(bytes))
  } catch {
    return null
  }
}

app.start({
  css: style,
  main() {
    const monitors = createBinding(app, "monitors")
    const currentThemeFile = `${THEMES_DIR}/current.json`
    let lastThemeSignature = ""

    const display = Gdk.Display.get_default()
    if (display) {
      const iconTheme = Gtk.IconTheme.get_for_display(display)
      iconTheme.add_search_path(`${GLib.get_home_dir()}/.config/ags/assets/icons`)
    }

    // Battery monitor: charger events + low-power warnings + 5% emergency shutdown.
    startBatteryMonitor()

    // Apply saved theme override CSS on top of base stylesheet
    const savedPreset = loadSavedThemePreset()
    if (savedPreset) {
      applyGeneratedThemeCSS(savedPreset as any)
      try {
        const preset = savedPreset as { id?: string; wallpaper?: string }
        lastThemeSignature = `${preset.id ?? ""}|${preset.wallpaper ?? ""}`
      } catch {
        lastThemeSignature = ""
      }
    }

    // Keep AGS colors in sync with current.json even if a UI callback path fails.
    GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 1, () => {
      try {
        const [ok, bytes] = GLib.file_get_contents(currentThemeFile)
        if (!ok) return GLib.SOURCE_CONTINUE
        const preset = JSON.parse(new TextDecoder().decode(bytes)) as {
          id?: string
          wallpaper?: string
        }
        const signature = `${preset.id ?? ""}|${preset.wallpaper ?? ""}`
        if (signature !== lastThemeSignature) {
          lastThemeSignature = signature
          applyGeneratedThemeCSS(preset as any)
        }
      } catch {
        // ignore parse/read errors and continue polling
      }
      return GLib.SOURCE_CONTINUE
    })

    return (
      <For each={monitors}>
        {(monitor) => {
          // Only create singletons if they don't already exist
          const needsLauncher = !app.get_window("applauncher")
          const needsSession = !app.get_window("session")
          const needsNotifCenter = !app.get_window("notification-center")
          const needsWidgets = !app.get_window("desktop-widgets")
          const needsThemeSwitcher = !app.get_window("theme-switcher")

          return (
            <This this={app}>
              <Bar gdkmonitor={monitor} />
              <ClockPopover gdkmonitor={monitor} />
              <MediaPopover gdkmonitor={monitor} />
              <VolumePopover gdkmonitor={monitor} />
              <BrightnessPopover gdkmonitor={monitor} />
              <WifiPopover gdkmonitor={monitor} />
              <BluetoothPopover gdkmonitor={monitor} />
              <BatteryPopover gdkmonitor={monitor} />
              <NotificationPopups gdkmonitor={monitor} />
              <OSD gdkmonitor={monitor} />
              {needsLauncher && <AppLauncher gdkmonitor={monitor} />}
              {needsSession && <SessionMenu gdkmonitor={monitor} />}
              {needsNotifCenter && <NotificationCenter gdkmonitor={monitor} />}
              {needsWidgets && <DesktopWidgets gdkmonitor={monitor} />}
              {needsThemeSwitcher && <ThemeSwitcher gdkmonitor={monitor} />}
            </This>
          )
        }}
      </For>
    )
  },

  requestHandler(request: string, respond: (msg: string) => void) {
    if (request.startsWith("osd-brightness")) {
      respond("ok")
      return
    }
    if (request === "toggle-notification-center") {
      const win = app.get_window("notification-center")
      if (win) win.visible = !win.visible
      respond("ok")
      return
    }
    if (request === "toggle-theme-switcher") {
      const win = app.get_window("theme-switcher")
      if (win) win.visible = !win.visible
      respond("ok")
      return
    }
    // apply-theme:<id> — reload CSS after shell script has applied hyprland changes
    if (request.startsWith("apply-theme:")) {
      const themeId = request.slice("apply-theme:".length).trim()
      respond("ok")

      GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
        try {
          const themeFile = `${THEMES_DIR}/${themeId}.json`
          const [ok, bytes] = GLib.file_get_contents(themeFile)
          if (ok) {
            const preset = JSON.parse(new TextDecoder().decode(bytes))
            applyGeneratedThemeCSS(preset)
          }
        } catch (e) {
          console.error("apply-theme: failed to reload CSS:", e)
        }
        return GLib.SOURCE_REMOVE
      })

      return
    }
    respond("unknown command")
  },
})
