import app from "ags/gtk4/app"
import Astal from "gi://Astal?version=4.0"
import Gtk from "gi://Gtk?version=4.0"
import Gdk from "gi://Gdk?version=4.0"
import Gsk from "gi://Gsk?version=4.0"
import GLib from "gi://GLib"
import Gio from "gi://Gio"
import GObject from "gi://GObject"
import Graphene from "gi://Graphene?version=1.0"
import Gst from "gi://Gst?version=1.0"
import GstApp from "gi://GstApp?version=1.0"
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
  addedAt: number
}

type DownloadedSortKey = "views" | "name" | "newest" | "oldest"
type DownloadedSortDir = "asc" | "desc"

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
  coverImagePath: string | null
}

type VideoColorMode = "original" | "mono" | "rgb332" | "rgb565" | "full"

interface VideoEffectSettings {
  fps: number
  blockSize: number
  cellSize: number
  gap: number
  colorMode: VideoColorMode
  threshold: number
  diffuser: boolean
  thickness: number
  diffusion: number
  glow: number
}

interface VideoEffectPreset {
  id: string
  name: string
  settings: VideoEffectSettings
  custom: boolean
}

export interface MediaCenterNowPlayingState {
  available: boolean
  title: string
  artist: string
  playing: boolean
  source: "youtube" | "mpris" | "none"
}

// ── Thumbnail cache ────────────────────────────────────────────────────
const thumbCache = new Map<string, string>()
const thumbTextureCache = new Map<string, Gdk.Texture>()
const thumbPending = new Set<string>()
const thumbWaiters = new Map<string, Set<(path: string) => void>>()
const THUMB_DIR = `${GLib.get_user_cache_dir()}/ags-yt-thumbs`
const YT_DLP = GLib.find_program_in_path("yt-dlp") || "/usr/bin/yt-dlp"

function ensureThumbDir() {
  try { GLib.mkdir_with_parents(THUMB_DIR, 0o755) } catch { /* ignore */ }
}

function fetchThumbnail(id: string, onDone: (path: string) => void) {
  if (thumbCache.has(id)) { onDone(thumbCache.get(id)!); return }

  let waiters = thumbWaiters.get(id)
  if (!waiters) {
    waiters = new Set()
    thumbWaiters.set(id, waiters)
  }
  waiters.add(onDone)
  if (thumbPending.has(id)) return
  thumbPending.add(id)
  ensureThumbDir()

  const finish = (path: string) => {
    thumbCache.set(id, path)
    thumbPending.delete(id)
    const pending = thumbWaiters.get(id)
    thumbWaiters.delete(id)
    for (const callback of pending || []) callback(path)
  }

  const fail = () => {
    thumbPending.delete(id)
    thumbWaiters.delete(id)
  }

  const dest = `${THUMB_DIR}/${id}.jpg`
  if (GLib.file_test(dest, GLib.FileTest.EXISTS)) {
    finish(dest)
    return
  }

  execAsync(["curl", "-sSL", "-o", dest,
    `https://img.youtube.com/vi/${id}/mqdefault.jpg`])
    .then(() => finish(dest))
    .catch(fail)
}

function thumbnailTexture(id: string, path: string): Gdk.Texture | null {
  const cached = thumbTextureCache.get(id)
  if (cached) return cached
  try {
    const texture = Gdk.Texture.new_from_file(Gio.File.new_for_path(path))
    thumbTextureCache.set(id, texture)
    return texture
  } catch {
    return null
  }
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

  const pic = new Gtk.Picture()
  pic.set_content_fit(Gtk.ContentFit.COVER)
  pic.set_size_request(w, h)
  pic.add_css_class("yt-thumb-img")
  stack.add_named(pic, "image")

  const tryLoad = (path: string) => {
    try {
      const texture = thumbnailTexture(id, path)
      if (texture) pic.set_paintable(texture)
      else pic.set_filename(path)
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
let ytTvRefreshHook: (() => void) | null = null
let ytPlayToken = 0
let ytUpgradeInFlightFor: string | null = null
let ytDownloadPid: number | null = null
let ytDownloadProgress = 0
let ytDownloadQuality: "360" | "480" | null = null
let ytCurrentQuality: "360" | "480" | null = null
let ytCurrentFilePath: string | null = null
let ytFilteredPipeline: Gst.Element | null = null
let ytFilteredSink: GstApp.AppSink | null = null
let ytFilteredLastPlaying: boolean | null = null
let ytFilteredObservedStream: Gtk.MediaStream | null = null
let ytFilteredPlayingSignalId = 0
let ytFilteredFrameTimerId = 0
let ytFilteredSourceFrame: Uint8Array | null = null
let ytFilteredSourceStride = 0
let ytFilteredHasVisibleFrame = false
const FILTERED_FRAME_WIDTH = 420
const FILTERED_FRAME_HEIGHT = 236
const DESKTOP_FILTERED_FRAME_WIDTH = 240
const DESKTOP_FILTERED_FRAME_HEIGHT = 135
const AMBIENT_LIGHT_COUNT = 12
const AMBIENT_FRAME_WIDTH = 224
const AMBIENT_FRAME_HEIGHT = 126
const AMBIENT_VIDEO_INSET = 0.13
const AMBIENT_VIDEO_SPAN = 1 - AMBIENT_VIDEO_INSET * 2
const MEDIA_TV_STAGE_WIDTH = 568
const MEDIA_TV_STAGE_HEIGHT = 319

// Keep Gtk.Picture attached to one dynamic paintable for the small ambient
// texture. Its contents update in place without replacing the picture source.
const MutableTexturePaintable = GObject.registerClass({
  Implements: [Gdk.Paintable],
}, class MutableTexturePaintable extends GObject.Object {
  private current: Gdk.Paintable | null = null
  private intrinsicWidth: number
  private intrinsicHeight: number

  constructor(width = 0, height = 0) {
    super()
    this.intrinsicWidth = width
    this.intrinsicHeight = height
  }

  setPaintable(paintable: Gdk.Paintable | null) {
    if (paintable === this.current) return
    this.current = paintable
    this.invalidate_contents()
  }

  vfunc_snapshot(snapshot: Gdk.Snapshot, width: number, height: number) {
    this.current?.snapshot(snapshot, width, height)
  }

  vfunc_get_current_image(): Gdk.Paintable {
    return this.current?.get_current_image()
      || Gdk.Paintable.new_empty(this.intrinsicWidth, this.intrinsicHeight)
  }

  vfunc_get_flags(): Gdk.PaintableFlags {
    return Gdk.PaintableFlags.STATIC_SIZE
  }

  vfunc_get_intrinsic_width(): number {
    return this.intrinsicWidth
  }

  vfunc_get_intrinsic_height(): number {
    return this.intrinsicHeight
  }

  vfunc_get_intrinsic_aspect_ratio(): number {
    return this.intrinsicHeight > 0 ? this.intrinsicWidth / this.intrinsicHeight : 0
  }
})

type MutableTexturePaintableInstance = InstanceType<typeof MutableTexturePaintable>
let ytFilteredTexture: Gdk.Texture | null = null
let ytDesktopFilteredTexture: Gdk.Texture | null = null
type VideoAccent = [number, number, number]
let ytAmbientPaintable: MutableTexturePaintableInstance | null = null
let ytAmbientHasAccents = false
let ytAmbientAccents: VideoAccent[] = Array.from(
  { length: AMBIENT_LIGHT_COUNT },
  () => [0, 0, 0] as VideoAccent,
)
let ytAmbientSpectrum = new Float32Array(AMBIENT_LIGHT_COUNT)
const ytVideoSurfaceListeners = new Set<() => void>()
const YT_MEDIA_DIR = `${GLib.get_home_dir()}/Video/TV`
const YT_META_FILE = `${YT_MEDIA_DIR}/video-meta.json`
const YT_PLAYLISTS_FILE = `${YT_MEDIA_DIR}/playlists.json`
const YT_PLAYCOUNTS_FILE = `${YT_MEDIA_DIR}/play-counts.json`
const ytVideoMeta = new Map<string, VideoMeta>()
const ytPlayCounts = new Map<string, number>()
let ytPlayCountsLoaded = false
const ytMetaFetchPending = new Set<string>()
let ytPlaylists: PlaylistEntry[] = []
let ytPlaylistsLoaded = false
let ytUiRefreshHook: (() => void) | null = null
let ytActivePlaylistId: string | null = null
let ytActivePlaylistMode: "sequential" | "shuffle" | null = null
let ytActivePlaylistIndex = -1
let ytActiveShuffleBag: string[] = []
let ytLastPlaylistPlayedId: string | null = null
let playlistDragPick: string | null = null

function notifyVideoSurfacesChanged() {
  for (const listener of ytVideoSurfaceListeners) listener()
}

export function subscribeMediaCenterVideoSurface(listener: () => void): () => void {
  ytVideoSurfaceListeners.add(listener)
  return () => ytVideoSurfaceListeners.delete(listener)
}

const DirectTextureWidget = GObject.registerClass(
  {},
  class DirectTextureWidget extends Gtk.Widget {
    private texture: Gdk.Texture | null = null

    setTexture(texture: Gdk.Texture | null) {
      if (texture === this.texture) return
      this.texture = texture
      this.queue_draw()
    }

    vfunc_snapshot(snapshot: Gtk.Snapshot) {
      if (!this.texture) return
      const width = this.get_width()
      const height = this.get_height()
      if (width <= 0 || height <= 0) return
      const textureWidth = this.texture.get_width()
      const textureHeight = this.texture.get_height()
      const scale = Math.min(width / textureWidth, height / textureHeight)
      const drawWidth = textureWidth * scale
      const drawHeight = textureHeight * scale
      const bounds = new Graphene.Rect()
      bounds.init(
        (width - drawWidth) / 2,
        (height - drawHeight) / 2,
        drawWidth,
        drawHeight,
      )
      snapshot.append_scaled_texture(this.texture, Gsk.ScalingFilter.NEAREST, bounds)
    }
  },
)

type DirectTextureWidgetInstance = InstanceType<typeof DirectTextureWidget>

export interface MediaCenterVideoEffectSurface {
  widget: Gtk.Widget
  setTexture(texture: Gdk.Texture | null): void
}

export function makeMediaCenterVideoEffectSurface(
  ...cssClasses: string[]
): MediaCenterVideoEffectSurface {
  const widget = new DirectTextureWidget() as DirectTextureWidgetInstance
  widget.set_hexpand(true)
  widget.set_vexpand(true)
  for (const cssClass of cssClasses) widget.add_css_class(cssClass)
  return {
    widget,
    setTexture: (texture) => widget.setTexture(texture),
  }
}

export function updateMediaCenterAudioSpectrum(values: number[]) {
  if (!values.length) return

  for (let index = 0; index < ytAmbientSpectrum.length; index++) {
    const bandStart = Math.floor(index * values.length / ytAmbientSpectrum.length)
    const bandEnd = Math.max(
      bandStart + 1,
      Math.ceil((index + 1) * values.length / ytAmbientSpectrum.length),
    )
    let squaredTotal = 0
    let sampleCount = 0
    for (let band = bandStart; band < Math.min(values.length, bandEnd); band++) {
      const value = Number(values[band])
      if (!Number.isFinite(value)) continue
      squaredTotal += value * value
      sampleCount++
    }
    // RMS preserves a strong hit inside a frequency slice without allowing
    // neighbouring slices or whole-spectrum energy to boost this light.
    const rms = sampleCount > 0 ? Math.sqrt(squaredTotal / sampleCount) : 0
    const target = Math.max(0, Math.min(1, rms / 100))
    const current = ytAmbientSpectrum[index]
    // Fast attack catches beats; the slower release produces the breathing tail.
    const smoothing = target > current ? 0.48 : 0.14
    const next = current + (target - current) * smoothing
    ytAmbientSpectrum[index] = next
  }

  // The light texture is published with the next decoded video frame. Updating
  // it independently from the video made GTK repaint two stacked surfaces at
  // slightly different times, which presented as a bright/dark flicker.
}

try { Gst.init(null) } catch { /* Gtk.Video remains available as fallback */ }

const DEFAULT_VIDEO_EFFECTS: VideoEffectSettings = {
  fps: 30,
  blockSize: 5,
  cellSize: 16,
  gap: 1,
  colorMode: "rgb332",
  threshold: 128,
  diffuser: false,
  thickness: 40,
  diffusion: 45,
  glow: 20,
}
const VIDEO_BLOCK_SIZES = [2, 3, 4, 5, 6, 8, 10, 12, 15, 16, 20, 24, 30, 40]

const videoEffects: VideoEffectSettings = { ...DEFAULT_VIDEO_EFFECTS }
const videoEffectsListeners = new Set<() => void>()
const videoPresetListeners = new Set<() => void>()
const VIDEO_PRESETS_FILE = `${GLib.get_user_config_dir()}/ags/video-effect-presets.json`

const makePresetSettings = (patch: Partial<VideoEffectSettings>): VideoEffectSettings => ({
  ...DEFAULT_VIDEO_EFFECTS,
  ...patch,
})

const BUILTIN_VIDEO_PRESETS: VideoEffectPreset[] = [
  {
    id: "builtin:reference-8bit",
    name: "Reference · 8-bit",
    settings: makePresetSettings({}),
    custom: false,
  },
  {
    id: "builtin:original",
    name: "Original video",
    settings: makePresetSettings({ colorMode: "original", gap: 0 }),
    custom: false,
  },
  {
    id: "builtin:mono-checkbox",
    name: "Mono checkbox",
    settings: makePresetSettings({ colorMode: "mono", threshold: 128 }),
    custom: false,
  },
  {
    id: "builtin:16bit-crisp",
    name: "16-bit crisp",
    settings: makePresetSettings({ colorMode: "rgb565", blockSize: 4, cellSize: 14, gap: 0 }),
    custom: false,
  },
  {
    id: "builtin:full-mosaic",
    name: "Full-color mosaic",
    settings: makePresetSettings({ colorMode: "full", blockSize: 5, cellSize: 16, gap: 1 }),
    custom: false,
  },
  {
    id: "builtin:diffused-glow",
    name: "Diffused glow",
    settings: makePresetSettings({
      colorMode: "rgb332",
      blockSize: 8,
      cellSize: 18,
      gap: 1,
      diffuser: true,
      thickness: 40,
      diffusion: 45,
      glow: 28,
    }),
    custom: false,
  },
]

let customVideoPresets: VideoEffectPreset[] = []

function normalizeVideoEffectSettings(raw: any): VideoEffectSettings | null {
  if (!raw || typeof raw !== "object") return null
  const colorModes: VideoColorMode[] = ["original", "mono", "rgb332", "rgb565", "full"]
  const colorMode = colorModes.includes(raw.colorMode) ? raw.colorMode as VideoColorMode : null
  if (!colorMode) return null

  const numberInRange = (value: any, min: number, max: number): number | null => {
    const n = Number(value)
    return Number.isFinite(n) ? Math.max(min, Math.min(max, Math.round(n))) : null
  }
  const fps = numberInRange(raw.fps, 1, 60)
  const blockSize = numberInRange(raw.blockSize, 2, 40)
  const cellSize = numberInRange(raw.cellSize, 10, 40)
  const gap = numberInRange(raw.gap, 0, 6)
  const threshold = numberInRange(raw.threshold, 1, 254)
  const thickness = numberInRange(raw.thickness, 0, 100)
  const diffusion = numberInRange(raw.diffusion, 0, 100)
  const glow = numberInRange(raw.glow, 0, 100)
  if ([fps, blockSize, cellSize, gap, threshold, thickness, diffusion, glow].some((n) => n === null)) return null
  if (!VIDEO_BLOCK_SIZES.includes(blockSize!)) return null

  return {
    fps: fps!,
    blockSize: blockSize!,
    cellSize: cellSize!,
    gap: gap!,
    colorMode,
    threshold: threshold!,
    diffuser: Boolean(raw.diffuser),
    thickness: thickness!,
    diffusion: diffusion!,
    glow: glow!,
  }
}

function loadCustomVideoPresets() {
  customVideoPresets = []
  try {
    const [ok, bytes] = GLib.file_get_contents(VIDEO_PRESETS_FILE)
    if (!ok) return
    const parsed = JSON.parse(new TextDecoder().decode(bytes)) as any[]
    if (!Array.isArray(parsed)) return
    customVideoPresets = parsed.flatMap((entry): VideoEffectPreset[] => {
      const name = typeof entry?.name === "string" ? entry.name.trim() : ""
      const settings = normalizeVideoEffectSettings(entry?.settings)
      if (!name || !settings) return []
      return [{
        id: typeof entry.id === "string" && entry.id ? entry.id : `custom:${GLib.uuid_string_random()}`,
        name: name.slice(0, 48),
        settings,
        custom: true,
      }]
    })
  } catch { /* malformed preset file starts with an empty custom list */ }
}

function saveCustomVideoPresets(): boolean {
  try {
    GLib.mkdir_with_parents(`${GLib.get_user_config_dir()}/ags`, 0o755)
    GLib.file_set_contents(VIDEO_PRESETS_FILE, JSON.stringify(
      customVideoPresets.map(({ id, name, settings }) => ({ id, name, settings })),
      null,
      2,
    ))
    return true
  } catch (error) {
    console.error("Could not save video presets:", error)
    return false
  }
}

function allVideoPresets(): VideoEffectPreset[] {
  return [...BUILTIN_VIDEO_PRESETS, ...customVideoPresets]
}

function videoEffectSettingsEqual(a: VideoEffectSettings, b: VideoEffectSettings): boolean {
  return a.fps === b.fps
    && a.blockSize === b.blockSize
    && a.cellSize === b.cellSize
    && a.gap === b.gap
    && a.colorMode === b.colorMode
    && a.threshold === b.threshold
    && a.diffuser === b.diffuser
    && a.thickness === b.thickness
    && a.diffusion === b.diffusion
    && a.glow === b.glow
}

loadCustomVideoPresets()

// ── Play queue ─────────────────────────────────────────────────────────
// Up-next list, independent of playlists. When the current track ends the
// queue is consulted first; if empty, the active playlist (if any) advances.
let ytQueue: YtResult[] = []
let ytQueueRefreshHook: (() => void) | null = null
let ytBarNextHook: (() => void) | null = null

function notifyQueueChanged() {
  ytQueueRefreshHook?.()
}

function enqueueTrack(track: YtResult) {
  if (!track?.id) return
  ytQueue.push(track)
  notifyQueueChanged()
}

function dequeueNextTrack(): YtResult | null {
  return ytQueue.shift() || null
}

function removeFromQueueAt(index: number) {
  if (index < 0 || index >= ytQueue.length) return
  ytQueue.splice(index, 1)
  notifyQueueChanged()
}

function moveInQueue(index: number, delta: -1 | 1) {
  const target = index + delta
  if (index < 0 || index >= ytQueue.length) return
  if (target < 0 || target >= ytQueue.length) return
  const tmp = ytQueue[index]
  ytQueue[index] = ytQueue[target]
  ytQueue[target] = tmp
  notifyQueueChanged()
}

function clearQueue() {
  if (ytQueue.length === 0) return
  ytQueue = []
  notifyQueueChanged()
}

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
        coverImagePath: typeof p.coverImagePath === "string" ? p.coverImagePath : null,
      }))
  } catch { /* ignore */ }
}

