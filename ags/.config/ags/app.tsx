import app from "ags/gtk4/app"
import { createBinding, For, This } from "ags"
import style from "./style.scss"
import Bar from "./widget/Bar"
import { NotificationPopups, NotificationCenter } from "./widget/Notifications"
import { OSD } from "./widget/OSD"
import { AppLauncher } from "./widget/AppLauncher"
import { SessionMenu } from "./widget/Session"
import { DesktopWidgets } from "./widget/DesktopWidgets"
import { ThemeSwitcher, generateThemeCSS } from "./widget/ThemeSwitcher"
import GLib from "gi://GLib"

const THEMES_DIR = `${GLib.get_home_dir()}/.config/ags/themes`

// Load and apply the saved theme CSS on startup
function loadSavedThemeCSS(): string {
  try {
    const currentFile = `${THEMES_DIR}/current.json`
    const [ok, bytes] = GLib.file_get_contents(currentFile)
    if (!ok) return ""
    const preset = JSON.parse(new TextDecoder().decode(bytes))
    return generateThemeCSS(preset)
  } catch {
    return ""
  }
}

app.start({
  css: style,
  main() {
    const monitors = createBinding(app, "monitors")

    // Apply saved theme override CSS on top of base stylesheet
    const savedCSS = loadSavedThemeCSS()
    if (savedCSS) {
      app.apply_css(savedCSS, false)
    }

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
      try {
        const themeFile = `${THEMES_DIR}/${themeId}.json`
        const [ok, bytes] = GLib.file_get_contents(themeFile)
        if (ok) {
          const preset = JSON.parse(new TextDecoder().decode(bytes))
          const css = generateThemeCSS(preset)
          app.apply_css(css, false)
        }
      } catch (e) {
        console.error("apply-theme: failed to reload CSS:", e)
      }
      respond("ok")
      return
    }
    respond("unknown command")
  },
})
