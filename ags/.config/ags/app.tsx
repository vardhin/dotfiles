import app from "ags/gtk4/app"
import { createBinding, For, This } from "ags"
import style from "./style.scss"
import Bar from "./widget/Bar"
import { NotificationPopups, NotificationCenter } from "./widget/Notifications"
import { OSD } from "./widget/OSD"
import { AppLauncher } from "./widget/AppLauncher"
import { SessionMenu } from "./widget/Session"
import { DesktopWidgets } from "./widget/DesktopWidgets"

app.start({
  css: style,
  main() {
    const monitors = createBinding(app, "monitors")

    return (
      <For each={monitors}>
        {(monitor) => {
          // Only create singletons if they don't already exist
          const needsLauncher = !app.get_window("applauncher")
          const needsSession = !app.get_window("session")
          const needsNotifCenter = !app.get_window("notification-center")
          const needsWidgets = !app.get_window("desktop-widgets")

          return (
            <This this={app}>
              <Bar gdkmonitor={monitor} />
              <NotificationPopups gdkmonitor={monitor} />
              <OSD gdkmonitor={monitor} />
              {needsLauncher && <AppLauncher gdkmonitor={monitor} />}
              {needsSession && <SessionMenu gdkmonitor={monitor} />}
              {needsNotifCenter && <NotificationCenter gdkmonitor={monitor} />}
              {needsWidgets && <DesktopWidgets gdkmonitor={monitor} />}
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
    respond("unknown command")
  },
})