function saveYtPlaylists() {
  ensureYtMediaDir()
  try {
    GLib.file_set_contents(YT_PLAYLISTS_FILE, JSON.stringify(ytPlaylists, null, 2))
  } catch { /* ignore */ }
}

function loadYtPlayCounts() {
  ensureYtMediaDir()
  ytPlayCountsLoaded = true
  ytPlayCounts.clear()
  try {
    const [ok, bytes] = GLib.file_get_contents(YT_PLAYCOUNTS_FILE)
    if (!ok) return
    const parsed = JSON.parse(new TextDecoder().decode(bytes)) as Record<string, number>
    for (const [id, count] of Object.entries(parsed)) {
      if (!id) continue
      const n = Number(count)
      if (Number.isFinite(n) && n > 0) ytPlayCounts.set(id, Math.floor(n))
    }
  } catch { /* ignore */ }
}

function saveYtPlayCounts() {
  ensureYtMediaDir()
  try {
    const obj: Record<string, number> = {}
    for (const [id, count] of ytPlayCounts.entries()) obj[id] = count
    GLib.file_set_contents(YT_PLAYCOUNTS_FILE, JSON.stringify(obj, null, 2))
  } catch { /* ignore */ }
}

function getPlayCount(id: string): number {
  return ytPlayCounts.get(id) || 0
}

function incrementPlayCount(id: string) {
  if (!id) return
  ytPlayCounts.set(id, getPlayCount(id) + 1)
  saveYtPlayCounts()
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
  // Gtk.MediaStream exposes duration/timestamp in microseconds. Keeping this
  // conversion explicit also makes the first ten seconds seek correctly.
  return raw / 1_000_000
}

function quantizeChannel(value: number, levels: number): number {
  return Math.round(Math.round(value * levels / 255) * 255 / levels)
}

function renderFilteredFrame(
  source: Uint8Array,
  sourceStride: number,
  width = FILTERED_FRAME_WIDTH,
  height = FILTERED_FRAME_HEIGHT,
): Uint8Array {
  const rowBytes = width * 4
  const output = new Uint8Array(rowBytes * height)

  if (videoEffects.colorMode === "original") {
    if (width === FILTERED_FRAME_WIDTH && height === FILTERED_FRAME_HEIGHT) {
      for (let y = 0; y < height; y++) {
        const sourceStart = y * sourceStride
        output.set(source.subarray(sourceStart, sourceStart + rowBytes), y * rowBytes)
      }
      return output
    }

    for (let y = 0; y < height; y++) {
      const sourceY = Math.min(
        FILTERED_FRAME_HEIGHT - 1,
        Math.floor((y + 0.5) * FILTERED_FRAME_HEIGHT / height),
      )
      for (let x = 0; x < width; x++) {
        const sourceX = Math.min(
          FILTERED_FRAME_WIDTH - 1,
          Math.floor((x + 0.5) * FILTERED_FRAME_WIDTH / width),
        )
        const sourceOffset = sourceY * sourceStride + sourceX * 4
        const outputOffset = (y * width + x) * 4
        output[outputOffset] = source[sourceOffset] || 0
        output[outputOffset + 1] = source[sourceOffset + 1] || 0
        output[outputOffset + 2] = source[sourceOffset + 2] || 0
        output[outputOffset + 3] = 255
      }
    }
    return output
  }

  for (let offset = 3; offset < output.length; offset += 4) output[offset] = 255

  // The old shader divided fractional UV coordinates, which rounded
  // differently on alternating rows. Every boundary here is an integer pixel:
  // the same pitch and the same literal gap are used across the whole frame.
  const pitch = Math.max(
    videoEffects.gap + 1,
    Math.round(videoEffects.blockSize * videoEffects.cellSize / 16),
  )
  const gap = Math.max(0, Math.min(pitch - 1, Math.round(videoEffects.gap)))
  const contentSize = pitch - gap

  const sample = (x: number, y: number): [number, number, number] => {
    const sx = Math.max(0, Math.min(
      FILTERED_FRAME_WIDTH - 1,
      Math.round((x + 0.5) * FILTERED_FRAME_WIDTH / width - 0.5),
    ))
    const sy = Math.max(0, Math.min(
      FILTERED_FRAME_HEIGHT - 1,
      Math.round((y + 0.5) * FILTERED_FRAME_HEIGHT / height - 0.5),
    ))
    const offset = sy * sourceStride + sx * 4
    return [source[offset] || 0, source[offset + 1] || 0, source[offset + 2] || 0]
  }

  const setPixel = (x: number, y: number, r: number, g: number, b: number) => {
    if (x < 0 || y < 0 || x >= width || y >= height) return
    const offset = (y * width + x) * 4
    output[offset] = r
    output[offset + 1] = g
    output[offset + 2] = b
    output[offset + 3] = 255
  }

  const drawTickLine = (x1: number, y1: number, x2: number, y2: number) => {
    const dx = x2 - x1
    const dy = y2 - y1
    const steps = Math.max(1, Math.abs(dx), Math.abs(dy))
    for (let step = 0; step <= steps; step++) {
      const x = Math.round(x1 + dx * step / steps)
      const y = Math.round(y1 + dy * step / steps)
      setPixel(x, y, 245, 245, 245)
      if (contentSize >= 8) setPixel(x, y + 1, 245, 245, 245)
    }
  }

  for (let cellY = 0; cellY < height; cellY += pitch) {
    for (let cellX = 0; cellX < width; cellX += pitch) {
      const centerX = cellX + (contentSize - 1) / 2
      const centerY = cellY + (contentSize - 1) / 2
      let [red, green, blue] = sample(centerX, centerY)

      if (videoEffects.diffuser) {
        const radius = pitch * Math.max(1, Math.round(videoEffects.diffusion / 34))
        let redTotal = red * 4
        let greenTotal = green * 4
        let blueTotal = blue * 4
        let weight = 4
        for (const [dx, dy] of [
          [-radius, 0], [radius, 0], [0, -radius], [0, radius],
          [-radius, -radius], [radius, -radius], [-radius, radius], [radius, radius],
        ]) {
          const [nearRed, nearGreen, nearBlue] = sample(centerX + dx, centerY + dy)
          redTotal += nearRed
          greenTotal += nearGreen
          blueTotal += nearBlue
          weight++
        }
        const glowScale = 1 + videoEffects.glow / 100
        const whiteMix = videoEffects.thickness / 300
        red = Math.min(255, redTotal / weight * glowScale * (1 - whiteMix) + 235 * whiteMix)
        green = Math.min(255, greenTotal / weight * glowScale * (1 - whiteMix) + 240 * whiteMix)
        blue = Math.min(255, blueTotal / weight * glowScale * (1 - whiteMix) + 248 * whiteMix)
      }

      let checked = false
      if (videoEffects.colorMode === "mono") {
        const luma = red * 0.299 + green * 0.587 + blue * 0.114
        checked = luma < videoEffects.threshold
        red = green = blue = checked ? 0 : 240
      } else if (videoEffects.colorMode === "rgb332") {
        red = quantizeChannel(red, 7)
        green = quantizeChannel(green, 7)
        blue = quantizeChannel(blue, 3)
      } else if (videoEffects.colorMode === "rgb565") {
        red = quantizeChannel(red, 31)
        green = quantizeChannel(green, 63)
        blue = quantizeChannel(blue, 31)
      }

      const contentRight = Math.min(width, cellX + contentSize)
      const contentBottom = Math.min(height, cellY + contentSize)
      for (let y = cellY; y < contentBottom; y++) {
        let offset = (y * width + cellX) * 4
        for (let x = cellX; x < contentRight; x++) {
          output[offset] = red
          output[offset + 1] = green
          output[offset + 2] = blue
          offset += 4
        }
      }

      if (checked && contentSize >= 4) {
        const left = cellX
        const top = cellY
        drawTickLine(
          Math.round(left + contentSize * 0.20),
          Math.round(top + contentSize * 0.52),
          Math.round(left + contentSize * 0.42),
          Math.round(top + contentSize * 0.72),
        )
        drawTickLine(
          Math.round(left + contentSize * 0.42),
          Math.round(top + contentSize * 0.72),
          Math.round(left + contentSize * 0.80),
          Math.round(top + contentSize * 0.28),
        )
      }
    }
  }

  return output
}

interface AmbientLight {
  x: number
  y: number
  directionX: number
  directionY: number
  region: readonly [number, number, number, number]
}

const ambientEdgePosition = (position: number) =>
  AMBIENT_VIDEO_INSET + AMBIENT_VIDEO_SPAN * position

