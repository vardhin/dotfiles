# dotfiles

Arch Linux rice: Hyprland + the Quickshell "Dot Shell" (a dot-matrix LED shell), Ghostty, zsh. Managed with GNU Stow, one module per top-level folder.

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
│   │   ├── defaults.conf       $TERMINAL, $BROWSER, $EDITOR, $scriptPath, $dotshell
│   │   ├── autostart.conf      session env, boot sound, Dot Shell, clipboard
│   │   ├── decorations.conf    zero chrome: one-dot gutter, focus by dim, blur, animations
│   │   ├── environment.conf    env vars
│   │   ├── input.conf          keyboard, touchpad, gestures
│   │   ├── keybinds.conf       every bind, as `bindd` with a description (cheatsheet)
│   │   ├── monitor.conf        outputs
│   │   └── windowrules.conf    window rules
│   ├── scripts/screenshot.sh
│   └── sounds/boot.wav
├── quickshell/.config/quickshell/dotshell/   → ~/.config/quickshell/dotshell
│   ├── shell.qml               entry point; IPC targets pane, strip, night, shell (tokens, export, …)
│   ├── Tokens.qml / Eras.qml   the seven eras, the era cascade and every display token (pitch,
│   │                           dot size, depth, wall, wallpaper, hue, cascade, night); persisted
│   │                           in ~/.local/state/dotshell/tokens.json (IPC target: tokens)
│   ├── Ui.qml                  which pane is open, on which screen
│   ├── DotSurface.qml          low-res QML canvas → LED dots (shaders/dot.frag); optional shape cut
│   ├── DeskPanel.qml, Shapes.js  one desktop panel (clock sign note image mpris pixels) and its outlines
│   ├── Pane.qml                a floating LED pane (layer-shell window + DotSurface)
│   ├── TopStrip.qml            workspaces | clock / ticker | status words, tray
│   ├── DotText DotLabel DotButton DotInput VuBar Marquee FlapText Frame Rule Line StatusWord
│   ├── services/               Notifs (the notification daemon), Audio, Brightness, Power
│   │                           (+ battery monitor), Net, Bt, Idle (+ logind bridge), Lock (PAM),
│   │                           Night, DropTerm, Notify, Panels (desktop panels, panels.json),
│   │                           DotBus (the `dot` socket), Export (era → Ghostty, Neovim, GTK, Qt)
│   ├── panes/                  Launcher, Messages, ToastStack, Osd, Session, Cheatsheet,
│   │                           Calendar, Audio, Brightness, Wifi, Bluetooth, Battery, Eras,
│   │                           Packages, LockScreen, Polkit, Wallpaper (dots/image/off, parallax), World
│   │                           (desktop panels; slides with workspaces)
│   ├── pam/dotshell            PAM stack for the lock screen (pam_unix only)
│   ├── shaders/                dot.frag(.qsb) for DotSurface; warm.glsl, the Hyprland
│   │                           night-warmth screen shader (GLSL ES 3.00, like every screen shader)
│   ├── build-shaders.sh        recompile .qsb after editing dot.frag (qt6-shadertools)
│   └── (../../.local/bin/dot)  the `dot` CLI, linked to ~/.local/bin/dot
├── ghostty/.config/ghostty/    → ~/.config/ghostty  (Departure Mono pixel font, no chrome; era
│                               colors from the generated dotshell.conf, gitignored)
├── fontconfig/.config/fontconfig/conf.d/   Departure Mono without antialiasing (hard pixels)
├── zsh/.zshrc                  → ~/.zshrc  (oh-my-zsh, powerlevel10k, eza, zoxide)
├── packages.txt                pacman packages
├── packages-aur.txt            AUR packages
└── install.sh
```

## Secrets

The old AGS Media Center kept YouTube Music request headers in `ags/.config/ags/browser.json`.
It stays gitignored for as long as a local copy exists; never commit it.

## Paths

Nothing hard-codes a username. Configs use `~` or `$HOME`. The wallpaper is the `wallpaper`
token (a `~/…` path); wallpapers themselves are not in the repo.

## Dot Shell

Run it by path: `qs -c dotshell` silently skips subfolders when `~/.config/quickshell/shell.qml`
exists. Hyprland starts it from `autostart.conf` as `$dotshell`. Quickshell hot-reloads on save.

```bash
alias dotshell='qs -p ~/.config/quickshell/dotshell'   # already in .zshrc
dotshell ipc show                          # every IPC target and function
```

It replaces, one for one: AGS (bar, popovers, launcher, notifications, OSD, session menu),
hyprlock, hypridle, polkit-gnome, awww and hyprsunset.

| Thing | How |
|---|---|
| Panes | `dotshell ipc call pane toggle <launcher\|session\|notifs\|cheatsheet\|calendar\|audio\|brightness\|wifi\|bluetooth\|battery>`; strip words open them too |
| Notifications | Dot Shell is the daemon. New ones scroll across the strip and pop top right; `Super N` lists live ones and the log (`~/.local/state/dotshell/notifications.json`); `Super Shift N` is do-not-disturb |
| Launcher | `Alt Space`: departure board. Type, arrows or Ctrl J/K, Enter; Ctrl 1–8 jumps to a gate. Launch counts rank results |
| Lock | `Super L` (`loginctl lock-session`), idle, the session menu and suspend all lock through logind. PAM stack: `pam/dotshell` |
| Idle | dim 5 min, lock 7.5 min, screen off 7.75 min. Caffeine (`Super Shift C`, or the brightness pane) holds all three |
| Night warmth | `Super Shift H` or `dotshell ipc call night toggle`: a Hyprland screen shader, persisted in tokens |
| Wallpaper | `dotshell ipc call tokens set wallpaper ~/wallpaper/x.jpg`; `wall` picks how it shows: `dots` (drawn by the matrix), `image` (plain, parallax), `off` (unlit glass) |
| Battery monitor | toasts on plug/unplug, at 15 % and 10 %; at 5 % a 60 s grace, then poweroff |
| Shortcuts | `Super /`: read live from `hyprctl -j binds`, described by the `bindd` descriptions |

```bash
dotshell ipc call tokens set era tokyo     # phosphor tokyo nineties matrix vfd aero gameboy
dotshell ipc call tokens set pitch 5       # 3 | 5 | 8 | 12 px per dot
dotshell ipc call tokens set dotSize 70    # 40–100 % of pitch
dotshell ipc call tokens set depth 16      # era | 8 | 16 | 24
dotshell ipc call tokens set wall dots     # dots | image | off
dotshell ipc call tokens set hue wallpaper # era | wallpaper (matugen picks the hue)
dotshell ipc call tokens set cascade false # true: era changes flip over in a wave
dotshell ipc call strip toggle
```

Binds: `Super D` toggles the strip, `Super Shift D` cycles eras, `Super T` opens the era switcher,
`Super I` the package manager (pacman + yay), `Super Ctrl D` restarts the shell.

### Eras

| Era | Id | Look |
|---|---|---|
| Phosphor | `phosphor` | amber CRT, mono |
| Tokyo Night | `tokyo` | magenta and cyan neon, violet ramp, glow |
| 90s Nights | `nineties` | hot pink, electric blue and yellow tubes, heavy glow |
| Matrix | `matrix` | green mono, square dots |
| VFD | `vfd` | car-stereo cyan-green with orange |
| Frutiger Aero | `aero` | light sky glass, glossy bubble dots, dark ink |
| Game Boy | `gameboy` | the four DMG greens, square dots, no glow |

`Super T` shows every era as a card in its own colors. **ERAS** page: arrows or j/k move, Enter
applies, 1–7 pick directly. Tab goes to **DISPLAY**: pitch, dot size, depth, wall, hue, cascade;
Up/Down pick a row, Left/Right change it. At coarse pitches the pane narrows and scrolls so it
always fits under the strip.

An era change flips every dot over in a wave from the top left, like a flip-disc board (the
`cascade` token; off = instant).

With `hue` set to `wallpaper`, matugen (`extra/matugen`) picks the wallpaper's source color and
every era is rotated onto that hue. Only the hue moves: the era's levels, glow and dot shape stay.

The era on screen is also exported to the apps around the shell, on every change:

| App | File | |
|---|---|---|
| Ghostty | `~/.config/ghostty/dotshell.conf` | included by the repo config, reloaded live (SIGUSR2) |
| Neovim | `~/.local/share/nvim/site/colors/dotshell.lua` | `:colorscheme dotshell`; running nvims that use it reload |
| GTK 3 / 4 | `~/.config/gtk-{3,4}.0/gtk.css` | libadwaita named colors; only written when missing or ours (first line says `dotshell:`); also sets the dark/light `color-scheme` |
| Qt | `~/.config/qt6ct/colors/dotshell.conf` | pick it once in qt6ct |

`dotshell ipc call export run` rewrites them by hand.

### Desktop panels and the `dot` bus

Panels are small LED boards on the desktop, behind windows. Each sits on one workspace and slides
away with it. Drag one to move it; it snaps to the 12 px grid. They persist in
`~/.local/state/dotshell/panels.json`. Scripts and agents drive them through
`$XDG_RUNTIME_DIR/dotshell.sock` (one JSON object per line), or the `dot` CLI:

```bash
dot spawn sign --id rain --shape strip --at 28,6 --size 40x6 --text "RAIN CITY"
dot spawn note --shape circle --at 72,6 --size 30x26 --ws 2 --text "hello"
dot write rain "NEW TEXT";  dot move rain 30 8;  dot set rain --slot 2 --dot false
dot pixels vis < frame.rgb     # raw RGB at the panel's dot size (dot list shows it)
dot era;  dot era tokyo;  dot era next
dot display --pitch 5 --depth 16 --wall dots --hue wallpaper
dot list;  dot rm rain
```

If you have your own `~/.config/fontconfig/fonts.conf` that sets antialiasing for every font,
put the Departure Mono rule from `fontconfig/` at its end too: fontconfig applies edits in
load order, and that file loads after `conf.d`.

