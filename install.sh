#!/usr/bin/env bash
# Install these dotfiles on an Arch machine.
#
#   ./install.sh            packages + zsh framework + stow all modules
#   ./install.sh --link     only (re)stow the modules
#   ./install.sh --dry-run  show what stow would do, change nothing
#
# Existing files that would block a symlink are moved to
# ~/.dotfiles-backup/<timestamp>/ before stowing.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES=(hypr ags ghostty zsh)
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
    # Already ours, directly or through a folded directory link: never touch it.
    [[ -e $target && $(readlink -f "$target") == "$(readlink -f "$src")" ]] && continue
    if [[ -e $target && ! -L $target ]]; then
      mkdir -p "$BACKUP/$(dirname "$rel")"
      mv "$target" "$BACKUP/$rel"
      log "backed up ~/$rel"
    fi
  done < <(find "$DOTFILES/$module" -type f -print0)
}

link_modules() {
  local dry=${1:-}
  command -v stow >/dev/null || { echo "stow is not installed (sudo pacman -S stow)" >&2; exit 1; }
  for m in "${MODULES[@]}"; do
    if [[ $dry == --dry-run ]]; then
      stow -n -v -d "$DOTFILES" -t "$HOME" --restow "$m" || true
    else
      backup_conflicts "$m"
      stow -d "$DOTFILES" -t "$HOME" --restow "$m"
      log "linked $m"
    fi
  done
}

case "${1:-}" in
  --dry-run) link_modules --dry-run ;;
  --link)    link_modules ;;
  "")        install_packages; install_zsh_framework; link_modules ;;
  *)         echo "usage: $0 [--link|--dry-run]" >&2; exit 2 ;;
esac

log "done"