// Frequencies progress clockwise from the upper-left top light. Each source
// samples the matching part of the picture edge and is driven by exactly one
// of the 12 CAVA slices.
const AMBIENT_LIGHTS: readonly AmbientLight[] = [
  { x: ambientEdgePosition(0.20), y: AMBIENT_VIDEO_INSET, directionX: 0, directionY: -1, region: [0.00, 0.00, 0.34, 0.20] },
  { x: ambientEdgePosition(0.50), y: AMBIENT_VIDEO_INSET, directionX: 0, directionY: -1, region: [0.33, 0.00, 0.67, 0.20] },
  { x: ambientEdgePosition(0.80), y: AMBIENT_VIDEO_INSET, directionX: 0, directionY: -1, region: [0.66, 0.00, 1.00, 0.20] },
  { x: 1 - AMBIENT_VIDEO_INSET, y: ambientEdgePosition(0.20), directionX: 1, directionY: 0, region: [0.80, 0.00, 1.00, 0.34] },
  { x: 1 - AMBIENT_VIDEO_INSET, y: ambientEdgePosition(0.50), directionX: 1, directionY: 0, region: [0.80, 0.33, 1.00, 0.67] },
  { x: 1 - AMBIENT_VIDEO_INSET, y: ambientEdgePosition(0.80), directionX: 1, directionY: 0, region: [0.80, 0.66, 1.00, 1.00] },
  { x: ambientEdgePosition(0.80), y: 1 - AMBIENT_VIDEO_INSET, directionX: 0, directionY: 1, region: [0.66, 0.80, 1.00, 1.00] },
  { x: ambientEdgePosition(0.50), y: 1 - AMBIENT_VIDEO_INSET, directionX: 0, directionY: 1, region: [0.33, 0.80, 0.67, 1.00] },
  { x: ambientEdgePosition(0.20), y: 1 - AMBIENT_VIDEO_INSET, directionX: 0, directionY: 1, region: [0.00, 0.80, 0.34, 1.00] },
  { x: AMBIENT_VIDEO_INSET, y: ambientEdgePosition(0.80), directionX: -1, directionY: 0, region: [0.00, 0.66, 0.20, 1.00] },
  { x: AMBIENT_VIDEO_INSET, y: ambientEdgePosition(0.50), directionX: -1, directionY: 0, region: [0.00, 0.33, 0.20, 0.67] },
  { x: AMBIENT_VIDEO_INSET, y: ambientEdgePosition(0.20), directionX: -1, directionY: 0, region: [0.00, 0.00, 0.20, 0.34] },
]

function refreshAmbientAccents(source: Uint8Array, sourceStride: number) {
  const nextAccents: VideoAccent[] = []

  for (const { region: [xStart, yStart, xEnd, yEnd] } of AMBIENT_LIGHTS) {
    const left = Math.floor(xStart * FILTERED_FRAME_WIDTH)
    const top = Math.floor(yStart * FILTERED_FRAME_HEIGHT)
    const right = Math.max(left + 1, Math.ceil(xEnd * FILTERED_FRAME_WIDTH))
    const bottom = Math.max(top + 1, Math.ceil(yEnd * FILTERED_FRAME_HEIGHT))
    let redTotal = 0
    let greenTotal = 0
    let blueTotal = 0
    let totalWeight = 0

    // Sparse sampling keeps the per-frame extraction cheap while still using
    // the whole surrounding region instead of a potentially noisy edge pixel.
    for (let y = top; y < bottom; y += 6) {
      for (let x = left; x < right; x += 6) {
        const offset = y * sourceStride + x * 4
        const red = source[offset] || 0
        const green = source[offset + 1] || 0
        const blue = source[offset + 2] || 0
        const maximum = Math.max(red, green, blue)
        const minimum = Math.min(red, green, blue)
        const saturation = maximum - minimum
        const brightness = red * 0.299 + green * 0.587 + blue * 0.114
        const weight = 0.22 + saturation / 255 * 0.68 + brightness / 255 * 0.10
        redTotal += red * weight
        greenTotal += green * weight
        blueTotal += blue * weight
        totalWeight += weight
      }
    }

    let red = totalWeight > 0 ? redTotal / totalWeight : 0
    let green = totalWeight > 0 ? greenTotal / totalWeight : 0
    let blue = totalWeight > 0 ? blueTotal / totalWeight : 0
    const luma = red * 0.299 + green * 0.587 + blue * 0.114
    red = luma + (red - luma) * 1.55
    green = luma + (green - luma) * 1.55
    blue = luma + (blue - luma) * 1.55
    const peak = Math.max(red, green, blue)
    const scale = peak > 0 && peak < 126 ? 126 / peak : peak > 235 ? 235 / peak : 1
    nextAccents.push([
      Math.max(0, Math.min(255, red * scale)),
      Math.max(0, Math.min(255, green * scale)),
      Math.max(0, Math.min(255, blue * scale)),
    ])
  }

  const blend = ytAmbientHasAccents ? 0.20 : 1
  ytAmbientAccents = nextAccents.map((next, index) => {
    const previous = ytAmbientAccents[index] || next
    return [
      previous[0] + (next[0] - previous[0]) * blend,
      previous[1] + (next[1] - previous[1]) * blend,
      previous[2] + (next[2] - previous[2]) * blend,
    ]
  })
  ytAmbientHasAccents = true
}

function renderAmbientFrame(): Uint8Array {
  const pixels = new Uint8Array(AMBIENT_FRAME_WIDTH * AMBIENT_FRAME_HEIGHT * 4)
  const lights = ytAmbientAccents.map((accent, index) => {
    const bandEnergy = ytAmbientSpectrum[index] || 0
    // CAVA values spend much of their time near the bottom of the range.
    // A square-root response keeps quiet slices visible while retaining peaks.
    const pulse = Math.sqrt(Math.max(0, bandEnergy))
    const descriptor = AMBIENT_LIGHTS[index]
    return {
      accent,
      x: descriptor.x,
      y: descriptor.y,
      directionX: descriptor.directionX,
      directionY: descriptor.directionY,
      strength: 0.10 + pulse * 1.18,
      // Each beam is one CAVA slice: its own bin alone controls how far and
      // how wide it travels away from the video.
      length: 0.018 + pulse * 0.155,
      width: 0.026 + pulse * 0.050,
    }
  })

  for (let y = 0; y < AMBIENT_FRAME_HEIGHT; y++) {
    const ny = y / Math.max(1, AMBIENT_FRAME_HEIGHT - 1)
    for (let x = 0; x < AMBIENT_FRAME_WIDTH; x++) {
      const nx = x / Math.max(1, AMBIENT_FRAME_WIDTH - 1)
      let red = 0
      let green = 0
      let blue = 0
      let total = 0

      for (const light of lights) {
        const deltaX = nx - light.x
        const deltaY = ny - light.y
        const normal = deltaX * light.directionX + deltaY * light.directionY
        if (normal < 0) continue
        const tangent = deltaX * -light.directionY + deltaY * light.directionX
        // Rays widen as they travel away from the video edge. Their direction
        // is one-sided, while their length follows the matching CAVA slice.
        const rayWidth = light.width + normal * 0.28
        const normalShape = normal * normal / Math.max(0.0001, light.length * light.length)
        const tangentShape = tangent * tangent / Math.max(0.0001, rayWidth * rayWidth)
        const amount = Math.exp(-(normalShape * 0.92 + tangentShape * 1.42)) * light.strength
        red += light.accent[0] * amount
        green += light.accent[1] * amount
        blue += light.accent[2] * amount
        total += amount
      }

      const offset = (y * AMBIENT_FRAME_WIDTH + x) * 4
      if (total > 0.001) {
        // Force the light tail to reach transparent before the texture edge.
        // This prevents the outer stage boundary from reading as a hard,
        // horizontal/vertical cutoff when a loud slice has a long ray.
        const edgeDistance = Math.min(nx, 1 - nx, ny, 1 - ny)
        const edgeProgress = Math.max(0, Math.min(1, edgeDistance / 0.10))
        const edgeFade = edgeProgress * edgeProgress * (3 - 2 * edgeProgress)
        const alpha = Math.max(0, Math.min(235, Math.round(total * edgeFade * 225)))
        const premultiply = alpha / 255
        pixels[offset] = Math.max(0, Math.min(alpha, Math.round(red / total * premultiply)))
        pixels[offset + 1] = Math.max(0, Math.min(alpha, Math.round(green / total * premultiply)))
        pixels[offset + 2] = Math.max(0, Math.min(alpha, Math.round(blue / total * premultiply)))
        pixels[offset + 3] = alpha
      }
    }
  }
  return pixels
}

function publishAmbientFrame(notify = true): boolean {
  if (!ytAmbientHasAccents) return false
  try {
    const bytes = new GLib.Bytes(renderAmbientFrame())
    const texture = Gdk.MemoryTexture.new(
      AMBIENT_FRAME_WIDTH,
      AMBIENT_FRAME_HEIGHT,
      Gdk.MemoryFormat.R8G8B8A8_PREMULTIPLIED,
      bytes,
      AMBIENT_FRAME_WIDTH * 4,
    )
    const created = ytAmbientPaintable === null
    if (!ytAmbientPaintable) {
      ytAmbientPaintable = new MutableTexturePaintable(
        AMBIENT_FRAME_WIDTH,
        AMBIENT_FRAME_HEIGHT,
      )
    }
    ytAmbientPaintable.setPaintable(texture)
    if (notify && created) notifyVideoSurfacesChanged()
    return created
  } catch (error) {
    console.error("Could not publish Media Center ambient frame:", error)
    return false
  }
}

function publishFilteredSourceFrame() {
  if (!ytFilteredSourceFrame || ytFilteredSourceStride < FILTERED_FRAME_WIDTH * 4) return
  if (!ytFilteredHasVisibleFrame) {
    // The first preroll frame in several downloaded videos is solid black.
    // Do not replace the working Gtk.Video fallback with that frame. Once the
    // decoder has produced real picture data, later black scenes are valid.
    let minimum = 255
    let maximum = 0
    for (let y = 0; y < FILTERED_FRAME_HEIGHT; y += 12) {
      for (let x = 0; x < FILTERED_FRAME_WIDTH; x += 12) {
        const offset = y * ytFilteredSourceStride + x * 4
        const red = ytFilteredSourceFrame[offset] || 0
        const green = ytFilteredSourceFrame[offset + 1] || 0
        const blue = ytFilteredSourceFrame[offset + 2] || 0
        minimum = Math.min(minimum, red, green, blue)
        maximum = Math.max(maximum, red, green, blue)
      }
    }
    if (maximum - minimum < 10 && maximum < 18) return
    ytFilteredHasVisibleFrame = true
  }

  try {
    const mediaPixels = renderFilteredFrame(
      ytFilteredSourceFrame,
      ytFilteredSourceStride,
      FILTERED_FRAME_WIDTH,
      FILTERED_FRAME_HEIGHT,
    )
    ytFilteredTexture = Gdk.MemoryTexture.new(
      FILTERED_FRAME_WIDTH,
      FILTERED_FRAME_HEIGHT,
      Gdk.MemoryFormat.R8G8B8A8_PREMULTIPLIED,
      new GLib.Bytes(mediaPixels),
      FILTERED_FRAME_WIDTH * 4,
    )
    // Render the desktop grid at its actual logical size. Scaling the 420px
    // Media Center grid down to 240px made a 5px cell become 2.86px, forcing
    // alternating cell widths. This texture keeps every desktop cell integral.
    const desktopPixels = renderFilteredFrame(
      ytFilteredSourceFrame,
      ytFilteredSourceStride,
      DESKTOP_FILTERED_FRAME_WIDTH,
      DESKTOP_FILTERED_FRAME_HEIGHT,
    )
    ytDesktopFilteredTexture = Gdk.MemoryTexture.new(
      DESKTOP_FILTERED_FRAME_WIDTH,
      DESKTOP_FILTERED_FRAME_HEIGHT,
      Gdk.MemoryFormat.R8G8B8A8_PREMULTIPLIED,
      new GLib.Bytes(desktopPixels),
      DESKTOP_FILTERED_FRAME_WIDTH * 4,
    )
    refreshAmbientAccents(ytFilteredSourceFrame, ytFilteredSourceStride)
    publishAmbientFrame(false)
    // DirectTextureWidget snapshots the new immutable texture. This bypasses
    // the large custom Gdk.Paintable path that rendered as black with a single
    // vertical artifact on this GTK backend.
    notifyVideoSurfacesChanged()
  } catch (error) {
    console.error("Could not publish Media Center video frame:", error)
  }
}

function pullFilteredVideoFrame(): boolean {
  const sink = ytFilteredSink
  if (!sink) return false
  try {
    // Preroll is the paused/seek frame; normal samples are the playing queue.
    // Do not mix both queues while playing or an old preroll can be published
    // immediately before the first post-seek sample.
    const sample = ytFilteredLastPlaying
      ? sink.try_pull_sample(0)
      : sink.try_pull_preroll(0) || sink.try_pull_sample(0)
    if (!sample) return false
    const buffer = sample.get_buffer()
    if (!buffer) return false
    const [mapped, info] = buffer.map(Gst.MapFlags.READ)
    if (!mapped) return false
    try {
      // GstMapInfo owns this memory only until unmap(). Keep a literal copy so
      // neither the renderer nor a later effects pass can observe recycled
      // decoder memory.
      ytFilteredSourceFrame = info.data.slice()
      ytFilteredSourceStride = Math.floor(info.data.length / FILTERED_FRAME_HEIGHT)
    } finally {
      buffer.unmap(info)
    }
    publishFilteredSourceFrame()
    return true
  } catch (error) {
    console.error("Could not read Media Center video frame:", error)
    return false
  }
}

function restartFilteredFrameTimer() {
  if (ytFilteredFrameTimerId) {
    GLib.source_remove(ytFilteredFrameTimerId)
    ytFilteredFrameTimerId = 0
  }
  if (!ytFilteredSink) return
  const interval = Math.max(16, Math.round(1000 / Math.max(1, videoEffects.fps)))
  ytFilteredFrameTimerId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, interval, () => {
    if (!ytFilteredSink) {
      ytFilteredFrameTimerId = 0
      return GLib.SOURCE_REMOVE
    }
    // Gtk.MediaStream's notify::playing is not reliable on every backend.
    // Poll the cheap boolean here so the video-only pipeline cannot remain
    // paused on its black preroll while the master audio stream advances.
    syncFilteredVideoRenderer()
    pullFilteredVideoFrame()
    return GLib.SOURCE_CONTINUE
  })
}

function applyVideoEffectsToRenderer() {
  restartFilteredFrameTimer()
  // Re-render the last decoded frame immediately, including while paused.
  publishFilteredSourceFrame()
}

function updateVideoEffects(patch: Partial<VideoEffectSettings>) {
  let changed = false
  for (const [key, value] of Object.entries(patch) as [keyof VideoEffectSettings, any][]) {
    if (videoEffects[key] === value) continue
    ;(videoEffects as any)[key] = value
    changed = true
  }
  if (!changed) return
  applyVideoEffectsToRenderer()
  for (const listener of videoEffectsListeners) listener()
}

