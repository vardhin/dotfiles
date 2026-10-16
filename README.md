# dotfiles

Arch Linux rice: Hyprland + the Quickshell "Dot Shell" (a dot-matrix LED shell, greeter and boot splash), Ghostty, Nautilus, mpv + Dot TV, mpd, zsh. Managed with GNU Stow, one module per top-level folder; `system/` holds the few files outside `~`.

> Mid re-rice. The plan (Hyprland + Quickshell + the dot-matrix "Dot Shell") lives in the
> *Arch Rice* doc, tab **Re-rice plan**. This README describes what is in the repo today.

## Install

```bash
git clone https://github.com/vardhin/dotfiles ~/dotfiles
cd ~/dotfiles
./install.sh            # pacman + AUR packages, oh-my-zsh + plugins, stow every module,
                        # enable mpd + mpd-mpris (user services)
./install.sh --link     # only (re)link the modules
./install.sh --dry-run  # show what stow would do
sudo system/install.sh  # greeter (greetd) + boot splash (plymouth); see Login and boot
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
│   ├── shell.qml               entry point; IPC targets pane, strip, night, shell (tokens, screen, export, …)
│   ├── greeter.qml             the login screen (greetd), a second entry point; see Login and boot
│   ├── Tokens.qml / Eras.qml   the seven eras, the era cascade and every display token (pitch,
│   │                           dot size, depth, wall, wallpaper, hue, cascade, night, screen,
│   │                           winfx); persisted
│   │                           in ~/.local/state/dotshell/tokens.json (IPC target: tokens)
│   ├── Ui.qml                  which pane is open, on which screen
│   ├── DotSurface.qml          low-res QML canvas → LED dots (shaders/dot.frag); optional shape cut
│   ├── DeskPanel.qml, Shapes.js  one desktop panel (clock sign note image mpris pixels) and its outlines
│   ├── Pane.qml                a floating LED pane (layer-shell window + DotSurface)
│   ├── DitherArt.qml, Spectrum.qml  album art in era colors (ordered dither); cava VU bars
│   ├── Scroller.qml, TvScreen.qml   looping LED text; Dot TV's video as dots (tvled.frag)
│   ├── TopStrip.qml            workspaces | clock / ticker | status words, tray
│   ├── DotText DotLabel DotButton DotInput VuBar Marquee FlapText Frame Rule Line StatusWord
│   │   RailButton RailMeter    (the side rail's glyph buttons and vertical meters)
│   ├── services/               Notifs (the notification daemon), Audio, Brightness, Power
│   │                           (+ battery monitor), Net, Bt, Idle (+ logind bridge), Lock (PAM),
│   │                           ScreenShader, DropTerm, Notify, Panels (desktop panels, panels.json),
│   │                           DotBus (the `dot` socket), Export (era → Ghostty, Neovim, GTK, Qt,
│   │                           Dot TV's LED shader), Media (MPRIS + cava), Tv (Dot TV library,
│   │                           SCREEN settings), Sys (CPU, memory, temperature)
│   ├── panes/                  Launcher, Messages, ToastStack, Osd, Session, Cheatsheet,
│   │                           Calendar, Audio, Brightness, Wifi, Bluetooth, Battery, Eras,
│   │                           Packages, Media (NOW / TV / LISTS / SCREEN), SideBar,
│   │                           WindowBorders (LED rings), LockScreen, Polkit,
│   │                           Wallpaper (dots/image/off, parallax), World
│   │                           (desktop panels; slides with workspaces), WindowFx (window
│   │                           open/close as LED dots)
│   ├── pam/dotshell            PAM stack for the lock screen (pam_unix only)
│   ├── shaders/                dot.frag(.qsb) for DotSurface, winfx.frag(.qsb) for WindowFx,
│   │                           art.frag(.qsb) for DitherArt, wall.frag(.qsb) the screen look
│   │                           on the wallpaper; screen.glsl, night warmth for Hyprland's
│   │                           screen shader (GLSL ES 3.00)
│   ├── build-shaders.sh        recompile .qsb after editing a .frag (qt6-shadertools)
│   └── (../../.local/bin/dot, dotws)  the `dot` CLI, and `dotws` (workspace switches
│                               through the shell), linked to ~/.local/bin
├── mpv/.config/mpv/            → ~/.config/mpv  mpv.conf; scripts/dottv.lua (Dot TV: titles, play
│                               counts, Endless Mix, L); shaders/dotled.glsl (LED video)
├── mpv/.local/bin/dottv        Dot TV, the YouTube library CLI (+ dottv.desktop)
├── mpd/.config/mpd/            → ~/.config/mpd  ~/Music over PipeWire (+ rmpc.desktop)
├── ghostty/.config/ghostty/    → ~/.config/ghostty  (Departure Mono pixel font, no chrome; era
│                               colors from the generated dotshell.conf, gitignored)
├── fontconfig/.config/fontconfig/conf.d/   Departure Mono without antialiasing (hard pixels)
├── zsh/.zshrc                  → ~/.zshrc  (oh-my-zsh, powerlevel10k, eza, zoxide)
├── system/                     outside ~, installed by `sudo system/install.sh`
│   ├── greetd/                 config.toml, hyprland.conf (the greeter's bare Hyprland)
│   ├── plymouth/dotshell/      the boot splash: script theme + build.py (images in era colors)
│   └── install.sh
├── packages.txt                pacman packages
├── packages-aur.txt            AUR packages
└── install.sh
```

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

