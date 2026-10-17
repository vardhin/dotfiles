#!/usr/bin/env bash
# Install these dotfiles on an Arch machine.
#
#   ./install.sh            packages + zsh framework + stow all modules + user services
#   ./install.sh --link     only (re)stow the modules (and check the compiled shaders)
#   ./install.sh --dry-run  show what stow would do, change nothing
#   ./install.sh --plugins  only build and load the Hyprland plugins (no sudo)
#   ./install.sh --yay      only save the yay defaults (no menus, sudo loop)
#
# Existing files that would block a symlink are moved to
# ~/.dotfiles-backup/<timestamp>/ before stowing.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES=(hypr quickshell ghostty fontconfig zsh mpv mpd cava)
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

log() { printf '\033[1;33m::\033[0m %s\n' "$*"; }

read_list() { grep -v '^\s*#' "$1" | sed 's/#.*//; s/\s\+$//; /^\s*$/d'; }

install_packages() {
  log "pacman packages"
  sudo pacman -S --needed - < <(read_list "$DOTFILES/packages.txt")

  local helper=""
  command -v paru >/dev/null && helper=paru
  [[ -z $helper ]] && command -v yay >/dev/null && helper=yay
  if [[ -n $helper ]]; then
    log "AUR packages via $helper"
    "$helper" -S --needed - < <(read_list "$DOTFILES/packages-aur.txt")
  else
    log "no AUR helper found; install these by hand:"
    read_list "$DOTFILES/packages-aur.txt" | sed 's/^/   /'
  fi
}

clone_once() { [[ -d $2 ]] || git clone --depth 1 "$1" "$2"; }

install_zsh_framework() {
  log "oh-my-zsh + custom plugins"
  clone_once https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
  local custom="$HOME/.oh-my-zsh/custom"
  clone_once https://github.com/zsh-users/zsh-autosuggestions "$custom/plugins/zsh-autosuggestions"
  clone_once https://github.com/zsh-users/zsh-completions "$custom/plugins/zsh-completions"
  clone_once https://github.com/zsh-users/zsh-history-substring-search "$custom/plugins/zsh-history-substring-search"
  clone_once https://github.com/zdharma-continuum/fast-syntax-highlighting "$custom/plugins/fast-syntax-highlighting"
  clone_once https://github.com/romkatv/powerlevel10k.git "$custom/themes/powerlevel10k"
}