function stopFilteredVideoRenderer(clearPaintables = true) {
  if (ytFilteredObservedStream && ytFilteredPlayingSignalId) {
    try { ytFilteredObservedStream.disconnect(ytFilteredPlayingSignalId) } catch { /* ignore */ }
  }
  ytFilteredObservedStream = null
  ytFilteredPlayingSignalId = 0
  if (ytFilteredFrameTimerId) {
    GLib.source_remove(ytFilteredFrameTimerId)
    ytFilteredFrameTimerId = 0
  }
  const pipeline = ytFilteredPipeline
  ytFilteredPipeline = null
  ytFilteredSink = null
  ytFilteredSourceFrame = null
  ytFilteredSourceStride = 0
  ytFilteredLastPlaying = null
  if (clearPaintables) {
    ytAmbientPaintable?.setPaintable(null)
    ytFilteredTexture = null
    ytDesktopFilteredTexture = null
    ytAmbientPaintable = null
    ytAmbientHasAccents = false
    ytFilteredHasVisibleFrame = false
    ytAmbientAccents = Array.from(
      { length: AMBIENT_LIGHT_COUNT },
      () => [0, 0, 0] as VideoAccent,
    )
    ytAmbientSpectrum.fill(0)
    // Drop the paintable from every UI surface before shutting down its pipeline.
    notifyVideoSurfacesChanged()
  }
  if (pipeline) {
    try { pipeline.get_bus()?.remove_signal_watch() } catch { /* ignore */ }
    try { pipeline.set_state(Gst.State.NULL) } catch { /* ignore */ }
  }
}

function rawMediaTimeToGstNs(raw: number): number {
  return Math.max(0, Math.round(mediaUnitsToSeconds(raw) * 1_000_000_000))
}

function syncFilteredVideoRenderer() {
  const pipeline = ytFilteredPipeline
  const stream = ytMediaStream as any
  if (!pipeline || !stream) return

  const playing = Boolean(stream.get_playing?.())
  if (ytFilteredLastPlaying !== playing) {
    ytFilteredLastPlaying = playing
    try { pipeline.set_state(playing ? Gst.State.PLAYING : Gst.State.PAUSED) } catch { /* ignore */ }
  }
}

function seekFilteredVideoRenderer(rawTimestamp: number) {
  const pipeline = ytFilteredPipeline
  if (!pipeline) return
  try {
    pipeline.seek_simple(
      Gst.Format.TIME,
      Gst.SeekFlags.FLUSH | Gst.SeekFlags.ACCURATE,
      rawMediaTimeToGstNs(rawTimestamp),
    )
  } catch { /* leave the renderer at its current position */ }
}

function startFilteredVideoRenderer(filePath: string) {
  // Preserve the last immutable frame during the 360p -> 480p pipeline swap.
  // The first frame from the new pipeline replaces it in both snapshot widgets.
  stopFilteredVideoRenderer(false)
  ytFilteredHasVisibleFrame = false

  try {
    const renderBin = Gst.parse_bin_from_description(
      // Keep GStreamer GL completely out of this process. On this Mesa stack
      // libgstgl crashes its render thread, which restarts AGS and looks like
      // full-screen blinking. Appsink retains only the newest CPU frame.
      "videoconvert ! videoscale method=0 ! " +
      `video/x-raw,format=RGBA,width=${FILTERED_FRAME_WIDTH},height=${FILTERED_FRAME_HEIGHT},pixel-aspect-ratio=1/1 ! ` +
      "appsink name=ags_video_sink max-buffers=1 drop=true sync=true",
      true,
    ) as Gst.Bin
    const sinkElement = renderBin.get_by_name("ags_video_sink")
    const playbin = Gst.ElementFactory.make("playbin", "ags_filtered_video")
    // GstApp installs the AppSink pull-method overrides when its GI namespace
    // is loaded. Keep this as a runtime check: a type-only use is removed by
    // the AGS bundler, leaving try_pull_sample/try_pull_preroll undefined and
    // silently forcing both video surfaces onto their unfiltered fallbacks.
    if (!sinkElement || !(sinkElement instanceof GstApp.AppSink) || !playbin) {
      throw new Error("Required GStreamer CPU video elements are unavailable")
    }
    const sink = sinkElement as GstApp.AppSink

    ;(playbin as any).video_sink = renderBin
    ;(playbin as any).flags = Number((playbin as any).flags) & ~0x06 // video only: no duplicate audio/subtitles
    ;(playbin as any).uri = Gio.File.new_for_path(filePath).get_uri()

    ytFilteredPipeline = playbin
    ytFilteredSink = sink
    ytFilteredLastPlaying = null
    restartFilteredFrameTimer()

    const stream = ytMediaStream
    if (stream) {
      ytFilteredObservedStream = stream
      ytFilteredPlayingSignalId = stream.connect("notify::playing", () => {
        if (ytFilteredObservedStream === stream) syncFilteredVideoRenderer()
      })
    }

    const bus = playbin.get_bus()
    bus?.add_signal_watch()
    bus?.connect("message::error", (_bus, message) => {
      if (ytFilteredPipeline !== playbin) return
      try {
        const [error, debug] = message.parse_error()
        console.error("Media Center CPU video renderer failed:", error.message, debug || "")
      } catch { /* ignore malformed error message */ }
      GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
        if (ytFilteredPipeline === playbin) stopFilteredVideoRenderer()
        return GLib.SOURCE_REMOVE
      })
    })

    playbin.set_state(Gst.State.PAUSED)
    // Synchronize once when the source is loaded, then react only to explicit
    // seeks and play-state notifications. A manual FLUSH keeps the previous
    // immutable texture visible until the first post-seek frame is published.
    seekFilteredVideoRenderer(readMediaTimestampRaw())
    syncFilteredVideoRenderer()
  } catch (error) {
    console.error("Falling back to Gtk.Video:", error)
    stopFilteredVideoRenderer()
  }
}

export function toggleMediaCenterVideoPlayback() {
  try {
    const stream = ytMediaStream as any
    if (!stream) return
    stream.set_playing?.(!Boolean(stream.get_playing?.()))
    syncFilteredVideoRenderer()
  } catch { /* ignore */ }
}

export function seekMediaCenterVideo(ratio: number) {
  try {
    const stream = ytMediaStream as any
    if (!stream) return
    const duration = Number(stream.get_duration?.() || 0)
    if (duration <= 0) return
    const target = Math.max(0, Math.min(1, ratio)) * duration
    stream.seek?.(target)
    seekFilteredVideoRenderer(target)
  } catch { /* ignore */ }
}

function refreshTvMode() {
  if (ytTvStack) {
    const desired = !ytNowPlaying
      ? "off"
      : ytVideoVisible && ytVideoReady ? "video" : "thumb"
    if (ytTvStack.get_visible_child_name() !== desired) ytTvStack.set_visible_child_name(desired)
  }
  ytTvRefreshHook?.()
  notifyVideoSurfacesChanged()
}

