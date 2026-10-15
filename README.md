# dotfiles

Arch Linux rice: Hyprland + AGS v3, zsh. Managed with GNU Stow, one module per top-level folder.

> Mid re-rice. The plan (Hyprland + Quickshell + the dot-matrix "Dot Shell") lives in the
> *Arch Rice* doc, tab **Re-rice plan**. This README describes what is in the repo today.

## Install

```bash
git clone https://github.com/vardhin/dotfiles ~/dotfiles
cd ~/dotfiles
./install.sh            # pacman + AUR packages, oh-my-zsh + plugins, stow every module
./install.sh --link     # only (re)link the modules
./install.sh --dry-run  # show what stow would do
```

Files that would block a link are moved to `~/.dotfiles-backup/<timestamp>/` first.
Re-running is safe.

## Layout

```
dotfiles/
├── hypr/.config/hypr/          → ~/.config/hypr
│   ├── hyprland.conf           entry point, sources config/*
│   ├── config/
│   │   ├── defaults.conf       $TERMINAL, $BROWSER, $EDITOR, $scriptPath, idle handler
│   │   ├── autostart.conf      boot sound, awww, ags, polkit, clipboard, idle
│   │   ├── decorations.conf    gaps, borders, blur, shadows, animations
│   │   ├── environment.conf    env vars
│   │   ├── input.conf          keyboard, touchpad, gestures
│   │   ├── keybinds.conf       every bind
│   │   ├── monitor.conf        outputs
│   │   └── windowrules.conf    window + layer rules
│   ├── hypridle.conf / hyprlock.conf (+ hyprlock/background.jpg)
│   ├── scripts/screenshot.sh
│   └── sounds/boot.wav
├── ags/.config/ags/            → ~/.config/ags   (AGS v3, GTK4, TSX)
│   ├── app.tsx                 entry point + IPC request handler
│   ├── widget/                 Bar (+ popovers), AppLauncher, Notifications, OSD,
│   │                           Session, ThemeSwitcher, MediaCenter
│   ├── lib/                    battery monitor, notify helper
│   ├── themes/*.json           theme presets; current.json is the active one
│   ├── scripts/apply-theme.sh  pushes a preset to Hyprland + wallpaper
│   ├── style.scss, assets/icons/
│   └── browser.json            NOT tracked: YouTube Music auth headers, see below
├── zsh/.zshrc                  → ~/.zshrc  (oh-my-zsh, powerlevel10k, eza, zoxide)
├── packages.txt                pacman packages
├── packages-aur.txt            AUR packages
└── install.sh
```

## Secrets

`ags/.config/ags/browser.json` holds YouTube Music request headers for the Media Center.
It is gitignored and must be regenerated locally after logging in; never commit it.

## Paths

Nothing hard-codes a username. Configs use `~` or `$HOME`; theme presets store wallpapers
as `~/wallpaper/<theme>/…`, expanded at runtime by `ThemeSwitcher.tsx` and `apply-theme.sh`.
Wallpapers themselves are not in the repo.
