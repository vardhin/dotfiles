import app from "ags/gtk4/app"
import GLib from "gi://GLib"
import Gio from "gi://Gio"
import Astal from "gi://Astal?version=4.0"
import Gtk from "gi://Gtk?version=4.0"
import Gdk from "gi://Gdk?version=4.0"
import { onCleanup } from "ags"
import { execAsync } from "ags/process"

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// TYPES
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

interface ThemeColors {
  bg: string; bg_solid: string; bg_dark: string
  fg: string; fg_dim: string; fg_faint: string
  accent: string; accent_dim: string; accent_glow: string
  green: string; teal: string; magenta: string
  yellow: string; red: string; orange: string
}

interface ThemeHyprland {
  active_border: string; inactive_border: string
  border_size: number; rounding: number
  shadow_color: string; shadow_range: number
  shadow_render_power: number; shadow_offset: string
  blur_size: number; blur_passes: number; blur_vibrancy: number
  dim_inactive: boolean; dim_strength: number
  gaps_in: number; gaps_out: number
}

interface ThemePreset {
  name: string; id: string; description: string
  swatches: string[]
  colors: ThemeColors
  hyprland: ThemeHyprland
  wallpaper: string
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// CONSTANTS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

const HOME = GLib.get_home_dir()
const THEMES_DIR = `${HOME}/.config/ags/themes`
const WALLPAPER_DIR = `${HOME}/wallpaper`
const CURRENT_THEME_FILE = `${THEMES_DIR}/current.json`

const THEME_IDS = [
  "frozen-winter",
  "catppuccin-mocha",
  "gruvbox-dark",
  "tokyo-night",
  "rose-pine",
]

const IMAGE_EXTS = new Set([".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp"])

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// HELPERS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function loadThemes(): ThemePreset[] {
  return THEME_IDS.flatMap((id) => {
    try {
      const [ok, bytes] = GLib.file_get_contents(`${THEMES_DIR}/${id}.json`)
      if (!ok) return []
      return [JSON.parse(new TextDecoder().decode(bytes)) as ThemePreset]
    } catch { return [] }
  })
}

function getCurrentThemeId(): string {
  try {
    const [ok, bytes] = GLib.file_get_contents(CURRENT_THEME_FILE)
    if (!ok) return "frozen-winter"
    return (JSON.parse(new TextDecoder().decode(bytes)) as ThemePreset).id
  } catch { return "frozen-winter" }
}

function listWallpapers(themeId: string): string[] {
  const dir = `${WALLPAPER_DIR}/${themeId}`
  try {
    const gdir = Gio.File.new_for_path(dir)
    const enumerator = gdir.enumerate_children(
      "standard::name,standard::type",
      Gio.FileQueryInfoFlags.NONE,
      null,
    )
    const files: string[] = []
    let info: Gio.FileInfo | null
    while ((info = enumerator.next_file(null)) !== null) {
      const name = info.get_name()
      const ext = name.substring(name.lastIndexOf(".")).toLowerCase()
      if (IMAGE_EXTS.has(ext)) files.push(`${dir}/${name}`)
    }
    enumerator.close(null)
    return files.sort()
  } catch { return [] }
}

function setWallpaper(path: string) {
  execAsync([
    "swww", "img", path,
    "--transition-type", "wipe",
    "--transition-angle", "30",
    "--transition-duration", "0.8",
  ]).catch(console.error)
}