# Move real files (not our symlinks) that stow would refuse to overwrite.
backup_conflicts() {
  local module=$1 src rel target
  while IFS= read -r -d '' src; do
    rel=${src#"$DOTFILES/$module/"}
    target="$HOME/$rel"
    if [[ -e $target && $(readlink -f "$target") == "$(readlink -f "$src")" ]]; then
      # A hand-made absolute link to the repo file: same content, but stow
      # refuses links it didn't make. Drop it so stow can make its own.
      if [[ -L $target && $(readlink "$target") == /* ]]; then
        rm "$target"
        log "replaced hand-made link ~/$rel"
      fi
      # Otherwise already ours, directly or through a folded directory link.
      continue
    fi
    if [[ -e $target && ! -L $target ]]; then
      mkdir -p "$BACKUP/$(dirname "$rel")"
      mv "$target" "$BACKUP/$rel"
      log "backed up ~/$rel"
    fi
  done < <(find "$DOTFILES/$module" -type f -print0)
}

# Links into this repo whose target is gone (a module or file was removed
# from the repo, like ags in Phase 3) are deleted, so nothing dangles.
prune_dead_links() {
  local link
  while IFS= read -r -d '' link; do
    [[ $(readlink "$link") == *"$(basename "$DOTFILES")/"* ]] || continue
    rm "$link"
    log "removed dead link ${link/#$HOME/~}"
  done < <(find "$HOME" "$HOME/.config" -maxdepth 1 -xtype l -print0 2>/dev/null)
}

link_modules() {
  local dry=${1:-}
  command -v stow >/dev/null || { echo "stow is not installed (sudo pacman -S stow)" >&2; exit 1; }
  if [[ $dry == --dry-run ]]; then
    for m in "${MODULES[@]}"; do stow -n -v -d "$DOTFILES" -t "$HOME" --restow "$m" || true; done
    return
  fi
  prune_dead_links
  # Clear every conflict first: one stray link trips stow on every module.
  for m in "${MODULES[@]}"; do backup_conflicts "$m"; done
  for m in "${MODULES[@]}"; do
    stow -d "$DOTFILES" -t "$HOME" --restow "$m"
    log "linked $m"
  done
  # Restowing drops and remakes the links; a running Hyprland that reloaded in
  # that gap is left with no binds. Reload it once the links are back.
  if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && command -v hyprctl >/dev/null; then
    hyprctl reload >/dev/null && log "reloaded Hyprland"
  fi
}

# mpd keeps its database and state in ~/.local/state/mpd (mpd/.config/mpd/mpd.conf);
# mpd-mpris puts it on MPRIS for Dot Shell. Units that are not installed are skipped.
enable_services() {
  log "user services"
  mkdir -p "$HOME/.local/state/mpd/playlists"
  local unit
  for unit in mpd.service mpd-mpris.service; do
    if systemctl --user cat "$unit" >/dev/null 2>&1; then
      systemctl --user enable --now "$unit"
    else
      log "no $unit; skipped"
    fi
  done
}

# McMojave-circle, -light and -dark into ~/.local/share/icons, unless some
# copy (yours, or the AUR package's) is there already.
install_icons() {
  local d
  for d in "$HOME/.local/share/icons" "$HOME/.icons" /usr/share/icons; do
    [[ -d $d/McMojave-circle-dark ]] && return 0
  done
  log "McMojave-circle icons"
  local tmp; tmp=$(mktemp -d)
  git clone --depth 1 https://github.com/vinceliuice/McMojave-circle.git "$tmp/McMojave-circle"
  "$tmp/McMojave-circle/install.sh"
  rm -rf "$tmp"
}

# Hyprland plugins: Hypr-DarkWindow (Dot Shell's per-window LED shading, the
# `winshade` token) and dynamic-cursors (stretch, shake to find). Built here
# against the headers the Arch hyprland package ships (pkg-config hyprland),
# not by hyprpm: hyprpm clones all of Hyprland's history and submodules to make
# those same headers, which takes ages. Each plugin repo's hyprpm.toml pins the
# plugin commit for every Hyprland release; the pin for the Hyprland in use is
# checked out (latest commit when there is none yet). The .so files go to
# ~/.local/lib/hypr-plugins, which lua/autostart.lua loads at session start.
# Their config lives in hypr/.config/hypr/lua/dotshell.lua and runs only once
# they are loaded, so a failed build leaves the desktop exactly as it was.
# Rerun after a Hyprland update (Hyprland refuses plugins built for another).
PLUGINS=(
  "https://github.com/micha4w/Hypr-DarkWindow Hypr-DarkWindow"
  "https://github.com/VirtCode/hypr-dynamic-cursors hypr-dynamic-cursors"
)
PLUGIN_SRC="$HOME/.local/src"
PLUGIN_DIR="$HOME/.local/lib/hypr-plugins"
install_plugins() {
  pkg-config --exists hyprland || { log "no Hyprland headers (pkg-config hyprland); plugins skipped"; return 0; }
  log "Hyprland plugins (built against Hyprland $(pkg-config --modversion hyprland))"
  # The Hyprland commit: the running one, else the installed binary's.
  local hypr url name dir pin so
  hypr=$(hyprctl version -j 2>/dev/null | sed -n 's/.*"commit": *"\([0-9a-f]*\)".*/\1/p')
  [[ -n $hypr ]] || hypr=$(Hyprland --version 2>/dev/null | sed -n 's/.* at commit \([0-9a-f]*\).*/\1/p')
  mkdir -p "$PLUGIN_SRC" "$PLUGIN_DIR"
  for entry in "${PLUGINS[@]}"; do
    read -r url name <<<"$entry"
    dir="$PLUGIN_SRC/$name"
    [[ -d $dir/.git ]] || git clone --depth 1 "$url" "$dir" || { log "could not clone $name"; continue; }
    git -C "$dir" fetch --depth 1 origin HEAD && git -C "$dir" checkout -q FETCH_HEAD
    pin=$(sed -n "s/.*\"$hypr\", *\"\([0-9a-f]*\)\".*/\1/p" "$dir/hyprpm.toml" 2>/dev/null | head -n1)
    if [[ -n $pin ]]; then
      git -C "$dir" fetch --depth 1 origin "$pin" && git -C "$dir" checkout -q "$pin" || { log "could not check out $name at $pin"; continue; }
    else
      log "$name has no pin for this Hyprland yet; building its latest commit"
    fi
    make -C "$dir" clean >/dev/null 2>&1
    make -C "$dir" -j"$(nproc)" || { log "$name did not build"; continue; }
    so=$(find "$dir" -name '*.so' -newer "$dir/Makefile" | head -n1)
    [[ -n $so ]] && install -m 755 "$so" "$PLUGIN_DIR/" && log "built $(basename "$so")"
  done
  if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    for so in "$PLUGIN_DIR"/*.so; do
      [[ -e $so ]] && hyprctl plugin load "$so" >/dev/null
    done
  fi
  return 0
}

# GTK apps and Firefox read the cursor and icons from gsettings; Hyprland
# itself sets XCURSOR_THEME (hypr/.config/hypr/lua/environment.lua). The
# cursor is Dot Shell's own DotShell theme once Export has drawn it (it also
# sets gsettings then); Bibata Amber until that first run.
set_theme() {
  command -v gsettings >/dev/null || return 0
  log "cursor and icon theme"
  local cursor=Bibata-Modern-Amber
  [[ -f $HOME/.local/share/icons/DotShell/index.theme ]] && cursor=DotShell
  gsettings set org.gnome.desktop.interface cursor-theme "$cursor"
  gsettings set org.gnome.desktop.interface cursor-size 24
  gsettings set org.gnome.desktop.interface icon-theme McMojave-circle-dark
}

# yay without the menus: no clean/diff/edit questions, make-dependencies
# removed after a build, and sudo kept alive through long builds (one
# password per command). Saved to ~/.config/yay/config.json.
configure_yay() {
  command -v yay >/dev/null || return 0
  log "yay defaults"
  yay -Y --save --answerclean None --answerdiff None --answeredit None --removemake --sudoloop
}

# The committed .qsb shaders must match their sources (build-shaders.sh
# records them); warn here, and refuse commits that would break it.
check_shaders() {
  git -C "$DOTFILES" config core.hooksPath .githooks 2>/dev/null || true
  "$DOTFILES/quickshell/.config/quickshell/dotshell/build-shaders.sh" --check \
    || log "shaders: rebuild with quickshell/.config/quickshell/dotshell/build-shaders.sh"
}

case "${1:-}" in
  --dry-run) link_modules --dry-run ;;
  --link)    link_modules; check_shaders ;;
  --plugins) install_plugins ;;
  --yay)     configure_yay ;;
  "")        install_packages; configure_yay; install_zsh_framework; link_modules; check_shaders; enable_services; install_icons; install_plugins; set_theme ;;
  *)         echo "usage: $0 [--link|--dry-run|--plugins|--yay]" >&2; exit 2 ;;
esac

log "done"
