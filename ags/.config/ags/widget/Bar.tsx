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
import { notify } from "../lib/notify"

function svgIcon(name: string): string {
  return `ags-${name}-symbolic`
}

function wifiGlyph(signal: number, connected: boolean): string {
  if (!connected) return svgIcon("wifi-off")
  if (signal > 75) return svgIcon("wifi-high")
  if (signal > 40) return svgIcon("wifi-medium")
  return svgIcon("wifi-low")
}

function brightnessGlyph(level: number): string {
  if (level < 0.33) return svgIcon("sun-low")
  if (level < 0.66) return svgIcon("sun-medium")
  return svgIcon("sun")
}

function volumeGlyph(level: number, muted: boolean): string {
  if (muted || level <= 0.01) return svgIcon("volume-muted")
  return svgIcon("volume")
}

function micGlyph(level: number, muted: boolean): string {
  if (muted || level <= 0.01) return svgIcon("mic-muted")
  return svgIcon("mic")
}

type BarPopoverKind = "clock" | "media" | "volume" | "brightness" | "wifi" | "bluetooth" | "battery"

const BAR_POPOVER_KINDS: BarPopoverKind[] = [
  "clock",
  "media",
  "volume",
  "brightness",
  "wifi",
  "bluetooth",
  "battery",
]

const BAR_POPOVER_TOP_MARGIN = 50
const BAR_POPOVER_RIGHT_MARGIN: Record<Exclude<BarPopoverKind, "clock" | "media">, number> = {
  volume: 188,
  brightness: 140,
  wifi: 92,
  bluetooth: 52,
  battery: 12,
}
const BAR_POPOVER_CLOCK_LEFT_MARGIN = 88

function barPopoverName(kind: BarPopoverKind, gdkmonitor: Gdk.Monitor): string {
  return `${kind}-popover-${gdkmonitor.connector}`
}

function toggleBarPopover(kind: BarPopoverKind, gdkmonitor: Gdk.Monitor) {
  const targetName = barPopoverName(kind, gdkmonitor)
  const target = app.get_window(targetName)
  if (!target) return

  const opening = !target.visible
  for (const popupKind of BAR_POPOVER_KINDS) {
    const name = barPopoverName(popupKind, gdkmonitor)
    if (name === targetName) continue
    const win = app.get_window(name)
    if (win) win.visible = false
  }

  target.visible = opening
}

// ━━━━━━━━━━━━━━ HYPRLAND WORKSPACES ━━━━━━━━━━━━━━━━━━
function Workspaces() {
  const hyprland = AstalHyprland.get_default()
  const focused = createBinding(hyprland, "focusedWorkspace")
  const workspaces = createBinding(hyprland, "workspaces")

  const createNextWorkspace = () => {
    const all = hyprland.get_workspaces() ?? []
    const maxId = all.reduce((m, ws) => (ws.id > m ? ws.id : m), 0)
    hyprland.dispatch("workspace", `${maxId + 1}`)
  }

  return (
    <box class="workspaces">
      <For each={workspaces((wss) =>
        wss
          .filter((ws) => ws.id > 0) // filter out special and invalid workspaces
          .sort((a, b) => a.id - b.id)
      )}>
        {(ws) => (
          <button
            class={focused((fw) => fw?.id === ws.id ? "focused" : "")}
            onClicked={() => hyprland.dispatch("workspace", `${ws.id}`)}
          >
            <label label={`${ws.id}`} />
          </button>
        )}
      </For>
      <button
        class="workspace-add"
        onClicked={createNextWorkspace}
        tooltipText="New workspace"
      >
        <label label="+" />
      </button>
    </box>
  )
}

// ━━━━━━━━━━━━━━ ACTIVE WINDOW TITLE ━━━━━━━━━━━━━━━━━━
function ActiveWindow() {
  const hyprland = AstalHyprland.get_default()
  const focused = createBinding(hyprland, "focusedClient")

  return (
    <box class="active-window" hexpand>
      <image class="active-window-icon" iconName={svgIcon("radio")} />
      <With value={focused}>
        {(client) =>
            <label
              label={client
                ? createBinding(client, "title")((t) => {
                    const title = t || ""
                    return title.length > 52 ? title.substring(0, 49) + "..." : title
                  })
                : "Desktop"}
            />
        }
      </With>
    </box>
  )
}

// ━━━━━━━━━━━━━━━━ MEDIA PLAYER ━━━━━━━━━━━━━━━━━━━━━━━
function formatMediaTime(seconds: number): string {
  if (!seconds || seconds < 0) return "0:00"
  const m = Math.floor(seconds / 60)
  const s = Math.floor(seconds % 60)
  return `${m}:${s.toString().padStart(2, "0")}`
}

