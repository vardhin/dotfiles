#!/usr/bin/env bash
# Install these dotfiles on an Arch machine.
#
#   ./install.sh            packages + zsh framework + stow all modules + user services
#   ./install.sh --link     only (re)stow the modules
#   ./install.sh --dry-run  show what stow would do, change nothing
#
# Existing files that would block a symlink are moved to
# ~/.dotfiles-backup/<timestamp>/ before stowing.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES=(hypr quickshell ghostty fontconfig zsh mpv mpd)
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

case "${1:-}" in
  --dry-run) link_modules --dry-run ;;
  --link)    link_modules ;;
  "")        install_packages; install_zsh_framework; link_modules; enable_services ;;
  *)         echo "usage: $0 [--link|--dry-run]" >&2; exit 2 ;;
esac

log "done"
