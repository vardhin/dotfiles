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

interface DownloadedVideoGroup {
  id: string
  qualities: string[]
}

interface VideoMeta {
  title?: string
  channel?: string
  duration?: string
}

interface PlaylistEntry {
  id: string
  name: string
  itemIds: string[]
  coverVideoId: string | null
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
let ytDownloadPid: number | null = null
let ytDownloadProgress = 0
let ytDownloadQuality: "360" | "480" | null = null
let ytCurrentQuality: "360" | "480" | null = null
const YT_MEDIA_DIR = `${GLib.get_home_dir()}/Video/TV`
const YT_META_FILE = `${YT_MEDIA_DIR}/video-meta.json`
const YT_PLAYLISTS_FILE = `${YT_MEDIA_DIR}/playlists.json`
const ytVideoMeta = new Map<string, VideoMeta>()
const ytMetaFetchPending = new Set<string>()
let ytPlaylists: PlaylistEntry[] = []
let ytPlaylistsLoaded = false
let ytUiRefreshHook: (() => void) | null = null
let ytActivePlaylistId: string | null = null
let ytActivePlaylistMode: "sequential" | "shuffle" | null = null
let ytActivePlaylistIndex = -1
let ytActiveShuffleBag: string[] = []
let ytLastPlaylistPlayedId: string | null = null

function ensureYtMediaDir() {
  try { GLib.mkdir_with_parents(YT_MEDIA_DIR, 0o755) } catch { /* ignore */ }
}

function loadYtVideoMeta() {
  ensureYtMediaDir()
  try {
    const [ok, bytes] = GLib.file_get_contents(YT_META_FILE)
    if (!ok) return
    const parsed = JSON.parse(new TextDecoder().decode(bytes)) as Record<string, VideoMeta>
    for (const [id, meta] of Object.entries(parsed)) {
      if (!id) continue
      ytVideoMeta.set(id, {
        title: meta.title || "",
        channel: meta.channel || "",
        duration: meta.duration || "",
      })
    }
  } catch { /* ignore */ }
}

function saveYtVideoMeta() {
  ensureYtMediaDir()
  try {
    const obj: Record<string, VideoMeta> = {}
    for (const [id, meta] of ytVideoMeta.entries()) obj[id] = meta
    GLib.file_set_contents(YT_META_FILE, JSON.stringify(obj, null, 2))
  } catch { /* ignore */ }
}

function loadYtPlaylists() {
  ensureYtMediaDir()
  ytPlaylistsLoaded = true
  ytPlaylists = []
  try {
    const [ok, bytes] = GLib.file_get_contents(YT_PLAYLISTS_FILE)
    if (!ok) return
    const parsed = JSON.parse(new TextDecoder().decode(bytes)) as PlaylistEntry[]
    if (!Array.isArray(parsed)) return
    ytPlaylists = parsed
      .filter((p) => p && typeof p.id === "string" && typeof p.name === "string")
      .map((p) => ({
        id: p.id,
        name: p.name,
        itemIds: Array.isArray(p.itemIds) ? p.itemIds.filter((x) => typeof x === "string") : [],
        coverVideoId: typeof p.coverVideoId === "string" ? p.coverVideoId : null,
      }))
  } catch { /* ignore */ }
}

function saveYtPlaylists() {
  ensureYtMediaDir()
  try {
    GLib.file_set_contents(YT_PLAYLISTS_FILE, JSON.stringify(ytPlaylists, null, 2))
  } catch { /* ignore */ }
}

function upsertVideoMeta(id: string, meta: VideoMeta) {
  const prev = ytVideoMeta.get(id) || {}
  ytVideoMeta.set(id, {
    title: meta.title || prev.title || "",
    channel: meta.channel || prev.channel || "",
    duration: meta.duration || prev.duration || "",
  })
  saveYtVideoMeta()
}

function queueFetchVideoMeta(id: string) {
  if (!id) return
  const existing = ytVideoMeta.get(id)
  if (existing?.title) return
  if (ytMetaFetchPending.has(id)) return
  ytMetaFetchPending.add(id)

  const watchUrl = `https://www.youtube.com/watch?v=${id}`
  execAsync([
    YT_DLP,
    "--no-warnings",
    "--no-playlist",
    "--extractor-args",
    "youtube:player_client=android",
    "--skip-download",
    "--print",
    "%(title)s|||%(channel)s|||%(duration_string)s",
    watchUrl,
  ])
    .then((raw: string) => {
      const line = (raw || "").trim().split("\n")[0] || ""
      const [title, channel, duration] = line.split("|||")
      upsertVideoMeta(id, {
        title: (title || "").trim(),
        channel: (channel || "").trim(),
        duration: (duration || "").trim(),
      })
      ytUiRefreshHook?.()
    })
    .catch(() => { /* ignore */ })
    .finally(() => {
      ytMetaFetchPending.delete(id)
    })
}

function getPlaylistById(id: string | null): PlaylistEntry | null {
  if (!id) return null
  return ytPlaylists.find((p) => p.id === id) || null
}

function makeShuffledBag(items: string[], lastPlayed: string | null): string[] {
  const arr = [...items]
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    const tmp = arr[i]
    arr[i] = arr[j]
    arr[j] = tmp
  }
  if (arr.length > 1 && lastPlayed && arr[0] === lastPlayed) {
    const tmp = arr[0]
    arr[0] = arr[1]
    arr[1] = tmp
  }
  return arr
}

