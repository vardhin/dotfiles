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

# ── 1. Read theme values ───────────────────────────────────────────────────────

mapfile -t THEME_VALUES < <(
  jq -r '
    .hyprland.active_border,
    .hyprland.inactive_border,
    .hyprland.border_size,
    .hyprland.rounding,
    .hyprland.shadow_color,
    .hyprland.shadow_range,
    .hyprland.shadow_render_power,
    .hyprland.shadow_offset,
    .hyprland.blur_size,
    .hyprland.blur_passes,
    .hyprland.blur_vibrancy,
    .hyprland.dim_inactive,
    .hyprland.dim_strength,
    .hyprland.gaps_in,
    .hyprland.gaps_out,
    .wallpaper
  ' "$THEME_FILE"
)

ACTIVE_BORDER="${THEME_VALUES[0]:-rgba(33aaffee)}"
INACTIVE_BORDER="${THEME_VALUES[1]:-rgba(777777aa)}"
BORDER_SIZE="${THEME_VALUES[2]:-2}"
ROUNDING="${THEME_VALUES[3]:-10}"
SHADOW_COLOR="${THEME_VALUES[4]:-rgba(00000066)}"
SHADOW_RANGE="${THEME_VALUES[5]:-20}"
SHADOW_POWER="${THEME_VALUES[6]:-3}"
SHADOW_OFFSET="${THEME_VALUES[7]:-0 4}"
BLUR_SIZE="${THEME_VALUES[8]:-6}"
BLUR_PASSES="${THEME_VALUES[9]:-2}"
BLUR_VIBRANCY="${THEME_VALUES[10]:-0.2}"
DIM_INACTIVE="${THEME_VALUES[11]:-true}"
DIM_STRENGTH="${THEME_VALUES[12]:-0.1}"
GAPS_IN="${THEME_VALUES[13]:-4}"
GAPS_OUT="${THEME_VALUES[14]:-8}"
WALLPAPER="${THEME_VALUES[15]:-}"

# ── 2. Apply hyprland decoration values live ──────────────────────────────────

HYPR_BATCH=$(cat <<EOF
keyword general:border_size ${BORDER_SIZE};
keyword general:gaps_in ${GAPS_IN};
keyword general:gaps_out ${GAPS_OUT};
keyword general:col.active_border ${ACTIVE_BORDER};
keyword general:col.inactive_border ${INACTIVE_BORDER};
keyword decoration:rounding ${ROUNDING};
keyword decoration:dim_inactive ${DIM_INACTIVE};
keyword decoration:dim_strength ${DIM_STRENGTH};
keyword decoration:blur:size ${BLUR_SIZE};
keyword decoration:blur:passes ${BLUR_PASSES};
keyword decoration:blur:vibrancy ${BLUR_VIBRANCY};
keyword decoration:shadow:color ${SHADOW_COLOR};
keyword decoration:shadow:range ${SHADOW_RANGE};
keyword decoration:shadow:render_power ${SHADOW_POWER};
keyword decoration:shadow:offset ${SHADOW_OFFSET}
EOF
)

hyprctl --batch "$HYPR_BATCH"

# ── 3. Save current theme pointer ─────────────────────────────────────────────

cp "$THEME_FILE" "$CURRENT_THEME_FILE"

# ── 4. Wallpaper ───────────────────────────────────────────────────────────────

if [[ "$WALLPAPER" == ~/* ]]; then
  WALLPAPER="$HOME/${WALLPAPER#~/}"
fi

if [[ -n "$WALLPAPER" && -f "$WALLPAPER" ]]; then
  swww img "$WALLPAPER" \
    --transition-type wipe \
    --transition-angle 30 \
    --transition-duration 0.8
fi

echo "Theme applied: $THEME_ID"
