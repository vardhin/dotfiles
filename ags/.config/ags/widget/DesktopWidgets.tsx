import app from "ags/gtk4/app"
import GLib from "gi://GLib"
import Astal from "gi://Astal?version=4.0"
import Gtk from "gi://Gtk?version=4.0"
import Gdk from "gi://Gdk?version=4.0"
import { onCleanup } from "ags"
import { createPoll } from "ags/time"
import {
  getMediaCenterDesktopVideoState,
  getMediaCenterNowPlayingState,
  makeMediaCenterVideoEffectSurface,
  makeMediaCenterVideoSettingsButton,
  type MediaCenterVideoEffectSurface,
  seekMediaCenterVideo,
  subscribeMediaCenterVideoSurface,
  toggleMediaCenterVideoPlayback,
  updateMediaCenterAudioSpectrum,
} from "./MediaCenter"

interface CpuSample {
  total: number
  idle: number
}

let lastCpuSample: CpuSample | null = null

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
    const idle = (parts[3] || 0) + (parts[4] || 0)
    const total = parts.reduce((a, b) => a + b, 0)

    const sample: CpuSample = { total, idle }
    if (!lastCpuSample) {
      lastCpuSample = sample
      return 0
    }

    const totalDelta = total - lastCpuSample.total
    const idleDelta = idle - lastCpuSample.idle
    lastCpuSample = sample

    if (totalDelta <= 0) return 0
    return Math.max(0, Math.min(100, Math.round(((totalDelta - idleDelta) / totalDelta) * 100)))
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
    const [ok, stdout] = GLib.spawn_command_line_sync("df -h /")
    if (!ok || !stdout) return { used: "0", total: "0", percent: 0 }
    const lines = new TextDecoder().decode(stdout).trim().split("\n")
    if (lines.length < 2) return { used: "0", total: "0", percent: 0 }
    const parts = lines[lines.length - 1].trim().split(/\s+/)
    const percent = Number((parts[4] || "0").replace("%", ""))
    return {
      total: parts[1] || "0",
      used: parts[2] || "0",
      percent: Number.isFinite(percent) ? Math.max(0, Math.min(100, percent)) : 0,
    }
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

function formatMediaTime(seconds: number): string {
  if (!Number.isFinite(seconds) || seconds < 0) return "0:00"
  const whole = Math.floor(seconds)
  const minutes = Math.floor(whole / 60)
  const secs = whole % 60
  return `${minutes}:${secs.toString().padStart(2, "0")}`
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
            updateMediaCenterAudioSpectrum(values)
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
  // This is the same arbitration used by the Media Center bar marquee:
  // internal YouTube playback first, otherwise the playing MPRIS client.
  const nowPlaying = createPoll(getMediaCenterNowPlayingState(), 200, getMediaCenterNowPlayingState)

  return (
    <box
      class="dw-np-card"
      orientation={Gtk.Orientation.VERTICAL}
      spacing={8}
      visible={nowPlaying((state) => state.available)}
    >
      <box orientation={Gtk.Orientation.VERTICAL} spacing={6} class="dw-np-inner">
        <box spacing={6}>
          <image
            class="dw-np-status-icon"
            pixelSize={14}
            iconName={nowPlaying((state) => state.playing
              ? "media-playback-pause-symbolic"
              : "media-playback-start-symbolic")}
          />
          <label label="NOW PLAYING" class="dw-np-header-label" />
          <label
            label={nowPlaying((state) => state.source === "youtube" ? "YT" : "MPRIS")}
            class="dw-np-source"
            hexpand
            xalign={1}
          />
        </box>
        <label
          class="dw-np-title"
          label={nowPlaying((state) => state.title || "Unknown")}
          xalign={0}
          wrap
          maxWidthChars={28}
        />
        <label
          class="dw-np-artist"
          label={nowPlaying((state) => state.artist || "Unknown artist")}
          xalign={0}
          wrap
          maxWidthChars={28}
        />
      </box>
    </box>
  )
}

// ━━━━━━━━━━━━━━━ AMBIENT MEDIA VIDEO ━━━━━━━━━━━━━━