function resetYtDownloadState() {
  ytDownloadPid = null
  ytDownloadProgress = 0
  ytDownloadQuality = null
}

function stopYtDownloader() {
  if (ytDownloadPid !== null) {
    try { GLib.spawn_command_line_async(`kill -SIGTERM ${ytDownloadPid}`) } catch { /* ignore */ }
    ytDownloadPid = null
  }
  ytDownloadProgress = 0
  ytDownloadQuality = null
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
  stopYtDownloader()
  clearEmbeddedMedia()
  // Best-effort cleanup for legacy processes from previous config versions.
  try { GLib.spawn_command_line_async("pkill -SIGTERM -f 'mpv --no-video'") } catch { /* ignore */ }
  try { GLib.spawn_command_line_async("pkill -SIGTERM -f 'ags-yt-video'") } catch { /* ignore */ }
}

function ytFilePath(videoId: string, quality: "360" | "480"): string {
  return `${YT_MEDIA_DIR}/${videoId}-${quality}.mp4`
}

async function downloadYtToFile(
  videoId: string,
  formats: string[],
  dest: string,
  quality: "360" | "480",
  token: number,
): Promise<boolean> {
  const watchUrl = `https://www.youtube.com/watch?v=${videoId}`

  const commonArgs = [
    YT_DLP,
    "--no-warnings",
    "--no-playlist",
    "--no-cache-dir",
    "--extractor-args",
    "youtube:player_client=android",
  ]

  const runSingleDownload = (format: string): Promise<boolean> => {
    return new Promise((resolve) => {
      try {
        const argv = [
          ...commonArgs,
          "-f",
          format,
          "--newline",
          "--progress",
          "--force-overwrites",
          "-o",
          dest,
          watchUrl,
        ]

        const [ok, pid, , stdoutFd, stderrFd] = GLib.spawn_async_with_pipes(
          null,
          argv,
          null,
          GLib.SpawnFlags.SEARCH_PATH | GLib.SpawnFlags.DO_NOT_REAP_CHILD,
          null,
        )
        if (!ok || !pid) { resolve(false); return }

        ytDownloadPid = pid
        ytDownloadQuality = quality
        ytDownloadProgress = 0

        const progressRegex = /(\d{1,3}(?:\.\d+)?)%/
        const parseLine = (line: string | null) => {
          if (!line) return
          const m = line.match(progressRegex)
          if (!m) return
          const pct = Number(m[1])
          if (!Number.isFinite(pct)) return
          ytDownloadProgress = Math.max(0, Math.min(100, pct))
        }

        const stdoutCh = GLib.IOChannel.unix_new(stdoutFd)
        const stderrCh = GLib.IOChannel.unix_new(stderrFd)
        stdoutCh.set_flags(GLib.IOFlags.NONBLOCK)
        stderrCh.set_flags(GLib.IOFlags.NONBLOCK)

        const watchFn = (ch: any) => {
          try {
            while (true) {
              const [status, line] = ch.read_line()
              if (status === GLib.IOStatus.NORMAL) {
                parseLine(line)
                continue
              }
              break
            }
          } catch { /* ignore */ }
          return true
        }

        const outWatch = GLib.io_add_watch(stdoutCh, GLib.PRIORITY_DEFAULT, GLib.IOCondition.IN, () => watchFn(stdoutCh))
        const errWatch = GLib.io_add_watch(stderrCh, GLib.PRIORITY_DEFAULT, GLib.IOCondition.IN, () => watchFn(stderrCh))

        GLib.child_watch_add(GLib.PRIORITY_DEFAULT, pid, () => {
          try { GLib.source_remove(outWatch) } catch { /* ignore */ }
          try { GLib.source_remove(errWatch) } catch { /* ignore */ }
          try { GLib.spawn_close_pid(pid) } catch { /* ignore */ }
          if (ytDownloadPid === pid) ytDownloadPid = null

          if (token !== ytPlayToken || ytNowPlaying?.id !== videoId) {
            resolve(false)
            return
          }

          if (GLib.file_test(dest, GLib.FileTest.EXISTS)) {
            ytDownloadProgress = 100
            resolve(true)
            return
          }
          resolve(false)
        })
      } catch {
        resolve(false)
      }
    })
  }

  for (const format of formats) {
    try {
      const ok = await runSingleDownload(format)
      if (ok) return true
    } catch {
      // Try next format fallback.
    }
  }

  return false
}

