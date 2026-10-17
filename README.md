# dotfiles

Arch Linux rice: Hyprland + the Quickshell "Dot Shell" (a dot-matrix LED shell, greeter and boot splash), Ghostty, Nautilus, mpv + Dot TV, mpd, zsh. Managed with GNU Stow, one module per top-level folder; `system/` holds the few files outside `~`.

> Mid re-rice. The plan (Hyprland + Quickshell + the dot-matrix "Dot Shell") lives in the
> *Arch Rice* doc, tab **Re-rice plan**. This README describes what is in the repo today.

## Install

```bash
git clone https://github.com/vardhin/dotfiles ~/dotfiles
cd ~/dotfiles
./install.sh            # pacman + AUR packages, oh-my-zsh + plugins, stow every module,
                        # enable mpd + mpd-mpris (user services), McMojave-circle icons
                        # (3 variants, from git), cursor + icon theme in gsettings
./install.sh --link     # only (re)link the modules (then reloads a running Hyprland)
./install.sh --dry-run  # show what stow would do
./install.sh --plugins  # build + load the Hyprland plugins (no hyprpm, no sudo): Hypr-DarkWindow, dynamic-cursors;
                        # rerun after a Hyprland update
sudo system/install.sh  # greeter (greetd) + boot splash (plymouth); see Login and boot
```

Files that would block a link are moved to `~/.dotfiles-backup/<timestamp>/` first.
Re-running is safe.

## Layout

