import app from "ags/gtk4/app"
import GLib from "gi://GLib"
import Astal from "gi://Astal?version=4.0"
import Gtk from "gi://Gtk?version=4.0"
import Gdk from "gi://Gdk?version=4.0"
import AstalHyprland from "gi://AstalHyprland"
import AstalBattery from "gi://AstalBattery"
import AstalPowerProfiles from "gi://AstalPowerProfiles"
import AstalWp from "gi://AstalWp"
import AstalNetwork from "gi://AstalNetwork"
import AstalTray from "gi://AstalTray"
import AstalMpris from "gi://AstalMpris"
import { For, With, createBinding, onCleanup } from "ags"
import { createPoll } from "ags/time"
import { execAsync } from "ags/process"

// ━━━━━━━━━━━━━━ HYPRLAND WORKSPACES ━━━━━━━━━━━━━━━━━━
function Workspaces() {
  const hyprland = AstalHyprland.get_default()
  const focused = createBinding(hyprland, "focusedWorkspace")

  return (
    <box class="workspaces">
      {Array.from({ length: 10 }, (_, i) => i + 1).map((id) => (
        <button
          class={focused((ws) => ws?.id === id ? "focused" : "")}
          onClicked={() => hyprland.dispatch("workspace", `${id}`)}
        >
          <label label={`${id}`} />
        </button>
      ))}
    </box>
  )
}

// ━━━━━━━━━━━━━━ ACTIVE WINDOW TITLE ━━━━━━━━━━━━━━━━━━
function ActiveWindow() {
  const hyprland = AstalHyprland.get_default()
  const focused = createBinding(hyprland, "focusedClient")

  return (
    <box class="active-window">
      <With value={focused}>
        {(client) =>
          client && (
            <label
              label={createBinding(client, "title")((t) =>
                t.length > 45 ? t.substring(0, 42) + "..." : t
              )}
            />
          )
        }
      </With>
    </box>
  )
}

// ━━━━━━━━━━━━━━━━ MEDIA PLAYER ━━━━━━━━━━━━━━━━━━━━━━━
function Mpris() {
  const mpris = AstalMpris.get_default()
  const players = createBinding(mpris, "players")

  return (
    <box class="media" visible={players((p) => p.length > 0)}>
      <For each={players}>
        {(player) => (
          <box spacing={4}>
            <button
              onClicked={() => player.previous()}
              visible={createBinding(player, "canGoPrevious")}
            >
              <image iconName="media-seek-backward-symbolic" />
            </button>
            <button
              onClicked={() => player.play_pause()}
              visible={createBinding(player, "canControl")}
            >
              <image
                iconName={createBinding(player, "playbackStatus")((s) =>
                  s === AstalMpris.PlaybackStatus.PLAYING
                    ? "media-playback-pause-symbolic"
                    : "media-playback-start-symbolic"
                )}
              />
            </button>
            <button
              onClicked={() => player.next()}
              visible={createBinding(player, "canGoNext")}
            >
              <image iconName="media-seek-forward-symbolic" />
            </button>
            <label
              label={createBinding(player, "title")((t) =>
                t ? (t.length > 30 ? t.substring(0, 27) + "..." : t) : ""
              )}
            />
          </box>
        )}
      </For>
    </box>
  )
}

// ━━━━━━━━━━━━━━━━━ SYSTEM TRAY ━━━━━━━━━━━━━━━━━━━━━━━
function Tray() {
  const tray = AstalTray.get_default()
  const items = createBinding(tray, "items")

  const init = (btn: Gtk.MenuButton, item: AstalTray.TrayItem) => {
    btn.menuModel = item.menuModel
    btn.insert_action_group("dbusmenu", item.actionGroup)
    item.connect("notify::action-group", () => {
      btn.insert_action_group("dbusmenu", item.actionGroup)
    })
  }

  return (
    <box class="systray">
      <For each={items}>
        {(item) => (
          <menubutton $={(self) => init(self, item)}>
            <image gicon={createBinding(item, "gicon")} />
          </menubutton>
        )}
      </For>
    </box>
  )
}

