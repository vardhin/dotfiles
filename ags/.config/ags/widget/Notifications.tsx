import app from "ags/gtk4/app"
import GLib from "gi://GLib"
import Astal from "gi://Astal?version=4.0"
import Gtk from "gi://Gtk?version=4.0"
import Gdk from "gi://Gdk?version=4.0"
import AstalNotifd from "gi://AstalNotifd"
import { createBinding, For, onCleanup } from "ags"
import { createPoll } from "ags/time"

interface NotificationHistoryItem {
  id: string
  appName: string
  summary: string
  body: string
  urgency: string
  timestamp: number
}

const HISTORY_SEP = "\u001f"
const DB_DIR = `${GLib.get_user_cache_dir()}/ags`
const DB_PATH = `${DB_DIR}/notifications.db`

function decode(bytes: Uint8Array): string {
  return new TextDecoder().decode(bytes)
}

function sqlEscape(value: string): string {
  return value
    .replaceAll("'", "''")
    .replaceAll(HISTORY_SEP, " ")
    .replaceAll("\n", " ")
    .replaceAll("\r", " ")
    .trim()
}

function hashText(input: string): string {
  let hash = 5381
  for (let i = 0; i < input.length; i++) {
    hash = ((hash << 5) + hash) + input.charCodeAt(i)
    hash |= 0
  }
  return Math.abs(hash).toString(16)
}

function runSql(sql: string): string {
  try {
    const cmd = `sqlite3 ${GLib.shell_quote(DB_PATH)} ${GLib.shell_quote(sql)}`
    const out = GLib.spawn_command_line_sync(cmd)[1]
    return decode(out).trim()
  } catch {
    return ""
  }
}

function initHistoryDb() {
  try {
    GLib.mkdir_with_parents(DB_DIR, 0o755)
  } catch {
    // ignore
  }

  runSql(`
    CREATE TABLE IF NOT EXISTS notifications (
      notif_id TEXT PRIMARY KEY,
      app_name TEXT NOT NULL,
      summary TEXT NOT NULL,
      body TEXT NOT NULL,
      urgency TEXT NOT NULL,
      ts INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_notifications_ts ON notifications(ts DESC);
  `)
}

function urgencyLabel(urgency: AstalNotifd.Urgency): string {
  switch (urgency) {
    case AstalNotifd.Urgency.CRITICAL:
      return "critical"
    case AstalNotifd.Urgency.LOW:
      return "low"
    default:
      return "normal"
  }
}

function persistNotification(notification: AstalNotifd.Notification) {
  const appName = sqlEscape(notification.appName || "System")
  const summary = sqlEscape(notification.summary || "(no title)")
  const body = sqlEscape(notification.body || "")
  const urgency = urgencyLabel(notification.urgency)

  const maybeId = (notification as unknown as { id?: number | string }).id
  const notifId = maybeId !== undefined
    ? `astal-${maybeId}`
    : `hash-${hashText(`${appName}|${summary}|${body}|${urgency}`)}`

  const ts = Date.now()
  runSql(
    `INSERT OR REPLACE INTO notifications (notif_id, app_name, summary, body, urgency, ts)
     VALUES ('${sqlEscape(notifId)}', '${appName}', '${summary}', '${body}', '${urgency}', ${ts});`
  )
}

function loadNotificationHistory(limit = 40): NotificationHistoryItem[] {
  const sql = `
    SELECT
      notif_id || char(31) ||
      app_name || char(31) ||
      summary || char(31) ||
      body || char(31) ||
      urgency || char(31) ||
      ts
    FROM notifications
    ORDER BY ts DESC
    LIMIT ${Math.max(1, limit)};
  `

  const out = runSql(sql)
  if (!out) return []

  return out
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      const [id, appName, summary, body, urgency, tsRaw] = line.split(HISTORY_SEP)
      return {
        id: id || "",
        appName: appName || "System",
        summary: summary || "(no title)",
        body: body || "",
        urgency: urgency || "normal",
        timestamp: Number(tsRaw) || 0,
      }
    })
}

function clearNotificationHistory() {
  runSql("DELETE FROM notifications;")
}

function formatHistoryTime(ts: number): string {
  if (!ts) return ""
  const dt = GLib.DateTime.new_from_unix_local(Math.floor(ts / 1000))
  if (!dt) return ""
  return dt.format("%b %d %H:%M") || ""
}

initHistoryDb()

// ━━━━━━━━━━━ NOTIFICATION POPUP (top-right toast) ━━━━━━━━━━━━
function NotificationIcon({ notification }: { notification: AstalNotifd.Notification }) {
  const appIcon = notification.appIcon || notification.desktopEntry || ""
  if (appIcon)
    return <image iconName={appIcon} pixelSize={48} />
  return <image iconName="dialog-information-symbolic" pixelSize={48} />
}