```
dotfiles/
├── hypr/.config/hypr/          → ~/.config/hypr   (Lua config, Hyprland 0.55+)
│   ├── hyprland.lua            entry point: require()s each module below (errors stay per module)
│   ├── lua/
│   │   ├── defaults.lua        programs, the Dot Shell command (shared table D)
│   │   ├── environment.lua     env vars; cursor theme (DotShell once drawn, else Bibata)
│   │   ├── monitor.lua         outputs (scale 1)
│   │   ├── input.lua           keyboard, touchpad
│   │   ├── look.lua            zero chrome: one-dot gutter, focus by dim, blur, curves, animations
│   │   ├── rules.lua           window and layer rules
│   │   ├── binds.lua           every bind, each with a description (cheatsheet); zoom in plain Lua
│   │   ├── autostart.lua       session start: env, boot sound, plugins, Dot Shell, clipboard
│   │   └── dotshell.lua        plugins (Hypr-DarkWindow, dynamic-cursors) and dotshell.apply():
│   │                           window shading and frosted panes from Dot Shell's hypr.lua state
│   ├── shaders/dotled.glsl, dotglass.glsl   per-window LED shaders (Hypr-DarkWindow)
│   ├── scripts/screenshot.sh
│   └── sounds/boot.wav
├── hypr/.local/bin/hyprdo      one dispatch in whichever config language Hyprland runs
├── quickshell/.config/quickshell/dotshell/   → ~/.config/quickshell/dotshell
│   ├── shell.qml               entry point; IPC targets pane, strip, night, shell (tokens, screen, export, …)
│   ├── greeter.qml             the login screen (greetd), a second entry point; see Login and boot
│   ├── Tokens.qml / Eras.qml   the thirteen eras, the era cascade and every display token (pitch,
│   │                           dot size, depth, wall, wallpaper, hue, cascade, night, screen,
│   │                           winfx, winshade, scene, sounds, frosted); persisted
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
│   ├── data/                   symbols.tsv (the SYMBOLS page) and build-symbols.py
│   ├── services/               Notifs (the notification daemon), Audio, Brightness, Power
│   │                           (+ battery monitor), Net, Bt, Idle (+ logind bridge), Lock (PAM),
│   │                           ScreenShader, DropTerm, Notify, Panels (desktop panels, panels.json),
│   │                           DotBus (the `dot` socket), Export (era → Ghostty, Neovim, GTK, Qt, VSCode,
│   │                           Firefox, rmpc, cava, Dot TV's LED shader), Media (MPRIS + cava), Tv
│   │                           (Dot TV library, SCREEN settings), Sys (CPU, memory, temperature),
│   │                           Capture (screenshots, recording, color picker), Clip (clipboard history),
│   │                           Hypr (every call into Hyprland, Lua or hyprlang), Sound (era UI sounds),
│   │                           Wall + WallCtx.js (the P10 wall: sources, software canvas, sender)
│   ├── panes/                  Launcher, Messages, ToastStack, Osd, Session, Cheatsheet,
│   │                           Calendar, Audio, Brightness, Wifi, Bluetooth, Battery, Eras,
│   │                           Packages, Media (NOW / TV / LISTS / SCREEN), Capture, Clip
│   │                           (CLIP / SYMBOLS), SideBar,
│   │                           WindowBorders (LED rings), LockScreen, Polkit,
│   │                           Wallpaper (dots/image/off, parallax), World
│   │                           (desktop panels; slides with workspaces), WindowFx (window
│   │                           open/close as LED dots), Scene + Scenes.js (the era scenes),
│   │                           Overview (the switchboard)
│   ├── pam/dotshell            PAM stack for the lock screen (pam_unix only)
│   ├── shaders/                dot.frag(.qsb) for DotSurface, winfx.frag(.qsb) for WindowFx,
│   │                           art.frag(.qsb) for DitherArt, wall.frag(.qsb) the screen look
│   │                           on the wallpaper; screen.glsl, night warmth for Hyprland's
│   │                           screen shader (GLSL ES 3.00)
│   ├── build-shaders.sh        recompile .qsb after editing a .frag (qt6-shadertools)
│   └── (../../.local/bin/dot, dotws, dotcursor, dotsound, dotwall, dotanime)  the `dot` CLI,
│                               `dotws` (workspace switches through the shell), the cursor and
│                               sound makers, the wall sender, anime through ani-cli; linked to
│                               ~/.local/bin
├── mpv/.config/mpv/            → ~/.config/mpv  mpv.conf; scripts/dottv.lua (Dot TV: titles, play
│                               counts, Endless Mix, L); shaders/dotled.glsl (LED video)
├── mpv/.local/bin/dottv        Dot TV, the YouTube library CLI (+ dottv.desktop)
├── mpd/.config/mpd/            → ~/.config/mpd  ~/Music over PipeWire (+ rmpc.desktop)
├── mpd/.config/rmpc/config.ron → ~/.config/rmpc  rmpc defaults + the era theme Dot Shell writes
├── cava/.config/cava/config    → ~/.config/cava  terminal cava (pipewire, true color, era theme)
├── ghostty/.config/ghostty/    → ~/.config/ghostty  (Departure Mono pixel font, no chrome; era
│                               colors from the generated dotshell.conf, gitignored)
├── fontconfig/.config/fontconfig/conf.d/   Departure Mono without antialiasing (hard pixels)
├── zsh/.zshrc                  → ~/.zshrc  (oh-my-zsh, powerlevel10k, eza, zoxide)
├── p10/                        the P10 wall's receiver, for the Raspberry Pi (not stowed):
│                               dotwall-pi.py, dotwall.service
├── system/                     outside ~, installed by `sudo system/install.sh`
│   ├── greetd/                 config.toml, hyprland.lua (the greeter's bare Hyprland)
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
| Panes | `dotshell ipc call pane toggle <launcher\|session\|notifs\|cheatsheet\|calendar\|audio\|brightness\|wifi\|bluetooth\|battery\|capture\|clip>`; strip words open them too |
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
                                           # nixie flap nightvision vapor arcade blueprint
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
dotshell ipc call tokens set winshade all  # off | dim | all: windows on the dot grid (plugin)
dotshell ipc call tokens set scene false   # the era's scene after three minutes idle
dotshell ipc call tokens set sounds full   # off | soft | full: the era's UI sounds
dotshell ipc call tokens set frosted true  # panes as LEDs on blurred glass
dotshell ipc call strip toggle
```

