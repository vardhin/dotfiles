import app from "ags/gtk4/app"
import Astal from "gi://Astal?version=4.0"
import Gtk from "gi://Gtk?version=4.0"
import Gdk from "gi://Gdk?version=4.0"
import { onCleanup } from "ags"
import { execAsync } from "ags/process"

// ━━━━━━━━━━━━━━━━━ SESSION / POWER MENU (replaces rofi powermenu) ━━━━━━━━━━━━━━━━

interface SessionAction {
  label: string
  icon: string
  command: string
  class: string
}

const actions: SessionAction[] = [
  {
    label: "Lock",
    icon: "system-lock-screen-symbolic",
    command: "hyprlock & disown",
    class: "session-lock",
  },
  {
    label: "Logout",
    icon: "system-log-out-symbolic",
    command: "hyprctl dispatch exit",
    class: "session-logout",
  },
  {
    label: "Suspend",
    icon: "media-playback-pause-symbolic",
    command: "hyprlock & disown; systemctl suspend",
    class: "session-suspend",
  },
  {
    label: "Reboot",
    icon: "system-reboot-symbolic",
    command: "systemctl reboot",
    class: "session-reboot",
  },
  {
    label: "Shutdown",
    icon: "system-shutdown-symbolic",
    command: "systemctl poweroff",
    class: "session-shutdown",
  },
]

export function SessionMenu({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
  let win: Astal.Window
  const { TOP, BOTTOM, LEFT, RIGHT } = Astal.WindowAnchor

  const hide = () => {
    win.visible = false
  }

  onCleanup(() => {
    win.destroy()
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
      namespace="ags-session"
      name="session"
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.IGNORE}
      keymode={Astal.Keymode.ON_DEMAND}
      anchor={TOP | BOTTOM | LEFT | RIGHT}
      application={app}
    >
      <box
        class="session-menu"
        halign={Gtk.Align.CENTER}
        valign={Gtk.Align.CENTER}
        spacing={24}
      >
        {actions.map((action) => (
          <button
            class={`session-button ${action.class}`}
            onClicked={() => {
              hide()
              execAsync(["bash", "-c", action.command])
            }}
          >
            <box orientation={Gtk.Orientation.VERTICAL} spacing={8}>
              <image iconName={action.icon} pixelSize={48} />
              <label label={action.label} />
            </box>
          </button>
        ))}
      </box>
    </window>
  )
}
