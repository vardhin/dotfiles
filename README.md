# dotfiles

Arch Linux rice: Hyprland + AGS v3 (being replaced by the Quickshell "Dot Shell"), Ghostty, zsh. Managed with GNU Stow, one module per top-level folder.

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
│   ├── hyprland.conf           entry point, sources config/* (defaults.conf first)
│   ├── config/
│   │   ├── defaults.conf       $TERMINAL, $BROWSER, $EDITOR, $scriptPath, idle handler
│   │   ├── autostart.conf      boot sound, awww, ags, polkit, clipboard, idle
│   │   ├── decorations.conf    zero chrome: one-dot gutter, focus by dim, blur, animations
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
├── quickshell/.config/quickshell/dotshell/   → ~/.config/quickshell/dotshell  (run: qs -p ~/.config/quickshell/dotshell)
│   ├── shell.qml               entry point; IPC targets strip, shell
│   ├── Tokens.qml              era, pitch, dot size, depth; persisted in
│   │                           ~/.local/state/dotshell/tokens.json (IPC target: tokens)
│   ├── Eras.qml                era presets (slot colors, unlit, glass, ramp, glow, shape)
│   ├── DotSurface.qml          low-res QML canvas → LED dots (shaders/dot.frag)
│   ├── DotText.qml             pixel-font text, 1 font px = 1 dot
│   ├── TopStrip.qml            top LED strip: workspaces, clock, tray glyphs
│   ├── shaders/dot.frag(.qsb)  dot mask, depth quantize, glow; .qsb is committed
│   └── build-shaders.sh        recompile .qsb after editing a shader (qt6-shadertools)
├── ghostty/.config/ghostty/    → ~/.config/ghostty  (Departure Mono pixel font, no chrome)
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

## Dot Shell

Run it by path: `qs -c dotshell` silently skips subfolders when `~/.config/quickshell/shell.qml`
exists. Hyprland uses `$dotshell` from `defaults.conf`. Quickshell hot-reloads on save.
Tokens can be changed live:

```bash
alias dotshell='qs -p ~/.config/quickshell/dotshell'
```

```bash
dotshell ipc call tokens set era tokyo     # phosphor | tokyo | matrix | vfd
dotshell ipc call tokens set pitch 5       # 3 | 5 | 8 | 12 px per dot
dotshell ipc call tokens set dotSize 70    # 40–100 % of pitch
dotshell ipc call tokens set depth 16      # era | 8 | 16 | 24
dotshell ipc call strip toggle
```

Binds: `Super D` toggles the strip, `Super Shift D` cycles eras, `Super Ctrl D` restarts it.