Binds: `Super D` toggles the strip, `Super Shift D` cycles eras, `Super T` opens the era switcher,
`Super Shift T` toggles full LED,
`Super W` the wallpapers, `Super F` files, `Super I` the package manager (pacman + yay), `Super Tab`
the switchboard, `Super Shift S` the era's scene, `Super Shift W` cycles window shading, `Super Ctrl D`
restarts the shell.

### Hyprland in Lua

The config is `hypr/.config/hypr/hyprland.lua` (Hyprland 0.55 reads it before `hyprland.conf`;
hyprlang is deprecated). Under Lua, `hyprctl keyword` is refused and `hyprctl dispatch X` means
`hl.dispatch(X)`, so nothing here sends the old strings: Dot Shell goes through `services/Hypr.qml`,
which asks `hyprctl -j status` for the config provider and speaks Lua (`hl.dsp.*`,
`hyprctl eval 'hl.config(...)'`) or hyprlang accordingly, and scripts use `hyprdo` the same way.
To go back to hyprlang, check out `hypr/` from before `ea37562`; the shell follows on its own.

| Thing | How |
|---|---|
| Window shading | `winshade` token (`Super Shift W`): **dim** draws every unfocused window as LED dots in the era ramp, fading in as it loses focus (`shaders/dotled.glsl`); **all** adds a faint dot mask on the focused one (`dotglass.glsl`); **off**. Needs Hypr-DarkWindow (`./install.sh --plugins`); without it unfocused windows are dimmed as before |
| Frosted panes | `frosted` token: the glass between a pane's dots turns translucent and Hyprland blurs the layers behind (`dotshell-<pane>`) |
| Cursor | `dotcursor` draws a pixel cursor theme in the era (15 cursors, LED dots with a rim, animated busy chasers) as one theme for hyprcursor and XCursor, `~/.local/share/icons/DotShell`; Export redraws it on era changes and sets it live. dynamic-cursors stretches it with speed and magnifies it when shaken, nearest-neighbour |
| State | Export writes `~/.local/state/dotshell/hypr.lua` (era ramp, grid, winshade, frosted) and runs `dotshell.apply()` in Hyprland's Lua |

### Capture and clipboard

| Key | |
|---|---|
| `Super Shift P` / `Super Shift Print` | **CAPTURE** pane. SHOT: area, screen, window, edit (swappy), delay 5. REC: region, full, sound on/off (gpu-screen-recorder, 60 fps, default output audio). PICK: color (hyprpicker, hex to the clipboard). Arrows + Enter, or the underlined letter |
| `Super Alt P` | record the focused monitor; again stops. While recording the strip shows a blinking `REC 0:12` (click it to stop) |
| `Super Alt C` | color picker |
| `Print`, `Super Print`, `Super P` | screenshot full screen / area (straight to `hypr/scripts/screenshot.sh`) |
| `Super V` | **CLIP** pane: clipboard history, newest first. Type to filter, Enter pastes into the window you came from (Ctrl Shift V in terminals), Ctrl Enter only copies, Ctrl D forgets |
| `Super .` | the same pane's **SYMBOLS** page: emoji, arrows, math, currency, box drawing, by name (`data/symbols.tsv`, built by `data/build-symbols.py`) |

Screenshots go to `~/Pictures/Screenshots`, recordings to `~/Videos/Recordings`. SCREEN and FULL
take the focused monitor. The history is text only, kept in `~/.local/state/dotshell/clipboard.json`
(100 entries); copies a password manager marks secret are never recorded. `dotshell ipc call clip clear`
empties it (`clip forget "text"` drops one entry); `dotshell ipc call capture rec|stop|shot|pick` drive capture from scripts.

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
| Nixie | `nixie` | cold-cathode orange, mono, heavy glow |
| Split-Flap | `flap` | airport board: white and yellow on black flaps, square dots |
| Night Vision | `nightvision` | Gen III P43 green, mono |
| Vaporwave | `vapor` | pink, cyan and lavender at dusk |
| Arcade | `arcade` | RGB332 cabinet primaries, square dots |
| Blueprint | `blueprint` | white lines on drafting blue |