function Mpris({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
  const mpris = AstalMpris.get_default()
  const players = createBinding(mpris, "players")

  return (
    <box class="media" visible={players((p) => p.length > 0)}>
      <For each={players}>
        {(player) => {
          const title = createBinding(player, "title")
          const playbackStatus = createBinding(player, "playbackStatus")
          const mediaIcon = playbackStatus((s) =>
            s === AstalMpris.PlaybackStatus.PLAYING
              ? svgIcon("pause")
              : svgIcon("play")
          )

          return (
            <box class="media-player" spacing={0}>
              <button
                class="media-toggle"
                onClicked={() => toggleBarPopover("media", gdkmonitor)}
                tooltipText="Media controls"
              >
                <box spacing={6}>
                  <image iconName={mediaIcon} />
                  <label
                    class="media-title-bar"
                    label={title((t) =>
                      t ? (t.length > 22 ? t.substring(0, 19) + "..." : t) : "Media"
                    )}
                  />
                </box>
              </button>
            </box>
          )
        }}
      </For>
    </box>
  )
}

export function MediaPopover({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
  const mpris = AstalMpris.get_default()
  const players = createBinding(mpris, "players")
  const popupName = barPopoverName("media", gdkmonitor)

  let win: Astal.Window | null = null
  const { TOP, LEFT, RIGHT, BOTTOM } = Astal.WindowAnchor

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
        const keyCtrl = new Gtk.EventControllerKey()
        keyCtrl.connect("key-pressed", (_ctrl, keyval) => {
          if (keyval === Gdk.KEY_Escape) hide()
        })
        self.add_controller(keyCtrl)
      }}
      visible={false}
      namespace="ags-bar-popover"
      name={popupName}
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.IGNORE}
      keymode={Astal.Keymode.ON_DEMAND}
      layer={Astal.Layer.OVERLAY}
      anchor={TOP | LEFT | BOTTOM | RIGHT}
      application={app}
    >
      <overlay>
        <button class="popover-backdrop" hexpand vexpand onClicked={hide}>
          <box />
        </button>

        <box
          $type="overlay"
          class="bar-popup-window media-popup-window"
          orientation={Gtk.Orientation.VERTICAL}
          halign={Gtk.Align.CENTER}
          valign={Gtk.Align.START}
          marginTop={BAR_POPOVER_TOP_MARGIN}
        >
          <box orientation={Gtk.Orientation.VERTICAL} spacing={8}>
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

                return (
                  <box class="media-popup" orientation={Gtk.Orientation.VERTICAL} spacing={10}>
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
                          label={position((p) => formatMediaTime(p))}
                          hexpand
                          xalign={0}
                        />
                        <label
                          class="media-time"
                          label={length((l) => formatMediaTime(l))}
                          xalign={1}
                        />
                      </box>
                    </box>

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

                    <box halign={Gtk.Align.CENTER}>
                      <label
                        class="media-player-name"
                        label={createBinding(player, "identity")((id) => id || "Player")}
                      />
                    </box>
                  </box>
                )
              }}
            </For>

            <label
              class="media-time"
              visible={players((p) => p.length === 0)}
              label="No active media players"
              xalign={0.5}
            />
          </box>
        </box>
      </overlay>
    </window>
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

// ━━━━━━━━━━━━━━━━━━ BLUETOOTH ━━━━━━━━━━━━━━━━━━━━━━━━━
interface BluetoothDevice {
  address: string
  name: string
  connected: boolean
}

interface BluetoothSharedState {
  powered: ReturnType<typeof createPoll<boolean>>
  devices: ReturnType<typeof createPoll<BluetoothDevice[]>>
  pollBluetooth: () => boolean
}

let bluetoothSharedState: BluetoothSharedState | null = null

function getBluetoothSharedState(): BluetoothSharedState {
  if (bluetoothSharedState) return bluetoothSharedState

  const pollBluetooth = () => {
    try {
      const out = GLib.spawn_command_line_sync("bluetoothctl show")[1]
      const text = new TextDecoder().decode(out)
      return /Powered:\s*yes/i.test(text)
    } catch {
      return false
    }
  }

  const pollDevices = (): BluetoothDevice[] => {
    try {
      const pairedOut = GLib.spawn_command_line_sync("bluetoothctl devices Paired")[1]
      const pairedText = new TextDecoder().decode(pairedOut).trim()
      const lines = pairedText ? pairedText.split("\n") : []

      const connOut = GLib.spawn_command_line_sync("bluetoothctl devices Connected")[1]
      const connText = new TextDecoder().decode(connOut).trim()
      const connLines = connText ? connText.split("\n") : []
      const connAddrs = new Set(
        connLines.map((l) => l.replace(/^Device\s+/, "").split(" ")[0])
      )

      return lines.map((line) => {
        const rest = line.replace(/^Device\s+/, "")
        const spaceIdx = rest.indexOf(" ")
        const address = rest.substring(0, spaceIdx)
        const name = rest.substring(spaceIdx + 1) || address
        return { address, name, connected: connAddrs.has(address) }
      })
    } catch {
      return []
    }
  }

  const powered = createPoll(false, 3000, pollBluetooth)
  const devices = createPoll([] as BluetoothDevice[], 5000, pollDevices)

  bluetoothSharedState = {
    powered,
    devices,
    pollBluetooth,
  }

  return bluetoothSharedState
}

