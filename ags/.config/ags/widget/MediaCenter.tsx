import app from "ags/gtk4/app"
import Astal from "gi://Astal?version=4.0"
import Gtk from "gi://Gtk?version=4.0"
import Gdk from "gi://Gdk?version=4.0"
import GLib from "gi://GLib"
import Gio from "gi://Gio"
import AstalMpris from "gi://AstalMpris"
import { For, createBinding, onCleanup } from "ags"
import { createPoll } from "ags/time"
import { execAsync } from "ags/process"

// ── Types ──────────────────────────────────────────────────────────────
interface YtResult {
  id: string
  title: string
  channel: string
  duration: string
}

// ── Thumbnail cache ────────────────────────────────────────────────────
const thumbCache = new Map<string, string>()
const thumbPending = new Set<string>()
const THUMB_DIR = `${GLib.get_user_cache_dir()}/ags-yt-thumbs`
const YT_DLP = GLib.find_program_in_path("yt-dlp") || "/usr/bin/yt-dlp"

function ensureThumbDir() {
  try { GLib.mkdir_with_parents(THUMB_DIR, 0o755) } catch { /* ignore */ }
}

function fetchThumbnail(id: string, onDone: (path: string) => void) {
  if (thumbCache.has(id)) { onDone(thumbCache.get(id)!); return }
  if (thumbPending.has(id)) return
  thumbPending.add(id)
  ensureThumbDir()

  const dest = `${THUMB_DIR}/${id}.jpg`
  if (GLib.file_test(dest, GLib.FileTest.EXISTS)) {
    thumbCache.set(id, dest)
    thumbPending.delete(id)
    onDone(dest)
    return
  }

  execAsync(["curl", "-sSL", "-o", dest,
    `https://img.youtube.com/vi/${id}/mqdefault.jpg`])
    .then(() => { thumbCache.set(id, dest); thumbPending.delete(id); onDone(dest) })
    .catch(() => { thumbPending.delete(id) })
}

function makeThumbnailWidget(id: string, w: number, h: number): Gtk.Widget {
  const stack = new Gtk.Stack()
  stack.set_size_request(w, h)
  stack.add_css_class("yt-thumb-stack")

  const placeholder = new Gtk.Box()
  placeholder.set_halign(Gtk.Align.CENTER)
  placeholder.set_valign(Gtk.Align.CENTER)
  const icon = Gtk.Image.new_from_icon_name("multimedia-player-symbolic")
  icon.pixel_size = Math.round(w / 3)
  icon.add_css_class("yt-thumb-placeholder")
  placeholder.append(icon)
  stack.add_named(placeholder, "placeholder")
  stack.set_visible_child_name("placeholder")

  const tryLoad = (path: string) => {
    try {
      if (stack.get_child_by_name("image")) {
        stack.set_visible_child_name("image")
        return
      }
      const pic = new Gtk.Picture()
      pic.set_filename(path)
      pic.set_content_fit(Gtk.ContentFit.COVER)
      pic.set_size_request(w, h)
      pic.add_css_class("yt-thumb-img")
      stack.add_named(pic, "image")
      stack.set_visible_child_name("image")
    } catch { /* keep placeholder */ }
  }

  if (thumbCache.has(id)) {
    tryLoad(thumbCache.get(id)!)
  } else {
    fetchThumbnail(id, (path) => {
      if (stack.get_visible_child_name() !== "image") tryLoad(path)
    })
  }

  return stack
}

// ── Embedded YouTube video state ───────────────────────────────────────
let ytVideoVisible = false
let ytVideoReady = false
let ytVideo: Gtk.Video | null = null
let ytMediaStream: Gtk.MediaFile | null = null
let ytTvStack: Gtk.Stack | null = null
let ytPlayToken = 0
let ytUpgradeInFlightFor: string | null = null
const YT_MEDIA_DIR = `${GLib.get_user_cache_dir()}/ags-yt-media`

function ensureYtMediaDir() {
  try { GLib.mkdir_with_parents(YT_MEDIA_DIR, 0o755) } catch { /* ignore */ }
}

function readMediaDurationRaw(): number {
  try { return Number((ytMediaStream as any)?.get_duration?.() || 0) } catch { return 0 }
}

function readMediaTimestampRaw(): number {
  try { return Number((ytMediaStream as any)?.get_timestamp?.() || 0) } catch { return 0 }
}

function mediaUnitsToSeconds(raw: number): number {
  if (!raw || raw <= 0) return 0
  // Gtk/GStreamer time can be ns or us depending on backend layers.
  if (raw > 10_000_000_000) return raw / 1_000_000_000
  if (raw > 10_000_000) return raw / 1_000_000
  return raw
}