`Super T` (or the brush on the side rail) shows every era as a card in its own colors. **ERAS** page: arrows or j/k move, Enter
applies, 1–9 pick directly. Tab goes to **DISPLAY**: pitch, dot size, depth, wall, hue, cascade, screen, windows, win shade,
workspaces, borders, bars, idle scene, sounds, pane glass;
Up/Down pick a row, Left/Right change it. Tab again: **WALLS** (`Super W`, or the picture on the side rail):
every image under `~/wallpaper` and `~/wallpapers` as a thumbnail in dots, the WALL mode on top; arrows
move, Enter sets it, R picks one at random. At coarse pitches the pane narrows and scrolls so it
always fits under the strip.

An era change flips every dot over in a wave from the top left, like a flip-disc board (the
`cascade` token; off = instant). The windows of the apps that recolor live (Ghostty, VSCode,
Firefox, Files, Dot TV: the `live` list in `services/Export.qml`) flip with it: each turns into
flip dots that go over to the new era's blank board (`hypr/.config/hypr/shaders/dotflip.glsl`),
holds while the export runs and the app swaps its colors, then turns back over in the new era, so
no app is seen changing colors. Needs Hypr-DarkWindow; another live app joins with one line in
`live`.

With `hue` set to `wallpaper`, matugen (`extra/matugen`) picks the wallpaper's source color and
every era is rotated onto that hue. Only the hue moves: the era's levels, glow and dot shape stay.

The era on screen is also exported to the apps around the shell, on every change:

| App | File | |
|---|---|---|
| Ghostty | `~/.config/ghostty/dotshell.conf` | included by the repo config, reloaded live (SIGUSR2) |
| Neovim | `~/.local/share/nvim/site/colors/dotshell.lua` | `:colorscheme dotshell`; running nvims that use it reload |
| GTK 3 | `~/.local/share/themes/DotShell/` | a theme of era colors over the one you had (remembered in `~/.local/state/dotshell/gtk-base`); every era swaps `gtk-theme` between `DotShell` and `DotShell-B` (a link), which makes running GTK 3 apps, Firefox included, reload it. GTK never rereads `gtk.css` in a running app, so `~/.config/gtk-3.0/gtk.css` is kept empty while ours. Also sets the dark/light `color-scheme` |
| GTK 4 | `~/.config/gtk-4.0/gtk.css` | libadwaita named colors and variables; only written when missing or ours (first line says `dotshell:`). libadwaita reads it at start only and nothing else outranks its colors, so Files is restarted under the theme flip by `dotreopen`: each window back at its folder and workspace (first tab only), skipped while a copy or move runs |
| Qt | `~/.config/qt6ct/colors/dotshell.conf` | pick it once in qt6ct |
| Greeter | `/var/lib/dotshell-greeter/dotshell/` | `tokens.json`, the wallpaper and the user name, once `system/install.sh` has made the folder yours |
| Firefox | `<profile>/chrome/userChrome.css`, `userContent.css` | every install's default profile; the pixel font (22 px, `--dot-font-size`), square corners, a lit outline on the selected tab, no titlebar buttons; new tab and `about:` pages in the era. The chrome's colors are GTK system colors (from the DotShell theme), so it follows an era live; `userContent.css` (new tab, `about:` pages) is read at start. Guarded like GTK. A `dotshell:begin … end` block in `user.js` turns userChrome on |
| VSCode | `~/.config/{Code,Code - OSS,VSCodium,Cursor}/User/settings.json` | workbench, terminal and syntax colors over the built-in Modern theme, merged into your settings (kept as they are; left alone if the file has comments or colors not set by Dot Shell). Live |
| rmpc | `~/.config/rmpc/themes/dotshell.ron` | picked by the repo's `config.ron`; hot-reloaded |
| cava | `~/.config/cava/themes/dotshell` | picked by the repo's `cava/.config/cava/config`; running cavas reload on SIGUSR2 |

