import app from "ags/gtk4/app"
import GLib from "gi://GLib"
import Astal from "gi://Astal?version=4.0"
import Gtk from "gi://Gtk?version=4.0"
import Gdk from "gi://Gdk?version=4.0"
import AstalMpris from "gi://AstalMpris"
import { onCleanup, createBinding, For } from "ags"
import { createPoll } from "ags/time"
import { execAsync } from "ags/process"

// ━━━━━━━━━━━━━━━ HELPERS ━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function readFile(path: string): string {
  try {
    const [ok, contents] = GLib.file_get_contents(path)
    if (ok && contents) return new TextDecoder().decode(contents).trim()
  } catch {}
  return ""
}

function now(fmt: string): string {
  const dt = GLib.DateTime.new_now_local()
  return dt ? (dt.format(fmt) ?? "") : ""
}

function getCpuUsage(): number {
  try {
    const [ok, contents] = GLib.file_get_contents("/proc/stat")
    if (!ok || !contents) return 0
    const line = new TextDecoder().decode(contents).split("\n")[0]
    const parts = line.split(/\s+/).slice(1).map(Number)
    const idle = parts[3]
    const total = parts.reduce((a, b) => a + b, 0)
    return total > 0 ? Math.round(((total - idle) / total) * 100) : 0
  } catch {
    return 0
  }
}

function getMemUsage(): { used: number; total: number; percent: number } {
  try {
    const [ok, contents] = GLib.file_get_contents("/proc/meminfo")
    if (!ok || !contents) return { used: 0, total: 0, percent: 0 }
    const text = new TextDecoder().decode(contents)
    const totalMatch = text.match(/MemTotal:\s+(\d+)/)
    const availMatch = text.match(/MemAvailable:\s+(\d+)/)
    const total = totalMatch ? parseInt(totalMatch[1]) / 1048576 : 0
    const avail = availMatch ? parseInt(availMatch[1]) / 1048576 : 0
    const used = total - avail
    return {
      used: Math.round(used * 10) / 10,
      total: Math.round(total * 10) / 10,
      percent: total > 0 ? Math.round((used / total) * 100) : 0,
    }
  } catch {
    return { used: 0, total: 0, percent: 0 }
  }
}

function getDiskUsage(): { used: string; total: string; percent: number } {
  try {
    const [ok, out] = GLib.spawn_command_line_sync("df -h /")
    if (!ok || !out[1]) return { used: "0", total: "0", percent: 0 }
    const lines = new TextDecoder().decode(out[1]).trim().split("\n")
    if (lines.length < 2) return { used: "0", total: "0", percent: 0 }
    const parts = lines[1].split(/\s+/)
    return { total: parts[1] || "0", used: parts[2] || "0", percent: parseInt(parts[4]) || 0 }
  } catch {
    return { used: "0", total: "0", percent: 0 }
  }
}

function getUptime(): string {
  try {
    const raw = readFile("/proc/uptime")
    const secs = Math.floor(parseFloat(raw.split(" ")[0]))
    const d = Math.floor(secs / 86400)
    const h = Math.floor((secs % 86400) / 3600)
    const m = Math.floor((secs % 3600) / 60)
    if (d > 0) return `${d}d ${h}h ${m}m`
    if (h > 0) return `${h}h ${m}m`
    return `${m}m`
  } catch {
    return "—"
  }
}

interface WeatherData {
  temp: string
  desc: string
  icon: string
  city: string
  humidity: string
  wind: string
}

const WEATHER_EMPTY: WeatherData = {
  temp: "—",
  desc: "Loading...",
  icon: "weather-clear-symbolic",
  city: "",
  humidity: "—",
  wind: "—",
}

function weatherIconName(code: number): string {
  if (code === 0) return "weather-clear-symbolic"
  if (code <= 3) return "weather-few-clouds-symbolic"
  if (code <= 48) return "weather-fog-symbolic"
  if (code <= 57) return "weather-showers-scattered-symbolic"
  if (code <= 67) return "weather-showers-symbolic"
  if (code <= 77) return "weather-snow-symbolic"
  if (code <= 82) return "weather-showers-symbolic"
  if (code <= 86) return "weather-snow-symbolic"
  if (code <= 99) return "weather-storm-symbolic"
  return "weather-clear-symbolic"
}