function refreshTvMode() {
  if (!ytTvStack) return
  if (!ytNowPlaying) {
    ytTvStack.set_visible_child_name("off")
    return
  }
  ytTvStack.set_visible_child_name(ytVideoVisible && ytVideoReady ? "video" : "thumb")
}

function clearEmbeddedMedia() {
  try {
    if (ytMediaStream) {
      ;(ytMediaStream as any).pause?.()
    }
  } catch { /* ignore */ }
  ytMediaStream = null
  ytVideoReady = false
  try { ytVideo?.set_media_stream(null) } catch { /* ignore */ }
  refreshTvMode()
}

function stopYtAll() {
  ytUpgradeInFlightFor = null
  clearEmbeddedMedia()
  // Best-effort cleanup for legacy processes from previous config versions.
  try { GLib.spawn_command_line_async("pkill -SIGTERM -f 'mpv --no-video'") } catch { /* ignore */ }
  try { GLib.spawn_command_line_async("pkill -SIGTERM -f 'ags-yt-video'") } catch { /* ignore */ }
}

function ytFilePath(videoId: string, quality: "360" | "480"): string {
  return `${YT_MEDIA_DIR}/${videoId}-${quality}.mp4`
}

async function downloadYtToFile(videoId: string, formats: string[], dest: string): Promise<boolean> {
  const watchUrl = `https://www.youtube.com/watch?v=${videoId}`

  const commonArgs = [
    YT_DLP,
    "--no-warnings",
    "--no-playlist",
    "--no-cache-dir",
    "--extractor-args",
    "youtube:player_client=android",
  ]

  for (const format of formats) {
    try {
      await execAsync([
        ...commonArgs,
        "-f",
        format,
        "--force-overwrites",
        "-o",
        dest,
        watchUrl,
      ])
      if (GLib.file_test(dest, GLib.FileTest.EXISTS)) return true
    } catch {
      // Try next format fallback.
    }
  }

  return false
}

async function ensureYtFile360(videoId: string): Promise<string> {
  ensureYtMediaDir()
  const dest = ytFilePath(videoId, "360")
  if (GLib.file_test(dest, GLib.FileTest.EXISTS)) return dest
  const ok = await downloadYtToFile(videoId, [
    // 360p-first startup path, with safe mp4 fallbacks.
    "best[height<=360][ext=mp4][vcodec!=none][acodec!=none]",
    "18",
    "best[height<=360][acodec!=none][vcodec!=none]",
    "best[height<=480][ext=mp4][vcodec!=none][acodec!=none]",
  ], dest)
  if (!ok) throw new Error("Could not download startup stream")
  return dest
}

async function ensureYtFile480(videoId: string): Promise<string> {
  ensureYtMediaDir()
  const dest = ytFilePath(videoId, "480")
  if (GLib.file_test(dest, GLib.FileTest.EXISTS)) return dest
  const ok = await downloadYtToFile(videoId, [
    // 480p target path after startup playback begins.
    "best[height<=480][ext=mp4][vcodec!=none][acodec!=none]",
    "best[height<=480][acodec!=none][vcodec!=none]",
    "best[ext=mp4][vcodec!=none][acodec!=none]",
  ], dest)
  if (!ok) throw new Error("Could not download upgraded stream")
  return dest
}

function swapMediaToFile(filePath: string, token: number, videoId: string) {
  if (token !== ytPlayToken || ytNowPlaying?.id !== videoId) return

  const hadPrevStream = ytMediaStream !== null
  const wasPlaying = (() => {
    if (!hadPrevStream) return true
    try { return Boolean((ytMediaStream as any)?.get_playing?.()) } catch { return true }
  })()
  const prevDur = readMediaDurationRaw()
  const prevPos = readMediaTimestampRaw()
  const prevRatio = prevDur > 0 ? Math.max(0, Math.min(1, prevPos / prevDur)) : 0

  const media = Gtk.MediaFile.new_for_file(Gio.File.new_for_path(filePath))
  media.set_muted(false)
  ytMediaStream = media
  ytVideo?.set_media_stream(media)
  try { (ytMediaStream as any).play?.() } catch { /* ignore */ }

  // Seek once duration becomes available on the new stream.
  let attempts = 0
  GLib.timeout_add(GLib.PRIORITY_DEFAULT, 120, () => {
    if (token !== ytPlayToken || ytNowPlaying?.id !== videoId) return GLib.SOURCE_REMOVE
    attempts++
    const dur = readMediaDurationRaw()
    if (dur > 0) {
      try {
        ;(ytMediaStream as any).seek?.(dur * prevRatio)
        ;(ytMediaStream as any).set_playing?.(hadPrevStream ? wasPlaying : true)
      } catch { /* ignore */ }
      return GLib.SOURCE_REMOVE
    }
    return attempts < 25 ? GLib.SOURCE_CONTINUE : GLib.SOURCE_REMOVE
  })
}