function NotificationWidget({
  notification,
  autoDismiss = true,
}: {
  notification: AstalNotifd.Notification
  autoDismiss?: boolean
}) {
  const timeout = autoDismiss
    ? setTimeout(() => {
      notification.dismiss()
    }, 5000)
    : 0

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
        persistNotification(notification)
        // Cleanup timeout if notification is dismissed before timer
        return () => {
          if (timeout) clearTimeout(timeout)
        }
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

function NotificationHistoryCard({ item }: { item: NotificationHistoryItem }) {
  const urgencyClass = `urgency-${item.urgency}`

  return (
    <box class={`notification notification-history ${urgencyClass}`} orientation={Gtk.Orientation.VERTICAL} spacing={6}>
      <box spacing={8}>
        <label class="notification-title" label={item.summary} hexpand xalign={0} />
        <label class="notification-appname" label={item.appName} />
      </box>
      {item.body && (
        <label class="notification-body" label={item.body} xalign={0} wrap maxWidthChars={42} />
      )}
      <box class="notification-history-meta" spacing={6}>
        <label class="notification-history-time" label={formatHistoryTime(item.timestamp)} xalign={0} />
        <label class="notification-history-urgency" label={item.urgency.toUpperCase()} xalign={1} hexpand />
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
          {(n) => <NotificationWidget notification={n} autoDismiss />}
        </For>
      </box>
    </window>
  )
}

// ━━━━━━━━━━━ NOTIFICATION CENTER (toggle panel) ━━━━━━━━━━━━━━
export function NotificationCenter({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
  const notifd = AstalNotifd.get_default()
  const notifications = createBinding(notifd, "notifications")
  const history = createPoll([] as NotificationHistoryItem[], 3000, () => loadNotificationHistory(45))

  let win: Astal.Window | null = null
  const { TOP, RIGHT, BOTTOM, LEFT } = Astal.WindowAnchor

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
      exclusivity={Astal.Exclusivity.IGNORE}
      keymode={Astal.Keymode.ON_DEMAND}
      layer={Astal.Layer.OVERLAY}
      anchor={TOP | RIGHT | BOTTOM | LEFT}
      application={app}
    >
      <overlay>
        <button class="notification-center-backdrop" hexpand vexpand onClicked={hide}>
          <box />
        </button>

        <box
          $type="overlay"
          orientation={Gtk.Orientation.VERTICAL}
          class="notification-center"
          widthRequest={420}
          halign={Gtk.Align.END}
          valign={Gtk.Align.FILL}
          vexpand
        >
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
              tooltipText="Clear active notifications"
            >
              <box spacing={4}>
                <image iconName="user-trash-symbolic" pixelSize={14} />
                <label label="Clear Live" />
              </box>
            </button>
            <button
              class="notification-clear-history"
              onClicked={() => {
                clearNotificationHistory()
              }}
              tooltipText="Clear notification history"
            >
              <box spacing={4}>
                <image iconName="edit-clear-all-symbolic" pixelSize={14} />
                <label label="Clear History" />
              </box>
            </button>
          </box>
          <Gtk.ScrolledWindow vexpand hscrollbarPolicy={Gtk.PolicyType.NEVER}>
            <box orientation={Gtk.Orientation.VERTICAL} spacing={6} class="notification-center-list">
              <box class="notification-center-section-header" spacing={8}>
                <label class="notification-center-section-title" label="Active" xalign={0} hexpand />
                <label class="notification-center-section-count" label={notifications((n) => `${n.length}`)} />
              </box>
              <For each={notifications}>
                {(n) => <NotificationWidget notification={n} autoDismiss={false} />}
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

              <box class="notification-center-history-separator" />

              <box class="notification-center-section-header" spacing={8}>
                <label class="notification-center-section-title" label="History" xalign={0} hexpand />
                <label class="notification-center-section-count" label={history((h) => `${h.length}`)} />
              </box>

              <For each={history}>
                {(item) => <NotificationHistoryCard item={item} />}
              </For>

              <box
                class="notification-history-empty"
                visible={history((h) => h.length === 0)}
                halign={Gtk.Align.CENTER}
                orientation={Gtk.Orientation.VERTICAL}
                spacing={8}
              >
                <image iconName="document-open-recent-symbolic" pixelSize={36} class="placeholder-icon" />
                <label label="No history yet" class="dim-sublabel" />
              </box>
            </box>
          </Gtk.ScrolledWindow>
        </box>
      </overlay>
    </window>
  )
}
