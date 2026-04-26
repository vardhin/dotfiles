import app from "ags/gtk4/app"
import Astal from "gi://Astal?version=4.0"
import Gtk from "gi://Gtk?version=4.0"
import Gdk from "gi://Gdk?version=4.0"
import GLib from "gi://GLib"
import { For, onCleanup } from "ags"
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
const thumbCache = new Map<string, string>()  // id → local file path
const thumbPending = new Set<string>()
const THUMB_DIR = `${GLib.get_user_cache_dir()}/ags-yt-thumbs`

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

// ── Thumbnail widget ───────────────────────────────────────────────────
// Returns a Gtk.Stack that flips from placeholder to actual image once downloaded.
function makeThumbnailWidget(id: string, w: number, h: number): Gtk.Widget {
  const stack = new Gtk.Stack()
  stack.set_size_request(w, h)
  stack.add_css_class("yt-thumb-stack")

  const placeholder = new Gtk.Box()
  placeholder.set_halign(Gtk.Align.CENTER)
  placeholder.set_valign(Gtk.Align.CENTER)
  const icon = new Gtk.Image()
  icon.set_icon_name("multimedia-player-symbolic")
  icon.set_pixel_size(Math.round(w / 3))
  icon.add_css_class("yt-thumb-placeholder")
  placeholder.append(icon)
  stack.add_named(placeholder, "placeholder")
  stack.set_visible_child_name("placeholder")

  const tryLoad = (path: string) => {
    try {
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
      // Check stack still has children (not yet destroyed)
      if (stack.get_visible_child_name() !== "image") tryLoad(path)
    })
  }

  return stack
}

// ── Process management (real PIDs via GLib.spawn_async) ───────────────
let audioPid: number | null = null
let videoPid: number | null = null
let videoVisible = false

function spawnMpv(args: string[]): number | null {
  try {
    const [ok, pid] = GLib.spawn_async(
      null,
      ["mpv", ...args],
      null,
      GLib.SpawnFlags.SEARCH_PATH | GLib.SpawnFlags.DO_NOT_REAP_CHILD,
      null,
    )
    if (!ok || !pid) return null
    GLib.child_watch_add(GLib.PRIORITY_DEFAULT, pid, () => {
      GLib.spawn_close_pid(pid)
    })
    return pid
  } catch {
    return null
  }
}

function killPid(pid: number) {
  try { GLib.spawn_command_line_async(`kill -SIGTERM ${pid}`) } catch { /* ignore */ }
  GLib.timeout_add(GLib.PRIORITY_DEFAULT, 800, () => {
    try { GLib.spawn_command_line_async(`kill -SIGKILL ${pid}`) } catch { /* ignore */ }
    return GLib.SOURCE_REMOVE
  })
}

function killAudio() {
  if (audioPid !== null) { killPid(audioPid); audioPid = null }
  // belt-and-suspenders for any stray mpv --no-video processes
  try { GLib.spawn_command_line_async("pkill -SIGTERM -f 'mpv --no-video'") } catch { /* ignore */ }
}

function killVideo() {
  if (videoPid !== null) { killPid(videoPid); videoPid = null }
  try { GLib.spawn_command_line_async("pkill -SIGTERM -f 'ags-yt-video'") } catch { /* ignore */ }
  videoVisible = false
}

function stopAll() {
  killAudio()
  killVideo()
}

function playAudio(videoId: string) {
  killAudio()
  audioPid = spawnMpv([
    "--no-video",
    "--really-quiet",
    `https://www.youtube.com/watch?v=${videoId}`,
  ])
}

function toggleVideoWindow(videoId: string) {
  if (videoVisible) { killVideo(); return }
  videoPid = spawnMpv([
    "--no-audio",
    "--really-quiet",
    "--geometry=640x360+100+100",
    "--title=ags-yt-video",
    "--ontop",
    `https://www.youtube.com/watch?v=${videoId}`,
  ])
  videoVisible = videoPid !== null
}