function startBackgroundUpgradeTo480(videoId: string, token: number) {
  if (ytUpgradeInFlightFor === videoId) return
  ytUpgradeInFlightFor = videoId
  ytStatusMsg = "Playing 360p, upgrading to 480p..."

  ensureYtFile480(videoId)
    .then((path) => {
      if (token !== ytPlayToken || ytNowPlaying?.id !== videoId) return
      swapMediaToFile(path, token, videoId)
      ytStatus = "playing"
      ytStatusMsg = ""
    })
    .catch(() => {
      // Keep current 360p playback if upgrade fails.
      if (token === ytPlayToken && ytNowPlaying?.id === videoId) {
        ytStatus = "playing"
        ytStatusMsg = ""
      }
    })
    .finally(() => {
      if (ytUpgradeInFlightFor === videoId) ytUpgradeInFlightFor = null
    })
}

async function playYtEmbedded(track: YtResult) {
  const token = ++ytPlayToken
  ytStatus = "searching"
  ytStatusMsg = "Downloading 360p..."
  ytVideoVisible = true
  ytUpgradeInFlightFor = null
  clearEmbeddedMedia()
  refreshTvMode()

  const filePath = await ensureYtFile360(track.id)
  if (token !== ytPlayToken || ytNowPlaying?.id !== track.id) return

  swapMediaToFile(filePath, token, track.id)

  ytVideoReady = true
  ytStatus = "playing"
  ytStatusMsg = "Playing 360p, upgrading to 480p..."
  refreshTvMode()

  // Upgrade quality in the background and hot-swap when ready.
  startBackgroundUpgradeTo480(track.id, token)
}

function toggleEmbeddedVideo() {
  ytVideoVisible = !ytVideoVisible
  refreshTvMode()
}

// ── YouTube search ─────────────────────────────────────────────────────
async function searchYoutube(query: string): Promise<YtResult[]> {
  if (!query.trim()) return []
  const raw = await execAsync([
    YT_DLP, "--flat-playlist", "--dump-json", "--no-warnings", "--no-playlist",
    `ytsearch8:${query}`,
  ])
  const results: YtResult[] = []
  for (const line of raw.trim().split("\n")) {
    if (!line.trim()) continue
    try {
      const obj = JSON.parse(line) as {
        id?: string; title?: string; uploader?: string
        channel?: string; duration?: number
      }
      const id = obj.id || ""
      if (!id) continue
      const secs = obj.duration || 0
      const m = Math.floor(secs / 60)
      const s = Math.floor(secs % 60)
      results.push({
        id,
        title: obj.title || "Unknown",
        channel: obj.uploader || obj.channel || "Unknown",
        duration: secs > 0 ? `${m}:${s.toString().padStart(2, "0")}` : "",
      })
    } catch { /* skip */ }
  }
  return results
}

// ── Module-level YT state ──────────────────────────────────────────────
let ytStatus: "idle" | "searching" | "playing" | "error" = "idle"
let ytStatusMsg = ""
let ytNowPlaying: YtResult | null = null
let ytSearchDebounce = 0