async function ensureYtFile360(videoId: string, token: number): Promise<string> {
  ensureYtMediaDir()
  const dest = ytFilePath(videoId, "360")
  if (GLib.file_test(dest, GLib.FileTest.EXISTS)) return dest
  const ok = await downloadYtToFile(videoId, [
    // 360p-first startup path, with safe mp4 fallbacks.
    "best[height<=360][ext=mp4][vcodec!=none][acodec!=none]",
    "18",
    "best[height<=360][acodec!=none][vcodec!=none]",
    "best[height<=480][ext=mp4][vcodec!=none][acodec!=none]",
  ], dest, "360", token)
  if (!ok) throw new Error("Could not download startup stream")
  return dest
}

async function ensureYtFile480(videoId: string, token: number): Promise<string> {
  ensureYtMediaDir()
  const dest = ytFilePath(videoId, "480")
  if (GLib.file_test(dest, GLib.FileTest.EXISTS)) return dest
  const ok = await downloadYtToFile(videoId, [
    // 480p target path after startup playback begins.
    "best[height<=480][ext=mp4][vcodec!=none][acodec!=none]",
    "best[height<=480][acodec!=none][vcodec!=none]",
    "best[ext=mp4][vcodec!=none][acodec!=none]",
  ], dest, "480", token)
  if (!ok) throw new Error("Could not download upgraded stream")
  return dest
}