| Hyprland | `~/.local/state/dotshell/hypr.lua` | window shading and frosted panes; `dotshell.apply()` runs right after |
| Cursor | `~/.local/share/icons/DotShell` | drawn by `dotcursor`; `hyprctl setcursor` and gsettings |
| Sounds | `~/.local/state/dotshell/sounds/<era>/` | synthesized by `dotsound`, played by `services/Sound.qml` |

`dotshell ipc call export run` rewrites them by hand.

### Scenes, sounds and the switchboard

**Scenes.** After three minutes idle (before the dim at five; not while a video plays) the whole screen becomes the era's dot board
and plays its piece (`panes/Scenes.js`, drawn at one pixel per dot): a terminal typing (Phosphor), rain
over the skyline (Tokyo), the sun setting on the neon grid (90s), glyph rain (Matrix), a car-stereo
clock and spectrum (VFD), bubbles (Aero), Life (Game Boy), the time in tubes (Nixie), a departure
board (Flap), a radar (Night Vision), a turning pyramid (Vapor), invaders (Arcade), a spirograph being
drafted (Blueprint). Any key or a real mouse move ends it; `Super Shift S` plays it now; the `scene`
token turns the idle trigger off.

**Sounds.** `dotsound` synthesizes the era's UI sounds (a voice per era: relay clicks, glass chimes,
pulse-wave blips, flap clacks...) for ten events: pane open and close, window open and close,
toast, alert, the era cascade, workspace switch, screenshot, recording. `sounds` token: off, soft, full (`pw-play`).

**Switchboard.** `Super Tab`: every workspace as a small LED screen, its windows captured (hidden
workspaces too) and dithered onto the era ramp. Arrows move, Enter goes, Shift Enter takes the
focused window along, 1–9 jump; the switch still dissolves.

### The P10 wall

