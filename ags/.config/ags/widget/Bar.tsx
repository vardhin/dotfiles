import app from "ags/gtk4/app"
import GLib from "gi://GLib"
import Astal from "gi://Astal?version=4.0"
import Gtk from "gi://Gtk?version=4.0"
import Gdk from "gi://Gdk?version=4.0"
import AstalHyprland from "gi://AstalHyprland"
import AstalBattery from "gi://AstalBattery"
import AstalPowerProfiles from "gi://AstalPowerProfiles"
import AstalWp from "gi://AstalWp"
import AstalTray from "gi://AstalTray"
import AstalMpris from "gi://AstalMpris"
import AstalNotifd from "gi://AstalNotifd"
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
        {(player) => {
          const title = createBinding(player, "title")
          const artist = createBinding(player, "artist")
          const playbackStatus = createBinding(player, "playbackStatus")
          const canGoPrev = createBinding(player, "canGoPrevious")
          const canGoNext = createBinding(player, "canGoNext")
          const canControl = createBinding(player, "canControl")
          const position = createBinding(player, "position")
          const length = createBinding(player, "length")

          const formatTime = (seconds: number) => {
            if (!seconds || seconds < 0) return "0:00"
            const m = Math.floor(seconds / 60)
            const s = Math.floor(seconds % 60)
            return `${m}:${s.toString().padStart(2, "0")}`
          }

          return (
            <box class="media-player" spacing={0}>
              <menubutton class="media-toggle">
                <box spacing={6}>
                  <image
                    iconName={playbackStatus((s) =>
                      s === AstalMpris.PlaybackStatus.PLAYING
                        ? "media-playback-start-symbolic"
                        : "media-playback-pause-symbolic"
                    )}
                  />
                  <label
                    class="media-title-bar"
                    label={title((t) =>
                      t ? (t.length > 22 ? t.substring(0, 19) + "..." : t) : "Media"
                    )}
                  />
                </box>
                <popover>
                  <box class="media-popup" orientation={Gtk.Orientation.VERTICAL} spacing={10}>
                    {/* Title & Artist */}
                    <box orientation={Gtk.Orientation.VERTICAL} spacing={2}>
                      <label
                        class="media-popup-title"
                        label={title((t) => t || "Unknown")}
                        xalign={0}
                        wrap
                        maxWidthChars={35}
                      />
                      <label
                        class="media-popup-artist"
                        label={artist((a) => a || "Unknown artist")}
                        xalign={0}
                        wrap
                        maxWidthChars={35}
                      />
                    </box>

                    {/* Progress bar */}
                    <box orientation={Gtk.Orientation.VERTICAL} spacing={2}>
                      <slider
                        class="media-progress"
                        widthRequest={260}
                        value={position((pos) => {
                          const len = player.length
                          return len > 0 ? pos / len : 0
                        })}
                        onChangeValue={({ value }) => {
                          const len = player.length
                          if (len > 0) player.set_position(value * len)
                        }}
                      />
                      <box>
                        <label
                          class="media-time"
                          label={position((p) => formatTime(p))}
                          hexpand
                          xalign={0}
                        />
                        <label
                          class="media-time"
                          label={length((l) => formatTime(l))}
                          xalign={1}
                        />
                      </box>
                    </box>

                    {/* Controls */}
                    <box class="media-controls" halign={Gtk.Align.CENTER} spacing={16}>
                      <button
                        class="media-control-btn"
                        onClicked={() => player.previous()}
                        visible={canGoPrev}
                        tooltipText="Previous"
                      >
                        <image iconName="media-skip-backward-symbolic" pixelSize={18} />
                      </button>
                      <button
                        class="media-play-btn"
                        onClicked={() => player.play_pause()}
                        visible={canControl}
                        tooltipText="Play/Pause"
                      >
                        <image
                          iconName={playbackStatus((s) =>
                            s === AstalMpris.PlaybackStatus.PLAYING
                              ? "media-playback-pause-symbolic"
                              : "media-playback-start-symbolic"
                          )}
                          pixelSize={22}
                        />
                      </button>
                      <button
                        class="media-control-btn"
                        onClicked={() => player.next()}
                        visible={canGoNext}
                        tooltipText="Next"
                      >
                        <image iconName="media-skip-forward-symbolic" pixelSize={18} />
                      </button>
                    </box>

                    {/* Player identity */}
                    <box halign={Gtk.Align.CENTER}>
                      <label
                        class="media-player-name"
                        label={createBinding(player, "identity")((id) => id || "Player")}
                      />
                    </box>
                  </box>
                </popover>
              </menubutton>

              {/* Inline prev/play/next buttons */}
              <button
                class="media-inline-btn"
                onClicked={() => player.previous()}
                visible={canGoPrev}
              >
                <image iconName="media-skip-backward-symbolic" pixelSize={14} />
              </button>
              <button
                class="media-inline-btn"
                onClicked={() => player.play_pause()}
                visible={canControl}
              >
                <image
                  iconName={playbackStatus((s) =>
                    s === AstalMpris.PlaybackStatus.PLAYING
                      ? "media-playback-pause-symbolic"
                      : "media-playback-start-symbolic"
                  )}
                  pixelSize={14}
                />
              </button>
              <button
                class="media-inline-btn"
                onClicked={() => player.next()}
                visible={canGoNext}
              >
                <image iconName="media-skip-forward-symbolic" pixelSize={14} />
              </button>
            </box>
          )
        }}
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
// Network status is shown via the system tray (nm-applet or similar).
// A dedicated Wireless widget was removed to avoid duplicate wifi icons.

