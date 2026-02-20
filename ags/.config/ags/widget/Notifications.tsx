import app from "ags/gtk4/app"
import Astal from "gi://Astal?version=4.0"
import Gtk from "gi://Gtk?version=4.0"
import Gdk from "gi://Gdk?version=4.0"
import AstalNotifd from "gi://AstalNotifd"
import { createBinding, For, onCleanup } from "ags"

// ━━━━━━━━━━━ NOTIFICATION POPUP (top-right toast) ━━━━━━━━━━━━
function NotificationIcon({ notification }: { notification: AstalNotifd.Notification }) {
  const appIcon = notification.appIcon || notification.desktopEntry || ""
  if (appIcon)
    return <image iconName={appIcon} pixelSize={48} />
  return <image iconName="dialog-information-symbolic" pixelSize={48} />
}

function NotificationWidget({ notification }: { notification: AstalNotifd.Notification }) {
  // Auto-dismiss after 5 seconds
  const timeout = setTimeout(() => {
    notification.dismiss()
  }, 5000)

  const urgencyClass = (() => {
    switch (notification.urgency) {
      case AstalNotifd.Urgency.CRITICAL: return "urgency-critical"
      case AstalNotifd.Urgency.LOW: return "urgency-low"
      default: return "urgency-normal"
    }
  })()

  return (
    <box
      class={`notification ${urgencyClass}`}
      spacing={10}
      $={() => {
        // Cleanup timeout if notification is dismissed before timer
        return () => clearTimeout(timeout)
      }}
    >
      <box class="notification-icon-box" valign={Gtk.Align.START}>
        <NotificationIcon notification={notification} />
      </box>
      <box orientation={Gtk.Orientation.VERTICAL} hexpand>
        <box spacing={6}>
          <label class="notification-title" label={notification.summary} hexpand xalign={0} />
          {notification.appName && (
            <label class="notification-appname" label={notification.appName} />
          )}
          <button class="notification-close" onClicked={() => notification.dismiss()}>
            <image iconName="window-close-symbolic" pixelSize={14} />
          </button>
        </box>
        {notification.body && (
          <label class="notification-body" label={notification.body} xalign={0} wrap maxWidthChars={40} useMarkup />
        )}
        {notification.get_actions().length > 0 && (
          <box class="notification-actions" spacing={6}>
            {notification.get_actions().map((action) => (
              <button
                class="notification-action"
                hexpand
                onClicked={() => notification.invoke(action.id)}
              >
                <label label={action.label} />
              </button>
            ))}
          </box>
        )}
      </box>
    </box>
  )
}

export function NotificationPopups({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
  const notifd = AstalNotifd.get_default()
  const notifications = createBinding(notifd, "notifications")

  let win: Astal.Window | null = null
  const { TOP, RIGHT } = Astal.WindowAnchor

  onCleanup(() => {
    win?.destroy()
  })

  return (
    <window
      $={(self) => (win = self)}
      visible={notifications((n) => n.length > 0)}
      namespace="ags-notification"
      name={`notifications-${gdkmonitor.connector}`}
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.NORMAL}
      anchor={TOP | RIGHT}
      application={app}
    >
      <box orientation={Gtk.Orientation.VERTICAL} spacing={6} class="notification-popups">
        <For each={notifications}>
          {(n) => <NotificationWidget notification={n} />}
        </For>
      </box>
    </window>
  )
}

// ━━━━━━━━━━━ NOTIFICATION CENTER (toggle panel) ━━━━━━━━━━━━━━
export function NotificationCenter({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
  const notifd = AstalNotifd.get_default()
  const notifications = createBinding(notifd, "notifications")

  let win: Astal.Window | null = null
  const { TOP, RIGHT, BOTTOM } = Astal.WindowAnchor

  const hide = () => {
    if (win) win.visible = false
  }

  onCleanup(() => {
    win?.destroy()
  })

  return (
    <window
      $={(self) => {
        win = self
        // Handle Escape key via GTK4 EventControllerKey
        const keyCtrl = new Gtk.EventControllerKey()
        keyCtrl.connect("key-pressed", (_ctrl, keyval) => {
          if (keyval === Gdk.KEY_Escape) hide()
        })
        self.add_controller(keyCtrl)
      }}
      visible={false}
      namespace="ags-notification-center"
      name="notification-center"
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.NORMAL}
      anchor={TOP | RIGHT | BOTTOM}
      keymode={Astal.Keymode.ON_DEMAND}
      application={app}
    >
      <box orientation={Gtk.Orientation.VERTICAL} class="notification-center" widthRequest={420}>
        <box class="notification-center-header" spacing={8}>
          <image iconName="preferences-system-notifications-symbolic" pixelSize={20} class="notification-center-icon" />
          <label class="notification-center-title" label="Notifications" hexpand xalign={0} />
          <button
            class="notification-dnd-toggle"
            tooltipText="Toggle Do Not Disturb"
            onClicked={() => {
              notifd.dontDisturb = !notifd.dontDisturb
            }}
          >
            <image
              iconName={createBinding(notifd, "dontDisturb")((dnd) =>
                dnd ? "notifications-disabled-symbolic" : "user-available-symbolic"
              )}
              pixelSize={16}
            />
          </button>
          <button
            class="notification-clear-all"
            onClicked={() => {
              for (const n of notifd.get_notifications()) n.dismiss()
            }}
          >
            <box spacing={4}>
              <image iconName="user-trash-symbolic" pixelSize={14} />
              <label label="Clear" />
            </box>
          </button>
        </box>
        <Gtk.ScrolledWindow vexpand hscrollbarPolicy={Gtk.PolicyType.NEVER}>
          <box orientation={Gtk.Orientation.VERTICAL} spacing={6} class="notification-center-list">
            <For each={notifications}>
              {(n) => <NotificationWidget notification={n} />}
            </For>
            <box
              class="notification-placeholder"
              visible={notifications((n) => n.length === 0)}
              halign={Gtk.Align.CENTER}
              valign={Gtk.Align.CENTER}
              orientation={Gtk.Orientation.VERTICAL}
              spacing={12}
              vexpand
            >
              <image iconName="preferences-system-notifications-symbolic" pixelSize={64} class="placeholder-icon" />
              <label label="All caught up!" class="dim-label" />
              <label label="No new notifications" class="dim-sublabel" />
            </box>
          </box>
        </Gtk.ScrolledWindow>
      </box>
    </window>
  )
}