function AmbientMediaVideo() {
  let card: Gtk.Box | null = null
  let surface: Gtk.Stack | null = null
  let fallbackVideo: Gtk.Video | null = null
  let effectSurface: MediaCenterVideoEffectSurface | null = null
  let ambientPicture: Gtk.Picture | null = null
  let playIcon: Gtk.Image | null = null
  let seek: Gtk.Scale | null = null
  let time: Gtk.Label | null = null
  let effectBadge: Gtk.Label | null = null
  let media: Gtk.MediaStream | null = null
  let texture: Gdk.Texture | null = null
  let ambientPaintable: Gdk.Paintable | null = null
  let lastVisible = false
  let updatingSeek = false

  const setVisible = (visible: boolean) => {
    if (card) card.visible = visible
    lastVisible = visible
  }

  const syncVideoSurface = () => {
    if (!card || !surface || !fallbackVideo || !effectSurface || !ambientPicture) return
    const state = getMediaCenterDesktopVideoState()
    const mediaCenterVisible = Boolean(app.get_window("media-center")?.visible)
    // Keep the card visible while paused so its play button can resume it.
    const shouldShow = state.ready && !mediaCenterVisible

    if (!shouldShow) {
      if (texture) {
        texture = null
        effectSurface.setTexture(null)
      }
      if (ambientPaintable) {
        ambientPaintable = null
        ambientPicture.set_paintable(null)
      }
      if (media) {
        media = null
        fallbackVideo.set_media_stream(null)
      }
      if (lastVisible) setVisible(false)
      return
    }

    if (state.ambientPaintable !== ambientPaintable) {
      ambientPaintable = state.ambientPaintable
      ambientPicture.set_paintable(ambientPaintable)
    }

    if (state.texture) {
      if (state.texture !== texture) {
        texture = state.texture
        effectSurface.setTexture(texture)
      }
      if (media) {
        media = null
        fallbackVideo.set_media_stream(null)
      }
      if (surface.get_visible_child_name() !== "filtered") {
        surface.set_visible_child_name("filtered")
      }
    } else {
      if (texture) {
        texture = null
        effectSurface.setTexture(null)
      }
      // Reuse the Media Center stream only until the filtered surface exists;
      // this never creates a second media/audio pipeline.
      if (state.mediaStream !== media) {
        media = state.mediaStream
        fallbackVideo.set_media_stream(media)
      }
      if (surface.get_visible_child_name() !== "fallback") {
        surface.set_visible_child_name("fallback")
      }
    }

    if (!lastVisible) setVisible(true)
  }

  const syncVideoControls = () => {
    const state = getMediaCenterDesktopVideoState()

    if (playIcon) {
      const iconName = state.playing
        ? "media-playback-pause-symbolic"
        : "media-playback-start-symbolic"
      if (playIcon.icon_name !== iconName) playIcon.icon_name = iconName
    }
    if (seek) {
      const ratio = state.durationSeconds > 0
        ? Math.max(0, Math.min(1, state.positionSeconds / state.durationSeconds))
        : 0
      if (Math.abs(seek.get_value() - ratio) >= 0.0005) {
        updatingSeek = true
        seek.set_value(ratio)
        updatingSeek = false
      }
      const seekable = state.durationSeconds > 0
      if (seek.sensitive !== seekable) seek.sensitive = seekable
    }
    if (time) {
      const label = `${formatMediaTime(state.positionSeconds)} / ${formatMediaTime(state.durationSeconds)}`
      if (time.label !== label) time.label = label
    }
    if (effectBadge) {
      const names: Record<string, string> = {
        original: "ORIGINAL",
        mono: "MONO",
        rgb332: "8-BIT",
        rgb565: "16-BIT",
        full: "24-BIT",
      }
      const label = names[state.effectMode] || state.effectMode.toUpperCase()
      if (effectBadge.label !== label) effectBadge.label = label
    }
  }

  const unsubscribeSurface = subscribeMediaCenterVideoSurface(syncVideoSurface)
  let initialSyncId = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
    initialSyncId = 0
    syncVideoSurface()
    syncVideoControls()
    return GLib.SOURCE_REMOVE
  })

  const sourceId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 250, () => {
    syncVideoControls()
    return GLib.SOURCE_CONTINUE
  })

  onCleanup(() => {
    if (initialSyncId) GLib.source_remove(initialSyncId)
    GLib.source_remove(sourceId)
    unsubscribeSurface()
    fallbackVideo?.set_media_stream(null)
    effectSurface?.setTexture(null)
    ambientPicture?.set_paintable(null)
    media = null
    texture = null
    ambientPaintable = null
  })

  return (
    <box
      $={(self) => {
        card = self
        self.visible = false
      }}
      class="dw-video-card"
      orientation={Gtk.Orientation.VERTICAL}
      spacing={8}
    >
      <box class="dw-video-header" spacing={6}>
        <image iconName="camera-video-symbolic" pixelSize={14} class="dw-video-header-icon" />
        <label label="VIDEO" class="dw-video-header-label" hexpand xalign={0} />
        <label
          $={(self) => { effectBadge = self }}
          label="8-BIT"
          class="dw-video-effect-badge"
        />
        <box
          class="dw-video-settings-slot"
          $={(self) => { self.append(makeMediaCenterVideoSettingsButton("dw-video-settings-btn")) }}
        />
      </box>
      <overlay
        $={(self) => { self.set_overflow(Gtk.Overflow.HIDDEN) }}
        class="dw-video-stage"
        widthRequest={324}
        heightRequest={182}
        halign={Gtk.Align.CENTER}
      >
        <box
          $={(self) => {
            const ambient = new Gtk.Picture()
            ambient.set_content_fit(Gtk.ContentFit.FILL)
            ambient.set_can_shrink(true)
            ambient.set_hexpand(true)
            ambient.set_vexpand(true)
            ambient.set_can_target(false)
            ambient.add_css_class("dw-video-ambient-light")
            ambientPicture = ambient
            self.append(ambient)
          }}
          class="dw-video-ambient"
          hexpand
          vexpand
        />
        <box
          $type="overlay"
          $={(self) => {
            self.set_overflow(Gtk.Overflow.HIDDEN)
            const videoStack = new Gtk.Stack()
            videoStack.set_size_request(240, 135)
            videoStack.set_halign(Gtk.Align.CENTER)
            videoStack.set_valign(Gtk.Align.CENTER)
            videoStack.set_overflow(Gtk.Overflow.HIDDEN)
            videoStack.set_transition_type(Gtk.StackTransitionType.NONE)
            videoStack.add_css_class("dw-video-player-shell")

            const mediaVideo = new Gtk.Video()
            mediaVideo.set_autoplay(true)
            mediaVideo.set_loop(false)
            mediaVideo.set_hexpand(true)
            mediaVideo.set_vexpand(true)
            mediaVideo.add_css_class("dw-video-player")
            fallbackVideo = mediaVideo

            const filtered = makeMediaCenterVideoEffectSurface(
              "dw-video-player",
              "dw-video-filtered",
            )
            effectSurface = filtered

            videoStack.add_named(mediaVideo, "fallback")
            videoStack.add_named(filtered.widget, "filtered")
            videoStack.set_visible_child_name("fallback")
            surface = videoStack
            self.append(videoStack)
          }}
          class="dw-video-surface"
          widthRequest={240}
          heightRequest={135}
          halign={Gtk.Align.CENTER}
          valign={Gtk.Align.CENTER}
        />
        <box
          $type="overlay"
          class="dw-video-scrim"
          widthRequest={240}
          heightRequest={135}
          halign={Gtk.Align.CENTER}
          valign={Gtk.Align.CENTER}
        />
      </overlay>
      <box class="dw-video-controls" spacing={7}>
        <button
          class="dw-video-play"
          tooltipText="Play or pause"
          onClicked={toggleMediaCenterVideoPlayback}
        >
          <image
            $={(self) => { playIcon = self }}
            iconName="media-playback-pause-symbolic"
            pixelSize={14}
          />
        </button>
        <slider
          $={(self) => { seek = self }}
          class="dw-video-seek"
          hexpand
          value={0}
          onChangeValue={({ value }) => {
            if (!updatingSeek) seekMediaCenterVideo(value)
          }}
        />
        <label
          $={(self) => { time = self }}
          class="dw-video-time"
          label="0:00 / 0:00"
          xalign={1}
        />
      </box>
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

  onCleanup(() => {
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
              <label class="dw-stat-value" label={uptime} />
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
          {/* Media Center video mirror */}
          <AmbientMediaVideo />

          {/* Now Playing */}
          <NowPlaying />

          {/* Audio Visualizer */}
          <MusicVisualizer />
        </box>

      </box>
    </window>
  )
}