It replaces, one for one: AGS (bar, popovers, launcher, notifications, OSD, session menu,
media center), hyprlock, hypridle, polkit-gnome, awww and hyprsunset.

| Thing | How |
|---|---|
| Panes | `dotshell ipc call pane toggle <launcher\|session\|notifs\|cheatsheet\|calendar\|audio\|brightness\|wifi\|bluetooth\|battery>`; strip words open them too |
| Notifications | Dot Shell is the daemon. New ones scroll across the strip and pop top right; `Super N` lists live ones and the log (`~/.local/state/dotshell/notifications.json`); `Super Shift N` is do-not-disturb |
| Launcher | `Alt Space`: departure board. Type, arrows or Ctrl J/K, Enter; Ctrl 1–8 jumps to a gate. Launch counts rank results |
| Lock | `Super L` (`loginctl lock-session`), idle, the session menu and suspend all lock through logind. PAM stack: `pam/dotshell` |
| Idle | dim 5 min, lock 7.5 min, screen off 7.75 min. Caffeine (`Super Shift C`, or the brightness pane) holds all three |
| Screen look | The `screen` token, drawn over the wallpaper only (`panes/Wallpaper.qml`, `shaders/wall.frag`); windows stay untouched. **glass**: faint dot mask on the shell's grid, phosphor tint, vignette. **LED** (`Super Shift T`, `dotshell ipc call screen toggle`): the wallpaper as dots in the era's colors (or the color depth). **board**: one color per dot, a true LED board. **off** |
| Night warmth | `Super Shift H` or `dotshell ipc call night toggle`: Hyprland's `screen_shader` (`shaders/screen.glsl`, written by Dot Shell), over windows too; persisted in tokens |
| Window effects | Windows open with a raster sweep of dots and close by collapsing to a line, drawn by Dot Shell on a click-through overlay (Hyprland has no per-window shaders); Hyprland's own window animation is cut to a fade. `winfx` token |
| Workspace switch | The old workspace dissolves into LED dots, flipping over in a wave toward where you are going, onto the new one. Adaptive: a switch soon after the last plays faster (650 ms down to 200 ms), and one mid-dissolve carries on from what is on screen. The snapshot is taken before Hyprland moves, so the workspace binds, the strip and the side bar switch through the shell (`dotws go 3`, `dotws move 3`, over the `dot` socket); Hyprland's own workspace animation is off while it is on. `wsfx` token (`false`: Hyprland's slide) |
| Wallpaper | `dotshell ipc call tokens set wallpaper ~/wallpaper/x.jpg`; `wall` picks how it shows: `dots` (drawn by the matrix), `image` (plain, parallax), `off` (unlit glass) |
| Battery monitor | toasts on plug/unplug, at 15 % and 10 %; at 5 % a 60 s grace, then poweroff |
| Shortcuts | `Super /`: read live from `hyprctl -j binds`, described by the `bindd` descriptions |
| Media | `Super M`, or the now-playing word on the strip (middle click plays/pauses, wheel skips). See [Media](#media) |
| Bars | top strip (workspaces, `+` for a new one, window title, clock, now playing, status); side rail on the right edge, 13 dots wide, holding only what the strip does not: launcher and files at the top, CPU / memory / temperature meters and the media transport in the middle, era switcher, wallpapers and session menu at the bottom. `Super T` → DISPLAY: TOP BAR, TITLE, SIDE BAR (off, on, auto: hidden until the pointer touches the right edge) |
| Files | `Super F`, or the folder on the side rail: Nautilus, the default for folders. libadwaita, so it takes the era colors from `gtk-4.0/gtk.css` whatever the GTK theme is |
| LED borders | a one-dot LED ring around every pane, desktop panel and window (lit for the focused window); windows get one-dot gaps for it. `borders` token |
| Border FX | the LED rings animate: a random one of comet, twins, flow, breathe, marquee, sparkle, scanner or wipe, new on every window or workspace switch (bright on the focused window, dim on the rest). While music plays they react to it instead (cava): spectrum around the ring, bass pulse, a rider whose speed follows the loudness, treble fizz, corner VU meters, all flashing on beats. `ledfx` token: `auto`, `random` (never music), `music`, `off` (still rings); `dotshell ipc call ledfx next` / `mode comet` |

```bash
dotshell ipc call tokens set era tokyo     # phosphor tokyo nineties matrix vfd aero gameboy
dotshell ipc call tokens set pitch 5       # 3 | 5 | 8 | 12 px per dot
dotshell ipc call tokens set dotSize 70    # 40–100 % of pitch
dotshell ipc call tokens set depth 16      # era | 8 | 16 | 24
dotshell ipc call tokens set wall dots     # dots | image | off
dotshell ipc call tokens set hue wallpaper # era | wallpaper (matugen picks the hue)
dotshell ipc call tokens set cascade false # true: era changes flip over in a wave
dotshell ipc call tokens set screen led    # glass | led | board | off
dotshell ipc call tokens set winfx false   # window open/close as dots
dotshell ipc call tokens set wsfx false    # workspace switches dissolve into dots
dotshell ipc call tokens set borders false # LED rings around panes, panels, windows
dotshell ipc call tokens set ledfx random  # border animations: auto | random | music | off
dotshell ipc call tokens set side auto     # off | on | auto (right side bar)
dotshell ipc call tokens set title false   # window title on the strip
dotshell ipc call strip toggle
```

Binds: `Super D` toggles the strip, `Super Shift D` cycles eras, `Super T` opens the era switcher,
`Super Shift T` toggles full LED,
`Super W` the wallpapers, `Super F` files, `Super I` the package manager (pacman + yay), `Super Ctrl D`
restarts the shell.

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

`Super T` (or the brush on the side rail) shows every era as a card in its own colors. **ERAS** page: arrows or j/k move, Enter
applies, 1–7 pick directly. Tab goes to **DISPLAY**: pitch, dot size, depth, wall, hue, cascade, screen, windows, workspaces;
Up/Down pick a row, Left/Right change it. Tab again: **WALLS** (`Super W`, or the picture on the side rail):
every image under `~/wallpaper` and `~/wallpapers` as a thumbnail in dots, the WALL mode on top; arrows
move, Enter sets it, R picks one at random. At coarse pitches the pane narrows and scrolls so it
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
| Greeter | `/var/lib/dotshell-greeter/dotshell/` | `tokens.json`, the wallpaper and the user name, once `system/install.sh` has made the folder yours |

`dotshell ipc call export run` rewrites them by hand.

### Login and boot

`sudo system/install.sh` sets up both; `greetd` or `plymouth` as an argument does one.

**Greeter.** greetd runs a bare Hyprland (`/etc/greetd/hyprland.conf`) whose one job is
`greeter.qml`: the lock screen's look, in the era and wallpaper you last used. Type the password,
Enter logs in and starts `start-hyprland`; Tab edits the user name, F11 reboots, F12 powers off.
The greeter user cannot read `~`, so the installer copies Dot Shell to `/usr/local/share/dotshell`
(rerun `sudo system/install.sh greetd` after changing `greeter.qml` or what it uses) and Export keeps
the colors in `/var/lib/dotshell-greeter/dotshell`. greetd is enabled for the next boot, not started:
it takes tty1, which would end a session logged in there. If the greeter ever fails, Ctrl Alt F2 gives
a text login.

**Splash.** A Plymouth script theme: the DOT SHELL sign as a dot board, a lit dot running under it.
`build.py` draws it in the era on screen at install time (from the Ghostty export); rerun
`sudo system/install.sh plymouth` to repaint it after an era change. The installer adds the `plymouth`
hook, `quiet splash` to `/etc/kernel/cmdline` (unified kernel images), and rebuilds with `mkinitcpio -P`;
edited files keep a `*.dotshell-bak` copy.

### Desktop panels and the `dot` bus

Panels are small LED boards on the desktop, behind windows. Each sits on one workspace and slides
away with it. Drag one to move it; it snaps to the 12 px grid. They persist in
`~/.local/state/dotshell/panels.json`. Scripts and agents drive them through
`$XDG_RUNTIME_DIR/dotshell.sock` (one JSON object per line), or the `dot` CLI:

```bash
dot spawn sign --id rain --shape strip --at 28,6 --size 40x6 --text "RAIN CITY"
dot spawn note --shape circle --at 72,6 --size 30x26 --ws 2 --text "hello"
dot spawn media --at 60,4 --size 48x14     # now playing: art, title, progress, spectrum
dot spawn vis --shape strip --at 60,20 --size 48x8   # spectrum analyser
dot write rain "NEW TEXT";  dot move rain 30 8;  dot set rain --slot 2 --dot false
dot pixels vis < frame.rgb     # raw RGB at the panel's dot size (dot list shows it)
dot era;  dot era tokyo;  dot era next
dot display --pitch 5 --depth 16 --wall dots --hue wallpaper
dot list;  dot rm rain
```

### Media

Players play, the shell renders. Anything on MPRIS shows up: mpv (mpv-mpris), mpd (mpd-mpris),
browsers. Dot Shell follows the player that is playing (or the last one that did); `S` in the pane
pins another. The media keys go to that same player (`dotshell ipc call media toggle|next|previous`).

| Where | What |
|---|---|
| Strip | focused window's title after the workspaces; now-playing word on the right |
| `Super M` | MEDIA pane, **NOW**: art dithered into the era's colors (or Dot TV's video, playing right in the pane), title, artist, seek bar, transport, spectrum (cava, only while shown and playing), Dot TV's up-next. Space, ← →, N/P, S |
| `Super Shift M` | MEDIA pane, **TV** page: the Dot TV library, most played first. Type to filter, `Ctrl S` searches YouTube. Enter plays, `Ctrl Q` queues, `Ctrl E` plays next, `Ctrl L` adds to the target list, `Ctrl D` deletes (twice), `Ctrl M` Endless Mix, `Ctrl G` saves a search result |
| **LISTS** page | playlists: Enter plays, `Ctrl R` shuffles, `Ctrl T` sets the target list, `Ctrl O` makes a list from the typed name |
| **SCREEN** page | the video's dot matrix, with a live preview: pitch (2–16 px), dot size, shape (era, round, square, bubble), color (era ramp, mono, 8 bit, 16 bit, full, raw), glow, dither. Saved in `~/.local/state/dotshell/tv.json` |
| Panels | `media` (now-playing board, click to play/pause), `vis` (spectrum), `mpris` (title, dithered art) |
| `Super Ctrl M` | the Dot TV window (mpv, same dot matrix as the pane) |