function clearEmbeddedMedia() {
  const prev = ytMediaStream
  // Clear shared state before notifying video surfaces so they never receive
  // the outgoing stream as a one-frame fallback during teardown.
  ytMediaStream = null
  ytVideoReady = false
  ytCurrentFilePath = null
  stopFilteredVideoRenderer()
  try { ytVideo?.set_media_stream(null) } catch { /* ignore */ }
  if (prev) {
    try { (prev as any).set_playing?.(false) } catch { /* ignore */ }
    try { (prev as any).set_muted?.(true) } catch { /* ignore */ }
    try { (prev as any).set_volume?.(0) } catch { /* ignore */ }
    try { (prev as any).stream_unprepared?.() } catch { /* ignore */ }
  }
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

function removeYtFile(videoId: string, quality: "360" | "480") {
  const path = ytFilePath(videoId, quality)
  try {
    if (GLib.file_test(path, GLib.FileTest.EXISTS)) GLib.unlink(path)
  } catch { /* ignore */ }
}

function cleanupLowQualityAfterHighQuality(videoId: string) {
  removeYtFile(videoId, "360")
}

function removeVideoFromPlaylists(videoId: string) {
  let changed = false
  for (const playlist of ytPlaylists) {
    const before = playlist.itemIds.length
    playlist.itemIds = playlist.itemIds.filter((id) => id !== videoId)
    if (playlist.itemIds.length !== before) changed = true
    if (playlist.coverVideoId === videoId) {
      playlist.coverVideoId = playlist.itemIds[0] || null
      changed = true
    }
  }
  if (changed) saveYtPlaylists()
}

function deleteDownloadedVideo(videoId: string) {
  const wasCurrent = ytNowPlaying?.id === videoId
  if (wasCurrent) {
    ytPlayToken++
    stopYtAll()
    ytNowPlaying = null
    ytStatus = "idle"
    ytStatusMsg = ""
    refreshTvMode()
  }
  removeYtFile(videoId, "360")
  removeYtFile(videoId, "480")
  ytVideoMeta.delete(videoId)
  saveYtVideoMeta()
  removeVideoFromPlaylists(videoId)
  ytUiRefreshHook?.()
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
  cleanupLowQualityAfterHighQuality(videoId)
  return dest
}

function swapMediaToFile(filePath: string, token: number, videoId: string, quality: "360" | "480") {
  if (token !== ytPlayToken || ytNowPlaying?.id !== videoId) return

  const prevStream = ytMediaStream
  const hadPrevStream = prevStream !== null
  const wasPlaying = (() => {
    if (!hadPrevStream) return true
    try { return Boolean((prevStream as any)?.get_playing?.()) } catch { return true }
  })()
  const prevDur = readMediaDurationRaw()
  const prevPos = readMediaTimestampRaw()
  const prevRatio = prevDur > 0 ? Math.max(0, Math.min(1, prevPos / prevDur)) : 0

  // Tear down the previous stream BEFORE wiring up the new one. Leaving the old
  // Gtk.MediaFile alive keeps its GStreamer pipeline decoding audio, which is the
  // "double audio" symptom during a 360p->480p hot-swap.
  if (prevStream) {
    try { (prevStream as any).set_playing?.(false) } catch { /* ignore */ }
    try { (prevStream as any).set_muted?.(true) } catch { /* ignore */ }
    try { (prevStream as any).set_volume?.(0) } catch { /* ignore */ }
    try { (prevStream as any).stream_unprepared?.() } catch { /* ignore */ }
  }

  const media = Gtk.MediaFile.new_for_file(Gio.File.new_for_path(filePath))
  media.set_muted(false)
  ytMediaStream = media
  ytCurrentQuality = quality
  ytCurrentFilePath = filePath
  // Bind the real playback widget immediately. Surface subscribers are also
  // notified so the desktop mirror follows 360p -> 480p stream replacements
  // instead of retaining the torn-down MediaFile.
  ytVideo?.set_media_stream(media)
  notifyVideoSurfacesChanged()
  startFilteredVideoRenderer(filePath)
  try { (ytMediaStream as any).set_playing?.(true) } catch { /* ignore */ }
  // PipeWire/PulseAudio may restore gjs streams as muted+0% — force unmute repeatedly until the stream is active.
  const unmutePactl = () => execAsync(["bash", "-c",
    "pactl list sink-inputs | awk '/Sink Input/{id=$3} /application.name.*=.*\"gjs\"/{print id}'" +
    " | tr -d '#' | while read sid; do pactl set-sink-input-mute \"$sid\" 0; pactl set-sink-input-volume \"$sid\" 100%; done"
  ]).catch(() => { /* ignore */ })
  let unmuteAttempts = 0
  const unmuteToken = token
  GLib.timeout_add(GLib.PRIORITY_DEFAULT, 200, () => {
    if (unmuteToken !== ytPlayToken) return GLib.SOURCE_REMOVE
    unmutePactl()
    unmuteAttempts++
    return unmuteAttempts < 8 ? GLib.SOURCE_CONTINUE : GLib.SOURCE_REMOVE
  })

  // Seek once duration becomes available on the new stream.
  let attempts = 0
  GLib.timeout_add(GLib.PRIORITY_DEFAULT, 120, () => {
    if (token !== ytPlayToken || ytNowPlaying?.id !== videoId) return GLib.SOURCE_REMOVE
    attempts++
    const dur = readMediaDurationRaw()
    if (dur > 0) {
      try {
        const target = dur * prevRatio
        ;(ytMediaStream as any).seek?.(target)
        seekFilteredVideoRenderer(target)
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
    cleanupLowQualityAfterHighQuality(track.id)
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

export function getMediaCenterDesktopVideoState() {
  const stream = ytMediaStream as any
  const filePath = ytCurrentFilePath
  const ready = Boolean(ytNowPlaying && ytVideoReady && filePath && GLib.file_test(filePath, GLib.FileTest.EXISTS))

  return {
    id: ytNowPlaying?.id || "",
    title: ytNowPlaying?.title || "",
    filePath: ready && filePath ? filePath : "",
    mediaStream: ready ? ytMediaStream : null,
    texture: ready ? ytDesktopFilteredTexture : null,
    ambientPaintable: ready ? ytAmbientPaintable : null,
    ready,
    playing: ready ? Boolean(stream?.get_playing?.()) : false,
    position: ready ? readMediaTimestampRaw() : 0,
    duration: ready ? readMediaDurationRaw() : 0,
    positionSeconds: ready ? mediaUnitsToSeconds(readMediaTimestampRaw()) : 0,
    durationSeconds: ready ? mediaUnitsToSeconds(readMediaDurationRaw()) : 0,
    quality: ytCurrentQuality,
    effectMode: videoEffects.colorMode,
  }
}

export function getMediaCenterNowPlayingState(): MediaCenterNowPlayingState {
  if (ytNowPlaying) {
    let playing = false
    try { playing = Boolean((ytMediaStream as any)?.get_playing?.()) } catch { /* ignore */ }
    return {
      available: true,
      title: ytNowPlaying.title || "Unknown",
      artist: ytNowPlaying.channel || "Unknown channel",
      playing,
      source: "youtube",
    }
  }

  const mpris = AstalMpris.get_default()
  const players = mpris.players || []
  const player = players.find((p) => p.playbackStatus === AstalMpris.PlaybackStatus.PLAYING)
    || players[0]
    || null
  if (!player) {
    return { available: false, title: "", artist: "", playing: false, source: "none" }
  }
  return {
    available: true,
    title: player.title || player.identity || "Unknown",
    artist: player.artist || player.identity || "Unknown artist",
    playing: player.playbackStatus === AstalMpris.PlaybackStatus.PLAYING,
    source: "mpris",
  }
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
      "-printf",
      "%T@\t%f\n",
    ])
  } catch {
    return []
  }

  const groups = new Map<string, Set<string>>()
  // Track the earliest mtime per id as its "added" timestamp.
  const addedAt = new Map<string, number>()
  for (const line of raw.split("\n")) {
    if (!line.trim()) continue
    const [mtimeStr, file] = line.split("\t")
    if (!file) continue
    const m = file.trim().match(/^(.+)-(\d{3,4})\.mp4$/)
    if (!m) continue
    const id = m[1]
    const q = m[2]
    if (!groups.has(id)) groups.set(id, new Set<string>())
    groups.get(id)!.add(q)
    const mtime = Number(mtimeStr) || 0
    const prev = addedAt.get(id)
    if (prev === undefined || mtime < prev) addedAt.set(id, mtime)
  }

  return Array.from(groups.entries())
    .map(([id, set]) => ({
      id,
      qualities: Array.from(set).sort((a, b) => Number(a) - Number(b)),
      addedAt: addedAt.get(id) || 0,
    }))
    .sort((a, b) => a.id.localeCompare(b.id))
}

interface DownloadedRowView {
  widget: Gtk.Widget
  update: (item: DownloadedVideoGroup) => void
}

function makeDownloadedRow(
  item: DownloadedVideoGroup,
  onPlay: (id: string) => void,
  onQueue: (id: string) => void,
  onToggleInPlaylist: (id: string) => void,
  onDeleteVideo: (id: string) => void,
  isInActivePlaylist: (id: string) => boolean,
  hasActivePlaylist: () => boolean,
): DownloadedRowView {
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

  const infoLbl = new Gtk.Label({ xalign: 0 })
  infoLbl.add_css_class("yt-result-channel")

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

  const queueBtn = new Gtk.Button()
  queueBtn.add_css_class("mc-downloaded-add")
  queueBtn.set_tooltip_text("Add to queue")
  const queueIcon = Gtk.Image.new_from_icon_name("media-playlist-consecutive-symbolic")
  queueIcon.pixel_size = 14
  queueBtn.set_child(queueIcon)
  queueBtn.connect("clicked", () => onQueue(item.id))
  row.append(queueBtn)

  const deleteBtn = new Gtk.Button()
  deleteBtn.add_css_class("mc-downloaded-delete")
  deleteBtn.set_tooltip_text("Delete video from disk")
  const deleteIcon = Gtk.Image.new_from_icon_name("user-trash-symbolic")
  deleteIcon.pixel_size = 14
  deleteBtn.set_child(deleteIcon)
  deleteBtn.connect("clicked", () => onDeleteVideo(item.id))
  row.append(deleteBtn)

  let lastHasSelection: boolean | null = null
  let lastInPlaylist: boolean | null = null
  const refreshPlaylistAction = () => {
    const hasSel = hasActivePlaylist()
    const inPl = hasSel && isInActivePlaylist(item.id)
    if (hasSel !== lastHasSelection) {
      lastHasSelection = hasSel
      listBtn.set_sensitive(hasSel)
    }
    if (inPl === lastInPlaylist) return
    lastInPlaylist = inPl
    if (inPl) {
      listBtn.add_css_class("active")
      listIcon.icon_name = "emblem-ok-symbolic"
    } else {
      listBtn.remove_css_class("active")
      listIcon.icon_name = "list-add-symbolic"
    }
  }

  const update = (next: DownloadedVideoGroup) => {
    if (next.id !== item.id) return
    const meta = ytVideoMeta.get(next.id)
    titleLbl.set_label(meta?.title || `Saved video (${next.id})`)
    if (!meta?.title) queueFetchVideoMeta(next.id)
    const plays = getPlayCount(next.id)
    const playsTag = `${plays} play${plays === 1 ? "" : "s"}`
    infoLbl.set_label([next.qualities.map((q) => `${q}p`).join(" "), playsTag].join("  •  "))
    refreshPlaylistAction()
  }

  update(item)
  return { widget: row, update }
}

// ── Imperative result row ─────────────────────────────────────────────
interface ResultRowView {
  widget: Gtk.Widget
  update: (track: YtResult) => void
}

function makeResultRow(
  track: YtResult,
  onPlay: (t: YtResult) => void,
  onQueue: (t: YtResult) => void,
): ResultRowView {
  let currentTrack = track
  const wrap = new Gtk.Box({ spacing: 4 })
  wrap.add_css_class("yt-result-wrap")

  const row = new Gtk.Button()
  row.add_css_class("yt-result-row")
  row.set_hexpand(true)

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

  const chanLbl = new Gtk.Label({ xalign: 0 })
  chanLbl.add_css_class("yt-result-channel")

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

  const durLbl = new Gtk.Label()
  durLbl.add_css_class("yt-result-duration")
  rightCol.append(durLbl)

  outer.append(rightCol)
  row.set_child(outer)

  let wasPlaying = false
  GLib.timeout_add(GLib.PRIORITY_DEFAULT, 200, () => {
    if (!wrap.get_parent()) return GLib.SOURCE_REMOVE
    const isPlaying = ytNowPlaying?.id === currentTrack.id
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

  row.connect("clicked", () => onPlay(currentTrack))
  wrap.append(row)

  const queueBtn = new Gtk.Button()
  queueBtn.add_css_class("yt-result-queue")
  queueBtn.set_valign(Gtk.Align.CENTER)
  queueBtn.set_tooltip_text("Add to queue")
  queueBtn.set_child(Gtk.Image.new_from_icon_name("list-add-symbolic"))
  queueBtn.connect("clicked", () => onQueue(currentTrack))
  wrap.append(queueBtn)

  const update = (next: YtResult) => {
    currentTrack = next
    row.set_tooltip_text(`Play: ${next.title}`)
    titleLbl.set_label(next.title)
    chanLbl.set_label(next.channel)
    durLbl.set_label(next.duration)
    durLbl.set_visible(Boolean(next.duration))
  }

  update(track)
  return { widget: wrap, update }
}

// ── Shared video-effects controls ─────────────────────────────────────
export function makeMediaCenterVideoSettingsButton(cssClass = "mc-video-settings-btn"): Gtk.MenuButton {
  const button = new Gtk.MenuButton()
  button.add_css_class("video-fx-button")
  button.add_css_class(cssClass)
  button.set_tooltip_text("Video effects and display settings")
  const buttonIcon = Gtk.Image.new_from_icon_name("emblem-system-symbolic")
  buttonIcon.pixel_size = 14
  button.set_child(buttonIcon)

  const popover = new Gtk.Popover()
  popover.add_css_class("video-fx-popover")
  const root = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL, spacing: 10 })
  root.add_css_class("video-fx-panel")

  const header = new Gtk.Box({ spacing: 8 })
  const headerText = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL, spacing: 1 })
  headerText.set_hexpand(true)
  const title = new Gtk.Label({ label: "VIDEO DISPLAY", xalign: 0 })
  title.add_css_class("video-fx-title")
  const subtitle = new Gtk.Label({ label: "Checkbox grid · stable CPU renderer", xalign: 0 })
  subtitle.add_css_class("video-fx-subtitle")
  headerText.append(title)
  headerText.append(subtitle)
  header.append(headerText)
  const reset = new Gtk.Button({ label: "Reset" })
  reset.add_css_class("video-fx-reset")
  reset.connect("clicked", () => updateVideoEffects({ ...DEFAULT_VIDEO_EFFECTS }))
  header.append(reset)
  root.append(header)

  const presetSection = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL, spacing: 6 })
  presetSection.add_css_class("video-fx-presets")
  const presetTitle = new Gtk.Label({ label: "PRESETS", xalign: 0 })
  presetTitle.add_css_class("video-fx-section-label")
  presetSection.append(presetTitle)

  const presetSelectRow = new Gtk.Box({ spacing: 7 })
  const presetSelect = Gtk.DropDown.new_from_strings(["Custom / unsaved"])
  presetSelect.add_css_class("video-fx-select")
  presetSelect.add_css_class("video-fx-preset-select")
  presetSelect.set_hexpand(true)
  presetSelectRow.append(presetSelect)
  const deletePreset = new Gtk.Button()
  deletePreset.add_css_class("video-fx-preset-delete")
  deletePreset.set_tooltip_text("Delete selected custom preset")
  const deletePresetIcon = Gtk.Image.new_from_icon_name("user-trash-symbolic")
  deletePresetIcon.pixel_size = 13
  deletePreset.set_child(deletePresetIcon)
  presetSelectRow.append(deletePreset)
  presetSection.append(presetSelectRow)

  const savePresetRow = new Gtk.Box({ spacing: 7 })
  const presetName = new Gtk.Entry()
  presetName.add_css_class("video-fx-preset-name")
  presetName.set_placeholder_text("Preset name…")
  presetName.set_max_length(48)
  presetName.set_hexpand(true)
  savePresetRow.append(presetName)
  const savePreset = new Gtk.Button({ label: "Save current" })
  savePreset.add_css_class("video-fx-preset-save")
  savePresetRow.append(savePreset)
  presetSection.append(savePresetRow)

  const presetStatus = new Gtk.Label({ xalign: 0 })
  presetStatus.add_css_class("video-fx-preset-status")
  presetStatus.set_visible(false)
  presetSection.append(presetStatus)
  root.append(presetSection)

  let presetOptions: (VideoEffectPreset | null)[] = []
  let syncingPreset = false
  const syncPresetSelection = () => {
    const index = presetOptions.findIndex((preset) =>
      preset !== null && videoEffectSettingsEqual(preset.settings, videoEffects))
    const selected = index >= 0 ? index : 0
    syncingPreset = true
    if (presetSelect.selected !== selected) presetSelect.selected = selected
    syncingPreset = false
    deletePreset.sensitive = Boolean(presetOptions[selected]?.custom)
  }
  const refreshPresetList = () => {
    presetOptions = [null, ...allVideoPresets()]
    const labels = presetOptions.map((preset) => {
      if (!preset) return "Custom / unsaved"
      return preset.custom ? `${preset.name} · saved` : preset.name
    })
    syncingPreset = true
    presetSelect.model = Gtk.StringList.new(labels)
    syncingPreset = false
    syncPresetSelection()
  }
  const setPresetStatus = (message: string, error = false) => {
    presetStatus.set_label(message)
    presetStatus.set_visible(Boolean(message))
    if (error) presetStatus.add_css_class("error")
    else presetStatus.remove_css_class("error")
  }

  presetSelect.connect("notify::selected", () => {
    if (syncingPreset) return
    const preset = presetOptions[presetSelect.selected]
    deletePreset.sensitive = Boolean(preset?.custom)
    if (!preset) return
    presetName.text = preset.custom ? preset.name : ""
    updateVideoEffects({ ...preset.settings })
    setPresetStatus(`Loaded “${preset.name}”`)
  })

  const saveCurrentPreset = () => {
    const name = presetName.text.trim()
    if (!name) {
      setPresetStatus("Enter a name before saving.", true)
      return
    }
    if (BUILTIN_VIDEO_PRESETS.some((preset) => preset.name.toLowerCase() === name.toLowerCase())) {
      setPresetStatus("That name belongs to a built-in preset.", true)
      return
    }

    const previousPresets = customVideoPresets.map((preset) => ({
      ...preset,
      settings: { ...preset.settings },
    }))
    const existing = customVideoPresets.find((preset) => preset.name.toLowerCase() === name.toLowerCase())
    if (existing) {
      existing.name = name
      existing.settings = { ...videoEffects }
    } else {
      customVideoPresets.push({
        id: `custom:${GLib.uuid_string_random()}`,
        name,
        settings: { ...videoEffects },
        custom: true,
      })
    }
    if (!saveCustomVideoPresets()) {
      customVideoPresets = previousPresets
      setPresetStatus("Could not write the preset file.", true)
      return
    }
    presetName.text = name
    setPresetStatus(existing ? `Updated “${name}”` : `Saved “${name}”`)
    for (const listener of videoPresetListeners) listener()
  }
  savePreset.connect("clicked", saveCurrentPreset)
  presetName.connect("activate", saveCurrentPreset)

  deletePreset.connect("clicked", () => {
    const preset = presetOptions[presetSelect.selected]
    if (!preset?.custom) return
    const previousPresets = customVideoPresets
    customVideoPresets = customVideoPresets.filter((item) => item.id !== preset.id)
    if (!saveCustomVideoPresets()) {
      customVideoPresets = previousPresets
      setPresetStatus("Could not update the preset file.", true)
      return
    }
    setPresetStatus(`Deleted “${preset.name}”`)
    for (const listener of videoPresetListeners) listener()
  })

  const colorModes: { value: VideoColorMode; label: string }[] = [
    { value: "original", label: "Original" },
    { value: "mono", label: "Mono checkbox" },
    { value: "rgb332", label: "8-bit · RGB332" },
    { value: "rgb565", label: "16-bit · RGB565" },
    { value: "full", label: "Full · 24-bit" },
  ]
  const blockSizes = VIDEO_BLOCK_SIZES

  const makeRow = (labelText: string, control: Gtk.Widget, valueLabel?: Gtk.Label): Gtk.Box => {
    const row = new Gtk.Box({ spacing: 8 })
    row.add_css_class("video-fx-row")
    const label = new Gtk.Label({ label: labelText, xalign: 0 })
    label.add_css_class("video-fx-label")
    label.set_size_request(86, -1)
    row.append(label)
    control.set_hexpand(true)
    row.append(control)
    if (valueLabel) {
      valueLabel.add_css_class("video-fx-value")
      valueLabel.set_size_request(34, -1)
      row.append(valueLabel)
    }
    return row
  }

  const mode = Gtk.DropDown.new_from_strings(colorModes.map((m) => m.label))
  mode.add_css_class("video-fx-select")
  mode.connect("notify::selected", () => {
    const selected = colorModes[mode.selected]
    if (selected) updateVideoEffects({ colorMode: selected.value })
  })
  root.append(makeRow("Color", mode))

  const block = Gtk.DropDown.new_from_strings(blockSizes.map((n) => `${n}×${n} px`))
  block.add_css_class("video-fx-select")
  block.connect("notify::selected", () => {
    const selected = blockSizes[block.selected]
    if (selected) updateVideoEffects({ blockSize: selected })
  })
  root.append(makeRow("px / box", block))

  const rangeWidgets: {
    key: keyof Pick<VideoEffectSettings, "fps" | "cellSize" | "gap" | "threshold" | "thickness" | "diffusion" | "glow">
    scale: Gtk.Scale
    value: Gtk.Label
  }[] = []
  const addRange = (
    labelText: string,
    key: typeof rangeWidgets[number]["key"],
    min: number,
    max: number,
    step: number,
  ): Gtk.Box => {
    const scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, min, max, step)
    scale.set_draw_value(false)
    scale.add_css_class("video-fx-scale")
    const value = new Gtk.Label({ xalign: 1 })
    scale.connect("value-changed", () => {
      updateVideoEffects({ [key]: Math.round(scale.get_value()) } as Partial<VideoEffectSettings>)
    })
    rangeWidgets.push({ key, scale, value })
    return makeRow(labelText, scale, value)
  }

  root.append(addRange("FPS", "fps", 1, 60, 1))
  root.append(addRange("Cell px", "cellSize", 10, 40, 1))
  root.append(addRange("Gap px", "gap", 0, 6, 1))
  root.append(addRange("Threshold", "threshold", 1, 254, 1))

  const separator = new Gtk.Separator({ orientation: Gtk.Orientation.HORIZONTAL })
  separator.add_css_class("video-fx-separator")
  root.append(separator)

  const diffuserSwitch = new Gtk.Switch()
  diffuserSwitch.set_halign(Gtk.Align.END)
  diffuserSwitch.connect("notify::active", () => updateVideoEffects({ diffuser: diffuserSwitch.active }))
  root.append(makeRow("Diffuser", diffuserSwitch))

  const diffuserDetails = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL, spacing: 7 })
  diffuserDetails.add_css_class("video-fx-diffuser")
  const diffuserTitle = new Gtk.Label({ label: "DIFFUSER KNOBS", xalign: 0 })
  diffuserTitle.add_css_class("video-fx-section-label")
  diffuserDetails.append(diffuserTitle)
  diffuserDetails.append(addRange("Thickness", "thickness", 0, 100, 1))
  diffuserDetails.append(addRange("Diffuse", "diffusion", 0, 100, 1))
  diffuserDetails.append(addRange("Glow", "glow", 0, 100, 1))
  root.append(diffuserDetails)

  const hint = new Gtk.Label({
    label: "Settings are shared with the desktop video.",
    xalign: 0,
  })
  hint.add_css_class("video-fx-hint")
  root.append(hint)

  const syncControls = () => {
    const modeIndex = colorModes.findIndex((m) => m.value === videoEffects.colorMode)
    if (mode.selected !== modeIndex) mode.selected = modeIndex
    const blockIndex = blockSizes.indexOf(videoEffects.blockSize)
    if (block.selected !== blockIndex) block.selected = blockIndex
    for (const item of rangeWidgets) {
      const next = Number(videoEffects[item.key])
      if (Math.round(item.scale.get_value()) !== next) item.scale.set_value(next)
      item.value.set_label(String(next))
    }
    if (diffuserSwitch.active !== videoEffects.diffuser) diffuserSwitch.active = videoEffects.diffuser
    diffuserDetails.sensitive = videoEffects.diffuser
    syncPresetSelection()
  }

  videoEffectsListeners.add(syncControls)
  videoPresetListeners.add(refreshPresetList)
  popover.connect("destroy", () => {
    videoEffectsListeners.delete(syncControls)
    videoPresetListeners.delete(refreshPresetList)
  })
  refreshPresetList()
  syncControls()
  popover.set_child(root)
  button.set_popover(popover)
  return button
}