// ── Imperative result row ─────────────────────────────────────────────
function makeResultRow(
  track: YtResult,
  onPlay: (t: YtResult) => void,
): Gtk.Widget {
  const row = new Gtk.Button()
  row.add_css_class("yt-result-row")
  row.set_tooltip_text(`Play: ${track.title}`)

  const outer = new Gtk.Box({ spacing: 10 })
  outer.set_margin_start(4); outer.set_margin_end(4)
  outer.set_margin_top(2);   outer.set_margin_bottom(2)

  const thumb = makeThumbnailWidget(track.id, 96, 54)
  outer.append(thumb)

  const textCol = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL, spacing: 3 })
  textCol.set_hexpand(true)
  textCol.set_valign(Gtk.Align.CENTER)

  const titleLbl = new Gtk.Label({ xalign: 0 })
  titleLbl.add_css_class("yt-result-title")
  titleLbl.set_ellipsize(3)
  titleLbl.set_max_width_chars(38)
  titleLbl.set_label(track.title)

  const chanLbl = new Gtk.Label({ xalign: 0 })
  chanLbl.add_css_class("yt-result-channel")
  chanLbl.set_label(track.channel)

  textCol.append(titleLbl)
  textCol.append(chanLbl)
  outer.append(textCol)

  const rightCol = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL, spacing: 4 })
  rightCol.set_valign(Gtk.Align.CENTER)
  rightCol.set_halign(Gtk.Align.END)

  const playImg = Gtk.Image.new_from_icon_name("audio-x-generic-symbolic")
  playImg.pixel_size = 16
  playImg.add_css_class("yt-result-icon")
  rightCol.append(playImg)

  if (track.duration) {
    const durLbl = new Gtk.Label()
    durLbl.add_css_class("yt-result-duration")
    durLbl.set_label(track.duration)
    rightCol.append(durLbl)
  }

  outer.append(rightCol)
  row.set_child(outer)

  let wasPlaying = false
  GLib.timeout_add(GLib.PRIORITY_DEFAULT, 200, () => {
    if (!row.get_parent()) return GLib.SOURCE_REMOVE
    const isPlaying = ytNowPlaying?.id === track.id
    if (isPlaying !== wasPlaying) {
      wasPlaying = isPlaying
      if (isPlaying) {
        row.add_css_class("playing")
        playImg.icon_name = "media-playback-start-symbolic"
      } else {
        row.remove_css_class("playing")
        playImg.icon_name = "audio-x-generic-symbolic"
      }
    }
    return GLib.SOURCE_CONTINUE
  })

  row.connect("clicked", () => onPlay(track))
  return row
}

// ── TV: shows current YT thumbnail and embedded video ─────────────────
function MediaTV(): { widget: Gtk.Widget; sourceId: number } {
  const frame = new Gtk.Box()
  frame.add_css_class("mc-tv")
  frame.set_size_request(420, 236)
  frame.set_halign(Gtk.Align.CENTER)

  const stack = new Gtk.Stack()
  stack.set_hexpand(true); stack.set_vexpand(true)
  stack.set_size_request(420, 236)
  ytTvStack = stack
  frame.append(stack)

  // empty / off state
  const offBox = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL, spacing: 6 })
  offBox.set_halign(Gtk.Align.CENTER); offBox.set_valign(Gtk.Align.CENTER)
  const offIcon = Gtk.Image.new_from_icon_name("video-display-symbolic")
  offIcon.pixel_size = 56
  offIcon.add_css_class("mc-tv-off-icon")
  const offLbl = new Gtk.Label({ label: "No signal" })
  offLbl.add_css_class("mc-tv-off-label")
  offBox.append(offIcon); offBox.append(offLbl)
  stack.add_named(offBox, "off")

  const thumbHolder = new Gtk.Box()
  thumbHolder.set_hexpand(true)
  thumbHolder.set_vexpand(true)
  stack.add_named(thumbHolder, "thumb")

  const video = new Gtk.Video()
  video.set_autoplay(true)
  video.set_loop(false)
  video.set_hexpand(true)
  video.set_vexpand(true)
  video.add_css_class("mc-tv-video")
  ytVideo = video
  stack.add_named(video, "video")
  stack.set_visible_child_name("off")

  let lastId = ""
  let thumbPic: Gtk.Picture | null = null
  const sourceId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 250, () => {
    const id = ytNowPlaying?.id || ""
    if (!id) {
      lastId = ""
      if (thumbPic) {
        thumbHolder.remove(thumbPic)
        thumbPic = null
      }
      refreshTvMode()
      return GLib.SOURCE_CONTINUE
    }

    if (id === lastId) {
      refreshTvMode()
      return GLib.SOURCE_CONTINUE
    }

    lastId = id
    if (thumbPic) {
      thumbHolder.remove(thumbPic)
      thumbPic = null
    }

    const dest = `${THUMB_DIR}/${id}.jpg`
    const setPic = (path: string) => {
      const pic = new Gtk.Picture()
      pic.set_filename(path)
      pic.set_content_fit(Gtk.ContentFit.COVER)
      pic.set_hexpand(true)
      pic.set_vexpand(true)
      pic.set_size_request(420, 236)
      pic.add_css_class("mc-tv-img")
      thumbPic = pic
      thumbHolder.append(pic)
      refreshTvMode()
    }

    if (GLib.file_test(dest, GLib.FileTest.EXISTS)) {
      setPic(dest)
    } else {
      ensureThumbDir()
      execAsync(["curl", "-sSL", "-o", dest,
        `https://img.youtube.com/vi/${id}/hqdefault.jpg`])
        .then(() => { if (ytNowPlaying?.id === id) setPic(dest) })
        .catch(() => { refreshTvMode() })
    }

    refreshTvMode()
    return GLib.SOURCE_CONTINUE
  })

  return { widget: frame, sourceId }
}

