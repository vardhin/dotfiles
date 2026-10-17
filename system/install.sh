#!/usr/bin/env bash
# System-wide pieces of the rice: files outside ~ that stow cannot link.
#   sudo system/install.sh            greeter + splash
#   sudo system/install.sh greetd     Dot Shell's greeter for greetd
#   sudo system/install.sh plymouth   the dot-matrix boot splash
#   sudo system/install.sh sudo       one sudo password per 15 min across terminals (opt-in, not in all)
#
# greetd:   /etc/greetd/{config.toml,hyprland.lua}; a copy of Dot Shell in
#           /usr/local/share/dotshell (the greeter user cannot read ~; rerun
#           after changing greeter.qml or anything it uses); the shared state
#           folder /var/lib/dotshell-greeter/dotshell, owned by you, where Dot
#           Shell's Export leaves the era, wallpaper and user name; enables
#           greetd for the next boot (starting it now would end a session
#           logged in on tty1).
# plymouth: the `dotshell` theme in the current era's colors (rerun after an
#           era change to repaint it), the plymouth hook in mkinitcpio.conf,
#           `quiet splash` in /etc/kernel/cmdline, then mkinitcpio -P.
#           Edited files are backed up next to themselves as *.dotshell-bak.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYS="$DOTFILES/system"

[ "$(id -u)" -eq 0 ] || { echo "run with sudo: sudo $0 ${*:-}" >&2; exit 1; }
USER_NAME="${SUDO_USER:-}"
[ -n "$USER_NAME" ] && [ "$USER_NAME" != root ] || { echo "run through sudo from your own user, so SUDO_USER is set" >&2; exit 1; }
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"

backup() {
  [ -e "$1" ] && [ ! -e "$1.dotshell-bak" ] && cp -a "$1" "$1.dotshell-bak"
  return 0
}

install_greetd() {
  command -v greetd >/dev/null || { echo "greetd is not installed (pacman -S greetd)" >&2; exit 1; }
  echo ":: greetd: Dot Shell greeter"
  backup /etc/greetd/config.toml
  install -Dm644 "$SYS/greetd/config.toml" /etc/greetd/config.toml
  install -Dm644 "$SYS/greetd/hyprland.lua" /etc/greetd/hyprland.lua
  rm -f /etc/greetd/hyprland.conf

  rsync -a --delete --chmod=Da+rx,Fa+r "$DOTFILES/quickshell/.config/quickshell/dotshell/" /usr/local/share/dotshell/

  install -d -m 755 /var/lib/dotshell-greeter
  install -d -o "$USER_NAME" -g "$(id -gn "$USER_NAME")" -m 755 /var/lib/dotshell-greeter/dotshell

  systemctl enable greetd.service
  echo "   greetd enabled; it takes over tty1 at the next boot."
  echo "   Run 'dotshell ipc call export run' (as $USER_NAME) to fill the greeter's colors now."
}

install_plymouth() {
  command -v plymouth-set-default-theme >/dev/null || { echo "plymouth is not installed (pacman -S plymouth)" >&2; exit 1; }
  local conf="$USER_HOME/.config/ghostty/dotshell.conf"
  [ -f "$conf" ] || { echo "no $conf yet: start Dot Shell once so it exports the era" >&2; exit 1; }
  echo ":: plymouth: dotshell splash"
  local theme=/usr/share/plymouth/themes/dotshell
  install -d "$theme"
  install -m644 "$SYS/plymouth/dotshell/dotshell.plymouth" "$SYS/plymouth/dotshell/dotshell.script" "$theme/"
  python3 -I "$SYS/plymouth/dotshell/build.py" "$conf" "$theme"
  plymouth-set-default-theme dotshell

  # The hook, right after udev (or systemd) on the active HOOKS= line.
  local mk=/etc/mkinitcpio.conf
  if ! grep -E '^\s*HOOKS=' "$mk" | grep -qw plymouth; then
    backup "$mk"
    sed -i -E '/^\s*HOOKS=/ { s/\b(udev|systemd)\b/\1 plymouth/ }' "$mk"
    grep -E '^\s*HOOKS=' "$mk" | grep -qw plymouth || { echo "could not add the plymouth hook to $mk; add it by hand" >&2; exit 1; }
  fi

  # Unified kernel images read the command line from /etc/kernel/cmdline.
  local cl=/etc/kernel/cmdline
  if [ -f "$cl" ]; then
    backup "$cl"
    for w in quiet splash; do
      grep -qw "$w" "$cl" || sed -i "1 s/\$/ $w/" "$cl"
    done
  else
    echo "   no $cl: add 'quiet splash' to your kernel command line by hand" >&2
  fi

  mkinitcpio -P
}

install_sudo() {
  echo ":: sudo: one password per 15 minutes across terminals"
  local f=/etc/sudoers.d/10-dotshell
  install -Dm440 "$SYS/sudoers/10-dotshell" "$f.new"
  if visudo -cqf "$f.new"; then mv "$f.new" "$f"; else rm -f "$f.new"; echo "   sudoers check failed; nothing installed" >&2; exit 1; fi
}

case "${1:-all}" in
  greetd)   install_greetd ;;
  plymouth) install_plymouth ;;
  sudo)     install_sudo ;;
  all)      install_greetd; install_plymouth ;;
  *)        echo "usage: sudo $0 [greetd|plymouth|sudo]" >&2; exit 1 ;;
esac