// ━━━━━━━━━━━━━━━━━ VOLUME ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function AudioOutput() {
  const wp = AstalWp.get_default()!
  const speaker = wp.defaultSpeaker
  const mic = wp.defaultMicrophone

  const speakerVol = createBinding(speaker, "volume")
  const speakerIcon = createBinding(speaker, "volumeIcon")
  const speakerMute = createBinding(speaker, "mute")
  const micVol = createBinding(mic, "volume")
  const micIcon = createBinding(mic, "volumeIcon")
  const micMute = createBinding(mic, "mute")

  return (
    <box class="volume">
      <menubutton>
        <box spacing={4}>
          <image iconName={speakerIcon} />
          <label
            class="volume-percent"
            label={speakerVol((v) => `${Math.round(v * 100)}%`)}
          />
        </box>
        <popover>
          <box class="volume-popup" orientation={Gtk.Orientation.VERTICAL} spacing={10}>
            {/* Speaker */}
            <box class="volume-row" spacing={8}>
              <button
                class="volume-mute-btn"
                onClicked={() => { speaker.mute = !speaker.mute }}
                tooltipText="Mute speaker"
              >
                <image iconName={speakerIcon} pixelSize={18} />
              </button>
              <slider
                class="volume-slider"
                hexpand
                value={speakerVol}
                onChangeValue={({ value }) => speaker.set_volume(value)}
              />
              <label
                class="volume-value"
                label={speakerVol((v) => `${Math.round(v * 100)}%`)}
                widthRequest={42}
              />
            </box>

            <box class="volume-separator" />

            {/* Microphone */}
            <box class="volume-row" spacing={8}>
              <button
                class="volume-mute-btn"
                onClicked={() => { mic.mute = !mic.mute }}
                tooltipText="Mute microphone"
              >
                <image iconName={micIcon} pixelSize={18} />
              </button>
              <slider
                class="volume-slider"
                hexpand
                value={micVol}
                onChangeValue={({ value }) => mic.set_volume(value)}
              />
              <label
                class="volume-value"
                label={micVol((v) => `${Math.round(v * 100)}%`)}
                widthRequest={42}
              />
            </box>
          </box>
        </popover>
      </menubutton>
    </box>
  )
}