function saveCurrentWallpaper(themeId: string, path: string) {
  execAsync([
    "bash", "-c",
    `jq --arg w "${path}" '.wallpaper = $w' "${THEMES_DIR}/${themeId}.json" > /tmp/theme-tmp.json && mv /tmp/theme-tmp.json "${THEMES_DIR}/${themeId}.json"`,
  ]).catch(console.error)
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// CSS GENERATOR (exported for app.tsx)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

export function generateThemeCSS(preset: ThemePreset): string {
  const c = preset.colors
  return `
/* ── Theme: ${preset.name} ── auto-generated ── */
@define-color theme_bg           ${c.bg};
@define-color theme_bg_solid     ${c.bg_solid};
@define-color theme_bg_dark      ${c.bg_dark};
@define-color theme_fg           ${c.fg};
@define-color theme_fg_dim       ${c.fg_dim};
@define-color theme_accent       ${c.accent};
@define-color theme_accent_dim   ${c.accent_dim};
@define-color theme_accent_glow  ${c.accent_glow};
@define-color theme_green        ${c.green};
@define-color theme_teal         ${c.teal};
@define-color theme_magenta      ${c.magenta};
@define-color theme_yellow       ${c.yellow};
@define-color theme_red          ${c.red};
@define-color theme_orange       ${c.orange};
`
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// APPLY THEME (hyprland + CSS)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

export function applyTheme(id: string) {
  execAsync([
    "bash",
    `${HOME}/.config/ags/scripts/apply-theme.sh`,
    id,
  ]).catch(console.error)
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// SWATCH STRIP
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function SwatchStrip(colors: string[]): Gtk.Box {
  const box = new Gtk.Box({ spacing: 0, hexpand: true })
  box.add_css_class("theme-card-swatches")
  for (const hex of colors) {
    const swatch = new Gtk.Box({ hexpand: true })
    swatch.add_css_class("theme-swatch")
    const provider = new Gtk.CssProvider()
    provider.load_from_string(`.theme-swatch { background: ${hex}; }`)
    swatch.get_style_context().add_provider(provider, Gtk.STYLE_PROVIDER_PRIORITY_USER)
    box.append(swatch)
  }
  return box
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// THEME ROW  (left sidebar item)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function ThemeRow(
  preset: ThemePreset,
  isActive: boolean,
  isSelected: boolean,
  onClick: () => void,
): Gtk.Button {
  const btn = new Gtk.Button()
  btn.add_css_class("theme-row")
  if (isActive) btn.add_css_class("theme-row-active")
  if (isSelected) btn.add_css_class("theme-row-selected")

  const inner = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL, spacing: 6 })

  // Swatch strip
  inner.append(SwatchStrip(preset.swatches))

  // Name + badge row
  const nameRow = new Gtk.Box({ spacing: 6 })
  const nameLabel = new Gtk.Label({ label: preset.name, xalign: 0 })
  nameLabel.set_hexpand(true)
  nameLabel.add_css_class("theme-row-name")
  nameRow.append(nameLabel)

  if (isActive) {
    const badge = new Gtk.Label({ label: "Active" })
    badge.add_css_class("theme-row-badge")
    nameRow.append(badge)
  }

  const descLabel = new Gtk.Label({ label: preset.description, xalign: 0, wrap: true, maxWidthChars: 22 })
  descLabel.add_css_class("theme-row-desc")

  inner.append(nameRow)
  inner.append(descLabel)
  btn.set_child(inner)
  btn.connect("clicked", onClick)
  return btn
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// WALLPAPER THUMBNAIL
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function WallpaperThumb(
  path: string,
  isActive: boolean,
  onClick: () => void,
): Gtk.Button {
  const btn = new Gtk.Button()
  btn.add_css_class("wp-thumb")
  if (isActive) btn.add_css_class("wp-thumb-active")

  // Use GTK Picture for the thumbnail
  const pic = new Gtk.Picture()
  pic.add_css_class("wp-thumb-img")
  pic.set_filename(path)
  pic.set_content_fit(Gtk.ContentFit.COVER)
  pic.set_size_request(160, 100)

  btn.set_child(pic)
  btn.connect("clicked", onClick)
  return btn
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MAIN WINDOW
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

export function ThemeSwitcher({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
  let win: Astal.Window
  const { TOP, BOTTOM, LEFT, RIGHT } = Astal.WindowAnchor

  // State
  let themes = loadThemes()
  let activeThemeId = getCurrentThemeId()
  let selectedThemeId = activeThemeId   // which theme is open in wallpaper panel
  let activeWallpaper = ""              // currently applied wallpaper path

  // DOM refs
  let themeListBox: Gtk.Box
  let wallpaperGrid: Gtk.FlowBox
  let wpThemeLabel: Gtk.Label
  let wpEmptyLabel: Gtk.Label
  let wpScrolled: Gtk.ScrolledWindow

  const hide = () => { win.visible = false }

  // ── Rebuild left theme list ──────────────────────────────
  const rebuildThemeList = () => {
    let child = themeListBox?.get_first_child()
    while (child) {
      const next = child.get_next_sibling()
      themeListBox.remove(child)
      child = next
    }
    for (const preset of themes) {
      const row = ThemeRow(
        preset,
        preset.id === activeThemeId,
        preset.id === selectedThemeId,
        () => {
          selectedThemeId = preset.id
          rebuildThemeList()
          rebuildWallpaperGrid()
        },
      )
      themeListBox.append(row)
    }
  }

  // ── Rebuild right wallpaper grid ─────────────────────────
  const rebuildWallpaperGrid = () => {
    wallpaperGrid?.remove_all()
    if (wpThemeLabel) {
      const preset = themes.find((t) => t.id === selectedThemeId)
      wpThemeLabel.label = preset ? `${preset.name} wallpapers` : "Wallpapers"
    }

    const walls = listWallpapers(selectedThemeId)

    if (wpEmptyLabel) wpEmptyLabel.visible = walls.length === 0
    if (wpScrolled) wpScrolled.visible = walls.length > 0

    for (const path of walls) {
      const isActive = path === activeWallpaper
      const thumb = WallpaperThumb(path, isActive, () => {
        activeWallpaper = path
        setWallpaper(path)
        saveCurrentWallpaper(selectedThemeId, path)
        // Also apply the theme if not already active
        if (selectedThemeId !== activeThemeId) {
          activeThemeId = selectedThemeId
          applyTheme(selectedThemeId)
        }
        rebuildThemeList()
        rebuildWallpaperGrid()
      })
      const item = new Gtk.FlowBoxChild()
      item.set_child(thumb)
      wallpaperGrid?.insert(item, -1)
    }
  }

  // ── Apply theme button ───────────────────────────────────
  const applySelectedTheme = () => {
    activeThemeId = selectedThemeId
    applyTheme(selectedThemeId)
    rebuildThemeList()
  }

  onCleanup(() => { win.destroy() })

  return (
    <window
      $={(self) => {
        win = self
        self.connect("notify::visible", () => {
          if (self.visible) {
            themes = loadThemes()
            activeThemeId = getCurrentThemeId()
            selectedThemeId = activeThemeId
            rebuildThemeList()
            rebuildWallpaperGrid()
          }
        })
        const keyCtrl = new Gtk.EventControllerKey()
        keyCtrl.connect("key-pressed", (_ctrl, keyval) => {
          if (keyval === Gdk.KEY_Escape) hide()
        })
        self.add_controller(keyCtrl)
      }}
      visible={false}
      namespace="ags-theme-switcher"
      name="theme-switcher"
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.IGNORE}
      keymode={Astal.Keymode.ON_DEMAND}
      layer={Astal.Layer.OVERLAY}
      anchor={TOP | BOTTOM | LEFT | RIGHT}
      application={app}
    >
      {/*
        The window fills the whole screen.
        Background is fully transparent so the real wallpaper shows through.
        The panel floats in the center with a solid (no blur) background.
      */}
      <overlay>
        {/* Invisible click-catcher backdrop — no visual, just closes on click */}
        <button
          class="ts-backdrop"
          hexpand
          vexpand
          onClicked={() => hide()}
        >
          <box />
        </button>

        {/* Floating panel */}
        <box
          $type="overlay"
          class="ts-panel"
          orientation={Gtk.Orientation.VERTICAL}
          halign={Gtk.Align.CENTER}
          valign={Gtk.Align.CENTER}
          spacing={0}
        >
          {/* ── Header ── */}
          <box class="ts-header" spacing={10}>
            <image iconName="preferences-desktop-theme-symbolic" pixelSize={18} class="ts-header-icon" />
            <label label="Themes" class="ts-title" hexpand xalign={0} />
            <button class="ts-close-btn" onClicked={() => hide()} tooltipText="Close  Esc">
              <image iconName="window-close-symbolic" pixelSize={14} />
            </button>
          </box>

          <box class="ts-divider" />

          {/* ── Body: left list + right wallpaper ── */}
          <box class="ts-body" spacing={0}>

            {/* LEFT — theme list */}
            <box class="ts-left" orientation={Gtk.Orientation.VERTICAL} spacing={0}>
              <Gtk.ScrolledWindow
                hscrollbarPolicy={Gtk.PolicyType.NEVER}
                vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
                vexpand
                class="ts-theme-scroll"
              >
                <box
                  $={(self) => { themeListBox = self }}
                  class="ts-theme-list"
                  orientation={Gtk.Orientation.VERTICAL}
                  spacing={6}
                />
              </Gtk.ScrolledWindow>

              {/* Apply theme button */}
              <box class="ts-apply-row">
                <button
                  class="ts-apply-btn"
                  hexpand
                  onClicked={() => applySelectedTheme()}
                  tooltipText="Apply selected theme (colors + decorations)"
                >
                  <box spacing={6} halign={Gtk.Align.CENTER}>
                    <image iconName="emblem-ok-symbolic" pixelSize={14} />
                    <label label="Apply Theme" />
                  </box>
                </button>
              </box>
            </box>

            <box class="ts-vsep" />

            {/* RIGHT — wallpaper grid */}
            <box class="ts-right" orientation={Gtk.Orientation.VERTICAL} spacing={10}>
              {/* Section label */}
              <box class="ts-wp-header" spacing={6}>
                <image iconName="emblem-photos-symbolic" pixelSize={14} class="ts-wp-icon" />
                <label
                  $={(self) => { wpThemeLabel = self }}
                  class="ts-wp-title"
                  label="Wallpapers"
                  hexpand
                  xalign={0}
                />
                <label label="~/wallpaper/" class="ts-wp-dir" />
              </box>

              {/* Empty state */}
              <box
                $={(self) => { wpEmptyLabel = self as unknown as Gtk.Label }}
                class="ts-wp-empty"
                orientation={Gtk.Orientation.VERTICAL}
                spacing={8}
                halign={Gtk.Align.CENTER}
                valign={Gtk.Align.CENTER}
                vexpand
              >
                <image iconName="folder-pictures-symbolic" pixelSize={48} class="ts-wp-empty-icon" />
                <label label="No wallpapers found" class="ts-wp-empty-label" />
                <label
                  label={`Add images to\n~/wallpaper/${selectedThemeId}/`}
                  class="ts-wp-empty-hint"
                  justify={Gtk.Justification.CENTER}
                />
              </box>

              {/* Wallpaper grid */}
              <Gtk.ScrolledWindow
                $={(self) => { wpScrolled = self }}
                hscrollbarPolicy={Gtk.PolicyType.NEVER}
                vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
                vexpand
                class="ts-wp-scroll"
              >
                <Gtk.FlowBox
                  $={(self) => { wallpaperGrid = self }}
                  class="ts-wp-grid"
                  maxChildrenPerLine={3}
                  minChildrenPerLine={2}
                  columnSpacing={10}
                  rowSpacing={10}
                  homogeneous
                  selectionMode={Gtk.SelectionMode.NONE}
                />
              </Gtk.ScrolledWindow>
            </box>
          </box>

          <box class="ts-divider" />

          {/* ── Footer ── */}
          <box class="ts-footer" spacing={16} halign={Gtk.Align.CENTER}>
            <box spacing={4}>
              <label label="Click wallpaper" class="ts-key" />
              <label label="to preview live" class="ts-footer-text" />
            </box>
            <label label="·" class="ts-footer-text" />
            <box spacing={4}>
              <label label="Apply Theme" class="ts-key" />
              <label label="for colors + decorations" class="ts-footer-text" />
            </box>
            <label label="·" class="ts-footer-text" />
            <box spacing={4}>
              <label label="Esc" class="ts-key" />
              <label label="close" class="ts-footer-text" />
            </box>
          </box>
        </box>
      </overlay>
    </window>
  )
}
