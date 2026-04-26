import app from "ags/gtk4/app"
import baseStyle from "../style.scss"
import GLib from "gi://GLib"
import Gio from "gi://Gio"
import GdkPixbuf from "gi://GdkPixbuf"
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

interface Rgb {
  r: number
  g: number
  b: number
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// CONSTANTS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

const HOME = GLib.get_home_dir()
const THEMES_DIR = `${HOME}/.config/ags/themes`
const WALLPAPER_DIR = `${HOME}/wallpaper`
const CURRENT_THEME_FILE = `${THEMES_DIR}/current.json`
const DYNAMIC_THEME_DIR = `${GLib.get_user_cache_dir()}/ags`
const DYNAMIC_THEME_FILE = `${DYNAMIC_THEME_DIR}/dynamic-theme.css`
const THEME_IDS = [
  "frozen-winter",
  "catppuccin-mocha",
  "gruvbox-dark",
  "tokyo-night",
  "rose-pine",
]

const IMAGE_EXTS = new Set([".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp"])
const WALLPAPER_CHUNK_SIZE = 12

const FALLBACK_ACCENT: Rgb = { r: 0, g: 191, b: 255 }

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

function resolveHomePath(path: string): string {
  if (!path) return ""
  if (path === "~") return HOME
  if (path.startsWith("~/")) return `${HOME}/${path.slice(2)}`
  return path
}

function clampByte(v: number): number {
  return Math.max(0, Math.min(255, Math.round(v)))
}

function clamp01(v: number): number {
  return Math.max(0, Math.min(1, v))
}

function mixRgb(a: Rgb, b: Rgb, amount: number): Rgb {
  const t = clamp01(amount)
  return {
    r: clampByte(a.r + (b.r - a.r) * t),
    g: clampByte(a.g + (b.g - a.g) * t),
    b: clampByte(a.b + (b.b - a.b) * t),
  }
}

function rgbToHex(c: Rgb): string {
  const h = (n: number) => clampByte(n).toString(16).padStart(2, "0")
  return `#${h(c.r)}${h(c.g)}${h(c.b)}`
}

function rgba(c: Rgb, alpha: number): string {
  return `rgba(${clampByte(c.r)}, ${clampByte(c.g)}, ${clampByte(c.b)}, ${clamp01(alpha).toFixed(3)})`
}

function parseHexColor(input: string): Rgb | null {
  const m = input.trim().match(/^#?([0-9a-fA-F]{6})$/)
  if (!m) return null
  const hex = m[1]
  return {
    r: parseInt(hex.slice(0, 2), 16),
    g: parseInt(hex.slice(2, 4), 16),
    b: parseInt(hex.slice(4, 6), 16),
  }
}

function rgbToHsl(c: Rgb): { h: number; s: number; l: number } {
  const r = c.r / 255
  const g = c.g / 255
  const b = c.b / 255
  const max = Math.max(r, g, b)
  const min = Math.min(r, g, b)
  const d = max - min
  let h = 0
  const l = (max + min) / 2

  if (d !== 0) {
    switch (max) {
      case r: h = ((g - b) / d) % 6; break
      case g: h = (b - r) / d + 2; break
      default: h = (r - g) / d + 4; break
    }
    h *= 60
    if (h < 0) h += 360
  }

  const s = d === 0 ? 0 : d / (1 - Math.abs(2 * l - 1))
  return { h, s, l }
}

function hslToRgb(h: number, s: number, l: number): Rgb {
  const hue = ((h % 360) + 360) % 360
  const sat = clamp01(s)
  const light = clamp01(l)
  const c = (1 - Math.abs(2 * light - 1)) * sat
  const x = c * (1 - Math.abs(((hue / 60) % 2) - 1))
  const m = light - c / 2

  let rp = 0
  let gp = 0
  let bp = 0
  if (hue < 60) [rp, gp, bp] = [c, x, 0]
  else if (hue < 120) [rp, gp, bp] = [x, c, 0]
  else if (hue < 180) [rp, gp, bp] = [0, c, x]
  else if (hue < 240) [rp, gp, bp] = [0, x, c]
  else if (hue < 300) [rp, gp, bp] = [x, 0, c]
  else [rp, gp, bp] = [c, 0, x]

  return {
    r: clampByte((rp + m) * 255),
    g: clampByte((gp + m) * 255),
    b: clampByte((bp + m) * 255),
  }
}

function relativeLuminance(c: Rgb): number {
  const linear = (v: number) => {
    const srgb = v / 255
    return srgb <= 0.04045 ? srgb / 12.92 : ((srgb + 0.055) / 1.055) ** 2.4
  }
  const r = linear(c.r)
  const g = linear(c.g)
  const b = linear(c.b)
  return 0.2126 * r + 0.7152 * g + 0.0722 * b
}

function readAverageWallpaperColor(path: string): Rgb | null {
  const resolved = resolveHomePath(path)
  if (!resolved) return null
  if (!GLib.file_test(resolved, GLib.FileTest.EXISTS)) return null

  try {
    const pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(resolved, 96, 96, true)
    const rawPixels = pixbuf.get_pixels() as unknown as Uint8Array | number[]
    const pixels = rawPixels instanceof Uint8Array ? rawPixels : new Uint8Array(rawPixels)
    const width = pixbuf.get_width()
    const height = pixbuf.get_height()
    const rowstride = pixbuf.get_rowstride()
    const channels = pixbuf.get_n_channels()

    let sumR = 0
    let sumG = 0
    let sumB = 0
    let weight = 0

    for (let y = 0; y < height; y += 1) {
      for (let x = 0; x < width; x += 1) {
        const idx = y * rowstride + x * channels
        const alpha = channels >= 4 ? pixels[idx + 3] / 255 : 1
        if (alpha < 0.02) continue
        sumR += pixels[idx] * alpha
        sumG += pixels[idx + 1] * alpha
        sumB += pixels[idx + 2] * alpha
        weight += alpha
      }
    }

    if (weight <= 0) return null
    return {
      r: clampByte(sumR / weight),
      g: clampByte(sumG / weight),
      b: clampByte(sumB / weight),
    }
  } catch {
    return null
  }
}

function deriveAdaptiveColors(base: ThemeColors, wallpaperPath: string): ThemeColors {
  const avg =
    readAverageWallpaperColor(wallpaperPath)
    ?? parseHexColor(base.accent)
    ?? parseHexColor(base.fg)
    ?? FALLBACK_ACCENT

  const wallpaperLuminance = relativeLuminance(avg)
  const wallpaperIsDark = wallpaperLuminance < 0.52
  const uiIsDark = wallpaperIsDark

  const surface = uiIsDark
    ? mixRgb(avg, { r: 10, g: 12, b: 17 }, 0.84)
    : mixRgb(avg, { r: 247, g: 250, b: 255 }, 0.52)
  const surfaceSolid = uiIsDark
    ? mixRgb(surface, { r: 7, g: 9, b: 13 }, 0.45)
    : mixRgb(surface, { r: 255, g: 255, b: 255 }, 0.18)
  const surfaceDark = uiIsDark
    ? mixRgb(surface, { r: 0, g: 0, b: 0 }, 0.38)
    : mixRgb(surface, { r: 221, g: 227, b: 237 }, 0.52)

  const hsl = rgbToHsl(avg)
  // Use the wallpaper's own dominant hue as the accent (not its complement).
  // If the wallpaper is near-grayscale, fall back to a cool blue.
  const accentHue = hsl.s < 0.12 ? 205 : hsl.h
  const accentSat = Math.min(0.92, Math.max(0.62, hsl.s + 0.25))
  const accentLight = uiIsDark ? 0.66 : 0.4
  const accent = hslToRgb(accentHue, accentSat, accentLight)

  const fg = uiIsDark ? { r: 247, g: 249, b: 252 } : { r: 20, g: 24, b: 32 }
  const fgDim = uiIsDark ? mixRgb(fg, surface, 0.32) : mixRgb(fg, surface, 0.4)
  const fgFaint = uiIsDark ? mixRgb(fg, surface, 0.52) : mixRgb(fg, surface, 0.56)

  const green = hslToRgb((accentHue + 118) % 360, 0.5, uiIsDark ? 0.58 : 0.4)
  const teal = hslToRgb((accentHue + 84) % 360, 0.52, uiIsDark ? 0.62 : 0.42)
  const magenta = hslToRgb((accentHue + 36) % 360, 0.58, uiIsDark ? 0.68 : 0.44)
  const yellow = hslToRgb((accentHue + 176) % 360, 0.66, uiIsDark ? 0.66 : 0.45)
  const red = hslToRgb((accentHue + 308) % 360, 0.66, uiIsDark ? 0.64 : 0.42)
  const orange = hslToRgb((accentHue + 236) % 360, 0.64, uiIsDark ? 0.62 : 0.44)

  return {
    bg: rgba(surface, uiIsDark ? 0.42 : 0.5),
    bg_solid: rgba(surfaceSolid, uiIsDark ? 0.58 : 0.62),
    bg_dark: rgba(surfaceDark, uiIsDark ? 0.5 : 0.55),
    fg: rgbToHex(fg),
    fg_dim: rgbToHex(fgDim),
    fg_faint: rgba(fgFaint, uiIsDark ? 0.78 : 0.82),
    accent: rgbToHex(accent),
    accent_dim: rgba(accent, uiIsDark ? 0.26 : 0.2),
    accent_glow: rgba(accent, uiIsDark ? 0.14 : 0.12),
    green: rgbToHex(green),
    teal: rgbToHex(teal),
    magenta: rgbToHex(magenta),
    yellow: rgbToHex(yellow),
    red: rgbToHex(red),
    orange: rgbToHex(orange),
  }
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
    "awww", "img", resolveHomePath(path),
    "--transition-type", "wipe",
    "--transition-angle", "30",
    "--transition-duration", "0.8",
  ]).catch(console.error)
}