// ━━━━━━━━━━━━━━━━━━ WIFI ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function Wireless() {
  const network = AstalNetwork.get_default()
  const wifi = createBinding(network, "wifi")

  return (
    <box class="network" visible={wifi(Boolean)}>
      <With value={wifi}>
        {(wifi) =>
          wifi && (
            <menubutton>
              <image iconName={createBinding(wifi, "iconName")} />
              <popover>
                <box orientation={Gtk.Orientation.VERTICAL}>
                  <For
                    each={createBinding(wifi, "accessPoints")((aps) =>
                      aps
                        .filter((ap) => !!ap.ssid)
                        .sort((a, b) => b.strength - a.strength)
                    )}
                  >
                    {(ap: AstalNetwork.AccessPoint) => (
                      <button
                        onClicked={() =>
                          execAsync(`nmcli d wifi connect ${ap.bssid}`)
                        }
                      >
                        <box spacing={4}>
                          <image iconName={createBinding(ap, "iconName")} />
                          <label label={createBinding(ap, "ssid")} />
                        </box>
                      </button>
                    )}
                  </For>
                </box>
              </popover>
            </menubutton>
          )
        }
      </With>
    </box>
  )
}

// ━━━━━━━━━━━━━━━━━ VOLUME ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function AudioOutput() {
  const { defaultSpeaker: speaker } = AstalWp.get_default()!

  return (
    <box class="volume">
      <menubutton>
        <image iconName={createBinding(speaker, "volumeIcon")} />
        <popover>
          <box>
            <slider
              widthRequest={200}
              onChangeValue={({ value }) => speaker.set_volume(value)}
              value={createBinding(speaker, "volume")}
            />
          </box>
        </popover>
      </menubutton>
    </box>
  )
}

// ━━━━━━━━━━━━━━━━━ BATTERY ━━━━━━━━━━━━━━━━━━━━━━━━━━━
function Battery() {
  const battery = AstalBattery.get_default()
  const powerprofiles = AstalPowerProfiles.get_default()

  const percent = createBinding(battery, "percentage")((p) =>
    `${Math.floor(p * 100)}%`
  )

  return (
    <box class="battery">
      <menubutton visible={createBinding(battery, "isPresent")}>
        <box spacing={4}>
          <image iconName={createBinding(battery, "iconName")} />
          <label label={percent} />
        </box>
        <popover>
          <box orientation={Gtk.Orientation.VERTICAL}>
            {powerprofiles.get_profiles().map(({ profile }) => (
              <button onClicked={() => powerprofiles.set_active_profile(profile)}>
                <label label={profile} xalign={0} />
              </button>
            ))}
          </box>
        </popover>
      </menubutton>
    </box>
  )
}

// ━━━━━━━━━━━━━━━━━━ CLOCK ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function Clock() {
  const time = createPoll("", 1000, () =>
    GLib.DateTime.new_now_local().format("%H:%M")!
  )
  const date = createPoll("", 60000, () =>
    GLib.DateTime.new_now_local().format("%a %b %d")!
  )

  return (
    <box class="clock" spacing={8}>
      <menubutton>
        <box spacing={8}>
          <label class="clock-time" label={time} />
          <label class="clock-date" label={date} />
        </box>
        <popover>
          <Gtk.Calendar />
        </popover>
      </menubutton>
    </box>
  )
}

// ━━━━━━━━━━━━━━━━━━ BAR ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
export default function Bar({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
  let win: Astal.Window
  const { TOP, LEFT, RIGHT } = Astal.WindowAnchor

  onCleanup(() => {
    win.destroy()
  })

  return (
    <window
      $={(self) => (win = self)}
      visible
      namespace="ags-bar"
      name={`bar-${gdkmonitor.connector}`}
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      anchor={TOP | LEFT | RIGHT}
      application={app}
    >
      <centerbox>
        <box $type="start" spacing={8}>
          <Workspaces />
          <ActiveWindow />
        </box>
        <box $type="center" spacing={8}>
          <Clock />
        </box>
        <box $type="end" spacing={8}>
          <Mpris />
          <Tray />
          <Wireless />
          <AudioOutput />
          <Battery />
        </box>
      </centerbox>
    </window>
  )
}