// ── CAVA visualizer ────────────────────────────────────────────────────
function CavaBars(): { widget: Gtk.Widget; cleanup: () => void } {
  const NUM_BARS = 32
  const bars: Gtk.LevelBar[] = []
  let cavaPid: number | null = null
  let destroyed = false

  const cavaConf = `/tmp/ags-mc-cava-${GLib.get_user_name()}.conf`
  const conf = `[general]
bars = ${NUM_BARS}
framerate = 30
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 100
`
  try { GLib.file_set_contents(cavaConf, conf) } catch { /* ignore */ }

  const container = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL, spacing: 6 })
  container.add_css_class("mc-viz-card")

  const header = new Gtk.Box({ spacing: 6 })
  header.add_css_class("mc-viz-header")
  const hIcon = Gtk.Image.new_from_icon_name("audio-speakers-symbolic")
  hIcon.pixel_size = 12
  hIcon.add_css_class("mc-viz-header-icon")
  const hLbl = new Gtk.Label({ label: "AUDIO SPECTRUM" })
  hLbl.add_css_class("mc-viz-header-label")
  hLbl.set_hexpand(true); hLbl.set_xalign(0)
  header.append(hIcon); header.append(hLbl)
  container.append(header)

  const barsBox = new Gtk.Box({ spacing: 3 })
  barsBox.add_css_class("mc-viz-bars")
  barsBox.set_halign(Gtk.Align.CENTER)
  barsBox.set_homogeneous(true)
  for (let i = 0; i < NUM_BARS; i++) {
    const lb = new Gtk.LevelBar()
    lb.add_css_class("mc-viz-bar")
    lb.set_orientation(Gtk.Orientation.VERTICAL)
    lb.set_inverted(true)
    lb.set_min_value(0); lb.set_max_value(1); lb.set_value(0)
    bars.push(lb)
    barsBox.append(lb)
  }
  container.append(barsBox)

  const start = () => {
    try {
      const [ok, pid, , stdoutFd] = GLib.spawn_async_with_pipes(
        null, ["cava", "-p", cavaConf], null,
        GLib.SpawnFlags.SEARCH_PATH | GLib.SpawnFlags.DO_NOT_REAP_CHILD,
        null,
      )
      if (!ok || !stdoutFd) return
      cavaPid = pid
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
        } catch { /* ignore */ }
        return !destroyed
      })
      GLib.child_watch_add(GLib.PRIORITY_DEFAULT, pid, () => {
        GLib.spawn_close_pid(pid)
      })
    } catch { /* ignore */ }
  }

  start()

  const cleanup = () => {
    destroyed = true
    if (cavaPid) {
      try { GLib.spawn_command_line_async(`kill ${cavaPid}`) } catch { /* ignore */ }
      cavaPid = null
    }
  }

  return { widget: container, cleanup }
}

// ── MPRIS player card ─────────────────────────────────────────────────
function formatMediaTime(seconds: number): string {
  if (!seconds || seconds < 0) return "0:00"
  const m = Math.floor(seconds / 60)
  const s = Math.floor(seconds % 60)
  return `${m}:${s.toString().padStart(2, "0")}`
}

function MprisCard({ player }: { player: AstalMpris.Player }) {
  const title = createBinding(player, "title")
  const artist = createBinding(player, "artist")
  const playbackStatus = createBinding(player, "playbackStatus")
  const canGoPrev = createBinding(player, "canGoPrevious")
  const canGoNext = createBinding(player, "canGoNext")
  const canControl = createBinding(player, "canControl")
  const position = createBinding(player, "position")
  const length = createBinding(player, "length")
  const identity = createBinding(player, "identity")

  return (
    <box class="mc-player-card" orientation={Gtk.Orientation.VERTICAL} spacing={8}>
      <box spacing={10}>
        <box orientation={Gtk.Orientation.VERTICAL} spacing={2} hexpand>
          <label
            class="mc-player-title"
            label={title((t) => t || "Unknown")}
            xalign={0}
            ellipsize={3}
            maxWidthChars={38}
          />
          <label
            class="mc-player-artist"
            label={artist((a) => a || "—")}
            xalign={0}
            ellipsize={3}
            maxWidthChars={38}
          />
        </box>
        <label
          class="mc-player-identity"
          label={identity((id) => id || "Player")}
          valign={Gtk.Align.START}
        />
      </box>

      <box orientation={Gtk.Orientation.VERTICAL} spacing={2}>
        <slider
          class="mc-player-progress"
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
            class="mc-player-time"
            label={position((p) => formatMediaTime(p))}
            hexpand xalign={0}
          />
          <label
            class="mc-player-time"
            label={length((l) => formatMediaTime(l))}
            xalign={1}
          />
        </box>
      </box>

      <box class="mc-player-controls" halign={Gtk.Align.CENTER} spacing={14}>
        <button
          class="mc-player-btn"
          onClicked={() => player.previous()}
          visible={canGoPrev}
          tooltipText="Previous"
        >
          <image iconName="media-skip-backward-symbolic" pixelSize={16} />
        </button>
        <button
          class="mc-player-play"
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
            pixelSize={20}
          />
        </button>
        <button
          class="mc-player-btn"
          onClicked={() => player.next()}
          visible={canGoNext}
          tooltipText="Next"
        >
          <image iconName="media-skip-forward-symbolic" pixelSize={16} />
        </button>
      </box>
    </box>
  )
}