function Bluetooth({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
  const { powered, devices } = getBluetoothSharedState()
  const connectedCount = devices((devs) => devs.filter((d) => d.connected).length)
  const icon = powered(() => svgIcon("bluetooth"))

  return (
    <box class="bluetooth">
      <button onClicked={() => toggleBarPopover("bluetooth", gdkmonitor)} tooltipText="Bluetooth">
        <box spacing={4}>
          <image iconName={icon} />
          <label
            class="bluetooth-count"
            visible={connectedCount((c) => c > 0)}
            label={connectedCount((c) => `${c}`)}
          />
        </box>
      </button>
    </box>
  )
}

export function BluetoothPopover({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
  const { powered, devices, pollBluetooth } = getBluetoothSharedState()
  const popupName = barPopoverName("bluetooth", gdkmonitor)

  let win: Astal.Window | null = null
  const { TOP, LEFT, RIGHT, BOTTOM } = Astal.WindowAnchor

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
        const keyCtrl = new Gtk.EventControllerKey()
        keyCtrl.connect("key-pressed", (_ctrl, keyval) => {
          if (keyval === Gdk.KEY_Escape) hide()
        })
        self.add_controller(keyCtrl)
      }}
      visible={false}
      namespace="ags-bar-popover"
      name={popupName}
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.IGNORE}
      keymode={Astal.Keymode.ON_DEMAND}
      layer={Astal.Layer.OVERLAY}
      anchor={TOP | LEFT | BOTTOM | RIGHT}
      application={app}
    >
      <overlay>
        <button class="popover-backdrop" hexpand vexpand onClicked={hide}>
          <box />
        </button>

        <box
          $type="overlay"
          class="bar-popup-window bluetooth-popup-window"
          halign={Gtk.Align.END}
          valign={Gtk.Align.START}
          marginTop={BAR_POPOVER_TOP_MARGIN}
          marginEnd={BAR_POPOVER_RIGHT_MARGIN.bluetooth}
        >
          <box class="bluetooth-popup" orientation={Gtk.Orientation.VERTICAL} spacing={10}>
            <box class="bluetooth-header" spacing={10}>
              <image iconName={svgIcon("bluetooth")} pixelSize={20} class="bluetooth-header-icon" />
              <label class="bluetooth-title" label="Bluetooth" hexpand xalign={0} />
              <button
                class={powered((on) => `bluetooth-toggle-btn ${on ? "active" : ""}`)}
                onClicked={() => {
                  const isOn = pollBluetooth()
                  execAsync(["bluetoothctl", "power", isOn ? "off" : "on"])
                }}
                tooltipText={powered((on) => on ? "Turn off" : "Turn on")}
              >
                <label label={powered((on) => on ? "ON" : "OFF")} />
              </button>
            </box>

            <box class="bluetooth-separator" />

            <button
              class="bluetooth-scan-btn"
              onClicked={() => {
                execAsync(["bash", "-c", "bluetoothctl --timeout 10 scan on &"])
              }}
              tooltipText="Scan for devices"
              visible={powered}
            >
              <box spacing={6}>
                <image iconName="view-refresh-symbolic" pixelSize={14} />
                <label label="Scan for devices" />
              </box>
            </button>

            <box
              orientation={Gtk.Orientation.VERTICAL}
              spacing={4}
              visible={powered}
            >
              <label class="bluetooth-section-title" label="Devices" xalign={0} />
              <For each={devices}>
                {(dev) => (
                  <button
                    class={`bluetooth-device-btn ${dev.connected ? "connected" : ""}`}
                    onClicked={() => {
                      execAsync([
                        "bluetoothctl",
                        dev.connected ? "disconnect" : "connect",
                        dev.address,
                      ])
                    }}
                    tooltipText={dev.connected ? "Disconnect" : "Connect"}
                  >
                    <box spacing={8}>
                      <image
                        iconName={dev.connected
                          ? "bluetooth-active-symbolic"
                          : "bluetooth-disabled-symbolic"
                        }
                        pixelSize={14}
                      />
                      <label label={dev.name} hexpand xalign={0} />
                      <label
                        class="bluetooth-device-status"
                        label={dev.connected ? "Connected" : "Paired"}
                      />
                    </box>
                  </button>
                )}
              </For>

              <label
                class="wifi-empty-label"
                visible={devices((devs) => devs.length === 0)}
                label="No paired devices"
                xalign={0}
              />
            </box>

            <button
              class="bluetooth-settings-btn"
              onClicked={() => execAsync(["blueman-manager"])}
              tooltipText="Open Bluetooth Settings"
            >
              <box spacing={6}>
                <image iconName="emblem-system-symbolic" pixelSize={14} />
                <label label="Bluetooth Settings" />
              </box>
            </button>
          </box>
        </box>
      </overlay>
    </window>
  )
}

// ━━━━━━━━━━━━━━━━━━ WIFI ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ━━━━━━━━━━━━━━ WIFI SHARED STATE ━━━━━━━━━━━━━━━━━━━━
// State + polling lives in a module-level singleton so the bar button
// and the layer-shell popover window can both subscribe to the same data.

interface WifiNetwork {
  ssid: string
  signal: number
  active: boolean
  security: string
  savedUuid: string
}

interface WifiInfo {
  available: boolean
  connected: boolean
  ssid: string
  signal: number
  ip: string
  iface: string
}

interface WifiUiState {
  busy: boolean
  message: string
  tone: "info" | "ok" | "err"
}

interface WifiSharedState {
  wifiInfo: ReturnType<typeof createPoll<WifiInfo>>
  networks: ReturnType<typeof createPoll<WifiNetwork[]>>
  status: ReturnType<typeof createPoll<WifiUiState>>
  handleRescan: () => void
  handleConnectToggle: (net: WifiNetwork) => void
  handleForget: (net: WifiNetwork) => void
}

let wifiSharedState: WifiSharedState | null = null