// ── YouTube search ─────────────────────────────────────────────────────
async function searchYoutube(query: string): Promise<YtResult[]> {
  if (!query.trim()) return []
  const raw = await execAsync([
    "yt-dlp", "--flat-playlist", "--dump-json", "--no-warnings", "--no-playlist",
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
  // kick off thumbnail fetches in background
  for (const r of results) fetchThumbnail(r.id, () => { /* cached for later */ })
  return results
}

// ── Module-level state ─────────────────────────────────────────────────
let ytResults: YtResult[] = []
let ytStatus: "idle" | "searching" | "playing" | "error" = "idle"
let ytStatusMsg = ""
let ytNowPlaying: YtResult | null = null
let ytSearchDebounce = 0

// ── Now-playing thumbnail box ─────────────────────────────────────────
// Returns the widget and a source ID to cancel the timer on cleanup.
function NowPlayingThumb(): { widget: Gtk.Widget; sourceId: number } {
  const container = new Gtk.Box()
  container.set_size_request(64, 36)
  let lastId = ""
  let child: Gtk.Widget | null = null

  const sourceId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 250, () => {
    const id = ytNowPlaying?.id || ""
    if (id !== lastId) {
      lastId = id
      if (child) { container.remove(child); child = null }
      if (id) {
        child = makeThumbnailWidget(id, 64, 36)
        container.append(child)
      }
    }
    return GLib.SOURCE_CONTINUE
  })

  return { widget: container, sourceId }
}

// ── Main popover ───────────────────────────────────────────────────────
export function YouTubePlayerPopover({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
  const resultsState    = createPoll([] as YtResult[], 300, () => ytResults)
  const statusState     = createPoll("idle" as typeof ytStatus, 200, () => ytStatus)
  const statusMsgState  = createPoll("", 200, () => ytStatusMsg)
  const nowPlayingState = createPoll(null as YtResult | null, 200, () => ytNowPlaying)
  const videoVisState   = createPoll(false, 300, () => videoVisible)

  let win: Astal.Window | null = null
  const { TOP, LEFT, RIGHT, BOTTOM } = Astal.WindowAnchor

  const hide = () => { if (win) win.visible = false }

  onCleanup(() => {
    if (ytSearchDebounce) GLib.source_remove(ytSearchDebounce)
    GLib.source_remove(npThumbSourceId)
    stopAll()
    win?.destroy()
  })

  const doSearch = (query: string) => {
    if (ytSearchDebounce) { GLib.source_remove(ytSearchDebounce); ytSearchDebounce = 0 }
    if (!query.trim()) { ytResults = []; ytStatus = "idle"; ytStatusMsg = ""; return }

    ytSearchDebounce = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 500, () => {
      ytSearchDebounce = 0
      ytStatus = "searching"; ytStatusMsg = "Searching..."
      searchYoutube(query).then((res) => {
        ytResults = res
        ytStatus = ytNowPlaying ? "playing" : (res.length > 0 ? "idle" : "error")
        ytStatusMsg = res.length > 0 ? "" : "No results found"
      }).catch(() => { ytStatus = "error"; ytStatusMsg = "Search failed" })
      return GLib.SOURCE_REMOVE
    })
  }

  const playTrack = (track: YtResult) => {
    ytNowPlaying = track
    ytStatus = "playing"
    ytStatusMsg = ""
    playAudio(track.id)
  }

  const stopPlayback = () => {
    stopAll()
    ytNowPlaying = null
    ytStatus = "idle"
    ytStatusMsg = ""
  }

  const { widget: npThumb, sourceId: npThumbSourceId } = NowPlayingThumb()

  return (
    <window
      $={(self) => {
        win = self
        const k = new Gtk.EventControllerKey()
        k.connect("key-pressed", (_c, kv) => { if (kv === Gdk.KEY_Escape) hide() })
        self.add_controller(k)
      }}
      visible={false}
      namespace="ags-yt-player"
      name="yt-player"
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
          class="yt-panel"
          orientation={Gtk.Orientation.VERTICAL}
          halign={Gtk.Align.CENTER}
          valign={Gtk.Align.START}
          marginTop={50}
          widthRequest={560}
        >
          {/* header */}
          <box class="yt-header" spacing={10}>
            <image iconName="multimedia-player-symbolic" pixelSize={18} class="yt-header-icon" />
            <label class="yt-title" label="YouTube Player" hexpand xalign={0} />
            <button class="yt-close-btn" onClicked={hide} tooltipText="Close">
              <image iconName="window-close-symbolic" pixelSize={14} />
            </button>
          </box>

          <box class="yt-divider" />

          {/* search */}
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

          {/* status */}
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

          {/* now-playing */}
          <box
            class="yt-now-playing"
            spacing={10}
            visible={nowPlayingState((np) => np !== null)}
          >
            {/* imperative thumbnail box — updated by NowPlayingThumb() timer */}
            <box $={(self) => { self.append(npThumb) }} />

            <box orientation={Gtk.Orientation.VERTICAL} hexpand spacing={2}>
              <label
                class="yt-np-title"
                label={nowPlayingState((np) => np?.title || "")}
                xalign={0} ellipsize={3} maxWidthChars={40}
              />
              <label
                class="yt-np-channel"
                label={nowPlayingState((np) => np?.channel || "")}
                xalign={0}
              />
            </box>

            <button
              class={videoVisState((v) => `yt-video-btn ${v ? "active" : ""}`)}
              tooltipText={videoVisState((v) => v ? "Close video" : "Watch video")}
              onClicked={() => { if (ytNowPlaying) toggleVideoWindow(ytNowPlaying.id) }}
            >
              <image iconName="camera-video-symbolic" pixelSize={15} />
            </button>

            <button class="yt-stop-btn" onClicked={stopPlayback} tooltipText="Stop playback">
              <image iconName="media-playback-stop-symbolic" pixelSize={15} />
            </button>
          </box>

          <box class="yt-divider" visible={nowPlayingState((np) => np !== null)} />

          {/* results */}
          <scrolledwindow
            class="yt-results-scroll"
            vexpand
            hscrollbarPolicy={Gtk.PolicyType.NEVER}
            vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
            maxContentHeight={460}
          >
            <box class="yt-results-list" orientation={Gtk.Orientation.VERTICAL} spacing={3}>
              <For each={resultsState}>
                {(track) => {
                  // Build row imperatively so we can embed a real Gtk.Widget thumbnail
                  const row = new Gtk.Button()
                  row.add_css_class("yt-result-row")
                  row.set_tooltip_text(`Play: ${track.title}`)

                  const outer = new Gtk.Box({ spacing: 10 })
                  outer.set_margin_start(4); outer.set_margin_end(4)
                  outer.set_margin_top(2);   outer.set_margin_bottom(2)

                  // thumbnail
                  const thumb = makeThumbnailWidget(track.id, 96, 54)
                  outer.append(thumb)

                  // text
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

                  // right side: play indicator + duration
                  const rightCol = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL, spacing: 4 })
                  rightCol.set_valign(Gtk.Align.CENTER)
                  rightCol.set_halign(Gtk.Align.END)

                  const playImg = new Gtk.Image()
                  playImg.set_icon_name("audio-x-generic-symbolic")
                  playImg.set_pixel_size(16)
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

                  // poll playing state for this row
                  let wasPlaying = false
                  GLib.timeout_add(GLib.PRIORITY_DEFAULT, 200, () => {
                    // stop polling if row is no longer attached
                    if (!row.get_parent()) return GLib.SOURCE_REMOVE
                    const isPlaying = ytNowPlaying?.id === track.id
                    if (isPlaying !== wasPlaying) {
                      wasPlaying = isPlaying
                      if (isPlaying) {
                        row.add_css_class("playing")
                        playImg.set_icon_name("media-playback-start-symbolic")
                      } else {
                        row.remove_css_class("playing")
                        playImg.set_icon_name("audio-x-generic-symbolic")
                      }
                    }
                    return GLib.SOURCE_CONTINUE
                  })

                  row.connect("clicked", () => playTrack(track))
                  return row
                }}
              </For>

              {/* empty */}
              <box
                class="yt-empty"
                orientation={Gtk.Orientation.VERTICAL}
                spacing={8}
                halign={Gtk.Align.CENTER}
                marginTop={32} marginBottom={32}
                visible={resultsState((r) => r.length === 0)}
              >
                <image iconName="multimedia-player-symbolic" pixelSize={48} class="yt-empty-icon" />
                <label
                  class="yt-empty-label"
                  label={statusState((s) => s === "searching" ? "Searching..." : "Search for a song to play")}
                />
              </box>
            </box>
          </scrolledwindow>

          {/* footer */}
          <box class="yt-footer" spacing={6}>
            <image iconName="audio-x-generic-symbolic" pixelSize={11} />
            <label class="yt-footer-text" label="Audio · mpv  ·  video window on demand" hexpand xalign={0} />
          </box>
        </box>
      </overlay>
    </window>
  )
}

// ── Bar button ─────────────────────────────────────────────────────────
export function YouTubeButton() {
  return (
    <box class="yt-bar-btn">
      <button
        onClicked={() => {
          const win = app.get_window("yt-player")
          if (win) win.visible = !win.visible
        }}
        tooltipText="YouTube Player"
      >
        <box spacing={4}>
          <image iconName="multimedia-player-symbolic" pixelSize={16} />
          <label class="yt-bar-label" label="YT" />
        </box>
      </button>
    </box>
  )
}