function saveCurrentWallpaper(themeId: string, path: string) {
  const updateFile = (filePath: string) => {
    try {
      const [ok, bytes] = GLib.file_get_contents(filePath)
      if (!ok) return
      const parsed = JSON.parse(new TextDecoder().decode(bytes)) as ThemePreset
      parsed.wallpaper = path
      GLib.file_set_contents(filePath, `${JSON.stringify(parsed, null, 2)}\n`)
    } catch {
      // ignore invalid or missing file
    }
  }

  updateFile(`${THEMES_DIR}/${themeId}.json`)
  if (getCurrentThemeId() === themeId) {
    updateFile(CURRENT_THEME_FILE)
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// CSS GENERATOR (exported for app.tsx)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

export function generateThemeCSS(preset: ThemePreset, wallpaperOverride = ""): string {
  const c = deriveAdaptiveColors(
    preset.colors,
    wallpaperOverride || preset.wallpaper || "",
  )
  // Keep alpha so Hyprland layer blur (configured in windowrules.conf) shows through.
  const barBg = c.bg
  const barBgSolid = c.bg_solid
  const barBgDark = c.bg_dark
  const css = `
/* ── Theme: ${preset.name} ── adaptive from wallpaper average ── */
@define-color theme_bg           ${c.bg};
@define-color theme_bg_solid     ${c.bg_solid};
@define-color theme_bg_dark      ${c.bg_dark};
@define-color theme_fg           ${c.fg};
@define-color theme_fg_dim       ${c.fg_dim};
@define-color theme_fg_faint     ${c.fg_faint};
@define-color theme_accent       ${c.accent};
@define-color theme_accent_dim   ${c.accent_dim};
@define-color theme_accent_glow  ${c.accent_glow};
@define-color theme_green        ${c.green};
@define-color theme_teal         ${c.teal};
@define-color theme_magenta      ${c.magenta};
@define-color theme_yellow       ${c.yellow};
@define-color theme_red          ${c.red};
@define-color theme_orange       ${c.orange};

* {
  color: ${c.fg};
}

window {
  color: ${c.fg} !important;
}

/* Single translucent shell — Hyprland blur + wallpaper accent tint */
window > box.bar-shell {
  background: linear-gradient(165deg, ${barBgSolid} 0%, ${barBg} 60%, ${barBgDark} 100%) !important;
  border-color: ${c.accent_dim} !important;
  box-shadow: none !important;
}

/* Lanes & legacy cluster wrappers stay flat — they're layout only */
.bar-shell .bar-cluster,
.bar-shell .bar-cluster-tray,
.bar-shell .bar-cluster-status,
.bar-shell .bar-lane,
.workspaces,
.active-window,
.clock,
.systray,
.volume,
.brightness,
.wifi,
.bluetooth,
.battery,
.notification-bell,
.theme-launcher,
.media,
.media-player {
  background: transparent !important;
  border-color: transparent !important;
}

.bar-shell .bar-divider {
  background: ${c.accent_dim} !important;
}

.workspaces button {
  color: ${c.fg_dim} !important;
}

.workspaces button:hover {
  background: ${c.accent_glow} !important;
  border-color: ${c.accent_dim} !important;
  color: ${c.fg} !important;
}

.workspaces button.focused {
  color: ${c.fg} !important;
  background: ${c.accent_dim} !important;
  border-color: ${c.accent} !important;
}

.active-window .active-window-icon,
.ts-header-icon,
.ts-wp-icon,
.wifi-header-icon,
.bluetooth-header-icon {
  color: ${c.fg} !important;
}

.volume-percent,
.battery-percent,
.media-title-bar,
.clock-time,
.clock-date,
.active-window label,
.active-window .active-window-face-title,
.notification-count {
  color: ${c.fg} !important;
}

.active-window .active-window-face-prompt {
  color: ${c.accent} !important;
}

button,
menubutton > button,
.session-button,
.notification-action,
.ts-apply-btn,
.applauncher-item,
.theme-row,
.wifi-network-btn,
.wifi-action-btn,
.bluetooth-device-btn,
.battery-profile-btn {
  color: ${c.fg} !important;
}

button:hover,
menubutton > button:hover,
.session-button:hover,
.notification-action:hover,
.ts-apply-btn:hover,
.applauncher-item:hover,
.theme-row:hover,
.wifi-network-btn:hover,
.wifi-action-btn:hover,
.bluetooth-device-btn:hover,
.battery-profile-btn:hover {
  background: ${c.accent_glow} !important;
  border-color: ${c.accent_dim} !important;
}

.ts-backdrop,
.popover-backdrop,
.notification-center-backdrop,
.ts-backdrop:hover,
.popover-backdrop:hover,
.notification-center-backdrop:hover {
  background: transparent !important;
  border-color: transparent !important;
}

.notification,
.notification-center,
.applauncher,
.session-menu,
.osd,
.dw-clock-card,
.dw-stats-card,
.dw-viz-card,
.dw-np-card {
  background: ${c.bg_solid} !important;
  border-color: ${c.accent_dim} !important;
  color: ${c.fg} !important;
}

.ts-panel {
  background: ${c.bg} !important;
  border-color: ${c.accent_dim} !important;
  color: ${c.fg} !important;
}

.ts-left,
.ts-apply-row {
  background: ${c.bg_dark} !important;
}

.ts-vsep,
.ts-divider {
  background: ${c.accent_dim} !important;
}

.theme-row.theme-row-active {
  border-color: ${c.accent} !important;
}

.theme-row .theme-row-badge,
.ts-apply-row .ts-apply-btn label,
.ts-apply-row .ts-apply-btn image {
  color: ${c.accent} !important;
}

.ts-apply-row .ts-apply-btn {
  background: ${c.accent_dim} !important;
  border-color: ${c.accent} !important;
}

.ts-apply-row .ts-apply-btn:hover {
  background: ${c.accent_glow} !important;
  border-color: ${c.accent} !important;
}

/* Bar popovers — use the lower-alpha surface so Hyprland's blur shows
 * through, matching the frosted look of the notification center. */
popover > contents {
  background: ${c.bg} !important;
  border-color: ${c.accent_dim} !important;
  color: ${c.fg} !important;
}

.bar-popup-window,
.wifi-popup-window {
  background: ${c.bg} !important;
  border-color: ${c.accent_dim} !important;
  color: ${c.fg} !important;
}

/* Inner popup containers stay transparent — the frosty bg is on
 * popover > contents. Track accent colors on their accent-colored
 * children so they follow the wallpaper-derived accent. */
.wifi-popup,
.bluetooth-popup,
.battery-popup,
.volume-popup,
.brightness-popup,
.media-popup {
  background: transparent !important;
  color: ${c.fg} !important;
}

.wifi-popup .wifi-header-icon,
.bluetooth-popup .bluetooth-header-icon,
.wifi-popup .wifi-scan-btn image,
.bluetooth-popup .bluetooth-scan-btn image,
.bluetooth-popup .bluetooth-toggle-btn.active,
.bluetooth-popup .bluetooth-device-btn image,
.bluetooth .bluetooth-count,
.wifi-popup .wifi-network-btn image,
.wifi-popup .wifi-action-btn.connect,
.wifi-popup .wifi-settings-btn image,
.battery-popup .battery-big-icon,
.battery-popup .battery-profile-btn image,
.volume-popup .volume-mute-btn image,
.brightness-popup .brightness-icon,
.brightness-popup .night-light-icon,
.brightness-popup .night-light-toggle.active {
  color: ${c.accent} !important;
}

.bluetooth .bluetooth-count {
  background: ${c.accent} !important;
  color: ${c.bg_dark} !important;
}

.wifi-popup .wifi-status-row.info,
.wifi-popup .wifi-status-row.info .wifi-status-icon,
.wifi-popup .wifi-status-row.info .wifi-status-label {
  border-color: ${c.accent_dim} !important;
  color: ${c.accent} !important;
}

.wifi-popup .wifi-scan-btn,
.wifi-popup .wifi-network-btn,
.wifi-popup .wifi-settings-btn,
.bluetooth-popup .bluetooth-scan-btn,
.bluetooth-popup .bluetooth-device-btn,
.bluetooth-popup .bluetooth-toggle-btn,
.battery-popup .battery-profile-btn {
  border-color: transparent !important;
}

.wifi-popup .wifi-scan-btn:hover,
.wifi-popup .wifi-network-btn:hover,
.wifi-popup .wifi-settings-btn:hover,
.bluetooth-popup .bluetooth-scan-btn:hover,
.bluetooth-popup .bluetooth-device-btn:hover,
.bluetooth-popup .bluetooth-toggle-btn:hover,
.battery-popup .battery-profile-btn:hover {
  background: ${c.accent_glow} !important;
  border-color: ${c.accent_dim} !important;
}

.wifi-popup .wifi-action-btn.connect {
  background: ${c.accent_glow} !important;
  border-color: ${c.accent_dim} !important;
}

.wifi-popup .wifi-action-btn.connect:hover {
  background: ${c.accent_dim} !important;
  border-color: ${c.accent} !important;
}

.media-popup .media-control-btn:hover,
.media-popup .media-play-btn {
  background: ${c.accent_dim} !important;
  border-color: ${c.accent} !important;
}

.media-popup .media-play-btn:hover {
  background: ${c.accent} !important;
}

slider highlight,
.volume-popup .volume-slider highlight,
.brightness-popup .brightness-slider highlight,
.media-popup .media-progress highlight {
  background: ${c.accent} !important;
}

.brightness-popup .night-light-toggle {
  border-color: ${c.accent_dim} !important;
}

.brightness-popup .night-light-toggle:hover {
  background: ${c.accent_glow} !important;
  border-color: ${c.accent} !important;
}

.brightness-popup .night-light-toggle.active {
  background: ${c.accent_dim} !important;
  border-color: ${c.accent} !important;
}

.notification-body,
.notification-appname,
.notification-history-meta label,
.applauncher-footer-text,
.applauncher-count,
.applauncher-desc,
.ts-footer-text,
.ts-wp-dir,
.ts-wp-empty-hint,
.theme-row-desc,
.wifi-subtitle,
.battery-popup-status,
.brightness-popup .night-light-label,
.osd-percent {
  color: ${c.fg_dim} !important;
}

.theme-row .theme-row-badge,
.applauncher-key,
.ts-key,
.notification-history-urgency,
.wifi-popup .wifi-status-row,
.notification-dnd-toggle,
.notification-clear-all,
.notification-clear-history {
  background: ${c.accent_dim} !important;
  color: ${c.fg} !important;
  border-color: ${c.accent} !important;
}

.applauncher-entry {
  color: ${c.fg} !important;
  caret-color: ${c.accent} !important;
  border-color: ${c.accent_dim} !important;
  background: ${c.bg_dark} !important;
}

.applauncher-entry selection {
  background: ${c.accent_dim} !important;
  color: ${c.fg} !important;
}

slider highlight,
levelbar block.filled,
.osd-level block.filled {
  background: ${c.accent} !important;
}

/* Active/selected state across popovers — battery profile, wifi network,
 * bluetooth device, etc. The base SCSS uses $accent rgbas for these, but
 * we re-emit them here so they track the wallpaper-derived accent. */
.battery-popup .battery-profile-btn.active,
.wifi-popup .wifi-network-btn.active,
.wifi-popup .wifi-network-row.active .wifi-network-btn,
.bluetooth-popup .bluetooth-device-btn.connected,
.bluetooth-popup .bluetooth-toggle-btn.active {
  background: ${c.accent_dim} !important;
  border-color: ${c.accent} !important;
  color: ${c.fg} !important;
}

.battery-popup .battery-check,
.wifi-popup .wifi-status-row.ok .wifi-status-icon,
.wifi-popup .wifi-status-row.ok .wifi-status-label {
  color: ${c.green} !important;
}

.wifi-popup .wifi-status-row.err .wifi-status-icon,
.wifi-popup .wifi-status-row.err .wifi-status-label,
.wifi-popup .wifi-action-btn.forget,
.wifi-popup .wifi-action-btn.disconnect {
  color: ${c.red} !important;
}

entry,
textarea {
  color: ${c.fg} !important;
}

.bar-shell image,
.bar-shell label,
.notification-center image,
.notification-center label,
.notification image,
.notification label,
.applauncher image,
.applauncher label,
.session-menu image,
.session-menu label,
.osd image,
.osd label,
.ts-panel image,
.ts-panel label,
.desktop-widgets image,
.desktop-widgets label {
  color: ${c.fg} !important;
}

.bar-shell button,
.bar-shell menubutton > button,
.notification-center button,
.notification button,
.applauncher button,
.session-menu button,
.ts-panel button,
.desktop-widgets button,
.desktop-widgets levelbar,
.osd levelbar {
  border-color: transparent !important;
  background: transparent !important;
}

.bar-shell button:hover,
.bar-shell menubutton > button:hover,
.notification-center button:hover,
.notification button:hover,
.applauncher button:hover,
.session-menu button:hover,
.ts-panel button:hover,
.desktop-widgets button:hover {
  background: ${c.accent_glow} !important;
  border-color: ${c.accent_dim} !important;
}
`

  // GTK CSS parser does not support !important; strip it from generated output.
  return css.replaceAll(" !important", "")
}

export function applyGeneratedThemeCSS(preset: ThemePreset, wallpaperOverride = "") {
  const css = generateThemeCSS(preset, wallpaperOverride)
  const stamped = `${css}\n/* apply-ts:${Date.now()} */\n`

  try {
    GLib.mkdir_with_parents(DYNAMIC_THEME_DIR, 0o755)
    GLib.file_set_contents(DYNAMIC_THEME_FILE, stamped)
    app.apply_css(`${baseStyle}\n${stamped}`, true)
  } catch (e) {
    console.error("applyGeneratedThemeCSS: failed:", e)
  }
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
  const withPath = btn as Gtk.Button & { _wallpaperPath?: string }
  withPath._wallpaperPath = path
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
  let wallpaperBuildSource = 0
  let wallpaperBuildToken = 0

  // DOM refs
  let themeListBox: Gtk.Box
  let wallpaperGrid: Gtk.FlowBox
  let wpThemeLabel: Gtk.Label
  let wpEmptyLabel: Gtk.Box
  let wpScrolled: Gtk.ScrolledWindow

  const hide = () => { win.visible = false }

  const findTheme = (id: string) => themes.find((t) => t.id === id)

  const stopWallpaperBuild = () => {
    if (wallpaperBuildSource !== 0) {
      GLib.source_remove(wallpaperBuildSource)
      wallpaperBuildSource = 0
    }
  }

  const refreshWallpaperActiveState = () => {
    let child = wallpaperGrid?.get_first_child()
    while (child) {
      const next = child.get_next_sibling()
      const flowChild = child as Gtk.FlowBoxChild
      const button = flowChild.get_child() as Gtk.Button & { _wallpaperPath?: string }
      if (button && button._wallpaperPath === activeWallpaper) {
        button.add_css_class("wp-thumb-active")
      } else if (button) {
        button.remove_css_class("wp-thumb-active")
      }
      child = next
    }
  }

  const applyThemeCssImmediately = (id: string, wallpaperOverride = "") => {
    const preset = findTheme(id)
    if (!preset) return
    applyGeneratedThemeCSS(preset, wallpaperOverride)
  }

  const syncActiveTheme = (id: string) => {
    activeThemeId = id
    activeWallpaper = findTheme(id)?.wallpaper ?? ""
  }

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
    stopWallpaperBuild()
    wallpaperBuildToken += 1
    const buildToken = wallpaperBuildToken

    wallpaperGrid?.remove_all()
    if (wpThemeLabel) {
      const preset = themes.find((t) => t.id === selectedThemeId)
      wpThemeLabel.label = preset ? `${preset.name} wallpapers` : "Wallpapers"
    }

    const walls = listWallpapers(selectedThemeId)

    if (wpEmptyLabel) wpEmptyLabel.visible = walls.length === 0
    if (wpScrolled) wpScrolled.visible = walls.length > 0

    if (walls.length === 0) return

    let index = 0
    const buildChunk = () => {
      if (buildToken !== wallpaperBuildToken) {
        wallpaperBuildSource = 0
        return false
      }

      const end = Math.min(index + WALLPAPER_CHUNK_SIZE, walls.length)
      while (index < end) {
        const path = walls[index]
        const isActive = path === activeWallpaper
        const thumb = WallpaperThumb(path, isActive, () => {
          activeWallpaper = path
          const themeChanged = selectedThemeId !== activeThemeId
          const selected = findTheme(selectedThemeId)
          if (selected) selected.wallpaper = path

          setWallpaper(path)
          saveCurrentWallpaper(selectedThemeId, path)
          applyThemeCssImmediately(selectedThemeId, path)

          // Also apply the theme if not already active.
          if (themeChanged) {
            syncActiveTheme(selectedThemeId)
            activeWallpaper = path
            applyTheme(selectedThemeId)
            rebuildThemeList()
          }

          refreshWallpaperActiveState()
        })
        const item = new Gtk.FlowBoxChild()
        item.set_child(thumb)
        wallpaperGrid?.insert(item, -1)
        index += 1
      }

      if (index >= walls.length) {
        wallpaperBuildSource = 0
        return false
      }

      return true
    }

    wallpaperBuildSource = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, buildChunk)
  }

  // ── Apply theme button ───────────────────────────────────
  const applySelectedTheme = () => {
    syncActiveTheme(selectedThemeId)
    applyThemeCssImmediately(selectedThemeId, activeWallpaper)
    applyTheme(selectedThemeId)
    rebuildThemeList()
    refreshWallpaperActiveState()
  }

  onCleanup(() => {
    stopWallpaperBuild()
    win.destroy()
  })

  return (
    <window
      $={(self) => {
        win = self
        self.connect("notify::visible", () => {
          if (self.visible) {
            themes = loadThemes()
            syncActiveTheme(getCurrentThemeId())
            selectedThemeId = activeThemeId
            rebuildThemeList()
            // Build wallpaper thumbnails in idle chunks so the panel appears instantly.
            GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
              if (!self.visible) return false
              rebuildWallpaperGrid()
              return false
            })
          } else {
            stopWallpaperBuild()
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
                $={(self) => { wpEmptyLabel = self }}
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