function getWifiSharedState(): WifiSharedState {
  if (wifiSharedState) return wifiSharedState

  const decode = (buf: Uint8Array) => new TextDecoder().decode(buf)
  const splitNmcliLine = (line: string) => line.includes("|") ? line.split("|") : line.split(":")

  let lastIface = ""
  let uiState: WifiUiState = { busy: false, message: "", tone: "info" }
  let clearStatusSource = 0
  let statusToken = 0

  const setUiState = (next: Partial<WifiUiState>, clearAfterMs = 0) => {
    uiState = { ...uiState, ...next }

    if (clearStatusSource !== 0) {
      GLib.source_remove(clearStatusSource)
      clearStatusSource = 0
    }

    if (clearAfterMs > 0) {
      statusToken += 1
      const token = statusToken
      clearStatusSource = GLib.timeout_add(GLib.PRIORITY_DEFAULT, clearAfterMs, () => {
        if (token !== statusToken) return GLib.SOURCE_REMOVE
        uiState = { busy: false, message: "", tone: "info" }
        clearStatusSource = 0
        return GLib.SOURCE_REMOVE
      })
    }
  }

  const pollWifi = (): WifiInfo => {
    try {
      const devOut = GLib.spawn_command_line_sync(
        "nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device"
      )[1]
      const devText = decode(devOut).trim()
      if (!devText) {
        return { available: false, connected: false, ssid: "", signal: 0, ip: "", iface: "" }
      }

      const wifiLines = devText
        .split("\n")
        .map((l) => l.trim())
        .filter(Boolean)
        .map((line) => splitNmcliLine(line))
        .filter((parts) => parts[1] === "wifi")

      if (wifiLines.length === 0) {
        return { available: false, connected: false, ssid: "", signal: 0, ip: "", iface: "" }
      }

      const connectedParts = wifiLines.find((parts) => parts[2] === "connected")
      const selected = connectedParts || wifiLines[0]

      const iface = selected[0] || ""
      const state = selected[2] || ""
      const ssid = selected.slice(3).join("|") || ""
      const connected = state === "connected" && ssid.length > 0

      lastIface = iface

      if (!connected || !iface) {
        return { available: true, connected: false, ssid: "", signal: 0, ip: "", iface }
      }

      const sigOut = GLib.spawn_command_line_sync(
        `nmcli -t -f ACTIVE,SIGNAL device wifi list ifname ${iface} --rescan no`
      )[1]
      const sigText = decode(sigOut).trim()
      const activeLine = sigText
        .split("\n")
        .map((l) => l.trim())
        .find((l) => /^(yes|\*)(\||:)/.test(l))
      const signal = activeLine ? parseInt(splitNmcliLine(activeLine)[1]) || 0 : 0

      const ipOut = GLib.spawn_command_line_sync(`nmcli -t -f IP4.ADDRESS device show ${iface}`)[1]
      const ipText = decode(ipOut)
      const ipMatch = ipText.match(/IP4\.ADDRESS\[[0-9]+\]:([^\n]+)/)
      const ip = ipMatch ? ipMatch[1].split("/")[0].trim() : ""

      return { available: true, connected: true, ssid, signal, ip, iface }
    } catch {
      return { available: false, connected: false, ssid: "", signal: 0, ip: "", iface: "" }
    }
  }

  const pollSavedConnections = (): Map<string, string> => {
    const map = new Map<string, string>()
    try {
      const out = GLib.spawn_command_line_sync(
        "nmcli -t -f NAME,UUID,TYPE connection show"
      )[1]
      const text = decode(out).trim()
      if (!text) return map

      for (const line of text.split("\n")) {
        const [name, uuid, type] = splitNmcliLine(line)
        if (!name || !uuid) continue
        if (type === "802-11-wireless" || type === "wifi") {
          map.set(name, uuid)
        }
      }
    } catch {
      return map
    }
    return map
  }

  const pollNetworks = (): WifiNetwork[] => {
    try {
      const savedConnections = pollSavedConnections()
      const ifaceArg = lastIface ? ` ifname ${lastIface}` : ""
      const out = GLib.spawn_command_line_sync(
        `nmcli -t -f SSID,SIGNAL,ACTIVE,SECURITY device wifi list${ifaceArg} --rescan no`
      )[1]
      const text = decode(out).trim()
      if (!text) return []

      const merged = new Map<string, WifiNetwork>()
      for (const line of text.split("\n")) {
        const parts = splitNmcliLine(line)
        const ssid = parts[0] || ""
        const signal = parseInt(parts[1]) || 0
        const active = parts[2] === "*" || parts[2] === "yes"
        const security = parts[3] === "--" ? "" : (parts[3] || "")

        if (!ssid) continue

        const candidate: WifiNetwork = {
          ssid,
          signal,
          active,
          security,
          savedUuid: savedConnections.get(ssid) || "",
        }

        const existing = merged.get(ssid)
        if (!existing) {
          merged.set(ssid, candidate)
          continue
        }

        if (candidate.active || candidate.signal > existing.signal) {
          merged.set(ssid, candidate)
        }
      }

      return Array.from(merged.values()).sort((a, b) => {
        if (a.active && !b.active) return -1
        if (!a.active && b.active) return 1
        return b.signal - a.signal
      })
    } catch {
      return []
    }
  }

  const runWifiAction = async (
    startMessage: string,
    command: string[],
    successMessage: string,
    errorMessage: string,
  ) => {
    setUiState({ busy: true, message: startMessage, tone: "info" })
    try {
      await execAsync(command)
      setUiState({ busy: false, message: successMessage, tone: "ok" }, 2200)
    } catch {
      setUiState({ busy: false, message: errorMessage, tone: "err" }, 3200)
    }
  }

  const handleRescan = () => {
    const info = pollWifi()
    const cmd = info.iface
      ? ["nmcli", "device", "wifi", "rescan", "ifname", info.iface]
      : ["nmcli", "device", "wifi", "rescan"]

    runWifiAction(
      "Rescanning networks...",
      cmd,
      "Scan finished",
      "Scan failed",
    )
  }

  const handleConnectToggle = (net: WifiNetwork) => {
    const info = pollWifi()
    const iface = info.iface || lastIface

    if (net.active) {
      if (iface) {
        runWifiAction(
          `Disconnecting from ${net.ssid}...`,
          ["nmcli", "device", "disconnect", iface],
          `Disconnected from ${net.ssid}`,
          "Disconnect failed",
        )
      } else {
        runWifiAction(
          `Disconnecting from ${net.ssid}...`,
          ["nmcli", "connection", "down", "id", net.ssid],
          `Disconnected from ${net.ssid}`,
          "Disconnect failed",
        )
      }
      return
    }

    if (net.savedUuid) {
      runWifiAction(
        `Connecting to ${net.ssid}...`,
        ["nmcli", "connection", "up", "uuid", net.savedUuid],
        `Connected to ${net.ssid}`,
        "Connect failed",
      )
      return
    }

    const connectCmd = ["nmcli", "device", "wifi", "connect", net.ssid]
    if (iface) {
      connectCmd.push("ifname", iface)
    }

    runWifiAction(
      `Connecting to ${net.ssid}...`,
      connectCmd,
      `Connected to ${net.ssid}`,
      net.security ? "Password needed or connection failed" : "Connect failed",
    )
  }

  const handleForget = (net: WifiNetwork) => {
    if (!net.savedUuid) return
    runWifiAction(
      `Forgetting ${net.ssid}...`,
      ["nmcli", "connection", "delete", "uuid", net.savedUuid],
      `Forgot ${net.ssid}`,
      "Forget failed",
    )
  }

  const wifiInfo = createPoll(
    { available: false, connected: false, ssid: "", signal: 0, ip: "", iface: "" },
    4000,
    pollWifi,
  )
  const networks = createPoll([] as WifiNetwork[], 8000, pollNetworks)
  const status = createPoll(uiState, 250, () => ({ ...uiState }))

  wifiSharedState = {
    wifiInfo,
    networks,
    status,
    handleRescan,
    handleConnectToggle,
    handleForget,
  }
  return wifiSharedState
}