**Dot TV** is the old AGS Media Center, rebuilt as a standalone app: mpv plays, `dottv` keeps the
library. mpv runs without a window (sound, queue, Endless Mix, MPRIS); the MEDIA pane plays the
saved file itself, muted, as LED dots, kept in time with mpv. `dottv open` gives mpv a window too. The library stays in `~/Video/TV` in the Media Center's own format (`<id>-480.mp4`,
`video-meta.json`, `playlists.json`, `play-counts.json`), plus `thumbs/`.

```bash
dottv search daft punk         # YouTube, via yt-dlp
dottv play K0HSD_i2DvA         # not saved yet: streams now, saves in the background
dottv play <id> --queue        # or --next
dottv mix on                   # Endless Mix: the library shuffled, never stops
dottv list play anime --shuffle
dottv led                      # LED dot shader on the video (L in the window)
dottv lib; dottv queue; dottv rm <id>; dottv thumbs
```

The pane draws the video with `shaders/tvled.frag`, the Dot TV window with
`mpv/.config/mpv/shaders/dotled.glsl`: the same math, the same SCREEN settings. Dot Shell rewrites
the window's settings and era colors on every change (`~/.local/state/dotshell/mpv-led.conf`) and
pushes them to a running Dot TV.

Music: mpd serves `~/Music` (`mpd/.config/mpd/mpd.conf`, state in `~/.local/state/mpd`); `rmpc` in
the launcher opens it in Ghostty.

If you have your own `~/.config/fontconfig/fonts.conf` that sets antialiasing for every font,
put the Departure Mono rule from `fontconfig/` at its end too: fontconfig applies edits in
load order, and that file loads after `conf.d`.