// ── TV: shows current YT thumbnail and embedded video ─────────────────
function MediaTV(): { widget: Gtk.Widget; cleanup: () => void } {
  const frame = new Gtk.Box()
  frame.add_css_class("mc-tv")
  frame.set_size_request(MEDIA_TV_STAGE_WIDTH, MEDIA_TV_STAGE_HEIGHT)
  frame.set_halign(Gtk.Align.CENTER)

  const stack = new Gtk.Stack()
  stack.set_hexpand(true); stack.set_vexpand(true)
  stack.set_size_request(MEDIA_TV_STAGE_WIDTH, MEDIA_TV_STAGE_HEIGHT)
  stack.set_transition_type(Gtk.StackTransitionType.NONE)
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

  const videoSurface = new Gtk.Stack()
  videoSurface.set_size_request(FILTERED_FRAME_WIDTH, FILTERED_FRAME_HEIGHT)
  videoSurface.set_halign(Gtk.Align.CENTER)
  videoSurface.set_valign(Gtk.Align.CENTER)
  videoSurface.set_overflow(Gtk.Overflow.HIDDEN)
  videoSurface.set_transition_type(Gtk.StackTransitionType.NONE)
  videoSurface.add_css_class("mc-tv-video-shell")

  // The real stream stays as a startup/error fallback. As soon as the CPU
  // renderer publishes a texture, switch to the direct 8/16/24-bit snapshot.
  const video = new Gtk.Video()
  video.set_autoplay(true)
  video.set_loop(false)
  video.set_hexpand(true)
  video.set_vexpand(true)
  video.add_css_class("mc-tv-video")
  ytVideo = video
  videoSurface.add_named(video, "fallback")

  const filteredSurface = makeMediaCenterVideoEffectSurface(
    "mc-tv-video",
    "mc-tv-filtered",
  )
  videoSurface.add_named(filteredSurface.widget, "filtered")
  videoSurface.set_visible_child_name("fallback")

  const ambientPicture = new Gtk.Picture()
  ambientPicture.set_content_fit(Gtk.ContentFit.FILL)
  ambientPicture.set_hexpand(true)
  ambientPicture.set_vexpand(true)
  ambientPicture.set_can_target(false)
  ambientPicture.add_css_class("mc-tv-ambient")

  const ambientShell = new Gtk.Overlay()
  ambientShell.set_hexpand(true)
  ambientShell.set_vexpand(true)
  ambientShell.set_overflow(Gtk.Overflow.HIDDEN)
  // This larger transparent canvas sits behind the centered video. Rays start
  // at the video edge and travel outward through the surrounding panel.
  ambientShell.set_child(ambientPicture)
  ambientShell.add_overlay(videoSurface)
  ambientShell.add_css_class("mc-tv-ambient-shell")

  stack.add_named(ambientShell, "video")
  stack.set_visible_child_name("off")

  let lastId = ""
  const thumbPic = new Gtk.Picture()
  thumbPic.set_content_fit(Gtk.ContentFit.COVER)
  thumbPic.set_halign(Gtk.Align.CENTER)
  thumbPic.set_valign(Gtk.Align.CENTER)
  thumbPic.set_size_request(FILTERED_FRAME_WIDTH, FILTERED_FRAME_HEIGHT)
  thumbPic.add_css_class("mc-tv-img")
  thumbHolder.append(thumbPic)
  let lastTexture: Gdk.Texture | null = null
  let lastAmbientPaintable: Gdk.Paintable | null = null
  let lastFallbackStream: Gtk.MediaStream | null = null

  const syncVideoSurface = () => {
    const mediaCenterVisible = Boolean(app.get_window("media-center")?.visible)
    const videoSurfaceVisible = mediaCenterVisible && ytVideoVisible && ytVideoReady
    const nextTexture = videoSurfaceVisible ? ytFilteredTexture : null
    const nextAmbientPaintable = videoSurfaceVisible ? ytAmbientPaintable : null
    const nextFallbackStream = videoSurfaceVisible && !nextTexture ? ytMediaStream : null
    if (nextTexture !== lastTexture) {
      lastTexture = nextTexture
      filteredSurface.setTexture(lastTexture)
    }
    if (nextAmbientPaintable !== lastAmbientPaintable) {
      lastAmbientPaintable = nextAmbientPaintable
      ambientPicture.set_paintable(lastAmbientPaintable)
    }
    if (nextFallbackStream !== lastFallbackStream) {
      lastFallbackStream = nextFallbackStream
      video.set_media_stream(lastFallbackStream)
    }
    const desiredSurface = lastTexture ? "filtered" : "fallback"
    if (videoSurface.get_visible_child_name() !== desiredSurface) {
      videoSurface.set_visible_child_name(desiredSurface)
    }
  }

  const unsubscribeSurface = subscribeMediaCenterVideoSurface(syncVideoSurface)
  const refreshThumbnail = () => {
    syncVideoSurface()
    const id = ytNowPlaying?.id || ""
    if (!id) {
      if (lastId) {
        lastId = ""
        thumbPic.set_paintable(null)
      }
      return
    }

    if (id === lastId) return

    lastId = id
    const setPic = (path: string) => {
      if (ytNowPlaying?.id !== id) return
      const texture = thumbnailTexture(id, path)
      if (texture) thumbPic.set_paintable(texture)
      else thumbPic.set_filename(path)
    }

    if (thumbCache.has(id)) setPic(thumbCache.get(id)!)
    else fetchThumbnail(id, setPic)
  }
  ytTvRefreshHook = refreshThumbnail
  refreshThumbnail()

  return {
    widget: frame,
    cleanup: () => {
      if (ytTvRefreshHook === refreshThumbnail) ytTvRefreshHook = null
      unsubscribeSurface()
      filteredSurface.setTexture(null)
      ambientPicture.set_paintable(null)
      video.set_media_stream(null)
      if (ytVideo === video) ytVideo = null
      thumbPic.set_paintable(null)
    },
  }
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
            updateMediaCenterAudioSpectrum(values)
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
  const queueCountState = createPoll(0, 300, () => ytQueue.length)

  let win: Astal.Window | null = null
  const { TOP, LEFT, RIGHT, BOTTOM } = Astal.WindowAnchor

  const hide = () => { if (win) win.visible = false }

  const { widget: tvWidget, cleanup: tvCleanup } = MediaTV()
  const { widget: cavaWidget, cleanup: cavaCleanup } = CavaBars()

  let resultsList: Gtk.Box | null = null
  let emptyBox: Gtk.Widget | null = null
  const resultRowCache = new Map<string, ResultRowView>()
  let downloadedList: Gtk.Box | null = null
  let downloadedEmpty: Gtk.Widget | null = null
  const downloadedRowCache = new Map<string, DownloadedRowView>()
  let downloadedItemsCache: DownloadedVideoGroup[] = []
  let downloadedSig = ""
  let downloadedRefreshId = 0
  let downloadedScanBusy = false
  let downloadedFilterEntry: Gtk.Entry | null = null
  let downloadedFilter = ""
  let downloadedSortKey: DownloadedSortKey = "newest"
  let downloadedSortDir: DownloadedSortDir = "desc"
  let playlistList: Gtk.Box | null = null
  let playlistEmpty: Gtk.Widget | null = null
  let playlistNameEntry: Gtk.Entry | null = null
  let playlistCoverEntry: Gtk.Entry | null = null
  let playlistItemsList: Gtk.Box | null = null
  let playlistItemsEmpty: Gtk.Widget | null = null
  let playlistAdvanceWatchId = 0
  let playlistEndedLatch = false
  let queueList: Gtk.Box | null = null
  let queueEmpty: Gtk.Widget | null = null

  if (!ytPlaylistsLoaded) loadYtPlaylists()
  if (!ytPlayCountsLoaded) loadYtPlayCounts()
  loadYtVideoMeta()

  const notifyListsChanged = () => {
    refreshDownloaded()
    rebuildDownloaded(downloadedItemsCache)
    rebuildPlaylists(ytPlaylists)
    rebuildPlaylistItems()
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
    ytPlaylists.push({ id, name: trimmed, itemIds: [], coverVideoId: null, coverImagePath: null })
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

  const moveTrackInActivePlaylist = (videoId: string, delta: -1 | 1) => {
    const playlist = getPlaylistById(ytActivePlaylistId)
    if (!playlist) return
    const idx = playlist.itemIds.indexOf(videoId)
    if (idx < 0) return
    const target = idx + delta
    if (target < 0 || target >= playlist.itemIds.length) return
    const tmp = playlist.itemIds[idx]
    playlist.itemIds[idx] = playlist.itemIds[target]
    playlist.itemIds[target] = tmp
    saveYtPlaylists()
    notifyListsChanged()
  }

  const removeTrackFromActivePlaylist = (videoId: string) => {
    const playlist = getPlaylistById(ytActivePlaylistId)
    if (!playlist) return
    const idx = playlist.itemIds.indexOf(videoId)
    if (idx < 0) return
    playlist.itemIds.splice(idx, 1)
    if (playlist.coverVideoId === videoId) playlist.coverVideoId = playlist.itemIds[0] || null
    saveYtPlaylists()
    notifyListsChanged()
  }

  const setCoverFromPlaylistItem = (videoId: string) => {
    const playlist = getPlaylistById(ytActivePlaylistId)
    if (!playlist) return
    playlist.coverVideoId = videoId
    playlist.coverImagePath = null
    if (playlistCoverEntry) playlistCoverEntry.text = ""
    saveYtPlaylists()
    notifyListsChanged()
  }

  const setCustomCoverPathForActivePlaylist = (path: string) => {
    const playlist = getPlaylistById(ytActivePlaylistId)
    if (!playlist) return
    const trimmed = path.trim()
    if (!trimmed) {
      playlist.coverImagePath = null
      saveYtPlaylists()
      notifyListsChanged()
      return
    }
    if (!GLib.file_test(trimmed, GLib.FileTest.EXISTS)) {
      ytStatus = "error"
      ytStatusMsg = "Cover image path does not exist"
      return
    }
    playlist.coverImagePath = trimmed
    saveYtPlaylists()
    notifyListsChanged()
  }

  const clearCustomCoverPathForActivePlaylist = () => {
    const playlist = getPlaylistById(ytActivePlaylistId)
    if (!playlist) return
    playlist.coverImagePath = null
    if (playlistCoverEntry) playlistCoverEntry.text = ""
    saveYtPlaylists()
    notifyListsChanged()
  }

  const openCoverFileChooser = () => {
    if (!win) return
    const chooser = new Gtk.FileChooserNative({
      title: "Select cover image",
      action: Gtk.FileChooserAction.OPEN,
      acceptLabel: "Select",
      cancelLabel: "Cancel",
      transientFor: win,
      modal: true,
    })
    const filter = new Gtk.FileFilter()
    filter.set_name("Images")
    filter.add_mime_type("image/png")
    filter.add_mime_type("image/jpeg")
    filter.add_mime_type("image/webp")
    filter.add_mime_type("image/gif")
    chooser.add_filter(filter)
    chooser.connect("response", (_dialog: Gtk.FileChooserNative, response: Gtk.ResponseType) => {
      if (response !== Gtk.ResponseType.ACCEPT) return
      const file = chooser.get_file()
      const path = file?.get_path() || ""
      if (!path) return
      if (playlistCoverEntry) playlistCoverEntry.text = path
      setCustomCoverPathForActivePlaylist(path)
    })
    chooser.show()
  }

  const beginTrackReorder = (videoId: string) => {
    playlistDragPick = videoId
    ytUiRefreshHook?.()
  }

  const endTrackReorder = (videoId: string) => {
    if (playlistDragPick === videoId) playlistDragPick = null
    ytUiRefreshHook?.()
  }

  // Pick / drop reordering helpers (pointer-friendly via pick/drop)
  const pickTrackForReorder = (videoId: string) => {
    if (!ytActivePlaylistId) return
    if (playlistDragPick === videoId) {
      playlistDragPick = null
    } else {
      playlistDragPick = videoId
    }
    ytUiRefreshHook?.()
  }

  const dropPickedBefore = (targetId: string) => {
    if (!ytActivePlaylistId || !playlistDragPick) return
    if (playlistDragPick === targetId) {
      playlistDragPick = null
      ytUiRefreshHook?.()
      return
    }
    const playlist = getPlaylistById(ytActivePlaylistId)
    if (!playlist) return
    const srcIdx = playlist.itemIds.indexOf(playlistDragPick)
    const tgtIdx = playlist.itemIds.indexOf(targetId)
    if (srcIdx < 0 || tgtIdx < 0) {
      playlistDragPick = null
      ytUiRefreshHook?.()
      return
    }
    // remove source
    playlist.itemIds.splice(srcIdx, 1)
    // compute insertion index after removal
    const insertAt = srcIdx < tgtIdx ? tgtIdx - 1 : tgtIdx
    playlist.itemIds.splice(insertAt, 0, playlistDragPick)
    playlistDragPick = null
    saveYtPlaylists()
    notifyListsChanged()
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
      if (p.coverImagePath && GLib.file_test(p.coverImagePath, GLib.FileTest.EXISTS)) {
        const customCover = new Gtk.Picture()
        customCover.set_filename(p.coverImagePath)
        customCover.set_content_fit(Gtk.ContentFit.COVER)
        customCover.set_size_request(56, 32)
        customCover.add_css_class("mc-playlist-custom-cover")
        selectBody.append(customCover)
      } else {
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
      }

      const labels = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL, spacing: 2 })
      labels.set_hexpand(true)
      const nameLbl = new Gtk.Label({ xalign: 0 })
      nameLbl.add_css_class("mc-playlist-name")
      nameLbl.set_label(p.name)
      const metaLbl = new Gtk.Label({ xalign: 0 })
      metaLbl.add_css_class("mc-playlist-meta")
      const coverTag = p.coverImagePath ? " • custom cover" : ""
      metaLbl.set_label(`${p.itemIds.length} items${coverTag}`)
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

  function rebuildPlaylistItems() {
    if (!playlistItemsList) return
    const playlist = getPlaylistById(ytActivePlaylistId)
    if (playlistCoverEntry) playlistCoverEntry.text = playlist?.coverImagePath || ""

    let child = playlistItemsList.get_first_child()
    while (child) {
      const next = child.get_next_sibling()
      if (child !== playlistItemsEmpty) playlistItemsList.remove(child)
      child = next
    }

    const ids = playlist?.itemIds || []
    let prev: Gtk.Widget | null = null
    ids.forEach((id, idx) => {
      const row = new Gtk.Box({ spacing: 6 })
      row.add_css_class("mc-playlist-item-row")
      if (playlistDragPick === id) row.add_css_class("picked")

      const motion = new Gtk.EventControllerMotion()
      motion.connect("enter", () => {
        if (playlistDragPick && playlistDragPick !== id) {
          dropPickedBefore(id)
        }
      })
      row.add_controller(motion)

      const playBtn = new Gtk.Button()
      playBtn.add_css_class("mc-playlist-item-play")
      playBtn.connect("clicked", () => playDownloadedTrack(id))
      const playBody = new Gtk.Box({ spacing: 8 })
      playBody.append(makeThumbnailWidget(id, 48, 28))
      const meta = ytVideoMeta.get(id)
      const lbl = new Gtk.Label({ xalign: 0 })
      lbl.add_css_class("mc-playlist-item-title")
      lbl.set_ellipsize(3)
      lbl.set_max_width_chars(28)
      lbl.set_label(meta?.title || `Saved video (${id})`)
      if (!meta?.title) queueFetchVideoMeta(id)
      playBody.append(lbl)
      playBtn.set_child(playBody)
      row.append(playBtn)

      const upBtn = new Gtk.Button()
      upBtn.add_css_class("mc-playlist-item-action")
      upBtn.set_tooltip_text("Move up")
      upBtn.set_sensitive(idx > 0)
      upBtn.connect("clicked", () => moveTrackInActivePlaylist(id, -1))
      upBtn.set_child(Gtk.Image.new_from_icon_name("go-up-symbolic"))
      row.append(upBtn)

      const downBtn = new Gtk.Button()
      downBtn.add_css_class("mc-playlist-item-action")
      downBtn.set_tooltip_text("Move down")
      downBtn.set_sensitive(idx < ids.length - 1)
      downBtn.connect("clicked", () => moveTrackInActivePlaylist(id, 1))
      downBtn.set_child(Gtk.Image.new_from_icon_name("go-down-symbolic"))
      row.append(downBtn)

      const coverBtn = new Gtk.Button()
      coverBtn.add_css_class("mc-playlist-item-action")
      if (playlist?.coverVideoId === id && !playlist?.coverImagePath) coverBtn.add_css_class("active")
      coverBtn.set_tooltip_text("Use as album cover")
      coverBtn.connect("clicked", () => setCoverFromPlaylistItem(id))
      coverBtn.set_child(Gtk.Image.new_from_icon_name("emblem-photos-symbolic"))
      row.append(coverBtn)

      const dragBtn = new Gtk.Button()
      dragBtn.add_css_class("mc-playlist-item-action")
      dragBtn.add_css_class("mc-playlist-item-drag-handle")
      dragBtn.set_tooltip_text(playlistDragPick === id ? "Release to cancel" : "Hold and drag to reorder")
      const dragGesture = new Gtk.GestureClick()
      dragGesture.connect("pressed", () => beginTrackReorder(id))
      dragGesture.connect("released", () => endTrackReorder(id))
      dragBtn.add_controller(dragGesture)
      const dragIcon = Gtk.Image.new_from_icon_name("transform-move-symbolic")
      dragIcon.pixel_size = 14
      dragBtn.set_child(dragIcon)
      row.append(dragBtn)

      const removeBtn = new Gtk.Button()
      removeBtn.add_css_class("mc-playlist-item-action")
      removeBtn.set_tooltip_text("Remove from playlist")
      removeBtn.connect("clicked", () => removeTrackFromActivePlaylist(id))
      removeBtn.set_child(Gtk.Image.new_from_icon_name("user-trash-symbolic"))
      row.append(removeBtn)

      playlistItemsList.insert_child_after(row, prev)
      prev = row
    })

    if (playlistItemsEmpty) playlistItemsEmpty.set_visible(ids.length === 0)
  }

  const playYtTrack = (track: YtResult) => {
    ytNowPlaying = track
    incrementPlayCount(track.id)
    upsertVideoMeta(track.id, {
      title: track.title,
      channel: track.channel,
      duration: track.duration,
    })
    refreshDownloaded()
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

  const deleteDownloadedTrack = (id: string) => {
    deleteDownloadedVideo(id)
    downloadedItemsCache = downloadedItemsCache.filter((item) => item.id !== id)
    rebuildDownloaded(downloadedItemsCache)
    rebuildPlaylists(ytPlaylists)
    rebuildPlaylistItems()
  }

  const trackFromId = (id: string): YtResult => {
    const meta = ytVideoMeta.get(id)
    return {
      id,
      title: meta?.title || `Saved video (${id})`,
      channel: meta?.channel || "Saved",
      duration: meta?.duration || "",
    }
  }

  const enqueueById = (id: string) => {
    enqueueTrack(trackFromId(id))
  }

  // Pull the next track from the queue first; fall back to the active playlist.
  const advanceToNext = () => {
    const next = dequeueNextTrack()
    if (next) {
      // Manual queue takes over: detach any playlist auto-advance.
      ytActivePlaylistMode = null
      notifyQueueChanged()
      playYtTrack(next)
      return
    }
    playNextFromActivePlaylist()
  }
  ytBarNextHook = advanceToNext

  // Play right now and push whatever is playing nowhere — used by "play next".
  const playFromQueueNow = (index: number) => {
    if (index < 0 || index >= ytQueue.length) return
    const track = ytQueue.splice(index, 1)[0]
    ytActivePlaylistMode = null
    notifyQueueChanged()
    playYtTrack(track)
  }

  const rebuildQueue = () => {
    if (!queueList) return
    let child = queueList.get_first_child()
    while (child) {
      const next = child.get_next_sibling()
      if (child !== queueEmpty) queueList.remove(child)
      child = next
    }

    let prev: Gtk.Widget | null = null
    ytQueue.forEach((track, index) => {
      const row = new Gtk.Box({ spacing: 8 })
      row.add_css_class("mc-queue-row")

      const posLbl = new Gtk.Label({ label: `${index + 1}` })
      posLbl.add_css_class("mc-queue-pos")
      row.append(posLbl)

      const playBtn = new Gtk.Button()
      playBtn.add_css_class("mc-queue-play")
      playBtn.set_hexpand(true)
      playBtn.set_tooltip_text(`Play now: ${track.title}`)

      const inner = new Gtk.Box({ spacing: 8 })
      inner.set_hexpand(true)
      const titleLbl = new Gtk.Label({ xalign: 0 })
      titleLbl.add_css_class("yt-result-title")
      titleLbl.set_ellipsize(3)
      titleLbl.set_max_width_chars(34)
      titleLbl.set_hexpand(true)
      titleLbl.set_label(track.title)
      inner.append(titleLbl)
      if (track.duration) {
        const durLbl = new Gtk.Label({ label: track.duration })
        durLbl.add_css_class("yt-result-duration")
        inner.append(durLbl)
      }
      playBtn.set_child(inner)
      playBtn.connect("clicked", () => playFromQueueNow(index))
      row.append(playBtn)

      const upBtn = new Gtk.Button()
      upBtn.add_css_class("mc-queue-action")
      upBtn.set_tooltip_text("Move up")
      upBtn.set_child(Gtk.Image.new_from_icon_name("go-up-symbolic"))
      upBtn.set_sensitive(index > 0)
      upBtn.connect("clicked", () => moveInQueue(index, -1))
      row.append(upBtn)

      const downBtn = new Gtk.Button()
      downBtn.add_css_class("mc-queue-action")
      downBtn.set_tooltip_text("Move down")
      downBtn.set_child(Gtk.Image.new_from_icon_name("go-down-symbolic"))
      downBtn.set_sensitive(index < ytQueue.length - 1)
      downBtn.connect("clicked", () => moveInQueue(index, 1))
      row.append(downBtn)

      const removeBtn = new Gtk.Button()
      removeBtn.add_css_class("mc-queue-action")
      removeBtn.set_tooltip_text("Remove from queue")
      removeBtn.set_child(Gtk.Image.new_from_icon_name("list-remove-symbolic"))
      removeBtn.connect("clicked", () => removeFromQueueAt(index))
      row.append(removeBtn)

      queueList!.insert_child_after(row, prev)
      prev = row
    })

    if (queueEmpty) queueEmpty.set_visible(ytQueue.length === 0)
  }
  ytQueueRefreshHook = rebuildQueue

  function rebuildResults(tracks: YtResult[]) {
    if (!resultsList) return

    const visibleIds = new Set(tracks.map((track) => track.id))
    // Preserve rows through the transient empty/searching state. Once a new
    // result set arrives, discard only rows that are genuinely no longer used.
    if (tracks.length > 0) {
      for (const [id, view] of resultRowCache) {
        if (visibleIds.has(id)) continue
        if (view.widget.get_parent() === resultsList) resultsList.remove(view.widget)
        resultRowCache.delete(id)
      }
    }

    let prev: Gtk.Widget | null = null
    for (const track of tracks) {
      let view = resultRowCache.get(track.id)
      if (!view) {
        view = makeResultRow(track, playYtTrack, enqueueTrack)
        resultRowCache.set(track.id, view)
        resultsList.insert_child_after(view.widget, prev)
      } else {
        view.update(track)
        resultsList.reorder_child_after(view.widget, prev)
      }
      view.widget.set_visible(true)
      prev = view.widget
    }
    for (const [id, view] of resultRowCache) {
      if (!visibleIds.has(id)) view.widget.set_visible(false)
    }
    if (emptyBox) emptyBox.set_visible(tracks.length === 0)
  }

  const downloadedMatchesFilter = (item: DownloadedVideoGroup): boolean => {
    const q = downloadedFilter.trim().toLowerCase()
    if (!q) return true
    const title = (ytVideoMeta.get(item.id)?.title || "").toLowerCase()
    const channel = (ytVideoMeta.get(item.id)?.channel || "").toLowerCase()
    return title.includes(q) || channel.includes(q) || item.id.toLowerCase().includes(q)
  }

  let downloadedSortLabel: Gtk.Label | null = null

  const sortKeyText = (key: DownloadedSortKey): string => {
    switch (key) {
      case "views": return "Views"
      case "name": return "Name"
      case "newest": return "Newest"
      case "oldest": return "Oldest"
    }
  }

  const refreshSortLabel = () => {
    if (!downloadedSortLabel) return
    const arrow = downloadedSortDir === "asc" ? "↑" : "↓"
    downloadedSortLabel.set_label(`${sortKeyText(downloadedSortKey)} ${arrow}`)
  }

  const setDownloadedSort = (key: DownloadedSortKey, dir: DownloadedSortDir) => {
    downloadedSortKey = key
    downloadedSortDir = dir
    refreshSortLabel()
    rebuildDownloaded(downloadedItemsCache)
  }

  const makeSortMenuButton = (): Gtk.Widget => {
    const menuBtn = new Gtk.MenuButton()
    menuBtn.add_css_class("mc-sort-btn")
    menuBtn.set_tooltip_text("Sort downloaded videos")

    const btnBody = new Gtk.Box({ spacing: 6 })
    const sortIcon = Gtk.Image.new_from_icon_name("view-sort-descending-symbolic")
    sortIcon.pixel_size = 14
    btnBody.append(sortIcon)
    const lbl = new Gtk.Label()
    lbl.add_css_class("mc-sort-label")
    downloadedSortLabel = lbl
    btnBody.append(lbl)
    menuBtn.set_child(btnBody)
    refreshSortLabel()

    const popover = new Gtk.Popover()
    popover.add_css_class("mc-sort-popover")
    const menu = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL, spacing: 2 })

    const options: { key: DownloadedSortKey; dir: DownloadedSortDir; label: string }[] = [
      { key: "views", dir: "desc", label: "Most played" },
      { key: "views", dir: "asc", label: "Least played" },
      { key: "name", dir: "asc", label: "Name (A→Z)" },
      { key: "name", dir: "desc", label: "Name (Z→A)" },
      { key: "newest", dir: "desc", label: "Newest first" },
      { key: "oldest", dir: "asc", label: "Oldest first" },
    ]

    for (const opt of options) {
      const item = new Gtk.Button()
      item.add_css_class("mc-sort-option")
      item.set_label(opt.label)
      item.connect("clicked", () => {
        setDownloadedSort(opt.key, opt.dir)
        popover.popdown()
      })
      menu.append(item)
    }

    popover.set_child(menu)
    menuBtn.set_popover(popover)
    return menuBtn
  }

  const downloadedTitle = (item: DownloadedVideoGroup): string =>
    (ytVideoMeta.get(item.id)?.title || `Saved video (${item.id})`).toLowerCase()

  // Sort respects the active key; direction flips the comparison. For "newest"
  // and "oldest" the key already fixes the natural order, and direction still
  // flips it so the toggle stays meaningful.
  const compareDownloaded = (a: DownloadedVideoGroup, b: DownloadedVideoGroup): number => {
    let cmp = 0
    switch (downloadedSortKey) {
      case "views":
        cmp = getPlayCount(a.id) - getPlayCount(b.id)
        break
      case "name":
        cmp = downloadedTitle(a).localeCompare(downloadedTitle(b))
        break
      case "newest":
      case "oldest":
        cmp = a.addedAt - b.addedAt
        break
    }
    // Stable tie-break by id so equal keys keep a deterministic order.
    if (cmp === 0) cmp = a.id.localeCompare(b.id)
    return downloadedSortDir === "asc" ? cmp : -cmp
  }

  function rebuildDownloaded(items: DownloadedVideoGroup[]) {
    if (!downloadedList) return
    downloadedItemsCache = items

    const itemIds = new Set(items.map((item) => item.id))
    for (const [id, view] of downloadedRowCache) {
      if (itemIds.has(id)) continue
      if (view.widget.get_parent() === downloadedList) downloadedList.remove(view.widget)
      downloadedRowCache.delete(id)
    }

    const visible = items.filter(downloadedMatchesFilter).sort(compareDownloaded)
    const visibleIds = new Set(visible.map((item) => item.id))
    let prev: Gtk.Widget | null = null
    for (const item of visible) {
      let view = downloadedRowCache.get(item.id)
      if (!view) {
        view = makeDownloadedRow(
          item,
          playDownloadedTrack,
          enqueueById,
          toggleTrackInActivePlaylist,
          deleteDownloadedTrack,
          isTrackInActivePlaylist,
          () => ytActivePlaylistId !== null,
        )
        downloadedRowCache.set(item.id, view)
        downloadedList.insert_child_after(view.widget, prev)
      } else {
        view.update(item)
        downloadedList.reorder_child_after(view.widget, prev)
      }
      view.widget.set_visible(true)
      prev = view.widget
    }
    for (const [id, view] of downloadedRowCache) {
      if (!visibleIds.has(id)) view.widget.set_visible(false)
    }
    if (downloadedEmpty) {
      downloadedEmpty.set_visible(visible.length === 0)
      const lbl = downloadedEmpty.get_first_child() as Gtk.Label | null
      if (lbl && typeof (lbl as any).set_label === "function") {
        lbl.set_label(
          items.length > 0 && visible.length === 0
            ? "No downloads match your search"
            : "No downloaded videos yet",
        )
      }
    }
  }

  // Re-render the already-scanned list against the current filter without a
  // disk rescan. Used by the downloaded-search box.
  const applyDownloadedFilter = (query: string) => {
    downloadedFilter = query
    rebuildDownloaded(downloadedItemsCache)
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
    // Advance when either the queue has something up next, or a playlist is
    // running on auto-advance. Without a current stream there's nothing to watch.
    const hasNext = ytQueue.length > 0 || Boolean(ytActivePlaylistId && ytActivePlaylistMode)
    if (!hasNext || !ytMediaStream) {
      playlistEndedLatch = false
      return GLib.SOURCE_CONTINUE
    }
    let ended = false
    try { ended = Boolean((ytMediaStream as any).get_ended?.()) } catch { ended = false }
    if (ended && !playlistEndedLatch) {
      playlistEndedLatch = true
      advanceToNext()
    } else if (!ended) {
      playlistEndedLatch = false
    }
    return GLib.SOURCE_CONTINUE
  })

  onCleanup(() => {
    if (ytSearchDebounce) GLib.source_remove(ytSearchDebounce)
    tvCleanup()
    if (downloadedRefreshId) GLib.source_remove(downloadedRefreshId)
    if (playlistAdvanceWatchId) GLib.source_remove(playlistAdvanceWatchId)
    ytUiRefreshHook = null
    ytQueueRefreshHook = null
    if (ytBarNextHook === advanceToNext) ytBarNextHook = null
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

  // Keep display presets in the sticky header. The previous button lived in a
  // conditional, scrollable row, so it disappeared (and its popover was torn
  // down) whenever playback state changed.
  const videoSettingsButton = makeMediaCenterVideoSettingsButton()

  return (
    <window
      $={(self) => {
        win = self
        const k = new Gtk.EventControllerKey()
        k.connect("key-pressed", (_c, kv) => { if (kv === Gdk.KEY_Escape) hide() })
        self.add_controller(k)
        self.connect("notify::visible", notifyVideoSurfacesChanged)
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
            <box
              class="mc-video-settings-slot mc-header-video-settings"
              $={(self) => { self.append(videoSettingsButton) }}
            />
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
                  onClicked={toggleMediaCenterVideoPlayback}
                >
                  <image
                    iconName={ytIsPlayingState((p) => p ? "media-playback-pause-symbolic" : "media-playback-start-symbolic")}
                    pixelSize={14}
                  />
                </button>

                <button
                  class="mc-stop-btn"
                  tooltipText="Skip to next in queue/playlist"
                  onClicked={() => advanceToNext()}
                >
                  <image iconName="media-skip-forward-symbolic" pixelSize={14} />
                </button>

                <slider
                  class="mc-player-progress"
                  hexpand
                  value={ytSeekState}
                  onChangeValue={({ value }) => seekMediaCenterVideo(value)}
                />

                <label class="mc-player-time" label={ytTimeState} xalign={1} />
              </box>

              {/* Up-next queue */}
              <box
                class="mc-queue-section"
                orientation={Gtk.Orientation.VERTICAL}
                spacing={6}
                marginTop={10}
                marginStart={18}
                marginEnd={18}
                visible={queueCountState((n) => n > 0)}
              >
                <box class="mc-queue-header" spacing={8}>
                  <label
                    class="mc-section-label"
                    label={queueCountState((n) => `UP NEXT · ${n}`)}
                    hexpand
                    xalign={0}
                  />
                  <button
                    class="mc-stop-btn"
                    tooltipText="Clear queue"
                    onClicked={() => clearQueue()}
                  >
                    <image iconName="edit-clear-all-symbolic" pixelSize={14} />
                  </button>
                </box>
                <box
                  class="mc-queue-list"
                  orientation={Gtk.Orientation.VERTICAL}
                  spacing={3}
                  $={(self) => {
                    queueList = self
                    rebuildQueue()
                  }}
                >
                  <box
                    class="mc-queue-empty"
                    halign={Gtk.Align.CENTER}
                    marginTop={6}
                    marginBottom={6}
                    $={(self) => { queueEmpty = self }}
                  >
                    <label class="yt-empty-label" label="Queue is empty" />
                  </box>
                </box>
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
                  <box class="yt-search-row mc-downloaded-search" spacing={8}>
                    <image iconName="system-search-symbolic" pixelSize={14} class="yt-search-icon" />
                    <entry
                      class="yt-search-entry"
                      hexpand
                      placeholderText="Filter downloaded videos..."
                      $={(self) => { downloadedFilterEntry = self }}
                      onChanged={(self) => applyDownloadedFilter(self.text)}
                    />
                    <button
                      class="mc-stop-btn"
                      tooltipText="Clear filter"
                      visible={false}
                      $={(self) => {
                        // Show the clear button only when there's text to clear.
                        GLib.timeout_add(GLib.PRIORITY_DEFAULT, 200, () => {
                          if (!self.get_parent()) return GLib.SOURCE_REMOVE
                          self.set_visible((downloadedFilterEntry?.text || "").length > 0)
                          return GLib.SOURCE_CONTINUE
                        })
                      }}
                      onClicked={() => {
                        if (downloadedFilterEntry) downloadedFilterEntry.text = ""
                        applyDownloadedFilter("")
                      }}
                    >
                      <image iconName="edit-clear-symbolic" pixelSize={13} />
                    </button>
                    <box $={(self) => { self.append(makeSortMenuButton()) }} />
                  </box>
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

                  <box class="mc-playlist-cover-row" spacing={8}>
                    <entry
                      class="yt-search-entry"
                      hexpand
                      placeholderText="Custom cover image path..."
                      $={(self) => { playlistCoverEntry = self }}
                      onActivate={(self) => setCustomCoverPathForActivePlaylist(self.text || "")}
                    />
                    <button
                      class="mc-video-btn"
                      tooltipText="Browse for cover image"
                      onClicked={() => openCoverFileChooser()}
                    >
                      <image iconName="folder-open-symbolic" pixelSize={14} />
                    </button>
                    <button
                      class="mc-video-btn"
                      tooltipText="Apply custom cover image"
                      onClicked={() => setCustomCoverPathForActivePlaylist(playlistCoverEntry?.text || "")}
                    >
                      <image iconName="emblem-photos-symbolic" pixelSize={14} />
                    </button>
                    <button
                      class="mc-stop-btn"
                      tooltipText="Clear custom cover"
                      onClicked={() => clearCustomCoverPathForActivePlaylist()}
                    >
                      <image iconName="edit-clear-symbolic" pixelSize={14} />
                    </button>
                  </box>

                  <box class="mc-playlist-item-label-row" orientation={Gtk.Orientation.VERTICAL}>
                    <label class="mc-playlist-hint" xalign={0} label="Playlist items (hold the move handle, then hover another row to drop)" />
                  </box>

                  <box
                    class="mc-playlist-items-list"
                    orientation={Gtk.Orientation.VERTICAL}
                    spacing={4}
                    $={(self) => {
                      playlistItemsList = self
                      rebuildPlaylistItems()
                    }}
                  >
                    <box
                      class="mc-playlist-items-empty"
                      orientation={Gtk.Orientation.VERTICAL}
                      spacing={6}
                      halign={Gtk.Align.CENTER}
                      marginTop={8}
                      marginBottom={8}
                      $={(self) => { playlistItemsEmpty = self }}
                    >
                      <label class="yt-empty-label" label="Select a playlist and add tracks from downloaded videos" />
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
  const currentMprisPlayer = (): AstalMpris.Player | null => {
    const list = mpris.players || []
    return list.find((p) => p.playbackStatus === AstalMpris.PlaybackStatus.PLAYING)
      || list[0]
      || null
  }

  const activeTitle = (): string => {
    if (ytNowPlaying) return ytNowPlaying.title || "Media Center"
    const player = currentMprisPlayer()
    return player?.title || player?.identity || "Media Center"
  }

  let marqueeTitle = ""
  let marqueeOffset = 0
  const marqueeState = createPoll("Media Center", 350, () => {
    const title = activeTitle().trim() || "Media Center"
    if (title !== marqueeTitle) {
      marqueeTitle = title
      marqueeOffset = 0
    }
    const width = 26
    if (title.length <= width) return title
    const loop = `${title}   •   `
    const doubled = loop + loop
    const visible = doubled.slice(marqueeOffset, marqueeOffset + width)
    marqueeOffset = (marqueeOffset + 1) % loop.length
    return visible
  })

  const hasMediaState = createPoll(false, 250, () =>
    Boolean(ytNowPlaying || currentMprisPlayer()),
  )
  const canToggleState = createPoll(false, 250, () =>
    ytNowPlaying ? Boolean(ytMediaStream) : Boolean(currentMprisPlayer()?.canControl),
  )
  const canNextState = createPoll(false, 250, () =>
    ytNowPlaying
      ? Boolean(ytBarNextHook && (ytQueue.length > 0 || (ytActivePlaylistId && ytActivePlaylistMode)))
      : Boolean(currentMprisPlayer()?.canGoNext),
  )
  const isPlayingState = createPoll(false, 200, () => {
    if (ytNowPlaying) {
      try { return Boolean((ytMediaStream as any)?.get_playing?.()) } catch { return false }
    }
    return currentMprisPlayer()?.playbackStatus === AstalMpris.PlaybackStatus.PLAYING
  })

  const togglePlayback = () => {
    if (ytNowPlaying) {
      try {
        const stream = ytMediaStream as any
        if (stream) stream.set_playing?.(!Boolean(stream.get_playing?.()))
      } catch { /* ignore */ }
      return
    }
    currentMprisPlayer()?.play_pause()
  }

  const playNext = () => {
    if (ytNowPlaying) {
      ytBarNextHook?.()
      return
    }
    const player = currentMprisPlayer()
    if (player?.canGoNext) player.next()
  }

  return (
    <box class="mc-bar-btn" spacing={2}>
      <button
        class="mc-bar-title-btn"
        onClicked={() => {
          const win = app.get_window("media-center")
          if (win) win.visible = !win.visible
        }}
        tooltipText="Media Center"
      >
        <box spacing={6}>
          <image iconName="multimedia-player-symbolic" pixelSize={14} />
          <label class="mc-bar-label" label={marqueeState} widthChars={26} maxWidthChars={26} xalign={0} />
        </box>
      </button>
      <button
        class="mc-bar-control"
        visible={hasMediaState}
        sensitive={canToggleState}
        tooltipText={isPlayingState((playing) => playing ? "Pause" : "Play")}
        onClicked={togglePlayback}
      >
        <image
          iconName={isPlayingState((playing) => playing
            ? "media-playback-pause-symbolic"
            : "media-playback-start-symbolic")}
          pixelSize={13}
        />
      </button>
      <button
        class="mc-bar-control"
        visible={hasMediaState}
        sensitive={canNextState}
        tooltipText="Next"
        onClicked={playNext}
      >
        <image iconName="media-skip-forward-symbolic" pixelSize={13} />
      </button>
    </box>
  )
}