// ── Main popover ──────────────────────────────────────────────────────
export function MediaCenterPopover({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
  const mpris = AstalMpris.get_default()
  const players = createBinding(mpris, "players")

  const statusState     = createPoll("idle" as typeof ytStatus, 200, () => ytStatus)
  const statusMsgState  = createPoll("", 200, () => ytStatusMsg)
  const ytPlayingState  = createPoll(null as YtResult | null, 200, () => ytNowPlaying)
  const videoVisState   = createPoll(false, 300, () => ytVideoVisible)
  const ytIsPlayingState = createPoll(false, 250, () => {
    try { return Boolean((ytMediaStream as any)?.get_playing?.()) } catch { return false }
  })
  const ytSeekState = createPoll(0, 250, () => {
    const durRaw = readMediaDurationRaw()
    const posRaw = readMediaTimestampRaw()
    if (durRaw <= 0 || posRaw < 0) return 0
    const r = posRaw / durRaw
    return Math.max(0, Math.min(1, r))
  })
  const ytTimeState = createPoll("0:00 / 0:00", 250, () => {
    const durSec = mediaUnitsToSeconds(readMediaDurationRaw())
    const posSec = mediaUnitsToSeconds(readMediaTimestampRaw())
    return `${formatMediaTime(posSec)} / ${formatMediaTime(durSec)}`
  })

  let win: Astal.Window | null = null
  const { TOP, LEFT, RIGHT, BOTTOM } = Astal.WindowAnchor

  const hide = () => { if (win) win.visible = false }

  const { widget: tvWidget, sourceId: tvSourceId } = MediaTV()
  const { widget: cavaWidget, cleanup: cavaCleanup } = CavaBars()

  let resultsList: Gtk.Box | null = null
  let emptyBox: Gtk.Widget | null = null

  const playYtTrack = (track: YtResult) => {
    ytNowPlaying = track
    playYtEmbedded(track).catch((error) => {
      ytStatus = "error"
      ytStatusMsg = error instanceof Error ? error.message : "Playback failed"
      clearEmbeddedMedia()
    })
  }

  function rebuildResults(tracks: YtResult[]) {
    if (!resultsList) return
    let child = resultsList.get_first_child()
    while (child) {
      const next = child.get_next_sibling()
      if (child !== emptyBox) resultsList.remove(child)
      child = next
    }
    let prev: Gtk.Widget | null = null
    for (const track of tracks) {
      const row = makeResultRow(track, playYtTrack)
      resultsList.insert_child_after(row, prev)
      prev = row
    }
    if (emptyBox) emptyBox.set_visible(tracks.length === 0)
  }

  onCleanup(() => {
    if (ytSearchDebounce) GLib.source_remove(ytSearchDebounce)
    GLib.source_remove(tvSourceId)
    cavaCleanup()
    stopYtAll()
    win?.destroy()
  })

  const doSearch = (query: string) => {
    if (ytSearchDebounce) { GLib.source_remove(ytSearchDebounce); ytSearchDebounce = 0 }
    if (!query.trim()) {
      ytStatus = "idle"
      ytStatusMsg = ""
      rebuildResults([])
      return
    }
    ytStatus = "searching"
    ytStatusMsg = "Searching..."
    rebuildResults([])

    ytSearchDebounce = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 500, () => {
      ytSearchDebounce = 0
      searchYoutube(query).then((res) => {
        ytStatus = ytNowPlaying ? "playing" : (res.length > 0 ? "idle" : "error")
        ytStatusMsg = res.length > 0 ? "" : "No results found"
        rebuildResults(res)
      }).catch((error) => {
        ytStatus = "error"
        ytStatusMsg = error instanceof Error ? error.message : "Search failed"
        rebuildResults([])
      })
      return GLib.SOURCE_REMOVE
    })
  }

  const stopYtPlayback = () => {
    ytPlayToken++
    stopYtAll()
    ytVideoVisible = false
    ytNowPlaying = null
    ytStatus = "idle"
    ytStatusMsg = ""
    refreshTvMode()
  }

  return (
    <window
      $={(self) => {
        win = self
        const k = new Gtk.EventControllerKey()
        k.connect("key-pressed", (_c, kv) => { if (kv === Gdk.KEY_Escape) hide() })
        self.add_controller(k)
      }}
      visible={false}
      namespace="ags-media-center"
      name="media-center"
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.IGNORE}
      keymode={Astal.Keymode.ON_DEMAND}
      layer={Astal.Layer.OVERLAY}
      anchor={TOP | LEFT | BOTTOM | RIGHT}
      application={app}
    >
      <overlay>
        <button class="popover-backdrop" hexpand vexpand onClicked={hide}><box /></button>

        <box
          $type="overlay"
          class="mc-panel"
          orientation={Gtk.Orientation.VERTICAL}
          halign={Gtk.Align.CENTER}
          valign={Gtk.Align.START}
          marginTop={50}
          marginBottom={50}
          widthRequest={620}
        >
          {/* Header (sticky, outside scroll) */}
          <box class="mc-header" spacing={10}>
            <image iconName="multimedia-player-symbolic" pixelSize={18} class="mc-header-icon" />
            <label class="mc-title" label="Media Center" hexpand xalign={0} />
            <button class="mc-close-btn" onClicked={hide} tooltipText="Close">
              <image iconName="window-close-symbolic" pixelSize={14} />
            </button>
          </box>

          <box class="mc-divider" />

          {/* Scrollable body */}
          <scrolledwindow
            class="mc-scroll"
            vexpand
            hscrollbarPolicy={Gtk.PolicyType.NEVER}
            vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
            propagateNaturalHeight
            maxContentHeight={720}
          >
            <box orientation={Gtk.Orientation.VERTICAL} spacing={0}>
              {/* TV */}
              <box class="mc-tv-row" halign={Gtk.Align.CENTER} marginTop={10}>
                <box $={(self) => { self.append(tvWidget) }} />
              </box>

              {/* YT now-playing label + open-video / stop */}
              <box
                class="mc-tv-controls"
                spacing={8}
                halign={Gtk.Align.CENTER}
                marginTop={6}
                visible={ytPlayingState((np) => np !== null)}
              >
                <label
                  class="mc-tv-title"
                  label={ytPlayingState((np) => np?.title || "")}
                  ellipsize={3}
                  maxWidthChars={42}
                  hexpand
                  xalign={0}
                />
                <button
                  class={videoVisState((v) => `mc-video-btn ${v ? "active" : ""}`)}
                  tooltipText={videoVisState((v) => v ? "Show thumbnail" : "Show embedded video")}
                  onClicked={() => {
                    if (!ytNowPlaying) return
                    if (!ytVideoReady) {
                      playYtEmbedded(ytNowPlaying).catch((error) => {
                        ytStatus = "error"
                        ytStatusMsg = error instanceof Error ? error.message : "Playback failed"
                        clearEmbeddedMedia()
                      })
                      return
                    }
                    toggleEmbeddedVideo()
                  }}
                >
                  <image iconName="camera-video-symbolic" pixelSize={14} />
                </button>
                <button class="mc-stop-btn" onClicked={stopYtPlayback} tooltipText="Stop YouTube">
                  <image iconName="media-playback-stop-symbolic" pixelSize={14} />
                </button>
              </box>

              <box
                class="mc-tv-seek-controls"
                spacing={8}
                halign={Gtk.Align.FILL}
                marginTop={6}
                marginStart={18}
                marginEnd={18}
                visible={ytPlayingState((np) => np !== null)}
              >
                <button
                  class="mc-stop-btn"
                  tooltipText={ytIsPlayingState((p) => p ? "Pause" : "Play")}
                  onClicked={() => {
                    try {
                      const stream = ytMediaStream as any
                      if (!stream) return
                      const playing = Boolean(stream.get_playing?.())
                      stream.set_playing?.(!playing)
                    } catch { /* ignore */ }
                  }}
                >
                  <image
                    iconName={ytIsPlayingState((p) => p ? "media-playback-pause-symbolic" : "media-playback-start-symbolic")}
                    pixelSize={14}
                  />
                </button>

                <slider
                  class="mc-player-progress"
                  hexpand
                  value={ytSeekState}
                  onChangeValue={({ value }) => {
                    try {
                      const stream = ytMediaStream as any
                      if (!stream) return
                      const durRaw = Number(stream.get_duration?.() || 0)
                      if (durRaw <= 0) return
                      const target = Math.max(0, Math.min(1, value)) * durRaw
                      stream.seek?.(target)
                    } catch { /* ignore */ }
                  }}
                />

                <label class="mc-player-time" label={ytTimeState} xalign={1} />
              </box>

              {/* CAVA visualizer */}
              <box class="mc-viz-row" marginTop={10}>
                <box hexpand $={(self) => { self.append(cavaWidget) }} />
              </box>

              <box class="mc-divider" marginTop={10} />

              {/* MPRIS players */}
              <box
                class="mc-players-section"
                orientation={Gtk.Orientation.VERTICAL}
                spacing={8}
                marginTop={10}
                visible={players((p) => p.length > 0)}
              >
                <label class="mc-section-label" label="ACTIVE PLAYERS" xalign={0} />
                <For each={players}>
                  {(player) => <MprisCard player={player} />}
                </For>
              </box>

              <box
                class="mc-no-players"
                visible={players((p) => p.length === 0)}
                halign={Gtk.Align.CENTER}
                marginTop={10}
                marginBottom={6}
              >
                <label class="mc-no-players-label" label="No active media players" />
              </box>

              <box class="mc-divider" marginTop={10} />

              {/* YouTube search */}
              <box class="mc-yt-section" orientation={Gtk.Orientation.VERTICAL} marginTop={8}>
                <box class="yt-search-row" spacing={8}>
                  <image iconName="system-search-symbolic" pixelSize={16} class="yt-search-icon" />
                  <entry
                    class="yt-search-entry"
                    hexpand
                    placeholderText="Search YouTube..."
                    onChanged={(self) => doSearch(self.text)}
                    onActivate={(self) => doSearch(self.text)}
                  />
                </box>

                <box
                  class={statusState((s) => `yt-status-row yt-status-${s}`)}
                  spacing={6}
                  visible={statusMsgState((m) => m.length > 0)}
                >
                  <image
                    iconName={statusState((s) =>
                      s === "searching" ? "view-refresh-symbolic" :
                      s === "error"     ? "dialog-error-symbolic" :
                                          "media-playback-start-symbolic"
                    )}
                    pixelSize={12}
                  />
                  <label class="yt-status-label" label={statusMsgState} hexpand xalign={0} />
                </box>

                <box
                  class="yt-results-list"
                  orientation={Gtk.Orientation.VERTICAL}
                  spacing={3}
                  $={(self) => { resultsList = self }}
                >
                  <box
                    class="yt-empty"
                    orientation={Gtk.Orientation.VERTICAL}
                    spacing={8}
                    halign={Gtk.Align.CENTER}
                    marginTop={20} marginBottom={20}
                    $={(self) => { emptyBox = self }}
                  >
                    <image iconName="multimedia-player-symbolic" pixelSize={36} class="yt-empty-icon" />
                    <label
                      class="yt-empty-label"
                      label={statusState((s) => s === "searching" ? "Searching..." : "Search YouTube to play media")}
                    />
                  </box>
                </box>
              </box>
            </box>
          </scrolledwindow>
        </box>
      </overlay>
    </window>
  )
}