// ━━━━━━━━━━━━━━━━━━ WIFI BAR BUTTON ━━━━━━━━━━━━━━━━━━━
function WiFi({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
  const { wifiInfo } = getWifiSharedState()
  const wifiIcon = wifiInfo((w) => wifiGlyph(w.signal, w.connected))

  return (
    <box class="wifi">
      <button onClicked={() => toggleBarPopover("wifi", gdkmonitor)} tooltipText="Wi-Fi">
        <image iconName={wifiIcon} />
      </button>
    </box>
  )
}

// ━━━━━━━━━━━━━━━ WIFI POPOVER (layer window) ━━━━━━━━━━
export function WifiPopover({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
  const { wifiInfo, networks, status, handleRescan, handleConnectToggle, handleForget } =
    getWifiSharedState()
  const popupName = barPopoverName("wifi", gdkmonitor)

  let win: Astal.Window | null = null
  const { TOP, LEFT, RIGHT, BOTTOM } = Astal.WindowAnchor

  const hide = () => {
    if (win) win.visible = false
  }

  const signalIcon = (signal: number) => wifiGlyph(signal, true)

  onCleanup(() => {
    win?.destroy()
  })

  return (
    <window
      $={(self) => {
        win = self
        const keyCtrl = new Gtk.EventControllerKey()
        keyCtrl.connect("key-pressed", (_ctrl, keyval) => {
          if (keyval === Gdk.KEY_Escape) hide()
        })
        self.add_controller(keyCtrl)
      }}
      visible={false}
      namespace="ags-wifi-popover"
      name={popupName}
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.IGNORE}
      keymode={Astal.Keymode.ON_DEMAND}
      layer={Astal.Layer.OVERLAY}
      anchor={TOP | LEFT | BOTTOM | RIGHT}
      application={app}
    >
      <overlay>
        <button class="popover-backdrop" hexpand vexpand onClicked={hide}>
          <box />
        </button>

        <box
          $type="overlay"
          class="wifi-popup-window"
          halign={Gtk.Align.END}
          valign={Gtk.Align.START}
          marginTop={BAR_POPOVER_TOP_MARGIN}
          marginEnd={BAR_POPOVER_RIGHT_MARGIN.wifi}
        >
          <box class="wifi-popup" orientation={Gtk.Orientation.VERTICAL} spacing={10} widthRequest={380}>
            {/* Header */}
            <box class="wifi-header" spacing={10}>
              <image iconName={svgIcon("wifi-high")} pixelSize={20} class="wifi-header-icon" />
              <box orientation={Gtk.Orientation.VERTICAL} hexpand>
                <label class="wifi-title" label="Wi-Fi" xalign={0} />
                <label
                  class="wifi-subtitle"
                  label={wifiInfo((w) => {
                    if (!w.available) return "No Wi-Fi adapter"
                    if (!w.connected) return "Not connected"
                    return `${w.ssid} - ${w.signal}%`
                  })}
                  xalign={0}
                />
              </box>
            </box>

            <box
              class={status((s) => `wifi-status-row ${s.tone}`)}
              spacing={6}
              visible={status((s) => s.message.length > 0)}
            >
              <image
                class="wifi-status-icon"
                iconName={status((s) => {
                  if (s.tone === "ok") return "emblem-ok-symbolic"
                  if (s.tone === "err") return "dialog-error-symbolic"
                  return "view-refresh-symbolic"
                })}
                pixelSize={12}
              />
              <label class="wifi-status-label" label={status((s) => s.message)} hexpand xalign={0} />
            </box>

            <box
              class="wifi-info-row"
              spacing={6}
              visible={wifiInfo((w) => w.connected && w.ip !== "")}
            >
              <image iconName="network-server-symbolic" pixelSize={12} class="wifi-info-icon" />
              <label
                class="wifi-info-label"
                label={wifiInfo((w) => w.ip)}
                hexpand xalign={0}
              />
            </box>

            <box class="wifi-separator" />

            <button
              class={status((s) => `wifi-scan-btn ${s.busy ? "busy" : ""}`)}
              onClicked={handleRescan}
              tooltipText="Rescan for networks"
              sensitive={status((s) => !s.busy)}
            >
              <box spacing={6}>
                <image iconName="view-refresh-symbolic" pixelSize={14} />
                <label label={status((s) => s.busy ? "Rescanning..." : "Rescan networks")} />
              </box>
            </button>

            <box orientation={Gtk.Orientation.VERTICAL} spacing={4}>
              <label class="wifi-section-title" label="Available Networks" xalign={0} />
              <For each={networks((n) => n.slice(0, 8))}>
                {(net) => (
                  <box class={`wifi-network-row ${net.active ? "active" : ""}`} spacing={6}>
                    <button
                      class={`wifi-network-btn ${net.active ? "active" : ""}`}
                      hexpand
                      onClicked={() => handleConnectToggle(net)}
                      tooltipText={net.active ? "Disconnect" : `Connect to ${net.ssid}`}
                    >
                      <box spacing={8}>
                        <image iconName={signalIcon(net.signal)} pixelSize={14} />
                        <label label={net.ssid} hexpand xalign={0} />
                        {net.security && (
                          <image iconName="channel-secure-symbolic" pixelSize={10} class="wifi-lock-icon" />
                        )}
                        <label
                          class="wifi-network-state"
                          label={
                            net.active
                              ? "Connected"
                              : (net.savedUuid ? "Saved" : (net.security ? "Secured" : "Open"))
                          }
                        />
                        <label
                          class="wifi-signal-label"
                          label={`${net.signal}%`}
                        />
                      </box>
                    </button>
                    <button
                      class={`wifi-action-btn ${net.active ? "disconnect" : "connect"}`}
                      onClicked={() => handleConnectToggle(net)}
                      sensitive={status((s) => !s.busy)}
                      tooltipText={net.active ? `Disconnect from ${net.ssid}` : `Connect to ${net.ssid}`}
                    >
                      <label label={net.active ? "Disconnect" : "Connect"} />
                    </button>
                    <button
                      class="wifi-action-btn forget"
                      visible={Boolean(net.savedUuid)}
                      onClicked={() => handleForget(net)}
                      sensitive={status((s) => !s.busy)}
                      tooltipText={`Forget ${net.ssid}`}
                    >
                      <label label="Forget" />
                    </button>
                  </box>
                )}
              </For>
              <label
                class="wifi-empty-label"
                visible={networks((n) => n.length === 0)}
                label="No networks found"
                xalign={0}
              />
            </box>

            <button
              class="wifi-settings-btn"
              onClicked={() => execAsync(["nm-connection-editor"])}
              tooltipText="Open Network Settings"
            >
              <box spacing={6}>
                <image iconName="emblem-system-symbolic" pixelSize={14} />
                <label label="Network Settings" />
              </box>
            </button>
          </box>
        </box>
      </overlay>
    </window>
  )
}

// ━━━━━━━━━━━━━━━━━ VOLUME ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function createAudioSharedState() {
  const wp = AstalWp.get_default()!
  const speaker = wp.defaultSpeaker
  const mic = wp.defaultMicrophone

  const speakerVol = createBinding(speaker, "volume")
  const micVol = createBinding(mic, "volume")
  const speakerGlyphIcon = createPoll(svgIcon("volume"), 300, () =>
    volumeGlyph(speaker.volume, speaker.mute)
  )
  const micGlyphIcon = createPoll(svgIcon("mic"), 300, () =>
    micGlyph(mic.volume, mic.mute)
  )

  return {
    speaker,
    mic,
    speakerVol,
    micVol,
    speakerGlyphIcon,
    micGlyphIcon,
  }
}