function swapMediaToFile(filePath: string, token: number, videoId: string, quality: "360" | "480") {
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
  ytCurrentQuality = quality
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

  ensureYtFile480(videoId, token)
    .then((path) => {
      if (token !== ytPlayToken || ytNowPlaying?.id !== videoId) return
      swapMediaToFile(path, token, videoId, "480")
      ytStatus = "playing"
      ytStatusMsg = ""
      resetYtDownloadState()
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
  ytCurrentQuality = null
  ytStatus = "searching"
  ytStatusMsg = "Downloading 360p..."
  ytVideoVisible = true
  ytUpgradeInFlightFor = null
  stopYtDownloader()
  clearEmbeddedMedia()
  refreshTvMode()

  const cached480 = ytFilePath(track.id, "480")
  if (GLib.file_test(cached480, GLib.FileTest.EXISTS)) {
    swapMediaToFile(cached480, token, track.id, "480")
    ytVideoReady = true
    ytStatus = "playing"
    ytStatusMsg = ""
    refreshTvMode()
    return
  }

  const filePath = await ensureYtFile360(track.id, token)
  if (token !== ytPlayToken || ytNowPlaying?.id !== track.id) return

  swapMediaToFile(filePath, token, track.id, "360")

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

async function listDownloadedVideoGroups(): Promise<DownloadedVideoGroup[]> {
  ensureYtMediaDir()
  let raw = ""
  try {
    raw = await execAsync([
      "find",
      YT_MEDIA_DIR,
      "-maxdepth",
      "1",
      "-type",
      "f",
      "-name",
      "*.mp4",
    ])
  } catch {
    return []
  }

  const groups = new Map<string, Set<string>>()
  for (const line of raw.split("\n")) {
    const path = line.trim()
    if (!path) continue
    const file = path.split("/").pop() || ""
    const m = file.match(/^(.+)-(\d{3,4})\.mp4$/)
    if (!m) continue
    const id = m[1]
    const q = m[2]
    if (!groups.has(id)) groups.set(id, new Set<string>())
    groups.get(id)!.add(q)
  }

  return Array.from(groups.entries())
    .map(([id, set]) => ({
      id,
      qualities: Array.from(set).sort((a, b) => Number(a) - Number(b)),
    }))
    .sort((a, b) => a.id.localeCompare(b.id))
}

function makeDownloadedRow(
  item: DownloadedVideoGroup,
  onPlay: (id: string) => void,
  onToggleInPlaylist: (id: string) => void,
  isInActivePlaylist: (id: string) => boolean,
  hasActivePlaylist: () => boolean,
): Gtk.Widget {
  const row = new Gtk.Box({ spacing: 8 })
  row.add_css_class("mc-downloaded-row")

  const playBtn = new Gtk.Button()
  playBtn.set_tooltip_text(`Play downloaded: ${item.id}`)
  playBtn.add_css_class("mc-downloaded-play")

  const outer = new Gtk.Box({ spacing: 10 })
  outer.set_margin_start(4); outer.set_margin_end(4)
  outer.set_margin_top(2);   outer.set_margin_bottom(2)

  const thumb = makeThumbnailWidget(item.id, 96, 54)
  outer.append(thumb)

  const textCol = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL, spacing: 3 })
  textCol.set_hexpand(true)
  textCol.set_valign(Gtk.Align.CENTER)

  const titleLbl = new Gtk.Label({ xalign: 0 })
  titleLbl.add_css_class("yt-result-title")
  titleLbl.set_ellipsize(3)
  titleLbl.set_max_width_chars(38)
  const meta = ytVideoMeta.get(item.id)
  titleLbl.set_label(meta?.title || `Saved video (${item.id})`)
  if (!meta?.title) queueFetchVideoMeta(item.id)

  const infoLbl = new Gtk.Label({ xalign: 0 })
  infoLbl.add_css_class("yt-result-channel")
  infoLbl.set_label(item.qualities.map((q) => `${q}p`).join("  •  "))

  textCol.append(titleLbl)
  textCol.append(infoLbl)
  outer.append(textCol)

  const playImg = Gtk.Image.new_from_icon_name("media-playback-start-symbolic")
  playImg.pixel_size = 16
  playImg.add_css_class("yt-result-icon")
  outer.append(playImg)

  playBtn.set_child(outer)
  playBtn.connect("clicked", () => onPlay(item.id))
  row.append(playBtn)

  const listBtn = new Gtk.Button()
  listBtn.add_css_class("mc-downloaded-add")
  listBtn.set_tooltip_text("Add/remove in selected playlist")
  const listIcon = Gtk.Image.new_from_icon_name("list-add-symbolic")
  listIcon.pixel_size = 14
  listBtn.set_child(listIcon)
  listBtn.connect("clicked", () => onToggleInPlaylist(item.id))
  row.append(listBtn)

  GLib.timeout_add(GLib.PRIORITY_DEFAULT, 300, () => {
    if (!row.get_parent()) return GLib.SOURCE_REMOVE
    const hasSel = hasActivePlaylist()
    listBtn.set_sensitive(hasSel)
    const inPl = hasSel && isInActivePlaylist(item.id)
    if (inPl) {
      listBtn.add_css_class("active")
      listIcon.icon_name = "emblem-ok-symbolic"
    } else {
      listBtn.remove_css_class("active")
      listIcon.icon_name = "list-add-symbolic"
    }
    return GLib.SOURCE_CONTINUE
  })

  return row
}

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
  const ytQualityState = createPoll("", 200, () => ytCurrentQuality ? `${ytCurrentQuality}p` : "")
  const ytDownloadState = createPoll("", 200, () => {
    if (!ytDownloadQuality) return ""
    return `${ytDownloadQuality}p ${Math.round(ytDownloadProgress)}%`
  })
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
  const activePlaylistState = createPoll("", 300, () => {
    const p = getPlaylistById(ytActivePlaylistId)
    return p ? `Selected: ${p.name}` : "Select playlist to add/remove tracks"
  })

  let win: Astal.Window | null = null
  const { TOP, LEFT, RIGHT, BOTTOM } = Astal.WindowAnchor

  const hide = () => { if (win) win.visible = false }

  const { widget: tvWidget, sourceId: tvSourceId } = MediaTV()
  const { widget: cavaWidget, cleanup: cavaCleanup } = CavaBars()

  let resultsList: Gtk.Box | null = null
  let emptyBox: Gtk.Widget | null = null
  let downloadedList: Gtk.Box | null = null
  let downloadedEmpty: Gtk.Widget | null = null
  let downloadedSig = ""
  let downloadedRefreshId = 0
  let downloadedScanBusy = false
  let playlistList: Gtk.Box | null = null
  let playlistEmpty: Gtk.Widget | null = null
  let playlistNameEntry: Gtk.Entry | null = null
  let playlistAdvanceWatchId = 0
  let playlistEndedLatch = false

  if (!ytPlaylistsLoaded) loadYtPlaylists()
  loadYtVideoMeta()

  const notifyListsChanged = () => {
    refreshDownloaded()
    rebuildPlaylists(ytPlaylists)
  }
  ytUiRefreshHook = notifyListsChanged

  const playNextFromActivePlaylist = () => {
    const playlist = getPlaylistById(ytActivePlaylistId)
    if (!playlist || playlist.itemIds.length === 0) return

    if (ytActivePlaylistMode === "shuffle") {
      if (ytActiveShuffleBag.length === 0) {
        ytActiveShuffleBag = makeShuffledBag(playlist.itemIds, ytLastPlaylistPlayedId)
      }
      const nextId = ytActiveShuffleBag.shift()
      if (!nextId) return
      ytLastPlaylistPlayedId = nextId
      playDownloadedTrack(nextId)
      return
    }

    if (ytActivePlaylistIndex < 0 || ytActivePlaylistIndex >= playlist.itemIds.length) {
      ytActivePlaylistIndex = 0
    } else {
      ytActivePlaylistIndex = (ytActivePlaylistIndex + 1) % playlist.itemIds.length
    }
    const nextId = playlist.itemIds[ytActivePlaylistIndex]
    ytLastPlaylistPlayedId = nextId
    playDownloadedTrack(nextId)
  }

  const startPlaylistPlayback = (playlistId: string, mode: "sequential" | "shuffle") => {
    const playlist = getPlaylistById(playlistId)
    if (!playlist || playlist.itemIds.length === 0) return

    ytActivePlaylistId = playlistId
    ytActivePlaylistMode = mode
    playlistEndedLatch = false

    if (mode === "shuffle") {
      ytActiveShuffleBag = makeShuffledBag(playlist.itemIds, ytLastPlaylistPlayedId)
      const first = ytActiveShuffleBag.shift()
      if (!first) return
      ytLastPlaylistPlayedId = first
      playDownloadedTrack(first)
      return
    }

    ytActivePlaylistIndex = 0
    const first = playlist.itemIds[ytActivePlaylistIndex]
    ytLastPlaylistPlayedId = first
    playDownloadedTrack(first)
  }

  const createPlaylist = (name: string) => {
    const trimmed = name.trim()
    if (!trimmed) return
    const id = GLib.uuid_string_random()
    ytPlaylists.push({ id, name: trimmed, itemIds: [], coverVideoId: null })
    ytActivePlaylistId = id
    saveYtPlaylists()
    if (playlistNameEntry) playlistNameEntry.text = ""
    notifyListsChanged()
  }

  const selectPlaylist = (id: string) => {
    ytActivePlaylistId = id
    notifyListsChanged()
  }

  const toggleTrackInActivePlaylist = (videoId: string) => {
    const playlist = getPlaylistById(ytActivePlaylistId)
    if (!playlist) return
    const idx = playlist.itemIds.indexOf(videoId)
    if (idx >= 0) {
      playlist.itemIds.splice(idx, 1)
      if (playlist.coverVideoId === videoId) {
        playlist.coverVideoId = playlist.itemIds[0] || null
      }
    } else {
      playlist.itemIds.push(videoId)
      if (!playlist.coverVideoId) playlist.coverVideoId = videoId
    }
    saveYtPlaylists()
    notifyListsChanged()
  }

  const isTrackInActivePlaylist = (videoId: string): boolean => {
    const playlist = getPlaylistById(ytActivePlaylistId)
    if (!playlist) return false
    return playlist.itemIds.includes(videoId)
  }

  function rebuildPlaylists(items: PlaylistEntry[]) {
    if (!playlistList) return
    let child = playlistList.get_first_child()
    while (child) {
      const next = child.get_next_sibling()
      if (child !== playlistEmpty) playlistList.remove(child)
      child = next
    }

    let prev: Gtk.Widget | null = null
    for (const p of items) {
      const row = new Gtk.Box({ spacing: 8 })
      row.add_css_class("mc-playlist-row")

      const selectBtn = new Gtk.Button()
      selectBtn.add_css_class("mc-playlist-select")
      if (ytActivePlaylistId === p.id) selectBtn.add_css_class("active")
      selectBtn.connect("clicked", () => selectPlaylist(p.id))

      const selectBody = new Gtk.Box({ spacing: 8 })
      const coverId = p.coverVideoId || p.itemIds[0] || ""
      if (coverId) {
        selectBody.append(makeThumbnailWidget(coverId, 56, 32))
      } else {
        const ph = new Gtk.Box()
        ph.add_css_class("mc-playlist-cover-placeholder")
        ph.set_size_request(56, 32)
        const phIcon = Gtk.Image.new_from_icon_name("folder-music-symbolic")
        phIcon.pixel_size = 14
        ph.append(phIcon)
        selectBody.append(ph)
      }

      const labels = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL, spacing: 2 })
      labels.set_hexpand(true)
      const nameLbl = new Gtk.Label({ xalign: 0 })
      nameLbl.add_css_class("mc-playlist-name")
      nameLbl.set_label(p.name)
      const metaLbl = new Gtk.Label({ xalign: 0 })
      metaLbl.add_css_class("mc-playlist-meta")
      metaLbl.set_label(`${p.itemIds.length} items`)
      labels.append(nameLbl)
      labels.append(metaLbl)
      selectBody.append(labels)
      selectBtn.set_child(selectBody)
      row.append(selectBtn)

      const seqBtn = new Gtk.Button()
      seqBtn.add_css_class("mc-playlist-action")
      seqBtn.set_tooltip_text("Play sequential")
      seqBtn.connect("clicked", () => startPlaylistPlayback(p.id, "sequential"))
      seqBtn.set_child(Gtk.Image.new_from_icon_name("media-skip-forward-symbolic"))
      row.append(seqBtn)

      const shufBtn = new Gtk.Button()
      shufBtn.add_css_class("mc-playlist-action")
      shufBtn.set_tooltip_text("Play true shuffle")
      shufBtn.connect("clicked", () => startPlaylistPlayback(p.id, "shuffle"))
      shufBtn.set_child(Gtk.Image.new_from_icon_name("media-playlist-shuffle-symbolic"))
      row.append(shufBtn)

      playlistList.insert_child_after(row, prev)
      prev = row
    }

    if (playlistEmpty) playlistEmpty.set_visible(items.length === 0)
  }

  const playYtTrack = (track: YtResult) => {
    ytNowPlaying = track
    upsertVideoMeta(track.id, {
      title: track.title,
      channel: track.channel,
      duration: track.duration,
    })
    playYtEmbedded(track).catch((error) => {
      ytStatus = "error"
      ytStatusMsg = error instanceof Error ? error.message : "Playback failed"
      clearEmbeddedMedia()
    })
  }

  const playDownloadedTrack = (id: string) => {
    const meta = ytVideoMeta.get(id)
    playYtTrack({
      id,
      title: meta?.title || `Saved video (${id})`,
      channel: meta?.channel || "Saved",
      duration: meta?.duration || "",
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

  function rebuildDownloaded(items: DownloadedVideoGroup[]) {
    if (!downloadedList) return
    let child = downloadedList.get_first_child()
    while (child) {
      const next = child.get_next_sibling()
      if (child !== downloadedEmpty) downloadedList.remove(child)
      child = next
    }
    let prev: Gtk.Widget | null = null
    for (const item of items) {
      const row = makeDownloadedRow(
        item,
        playDownloadedTrack,
        toggleTrackInActivePlaylist,
        isTrackInActivePlaylist,
        () => ytActivePlaylistId !== null,
      )
      downloadedList.insert_child_after(row, prev)
      prev = row
    }
    if (downloadedEmpty) downloadedEmpty.set_visible(items.length === 0)
  }

  const refreshDownloaded = () => {
    if (downloadedScanBusy) return
    downloadedScanBusy = true
    listDownloadedVideoGroups()
      .then((items) => {
        for (const it of items) {
          const meta = ytVideoMeta.get(it.id)
          if (!meta?.title) queueFetchVideoMeta(it.id)
        }
        const sig = items
          .map((it) => {
            const title = ytVideoMeta.get(it.id)?.title || ""
            return `${it.id}:${it.qualities.join(",")}:${title}`
          })
          .join("|")
        if (sig !== downloadedSig) {
          downloadedSig = sig
          rebuildDownloaded(items)
        }
      })
      .catch(() => {
        if (downloadedSig !== "") {
          downloadedSig = ""
          rebuildDownloaded([])
        }
      })
      .finally(() => {
        downloadedScanBusy = false
      })
  }

  refreshDownloaded()
  downloadedRefreshId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1800, () => {
    refreshDownloaded()
    return GLib.SOURCE_CONTINUE
  })

  playlistAdvanceWatchId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 300, () => {
    if (!ytActivePlaylistId || !ytActivePlaylistMode || !ytMediaStream) {
      playlistEndedLatch = false
      return GLib.SOURCE_CONTINUE
    }
    let ended = false
    try { ended = Boolean((ytMediaStream as any).get_ended?.()) } catch { ended = false }
    if (ended && !playlistEndedLatch) {
      playlistEndedLatch = true
      playNextFromActivePlaylist()
    } else if (!ended) {
      playlistEndedLatch = false
    }
    return GLib.SOURCE_CONTINUE
  })

  onCleanup(() => {
    if (ytSearchDebounce) GLib.source_remove(ytSearchDebounce)
    GLib.source_remove(tvSourceId)
    if (downloadedRefreshId) GLib.source_remove(downloadedRefreshId)
    if (playlistAdvanceWatchId) GLib.source_remove(playlistAdvanceWatchId)
    ytUiRefreshHook = null
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
    ytCurrentQuality = null
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
                <label
                  class="mc-tv-quality-badge"
                  label={ytQualityState}
                  visible={ytQualityState((q) => q.length > 0)}
                />
                <label
                  class="mc-tv-download-progress"
                  label={ytDownloadState}
                  visible={ytDownloadState((t) => t.length > 0)}
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

                <box class="mc-downloaded-section" orientation={Gtk.Orientation.VERTICAL} spacing={6} marginTop={10}>
                  <label class="mc-section-label" label="DOWNLOADED VIDEOS" xalign={0} />
                  <label class="mc-playlist-hint" label={activePlaylistState} xalign={0} />
                  <box
                    class="mc-downloaded-list"
                    orientation={Gtk.Orientation.VERTICAL}
                    spacing={3}
                    $={(self) => { downloadedList = self }}
                  >
                    <box
                      class="mc-downloaded-empty"
                      orientation={Gtk.Orientation.VERTICAL}
                      spacing={6}
                      halign={Gtk.Align.CENTER}
                      marginTop={8}
                      marginBottom={8}
                      $={(self) => { downloadedEmpty = self }}
                    >
                      <label class="yt-empty-label" label="No downloaded videos yet" />
                    </box>
                  </box>
                </box>

                <box class="mc-playlists-section" orientation={Gtk.Orientation.VERTICAL} spacing={6} marginTop={10}>
                  <label class="mc-section-label" label="PLAYLISTS" xalign={0} />

                  <box class="mc-playlist-create-row" spacing={8}>
                    <entry
                      class="yt-search-entry"
                      hexpand
                      placeholderText="Create playlist..."
                      $={(self) => { playlistNameEntry = self }}
                      onActivate={(self) => createPlaylist(self.text || "")}
                    />
                    <button
                      class="mc-video-btn"
                      tooltipText="Create playlist"
                      onClicked={() => createPlaylist(playlistNameEntry?.text || "")}
                    >
                      <image iconName="list-add-symbolic" pixelSize={14} />
                    </button>
                  </box>

                  <box
                    class="mc-playlist-list"
                    orientation={Gtk.Orientation.VERTICAL}
                    spacing={4}
                    $={(self) => {
                      playlistList = self
                      rebuildPlaylists(ytPlaylists)
                    }}
                  >
                    <box
                      class="mc-playlist-empty"
                      orientation={Gtk.Orientation.VERTICAL}
                      spacing={6}
                      halign={Gtk.Align.CENTER}
                      marginTop={8}
                      marginBottom={8}
                      $={(self) => { playlistEmpty = self }}
                    >
                      <label class="yt-empty-label" label="No playlists yet" />
                    </box>
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