// ── Bar button ────────────────────────────────────────────────────────
export function MediaCenterButton() {
  const mpris = AstalMpris.get_default()
  const players = createBinding(mpris, "players")

  // active player = first PLAYING; fallback to first player
  const activePlayer = players((list) => {
    if (list.length === 0) return null
    const playing = list.find((p) =>
      p.playbackStatus === AstalMpris.PlaybackStatus.PLAYING
    )
    return playing || list[0]
  })

  // re-bind title/status when the active player changes
  const labelBinding = activePlayer((p) => {
    if (!p) return "MEDIA"
    const t = p.title || ""
    if (!t) return p.identity || "MEDIA"
    return t.length > 24 ? t.substring(0, 21) + "..." : t
  })

  const iconBinding = activePlayer((p) => {
    if (!p) return "multimedia-player-symbolic"
    return p.playbackStatus === AstalMpris.PlaybackStatus.PLAYING
      ? "media-playback-start-symbolic"
      : "media-playback-pause-symbolic"
  })

  return (
    <box class="mc-bar-btn">
      <button
        onClicked={() => {
          const win = app.get_window("media-center")
          if (win) win.visible = !win.visible
        }}
        tooltipText="Media Center"
      >
        <box spacing={6}>
          <image iconName={iconBinding} pixelSize={14} />
          <label class="mc-bar-label" label={labelBinding} />
        </box>
      </button>
    </box>
  )
}
