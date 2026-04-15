#!/usr/bin/env bash
# apply-theme.sh — Apply a theme preset to hyprland + AGS + wallpaper
# Usage: apply-theme.sh <theme-id>
# Example: apply-theme.sh catppuccin-mocha

set -euo pipefail

THEMES_DIR="$HOME/.config/ags/themes"
CURRENT_THEME_FILE="$HOME/.config/ags/themes/current.json"

THEME_ID="${1:-}"
if [[ -z "$THEME_ID" ]]; then
  echo "Usage: apply-theme.sh <theme-id>" >&2
  exit 1
fi

THEME_FILE="$THEMES_DIR/${THEME_ID}.json"
if [[ ! -f "$THEME_FILE" ]]; then
  echo "Theme not found: $THEME_FILE" >&2
  exit 1
fi

# ── helpers ────────────────────────────────────────────────────────────────────

jq_get() { jq -r "$1" "$THEME_FILE"; }

# ── 1. Read theme values ───────────────────────────────────────────────────────

ACTIVE_BORDER=$(jq_get '.hyprland.active_border')
INACTIVE_BORDER=$(jq_get '.hyprland.inactive_border')
BORDER_SIZE=$(jq_get '.hyprland.border_size')
ROUNDING=$(jq_get '.hyprland.rounding')
SHADOW_COLOR=$(jq_get '.hyprland.shadow_color')
SHADOW_RANGE=$(jq_get '.hyprland.shadow_range')
SHADOW_POWER=$(jq_get '.hyprland.shadow_render_power')
SHADOW_OFFSET=$(jq_get '.hyprland.shadow_offset')
BLUR_SIZE=$(jq_get '.hyprland.blur_size')
BLUR_PASSES=$(jq_get '.hyprland.blur_passes')
BLUR_VIBRANCY=$(jq_get '.hyprland.blur_vibrancy')
DIM_INACTIVE=$(jq_get '.hyprland.dim_inactive')
DIM_STRENGTH=$(jq_get '.hyprland.dim_strength')
GAPS_IN=$(jq_get '.hyprland.gaps_in')
GAPS_OUT=$(jq_get '.hyprland.gaps_out')
WALLPAPER=$(jq_get '.wallpaper')

# ── 2. Apply hyprland decoration values live ──────────────────────────────────

hyprctl keyword general:border_size "$BORDER_SIZE"
hyprctl keyword general:gaps_in "$GAPS_IN"
hyprctl keyword general:gaps_out "$GAPS_OUT"
hyprctl keyword general:col.active_border "$ACTIVE_BORDER"
hyprctl keyword general:col.inactive_border "$INACTIVE_BORDER"

hyprctl keyword decoration:rounding "$ROUNDING"
hyprctl keyword decoration:dim_inactive "$DIM_INACTIVE"
hyprctl keyword decoration:dim_strength "$DIM_STRENGTH"

hyprctl keyword decoration:blur:size "$BLUR_SIZE"
hyprctl keyword decoration:blur:passes "$BLUR_PASSES"
hyprctl keyword decoration:blur:vibrancy "$BLUR_VIBRANCY"

hyprctl keyword decoration:shadow:color "$SHADOW_COLOR"
hyprctl keyword decoration:shadow:range "$SHADOW_RANGE"
hyprctl keyword decoration:shadow:render_power "$SHADOW_POWER"
hyprctl keyword decoration:shadow:offset "$SHADOW_OFFSET"

# ── 3. Wallpaper ───────────────────────────────────────────────────────────────

if [[ -n "$WALLPAPER" && -f "$WALLPAPER" ]]; then
  swww img "$WALLPAPER" \
    --transition-type wipe \
    --transition-angle 30 \
    --transition-duration 1.2
fi

# ── 4. Save current theme pointer ─────────────────────────────────────────────

cp "$THEME_FILE" "$CURRENT_THEME_FILE"

# ── 5. Tell AGS to reload CSS with new theme ─────────────────────────────────

ags request "apply-theme:${THEME_ID}"

echo "Theme applied: $THEME_ID"