A real LED board, 2x2 P10 RGB panels (64x32) on a Raspberry Pi 5, shows a piece of the shell. Dot
Shell renders every frame itself at the wall's size (`services/WallCtx.js`, a software canvas with a
5x7 LED font) and `dotwall feed` sends it over UDP; on the Pi, `p10/dotwall-pi.py` only puts pixels on
the panels (hzeller rpi-rgb-led-matrix, Adafruit's Pi 5 piomatter, or a terminal preview).

```bash
# on the Pi
sudo install -Dm755 p10/dotwall-pi.py /usr/local/bin/dotwall-pi
sudo install -Dm644 p10/dotwall.service /etc/systemd/system/dotwall.service
sudo systemctl enable --now dotwall        # panel options on ExecStart: dotwall-pi --help
# on the laptop
dot wall on 192.168.1.40 --source clock    # scene | clock | media | text | pixels
dot wall text "OPEN 24 HRS";  dot wall source scene;  dot wall off
dotwall test 192.168.1.40                  # color bars, no shell needed
```

### Login and boot

`sudo system/install.sh` sets up both; `greetd` or `plymouth` as an argument does one.

**Greeter.** greetd runs a bare Hyprland (`/etc/greetd/hyprland.lua`) whose one job is
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
| `Super M` | MEDIA pane, **NOW**: the art as it is (or Dot TV's video, playing right in the pane), title, artist, seek bar, transport, spectrum (cava, only while shown and playing), Dot TV's up-next. Space, ← →, N/P, S |
| `Super Shift M` | MEDIA pane, **TV** page: the Dot TV library, most played first. Type to filter, `Ctrl S` searches YouTube. Enter plays, `Ctrl Q` queues, `Ctrl E` plays next, `Ctrl L` adds to the target list, `Ctrl D` deletes (twice), `Ctrl M` Endless Mix, `Ctrl G` saves a search result |
| **ANIME** page | anime through ani-cli, as shelves of covers: **SEARCH** (type, Enter), **FEATURED** (trending on AniList), **CATEGORIES** (pick one for a shelf of its most popular), **LIKED**, **WATCHLIST**, **DOWNLOADS**. A shelf folds on its header (`Ctrl X`); empty ones fold themselves and the open ones share the height. **AUDIO SUB DUB** by the field: the framed one is in use. The download button (or `Ctrl Q`) opens the queue: what downloads now with its bar, what waits (DROP), what failed (RETRY), what is saved. Enter on a cover opens the show: WATCHED / SAVED / PLAYER lines say where it stands, a bar runs while it downloads, and a failure says what happened with fixes to click (try dub, other match, retry). A click picks an episode, a double click (or Enter) plays it; under the legend, saved episodes are underlined, queued ones faintly, watched ones dim. `G` gets one, `A` all, from-where-you-left-off with **FROM EP n**, **KEEP NEXT 3 SAVED** prefetches, `S` (WRONG? NEXT) tries ani-cli's next match |
| **LISTS** page | playlists, then the YouTube Music stations (♪, read-only): Enter plays, `Ctrl R` shuffles, `Ctrl T` sets the target list, `Ctrl O` makes a list from the typed name. **SYNC** (or `Ctrl Y`) fetches new songs and stations |
| **SCREEN** page | the video's dot matrix, with a live preview: pitch (2–16 px), dot size, shape (era, round, square, bubble), color (era ramp, mono, 8 bit, 16 bit, full, raw), glow, dither. Saved in `~/.local/state/dotshell/tv.json` |
| Panels | `media` (now-playing board, click to play/pause), `vis` (spectrum), `mpris` (title, art) |
| `Super Ctrl M` | the Dot TV window (mpv, same dot matrix as the pane) |

**Dot TV** is the old AGS Media Center, rebuilt as a standalone app: mpv plays, `dottv` keeps the
library. mpv runs without a window (sound, queue, Endless Mix, MPRIS); the MEDIA pane plays the
saved file itself, muted, as LED dots, kept in time with mpv. `dottv open` gives mpv a window too. The library stays in `~/Video/TV` in the Media Center's own format (`<id>-480.mp4`,
`video-meta.json`, `playlists.json`, `play-counts.json`), plus `thumbs/`.

**YouTube Music** comes from [ytmusic-helper](~/Documents/git/ytmusic-helper) (`sync_ytmusic.py`),
linked at `~/Music/ytmusic` (or `$DOTTV_MUSIC`). Its `.music-cache/<id>.mp3` join the library as
songs (♪), keyed by the same YouTube id, so play counts, lists and Endless Mix take them too; its
`stations/*/station.json` become read-only lists. `dottv sync` runs the sync in the background
(log in `~/.local/state/dotshell/ytmusic-sync.log`) and notifies when done.

**Anime** goes through [ani-cli](https://github.com/pystardust/ani-cli) (AUR), driven by `dotanime`:
AniList gives the covers, trending shows and categories; ani-cli finds the show on its source and
plays it in mpv (so NOW shows it, with the cover). `dotanime` answers ani-cli's menus itself (it is
linked as a `rofi` first on its PATH), so nothing pops up. Episodes download one at a time to
`~/Video/Anime/<title>/` (`$DOTANIME_DIR`, at `$DOTANIME_QUALITY`, 720 by default); **PREFETCH**
keeps the next 3 (`$DOTANIME_PREFETCH`) saved as you watch. Likes, the watchlist and where you left
off are in `~/.local/state/dotshell/anime.json`; covers in `~/.cache/dotanime`.

```bash
dotanime search frieren        # JSON; also featured, genres, genre NAME, info ID
dotanime get 154587 1-4        # download episodes; cancel ID, rm ID EP|all
dotanime play 154587 5         # streams, or plays the saved file
```

```bash
ln -s ~/Documents/git/ytmusic-helper ~/Music/ytmusic   # once
dottv sync                     # or --here to wait and watch
dottv music                    # reindex; fill in missing titles, durations, art
```

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