let audioSharedState: ReturnType<typeof createAudioSharedState> | null = null

function getAudioSharedState() {
  if (!audioSharedState) audioSharedState = createAudioSharedState()
  return audioSharedState
}

function AudioOutput({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
  const { speakerVol, speakerGlyphIcon } = getAudioSharedState()

  return (
    <box class="volume">
      <button onClicked={() => toggleBarPopover("volume", gdkmonitor)} tooltipText="Volume and microphone">
        <box spacing={4}>
          <image iconName={speakerGlyphIcon} />
          <label
            class="volume-percent"
            label={speakerVol((v) => `${Math.round(v * 100)}%`)}
          />
        </box>
      </button>
    </box>
  )
}

export function VolumePopover({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
  const { speaker, mic, speakerVol, micVol, speakerGlyphIcon, micGlyphIcon } = getAudioSharedState()
  const popupName = barPopoverName("volume", gdkmonitor)

  let win: Astal.Window | null = null
  const { TOP, LEFT, RIGHT, BOTTOM } = Astal.WindowAnchor

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
        const keyCtrl = new Gtk.EventControllerKey()
        keyCtrl.connect("key-pressed", (_ctrl, keyval) => {
          if (keyval === Gdk.KEY_Escape) hide()
        })
        self.add_controller(keyCtrl)
      }}
      visible={false}
      namespace="ags-bar-popover"
      name={popupName}
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.IGNORE}
      keymode={Astal.Keymode.ON_DEMAND}
      layer={Astal.Layer.OVERLAY}
      anchor={TOP | LEFT | BOTTOM | RIGHT}
      application={app}
    >
      <overlay>
        <button class="popover-backdrop" hexpand vexpand onClicked={hide}>
          <box />
        </button>

        <box
          $type="overlay"
          class="bar-popup-window volume-popup-window"
          halign={Gtk.Align.END}
          valign={Gtk.Align.START}
          marginTop={BAR_POPOVER_TOP_MARGIN}
          marginEnd={BAR_POPOVER_RIGHT_MARGIN.volume}
        >
          <box class="volume-popup" orientation={Gtk.Orientation.VERTICAL} spacing={10}>
            <box class="volume-row" spacing={8}>
              <button
                class="volume-mute-btn"
                onClicked={() => { speaker.mute = !speaker.mute }}
                tooltipText="Mute speaker"
              >
                <image iconName={speakerGlyphIcon} pixelSize={18} />
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

            <box class="volume-row" spacing={8}>
              <button
                class="volume-mute-btn"
                onClicked={() => { mic.mute = !mic.mute }}
                tooltipText="Mute microphone"
              >
                <image iconName={micGlyphIcon} pixelSize={18} />
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
        </box>
      </overlay>
    </window>
  )
}

// ━━━━━━━━━━━━━━━━━ BRIGHTNESS ━━━━━━━━━━━━━━━━━━━━━━━━━━
function readBrightness(): number {
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
    } catch {
      // skip
    }
  }
  return 1
}

let brightnessValueState: ReturnType<typeof createPoll<number>> | null = null
let nightLightEnabledState: ReturnType<typeof createPoll<boolean>> | null = null

function getBrightnessValue() {
  if (!brightnessValueState) brightnessValueState = createPoll(1, 2000, readBrightness)
  return brightnessValueState
}

function isNightLightEnabled(): boolean {
  try {
    const out = GLib.spawn_command_line_sync("pgrep -x hyprsunset")[1]
    return new TextDecoder().decode(out).trim().length > 0
  } catch {
    return false
  }
}

function getNightLightEnabled() {
  if (!nightLightEnabledState) nightLightEnabledState = createPoll(false, 2000, isNightLightEnabled)
  return nightLightEnabledState
}

function toggleNightLight() {
  execAsync(["bash", "-c", "pkill hyprsunset || hyprsunset --temperature 4000"]).catch(console.error)
}

function Brightness({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
  const brightnessValue = getBrightnessValue()
  const brightnessIcon = brightnessValue((v) => brightnessGlyph(v))

  return (
    <box class="brightness">
      <button onClicked={() => toggleBarPopover("brightness", gdkmonitor)} tooltipText="Brightness">
        <box spacing={4}>
          <image iconName={brightnessIcon} />
        </box>
      </button>
    </box>
  )
}

export function BrightnessPopover({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
  const brightnessValue = getBrightnessValue()
  const nightLightEnabled = getNightLightEnabled()
  const brightnessIcon = brightnessValue((v) => brightnessGlyph(v))
  const popupName = barPopoverName("brightness", gdkmonitor)

  let win: Astal.Window | null = null
  const { TOP, LEFT, RIGHT, BOTTOM } = Astal.WindowAnchor

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
        const keyCtrl = new Gtk.EventControllerKey()
        keyCtrl.connect("key-pressed", (_ctrl, keyval) => {
          if (keyval === Gdk.KEY_Escape) hide()
        })
        self.add_controller(keyCtrl)
      }}
      visible={false}
      namespace="ags-bar-popover"
      name={popupName}
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.IGNORE}
      keymode={Astal.Keymode.ON_DEMAND}
      layer={Astal.Layer.OVERLAY}
      anchor={TOP | LEFT | BOTTOM | RIGHT}
      application={app}
    >
      <overlay>
        <button class="popover-backdrop" hexpand vexpand onClicked={hide}>
          <box />
        </button>

        <box
          $type="overlay"
          class="bar-popup-window brightness-popup-window"
          halign={Gtk.Align.END}
          valign={Gtk.Align.START}
          marginTop={BAR_POPOVER_TOP_MARGIN}
          marginEnd={BAR_POPOVER_RIGHT_MARGIN.brightness}
        >
          <box class="brightness-popup" orientation={Gtk.Orientation.VERTICAL} spacing={10}>
            <box class="brightness-main-row" spacing={8}>
              <image iconName={brightnessIcon} pixelSize={18} class="brightness-icon" />
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

            <box class="brightness-separator" />

            <box class="night-light-row" spacing={8}>
              <image iconName="weather-clear-night-symbolic" pixelSize={15} class="night-light-icon" />
              <label class="night-light-label" label="Night Light" hexpand xalign={0} />
              <button
                class={nightLightEnabled((on) => `night-light-toggle ${on ? "active" : ""}`)}
                onClicked={toggleNightLight}
                tooltipText={nightLightEnabled((on) => on ? "Disable night light" : "Enable night light")}
              >
                <label label={nightLightEnabled((on) => on ? "ON" : "OFF")} />
              </button>
            </box>
          </box>
        </box>
      </overlay>
    </window>
  )
}