function weatherDescription(code: number): string {
  const map: Record<number, string> = {
    0: "Clear sky",
    1: "Mainly clear", 2: "Partly cloudy", 3: "Overcast",
    45: "Foggy", 48: "Icy fog",
    51: "Light drizzle", 53: "Drizzle", 55: "Heavy drizzle",
    61: "Light rain", 63: "Rain", 65: "Heavy rain",
    71: "Light snow", 73: "Snow", 75: "Heavy snow",
    77: "Snow grains",
    80: "Light showers", 81: "Showers", 82: "Heavy showers",
    85: "Light snow showers", 86: "Snow showers",
    95: "Thunderstorm", 96: "Thunderstorm + hail", 99: "Heavy thunderstorm",
  }
  return map[code] || "Unknown"
}

async function fetchWeather(): Promise<WeatherData> {
  try {
    // Get location via IP geolocation
    const geoRaw = await execAsync(["curl", "-sf", "--max-time", "5",
      "https://ipinfo.io/json"])
    const geo = JSON.parse(geoRaw)
    const [lat, lon] = (geo.loc || "0,0").split(",")
    const city = geo.city || ""

    // Fetch weather from Open-Meteo (free, no API key)
    const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,weather_code,relative_humidity_2m,wind_speed_10m&temperature_unit=celsius`
    const raw = await execAsync(["curl", "-sf", "--max-time", "5", url])
    const data = JSON.parse(raw)
    const cur = data.current

    return {
      temp: `${Math.round(cur.temperature_2m)}°C`,
      desc: weatherDescription(cur.weather_code),
      icon: weatherIconName(cur.weather_code),
      city,
      humidity: `${cur.relative_humidity_2m}%`,
      wind: `${Math.round(cur.wind_speed_10m)} km/h`,
    }
  } catch {
    return WEATHER_EMPTY
  }
}

// ━━━━━━━━━━━━━━━ CAVA VISUALIZER ━━━━━━━━━━━━━━━━━━━━

function MusicVisualizer() {
  const NUM_BARS = 14
  const bars: Gtk.LevelBar[] = []
  let cavaProcess: any = null
  let destroyed = false

  // Temporary cava config for raw output
  const cavaConf = `/tmp/ags-cava-${GLib.get_user_name()}.conf`
  const confContent = `[general]
bars = ${NUM_BARS}
framerate = 30
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 100
`

  try {
    GLib.file_set_contents(cavaConf, confContent)
  } catch {}

  // Start cava process
  const startCava = () => {
    try {
      const [ok, pid, stdinFd, stdoutFd] = GLib.spawn_async_with_pipes(
        null, ["cava", "-p", cavaConf], null,
        GLib.SpawnFlags.SEARCH_PATH | GLib.SpawnFlags.DO_NOT_REAP_CHILD,
        null
      )
      if (!ok || !stdoutFd) return

      cavaProcess = pid
      const channel = GLib.IOChannel.unix_new(stdoutFd)
      channel.set_flags(GLib.IOFlags.NONBLOCK)

      GLib.io_add_watch(channel, GLib.PRIORITY_DEFAULT, GLib.IOCondition.IN, () => {
        if (destroyed) return false
        try {
          const [status, line] = channel.read_line()
          if (status === GLib.IOStatus.NORMAL && line) {
            const values = line.trim().split(";").filter(Boolean).map(Number)
            for (let i = 0; i < NUM_BARS && i < values.length; i++) {
              if (bars[i]) bars[i].value = (values[i] || 0) / 100
            }
          }
        } catch {}
        return !destroyed
      })

      GLib.child_watch_add(GLib.PRIORITY_DEFAULT, pid, () => {
        GLib.spawn_close_pid(pid)
      })
    } catch {}
  }

  onCleanup(() => {
    destroyed = true
    if (cavaProcess) {
      try { GLib.spawn_command_line_async(`kill ${cavaProcess}`) } catch {}
    }
  })

  return (
    <box
      orientation={Gtk.Orientation.VERTICAL}
      class="dw-viz-card"
      spacing={8}
      $={() => startCava()}
    >
      <box class="dw-viz-header" spacing={6}>
        <image iconName="audio-speakers-symbolic" pixelSize={14} class="dw-viz-header-icon" />
        <label label="AUDIO" class="dw-viz-header-label" />
      </box>
      <box class="dw-viz-bars" spacing={3} halign={Gtk.Align.CENTER} homogeneous>
        {Array.from({ length: NUM_BARS }, (_, i) => (
          <levelbar
            $={(self) => { bars[i] = self }}
            class="dw-viz-bar"
            orientation={Gtk.Orientation.VERTICAL}
            inverted
            value={0}
            maxValue={1}
            minValue={0}
          />
        ))}
      </box>
    </box>
  )
}

// ━━━━━━━━━━━━━━━ NOW PLAYING ━━━━━━━━━━━━━━━━━━━━━━━

function NowPlaying() {
  const mpris = AstalMpris.get_default()
  const players = createBinding(mpris, "players")

  return (
    <box
      class="dw-np-card"
      orientation={Gtk.Orientation.VERTICAL}
      spacing={8}
      visible={players((p) => p.length > 0)}
    >
      <For each={players}>
        {(player) => {
          const title = createBinding(player, "title")
          const artist = createBinding(player, "artist")
          const status = createBinding(player, "playbackStatus")

          return (
            <box orientation={Gtk.Orientation.VERTICAL} spacing={6} class="dw-np-inner">
              <box spacing={6}>
                <image
                  class="dw-np-status-icon"
                  pixelSize={14}
                  iconName={status((s) =>
                    s === AstalMpris.PlaybackStatus.PLAYING
                      ? "media-playback-start-symbolic"
                      : "media-playback-pause-symbolic"
                  )}
                />
                <label label="NOW PLAYING" class="dw-np-header-label" />
              </box>
              <label
                class="dw-np-title"
                label={title((t) => t || "Unknown")}
                xalign={0}
                wrap
                maxWidthChars={28}
              />
              <label
                class="dw-np-artist"
                label={artist((a) => a || "Unknown artist")}
                xalign={0}
                wrap
                maxWidthChars={28}
              />
            </box>
          )
        }}
      </For>
    </box>
  )
}

// ━━━━━━━━━━━━━━━ MAIN WIDGET ━━━━━━━━━━━━━━━━━━━━━━━

export function DesktopWidgets({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
  let win: Astal.Window
  const { TOP, BOTTOM, RIGHT, LEFT } = Astal.WindowAnchor

  // Clock
  const timeStr = createPoll(now("%H:%M"), 1000, () => now("%H:%M"))
  const secStr = createPoll(now("%S"), 1000, () => now("%S"))
  const dateStr = createPoll(now("%A, %B %e"), 60000, () => now("%A, %B %e"))
  const yearStr = createPoll(now("%Y"), 60000, () => now("%Y"))

  // System
  const cpu = createPoll(0, 3000, getCpuUsage)
  const mem = createPoll({ used: 0, total: 0, percent: 0 }, 5000, getMemUsage)
  const disk = createPoll({ used: "0", total: "0", percent: 0 }, 30000, getDiskUsage)
  const uptime = createPoll("—", 60000, getUptime)

  // Weather
  let weatherLabel: Gtk.Label | null = null
  let weatherDesc: Gtk.Label | null = null
  let weatherIcon: Gtk.Image | null = null
  let weatherCity: Gtk.Label | null = null
  let weatherHumidity: Gtk.Label | null = null
  let weatherWind: Gtk.Label | null = null

  const updateWeatherUI = (w: WeatherData) => {
    if (weatherLabel) weatherLabel.label = w.temp
    if (weatherDesc) weatherDesc.label = w.desc
    if (weatherIcon) weatherIcon.iconName = w.icon
    if (weatherCity) weatherCity.label = w.city
    if (weatherHumidity) weatherHumidity.label = w.humidity
    if (weatherWind) weatherWind.label = w.wind
  }

  fetchWeather().then(updateWeatherUI)
  const weatherTimer = setInterval(() => {
    fetchWeather().then(updateWeatherUI)
  }, 900000)

  onCleanup(() => {
    clearInterval(weatherTimer)
    win.destroy()
  })

  return (
    <window
      $={(self) => {
        win = self
        self.set_layer(Astal.Layer.BACKGROUND)
        self.visible = true
      }}
      visible={false}
      namespace="ags-desktop-widgets"
      name="desktop-widgets"
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.NONE}
      keymode={Astal.Keymode.ON_DEMAND}
      anchor={TOP | BOTTOM | LEFT | RIGHT}
      application={app}
    >
      <box class="desktop-widgets" vexpand hexpand>

        {/* ═══ LEFT COLUMN ═══ */}
        <box
          orientation={Gtk.Orientation.VERTICAL}
          spacing={16}
          valign={Gtk.Align.CENTER}
          halign={Gtk.Align.START}
          class="dw-col-left"
        >
          {/* Clock */}
          <box orientation={Gtk.Orientation.VERTICAL} class="dw-clock-card" spacing={2}>
            <box halign={Gtk.Align.CENTER} spacing={4} class="dw-clock-row">
              <label class="dw-clock-time" label={timeStr} />
              <label class="dw-clock-seconds" label={secStr} />
            </box>
            <label class="dw-clock-date" label={dateStr} halign={Gtk.Align.CENTER} />
            <label class="dw-clock-year" label={yearStr} halign={Gtk.Align.CENTER} />
          </box>

          {/* Weather */}
          <box orientation={Gtk.Orientation.VERTICAL} class="dw-weather-card" spacing={10}>
            <box spacing={10}>
              <image
                $={(self) => { weatherIcon = self }}
                iconName="weather-clear-symbolic"
                pixelSize={36}
                class="dw-weather-icon"
              />
              <box orientation={Gtk.Orientation.VERTICAL} spacing={2}>
                <label $={(self) => { weatherLabel = self }} label="—" class="dw-weather-temp" xalign={0} />
                <label $={(self) => { weatherDesc = self }} label="Loading..." class="dw-weather-desc" xalign={0} />
              </box>
            </box>
            <box spacing={12} class="dw-weather-details">
              <box spacing={4}>
                <image iconName="weather-fog-symbolic" pixelSize={12} class="dw-weather-detail-icon" />
                <label $={(self) => { weatherHumidity = self }} label="—" class="dw-weather-detail" />
              </box>
              <box spacing={4}>
                <image iconName="weather-windy-symbolic" pixelSize={12} class="dw-weather-detail-icon" />
                <label $={(self) => { weatherWind = self }} label="—" class="dw-weather-detail" />
              </box>
            </box>
            <label $={(self) => { weatherCity = self }} label="" class="dw-weather-city" xalign={0} />
          </box>

          {/* System Stats */}
          <box orientation={Gtk.Orientation.VERTICAL} class="dw-stats-card" spacing={12}>
            <box class="dw-stats-header" spacing={6}>
              <image iconName="utilities-system-monitor-symbolic" pixelSize={14} class="dw-stats-header-icon" />
              <label label="SYSTEM" class="dw-stats-header-label" />
            </box>
            <box orientation={Gtk.Orientation.VERTICAL} spacing={4}>
              <box>
                <label label="CPU" class="dw-stat-label" hexpand xalign={0} />
                <label class="dw-stat-value" label={cpu((c) => `${c}%`)} />
              </box>
              <levelbar class="dw-stat-bar dw-stat-bar-cpu" value={cpu((c) => c / 100)} maxValue={1} minValue={0} />
            </box>
            <box orientation={Gtk.Orientation.VERTICAL} spacing={4}>
              <box>
                <label label="MEM" class="dw-stat-label" hexpand xalign={0} />
                <label class="dw-stat-value" label={mem((m) => `${m.used}/${m.total} GB`)} />
              </box>
              <levelbar class="dw-stat-bar dw-stat-bar-mem" value={mem((m) => m.percent / 100)} maxValue={1} minValue={0} />
            </box>
            <box orientation={Gtk.Orientation.VERTICAL} spacing={4}>
              <box>
                <label label="DISK" class="dw-stat-label" hexpand xalign={0} />
                <label class="dw-stat-value" label={disk((d) => `${d.used}/${d.total}`)} />
              </box>
              <levelbar class="dw-stat-bar dw-stat-bar-disk" value={disk((d) => d.percent / 100)} maxValue={1} minValue={0} />
            </box>
            <box class="dw-uptime-row" spacing={6}>
              <image iconName="preferences-system-time-symbolic" pixelSize={12} class="dw-uptime-icon" />
              <label class="dw-stat-label" label="UP" hexpand xalign={0} />
              <label class="dw-stat-value" label={uptime()} />
            </box>
          </box>
        </box>

        {/* ═══ SPACER ═══ */}
        <box hexpand />

        {/* ═══ RIGHT COLUMN ═══ */}
        <box
          orientation={Gtk.Orientation.VERTICAL}
          spacing={16}
          valign={Gtk.Align.CENTER}
          halign={Gtk.Align.END}
          class="dw-col-right"
        >
          {/* Now Playing */}
          <NowPlaying />

          {/* Audio Visualizer */}
          <MusicVisualizer />
        </box>

      </box>
    </window>
  )
}