// ━━━━━━━━━━━━━━━━━ BRIGHTNESS ━━━━━━━━━━━━━━━━━━━━━━━━━━
function Brightness() {
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
    return 1
  }

  const brightnessValue = createPoll(1, 2000, readBrightness)

  const brightnessIcon = brightnessValue((v) => {
    if (v < 0.33) return "display-brightness-low-symbolic"
    if (v < 0.66) return "display-brightness-medium-symbolic"
    return "display-brightness-symbolic"
  })

  return (
    <box class="brightness">
      <menubutton>
        <box spacing={4}>
          <image iconName={brightnessIcon} />
        </box>
        <popover>
          <box class="brightness-popup" spacing={8}>
            <image iconName="display-brightness-symbolic" pixelSize={18} class="brightness-icon" />
            <slider
              class="brightness-slider"
              hexpand
              widthRequest={180}
              value={brightnessValue}
              onChangeValue={({ value }) => {
                const pct = Math.round(value * 100)
                execAsync(["brightnessctl", "set", `${pct}%`])
              }}
            />
            <label
              class="brightness-value"
              label={brightnessValue((v) => `${Math.round(v * 100)}%`)}
              widthRequest={42}
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

  const percentage = createBinding(battery, "percentage")
  const charging = createBinding(battery, "charging")
  const iconName = createBinding(battery, "iconName")
  const isPresent = createBinding(battery, "isPresent")
  const timeToEmpty = createBinding(battery, "timeToEmpty")
  const timeToFull = createBinding(battery, "timeToFull")
  const activeProfile = createBinding(powerprofiles, "activeProfile")

  const formatTime = (seconds: number) => {
    if (!seconds || seconds <= 0) return ""
    const h = Math.floor(seconds / 3600)
    const m = Math.floor((seconds % 3600) / 60)
    if (h > 0) return `${h}h ${m}m`
    return `${m}m`
  }

  const percentText = percentage((p) => `${Math.floor(p * 100)}%`)

  const profileIcon = (profile: string) => {
    switch (profile) {
      case "power-saver": return "battery-profile-powersave-symbolic"
      case "balanced": return "battery-profile-balanced-symbolic"
      case "performance": return "battery-profile-performance-symbolic"
      default: return "speedometer-symbolic"
    }
  }

  const profileLabel = (profile: string) => {
    switch (profile) {
      case "power-saver": return "🔋 Power Saver"
      case "balanced": return "⚖️ Balanced"
      case "performance": return "🚀 Performance"
      default: return profile
    }
  }

  return (
    <box class="battery">
      <menubutton visible={isPresent}>
        <box spacing={4}>
          <image iconName={iconName} />
          <label class="battery-percent" label={percentText} />
        </box>
        <popover>
          <box class="battery-popup" orientation={Gtk.Orientation.VERTICAL} spacing={10}>
            {/* Battery status header */}
            <box class="battery-header" spacing={10}>
              <image iconName={iconName} pixelSize={32} class="battery-big-icon" />
              <box orientation={Gtk.Orientation.VERTICAL} hexpand>
                <label
                  class="battery-popup-percent"
                  label={percentText}
                  xalign={0}
                />
                <label
                  class="battery-popup-status"
                  label={charging((c) => c ? "Charging" : "On battery")}
                  xalign={0}
                />
              </box>
            </box>

            {/* Time remaining */}
            <box class="battery-info-row" spacing={6}>
              <image iconName="hourglass-symbolic" pixelSize={14} class="battery-info-icon" />
              <label
                class="battery-info-label"
                label={charging((isCharging) => {
                  if (isCharging) {
                    const t = battery.timeToFull
                    return t > 0 ? `Full in ${formatTime(t)}` : "Calculating..."
                  }
                  const t = battery.timeToEmpty
                  return t > 0 ? `${formatTime(t)} remaining` : "Calculating..."
                })}
                hexpand
                xalign={0}
              />
            </box>

            <box class="battery-separator" />

            {/* Power profiles */}
            <label class="battery-section-title" label="Power Profile" xalign={0} />
            <box orientation={Gtk.Orientation.VERTICAL} spacing={4} class="battery-profiles">
              {powerprofiles.get_profiles().map(({ profile }) => (
                <button
                  class={activeProfile((ap) =>
                    `battery-profile-btn ${ap === profile ? "active" : ""}`
                  )}
                  onClicked={() => powerprofiles.set_active_profile(profile)}
                >
                  <box spacing={8}>
                    <image iconName={profileIcon(profile)} pixelSize={16} />
                    <label label={profileLabel(profile)} hexpand xalign={0} />
                    <image
                      iconName="object-select-symbolic"
                      pixelSize={14}
                      visible={activeProfile((ap) => ap === profile)}
                      class="battery-check"
                    />
                  </box>
                </button>
              ))}
            </box>
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

// ━━━━━━━━━━━━━━━ NOTIFICATION BELL ━━━━━━━━━━━━━━━━━━━
function NotificationButton() {
  const notifd = AstalNotifd.get_default()
  const notifications = createBinding(notifd, "notifications")
  const dndEnabled = createBinding(notifd, "dontDisturb")

  return (
    <box class="notification-bell">
      <button
        onClicked={() => {
          // Toggle the notification center window directly
          const win = app.get_window("notification-center")
          if (win) {
            win.visible = !win.visible
          }
        }}
        tooltipText={notifications((n) => `${n.length} notification${n.length !== 1 ? "s" : ""}`)}
      >
        <box spacing={4}>
          <image
            iconName={dndEnabled((dnd) =>
              dnd ? "notifications-disabled-symbolic" : "preferences-system-notifications-symbolic"
            )}
          />
          <label
            class="notification-count"
            visible={notifications((n) => n.length > 0)}
            label={notifications((n) => `${n.length}`)}
          />
        </box>
      </button>
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
        <box $type="end" spacing={4}>
          <Mpris />
          <Tray />
          <Brightness />
          <AudioOutput />
          <Battery />
          <NotificationButton />
        </box>
      </centerbox>
    </window>
  )
}