// ━━━━━━━━━━━━━━━━━ BATTERY ━━━━━━━━━━━━━━━━━━━━━━━━━━━
function formatBatteryTime(seconds: number) {
  if (!seconds || seconds <= 0) return ""
  const h = Math.floor(seconds / 3600)
  const m = Math.floor((seconds % 3600) / 60)
  if (h > 0) return `${h}h ${m}m`
  return `${m}m`
}

function batteryProfileIcon(profile: string) {
  switch (profile) {
    case "power-saver": return svgIcon("leaf")
    case "balanced": return svgIcon("gauge")
    case "performance": return svgIcon("bolt")
    default: return svgIcon("gauge")
  }
}

function batteryProfileLabel(profile: string) {
  switch (profile) {
    case "power-saver": return "Power Saver"
    case "balanced": return "Balanced"
    case "performance": return "Performance"
    default: return profile
  }
}

function createBatterySharedState() {
  const battery = AstalBattery.get_default()
  const powerprofiles = AstalPowerProfiles.get_default()

  const percentage = createBinding(battery, "percentage")
  const isPresent = createBinding(battery, "isPresent")
  const state = createBinding(battery, "state")
  const activeProfile = createBinding(powerprofiles, "activeProfile")
  const batteryGlyphIcon = createPoll(svgIcon("battery"), 1200, () =>
    battery.charging ? svgIcon("battery-charging") : svgIcon("battery")
  )

  const timeText = createPoll("", 5000, () => {
    const s = battery.state
    if (s === AstalBattery.State.FULLY_CHARGED) return "Fully charged"
    if (s === AstalBattery.State.CHARGING) {
      const t = battery.timeToFull
      return t > 0 ? `Full in ${formatBatteryTime(t)}` : "Estimating..."
    }
    if (s === AstalBattery.State.DISCHARGING) {
      const t = battery.timeToEmpty
      return t > 0 ? `${formatBatteryTime(t)} remaining` : "Estimating..."
    }
    if (s === AstalBattery.State.EMPTY) return "Empty"
    if (s === AstalBattery.State.PENDING_CHARGE) return "Waiting to charge"
    if (s === AstalBattery.State.PENDING_DISCHARGE) return "Waiting to discharge"
    return "Idle"
  })

  const statusText = state((s: AstalBattery.State) => {
    if (s === AstalBattery.State.FULLY_CHARGED) return "Fully charged"
    if (s === AstalBattery.State.CHARGING) return "Charging"
    if (s === AstalBattery.State.DISCHARGING) return "On battery"
    if (s === AstalBattery.State.EMPTY) return "Empty"
    return "Idle"
  })

  const percentText = percentage((p) => `${Math.floor(p * 100)}%`)

  return {
    battery,
    powerprofiles,
    percentage,
    isPresent,
    state,
    activeProfile,
    batteryGlyphIcon,
    timeText,
    statusText,
    percentText,
  }
}

let batterySharedState: ReturnType<typeof createBatterySharedState> | null = null

function getBatterySharedState() {
  if (!batterySharedState) batterySharedState = createBatterySharedState()
  return batterySharedState
}

function Battery({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
  const { isPresent, batteryGlyphIcon, percentText } = getBatterySharedState()

  return (
    <box class="battery">
      <button visible={isPresent} onClicked={() => toggleBarPopover("battery", gdkmonitor)} tooltipText="Battery and power profiles">
        <box spacing={4}>
          <image iconName={batteryGlyphIcon} />
          <label class="battery-percent" label={percentText} />
        </box>
      </button>
    </box>
  )
}

export function BatteryPopover({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
  const {
    powerprofiles,
    activeProfile,
    batteryGlyphIcon,
    percentText,
    statusText,
    timeText,
  } = getBatterySharedState()
  const popupName = barPopoverName("battery", gdkmonitor)

  let win: Astal.Window | null = null
  const { TOP, LEFT, RIGHT, BOTTOM } = Astal.WindowAnchor

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
        const keyCtrl = new Gtk.EventControllerKey()
        keyCtrl.connect("key-pressed", (_ctrl, keyval) => {
          if (keyval === Gdk.KEY_Escape) hide()
        })
        self.add_controller(keyCtrl)
      }}
      visible={false}
      namespace="ags-bar-popover"
      name={popupName}
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.IGNORE}
      keymode={Astal.Keymode.ON_DEMAND}
      layer={Astal.Layer.OVERLAY}
      anchor={TOP | LEFT | BOTTOM | RIGHT}
      application={app}
    >
      <overlay>
        <button class="popover-backdrop" hexpand vexpand onClicked={hide}>
          <box />
        </button>

        <box
          $type="overlay"
          class="bar-popup-window battery-popup-window"
          halign={Gtk.Align.END}
          valign={Gtk.Align.START}
          marginTop={BAR_POPOVER_TOP_MARGIN}
          marginEnd={BAR_POPOVER_RIGHT_MARGIN.battery}
        >
          <box class="battery-popup" orientation={Gtk.Orientation.VERTICAL} spacing={10}>
            <box class="battery-header" spacing={10}>
              <image iconName={batteryGlyphIcon} pixelSize={32} class="battery-big-icon" />
              <box orientation={Gtk.Orientation.VERTICAL} hexpand>
                <label
                  class="battery-popup-percent"
                  label={percentText}
                  xalign={0}
                />
                <label
                  class="battery-popup-status"
                  label={statusText}
                  xalign={0}
                />
              </box>
            </box>

            <box class="battery-info-row" spacing={6}>
              <image iconName={svgIcon("hourglass")} pixelSize={14} class="battery-info-icon" />
              <label
                class="battery-info-label"
                label={timeText}
                hexpand
                xalign={0}
              />
            </box>

            <box class="battery-separator" />

            <label class="battery-section-title" label="Power Profile" xalign={0} />
            <box orientation={Gtk.Orientation.VERTICAL} spacing={4} class="battery-profiles">
              {powerprofiles.get_profiles().map(({ profile }) => (
                <button
                  class={activeProfile((ap) =>
                    `battery-profile-btn ${ap === profile ? "active" : ""}`
                  )}
                  onClicked={() => {
                    if (powerprofiles.activeProfile === profile) return
                    powerprofiles.set_active_profile(profile)
                    notify({
                      summary: "Power profile",
                      body: batteryProfileLabel(profile),
                      urgency: "low",
                      appName: "ags-battery",
                      expireTime: 1800,
                      replaceTag: "ags-power-profile",
                      icon: batteryProfileIcon(profile),
                    })
                  }}
                >
                  <box spacing={8}>
                    <image iconName={batteryProfileIcon(profile)} pixelSize={16} />
                    <label label={batteryProfileLabel(profile)} hexpand xalign={0} />
                    <image
                      iconName={svgIcon("check")}
                      pixelSize={14}
                      visible={activeProfile((ap) => ap === profile)}
                      class="battery-check"
                    />
                  </box>
                </button>
              ))}
            </box>
          </box>
        </box>
      </overlay>
    </window>
  )
}

// ━━━━━━━━━━━━━━━━━━ CLOCK ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function Clock({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
  const time = createPoll("", 1000, () =>
    GLib.DateTime.new_now_local().format("%H:%M")!
  )
  const date = createPoll("", 60000, () =>
    GLib.DateTime.new_now_local().format("%a %b %d")!
  )

  return (
    <box class="clock" spacing={8}>
      <button onClicked={() => toggleBarPopover("clock", gdkmonitor)} tooltipText="Calendar">
        <box spacing={8}>
          <label class="clock-time" label={time} />
          <label class="clock-date" label={date} />
        </box>
      </button>
    </box>
  )
}

export function ClockPopover({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
  const popupName = barPopoverName("clock", gdkmonitor)
  let win: Astal.Window | null = null
  const { TOP, LEFT, RIGHT, BOTTOM } = Astal.WindowAnchor

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
        const keyCtrl = new Gtk.EventControllerKey()
        keyCtrl.connect("key-pressed", (_ctrl, keyval) => {
          if (keyval === Gdk.KEY_Escape) hide()
        })
        self.add_controller(keyCtrl)
      }}
      visible={false}
      namespace="ags-bar-popover"
      name={popupName}
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.IGNORE}
      keymode={Astal.Keymode.ON_DEMAND}
      layer={Astal.Layer.OVERLAY}
      anchor={TOP | LEFT | BOTTOM | RIGHT}
      application={app}
    >
      <overlay>
        <button class="popover-backdrop" hexpand vexpand onClicked={hide}>
          <box />
        </button>

        <box
          $type="overlay"
          class="bar-popup-window clock-popup-window"
          halign={Gtk.Align.START}
          valign={Gtk.Align.START}
          marginTop={BAR_POPOVER_TOP_MARGIN}
          marginStart={BAR_POPOVER_CLOCK_LEFT_MARGIN}
        >
          <box class="clock-popup" orientation={Gtk.Orientation.VERTICAL}>
            <Gtk.Calendar />
          </box>
        </box>
      </overlay>
    </window>
  )
}

// ━━━━━━━━━━━━━━━ NOTIFICATION BELL ━━━━━━━━━━━━━━━━━━━
function NotificationButton() {
  const notifd = AstalNotifd.get_default()
  const notifications = createBinding(notifd, "notifications")
  const dndEnabled = createBinding(notifd, "dontDisturb")
  const notificationIcon = dndEnabled((dnd) =>
    dnd ? svgIcon("bell-off") : svgIcon("bell")
  )

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
          <image iconName={notificationIcon} />
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

// ━━━━━━━━━━━━━━━ THEME SWITCHER BUTTON ━━━━━━━━━━━━━━━━━━
function ThemeButton() {
  return (
    <box class="theme-launcher">
      <button
        onClicked={() => {
          const win = app.get_window("theme-switcher")
          if (win) {
            win.visible = !win.visible
          }
        }}
        tooltipText="Theme and wallpaper menu"
      >
        <box spacing={4}>
          <image iconName={svgIcon("palette")} />
          <label class="theme-launcher-label" label="Theme" />
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
      marginTop={4}
      marginLeft={10}
      marginRight={10}
      application={app}
    >
      <box class="bar-shell" spacing={8}>
        <box class="bar-lane bar-lane-left" spacing={8}>
          <Workspaces />
          <Clock gdkmonitor={gdkmonitor} />
        </box>

        <box class="bar-lane bar-lane-middle" hexpand spacing={8}>
          <ActiveWindow />
          <Mpris gdkmonitor={gdkmonitor} />
        </box>

        <box class="bar-lane bar-lane-right" spacing={6} halign={Gtk.Align.END}>
          <box class="bar-cluster bar-cluster-tray" spacing={4}>
            <Tray />
            <ThemeButton />
            <NotificationButton />
          </box>

          <box class="bar-divider" />

          <box class="bar-cluster bar-cluster-status" spacing={2}>
            <AudioOutput gdkmonitor={gdkmonitor} />
            <Brightness gdkmonitor={gdkmonitor} />
            <WiFi gdkmonitor={gdkmonitor} />
            <Bluetooth gdkmonitor={gdkmonitor} />
            <Battery gdkmonitor={gdkmonitor} />
          </box>
        </box>
      </box>
    </window>
  )
}
