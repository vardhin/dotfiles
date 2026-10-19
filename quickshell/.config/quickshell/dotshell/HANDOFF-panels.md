# Handoff: era hardware for panels (media first), then the panel manager

Written 2026-10-18 for the next Claude Code chat. Read all of it before touching a file.

## Ground rules (from the user)

- **Dot Shell hot-reloads on every save.** The user is looking at it live. Every save must leave a working shell. See "The mistake" below.
- When you need the user, send a short `notify-send "Claude" "<one line>"` and **then stop and end the turn**. Don't keep working; they come back with what you asked for.
- Never take screenshots yourself (no grim, no opening panes over IPC to look). Ask the user for screenshots.
- Get one panel looking right in every era before starting on the next panel. The user called the earlier generic boards "garbage slop".
- Check the live log after each save: `timeout 5 qs log -p ~/.config/quickshell/dotshell 2>&1 | grep -vE "socket|textinput|font.db" | tail`. You want "Configuration Loaded" with no `caused by`. The `PanelNode.qml[540]` and `DeskPanel.qml[51]` errors further up are old.

## The mistake that skeletonized the VFD media panel

The VFD media panel was finished and looked right. I then rewrote the shared device table `Hardware.js` into a new format: `bezel` changed from a number to `{l,t,r,b}`, and the keys' flat color fields moved under `keys.style`/`items`. I also rewrote `Faceplate.qml`/`WindowGlass.qml` against that format. I did this *before* moving the files that read it: `MediaVfd.qml`, `Pane.qml`, `TransportKeys.qml`, `RubberKey.qml`.

Each save hot-reloaded into the running shell. The old readers got `NaN` geometry and `undefined` colors, and the panel the user was looking at turned into a bare skeleton.

**Rule:** to change a shared table, either add the new fields next to the old ones, or update the readers in the same step, or build the new version under new names and switch over last. Never save the table first and the readers "later".

The second bug was in `DeviceKey.qml`. Keys got their colors from functions (`function top(): color { ... }` called from bindings), and those calls returned white or black. So every gradient key rendered flat black, and the d-pad rendered white. The fix was plain `readonly property color topColor: ...` bindings. **Don't compute colors in functions called from bindings in these components; use properties.**

## Design source

The design canvas is https://claude.ai/artifact/SwsyBjuo92uGFwUFajiHG8 (a Design-type artifact, "Dot Shell home panels"). Read it with the Artifact tool: `action: read`, `paths: [...]`. Don't use WebFetch.

- `project/canvas.json`: the index. There is one page per panel: now, clock, ws, sys, bat, msg, cap, caf, tray, dl, files, clip, todo, shots, dock, dnd (drag & dock), and dirs (early directions).
- For each panel there is a component file plus showcase boards. For example:
  - `NowPlaying.dc.html` is the component. Its `mode` is compact | expanded | popped | bar | rail, and its `era` is one of 13.
  - `NP-Eras` shows compact, strip and rail in all eras.
  - `NP-Expanded` shows expanded in all eras.
  - `NP-States` shows one era with all its states.
- Other panels follow the same pattern: `Clock.dc.html` + `CK-Eras` + `CK-Expanded`, `System.dc.html` + `SY-*`, and so on.
- In `NowPlaying.dc.html`, each era has its own hand-drawn compact skin (the `sk.<era>` blocks). Expanded, strip and rail are driven by a per-era token table, `tokens(k)` in its script. That table is the best spec for colors, fonts, borders and key styles.
- The 13 eras are phosphor, tokyo, nineties, matrix, vfd, aero, gameboy, nixie, flap, nightvision, vapor, arcade and blueprint. They match `Eras.qml`.
- Only the parts drawn with the `dm`/`pn` classes are LED dots. Plates, bezels, keys, tubes and title bars are physical hardware drawn crisply around the dots. That is the direction the user approved with VFD: a dot display window inside a real device.
- The design's web fonts (VT323, Tilt Neon, Audiowide, Doto, ...) are **not installed**. Hardware text uses `Tokens.font` (DepartureMono).

## How the shell is built (what matters here)

- Root: `quickshell/.config/quickshell/dotshell/`. It's run as `qs -p ~/.config/quickshell/dotshell` (a symlink to the repo).
- Desktop panels: `services/Panels.qml` holds the store (`~/.local/state/dotshell/panels.json`, version 5). Each panel is `{ id, template, place: home|strip|rail, x, y, w, h (12 px units), zone, order, ... }`.
  - `DeskPanel.qml` draws a home panel.
  - `DockItem.qml`/`DockRow.qml` draw docked ones.
  - `Templates.js` holds the layouts (compact/expanded/strip/rail, drawn in dots by `PanelNode.qml`).
  - `Skins.js` holds the per-era frame type and words for the generic board.
- `DotSurface.qml`: children are authored in dots (1 px = 1 dot), and the shader draws LEDs in era colors. `shape` is an SVG path in dots that cuts the surface.
- `MatrixText.qml` + `Matrix.js`: 5x7 and 3x5 dot fonts. **5x7 has no `<` `>`, and 3x5 has no `[ ] # < > _ =`**. Add glyphs before using them.
- `Pane.qml`: a layer-shell pane. With `hardware` it draws the faceplate, window glass and key row. With `from` it grows out of a home panel's rect.
  - MEDIA (Super M) is `panes/MediaPane.qml`. It grows out of the media panel when that panel is on home.

## Media panel: where it stands

Done and live (VFD only):

- `DeskPanel.qml`: `faced` is true only for `media`, compact, rect, era `vfd`. It loads `MediaVfd.qml` instead of the generic board.
- `MediaVfd.qml`: `Hardware.get("vfd")` + `Hardware.layout()` → `Faceplate` + window (`DotSurface` running `VfdReadout`) + `WindowGlass` + `DeviceKeys`.
- `VfdReadout.qml` shows the annunciators, a 5x7 title, a big time, the synced lyric line (karaoke, with a countdown before the first line), the artist and album, a thin spectrum with falling peaks, and a segment seek bar.
  - With `full: true` (inside MEDIA) it drops the spectrum but keeps the synced lyric under the title.
- `panes/MediaPane.qml`:
  - `hardware` is `Hardware.get("vfd")` only when the era is vfd, else `null`, so the plain pane shows.
  - The NOW page order: readout (title → synced lyric → artist → seek bar), then spectrum + note bar, then the unsynced lyrics sheet, then the MIX/SCREEN row, then the Dot TV queue. The user asked for exactly this order; keep it.
- `DockItem.qml`: a click on a docked item runs the template's own `click` first. For media that's `pane media`, so MEDIA opens instead of the old peek board.

Built and tested offscreen, but **not wired for the other eras yet**:

- `Hardware.js` describes a device for **all 13 eras**, from the canvas's compact skins. It has:
  - `plate` (shape rect/pill/skew, fills, strokes/neon glow, brackets, bevel, grid, rivets, gloss, legend)
  - `head` (title band: vapor title bar, arcade marquee, flap header, blueprint caption)
  - `bezel`, `window` (radius/pill, shade, scan, gloss, vignette, sunken bevel, Game Boy frame + mark)
  - `side` (nixie tubes)
  - `keys` (at bottom or right; stretch/start/center/end/free; per-key style)
  - `readout` options (art, legends, prefix/cursor, bar style, flaps, rain, time)
  - Helpers: `get(era)` fills in the defaults, `big(hw)` gives the full-pane form (pill/skew → rounded rect, keys in a row), `layout(hw, w, h)` gives the rects, plus `platePath`/`windowPath`/`rounded`/`skewed`/`ink`/`icons`.
- `Faceplate.qml`, `WindowGlass.qml`, `DeviceKey.qml` and `DeviceKeys.qml` render any of those entries. All key styles were checked offscreen; see "Offscreen test" below. Tokyo's glow-only neon rings can't be checked offscreen, because MultiEffect doesn't render in the software backend.

## Next: the media panel in the other 12 eras

Switch them **one era at a time**, each in a working state, and get the user's screenshot before moving on.

1. **Readout.**
   - Generalize `VfdReadout.qml` into `MediaReadout.qml`, driven by `hw.readout`. Keep `VfdReadout.qml` working until the switch.
   - Add art (square/round, real album art as dots via an `Image` in the canvas, with a placeholder when there's none).
   - Add the bar styles: segments, blocks, lives, line + knob, chevrons, text `[####----]`, box, tube, dim (dimension line), flap.
   - Add: a fixed legend word (`//SIGNAL.LOCKED`, `TGT ACQ · CH 02`), the `> ` prefix with a blinking cursor (phosphor), flap tiles with a seam behind the title cells, falling code rain (matrix), a reticle over round art (nightvision), and `time: none` for nixie.
   - Compare each era against its `sk.<era>` block in `NowPlaying.dc.html`.
2. **Window shapes.**
   - Pill and skew windows must cut the dots: set the window `DotSurface`'s `shape` to `Hardware.windowPath(hw, cols, rows, Tokens.pitch)`.
   - Clip the glass with the same path; a Rectangle `clip` is only rectangular.
   - The readout needs extra side padding inside a pill.
3. **`NixieTubes.qml`** for `side.kind === "tubes"`: four glass tubes plus a colon showing `mm:ss` of the position, glowing digits over a dim "8".
4. **`MediaDevice.qml`** replaces `MediaVfd.qml`. It works like `MediaVfd` but uses `Hardware.get(Tokens.era)`, `layout()`, the head band (`Faceplate` gets `ctx` for `{pos}`/`{len}`), the side and the shaped window.
   - Then set `DeskPanel.faced` to `!!Hardware.get(Tokens.era)` (still media, compact, rect, not raw).
5. **`Pane.qml`** still only knows `bezel.l`, a bottom key row and a plain faceplate.
   - Make it use `Hardware.big(hw)`: the head band height above the window, the separate l/t/r/b bezels, and `surface.shape` from `windowPath`.
   - Then set `MediaPane.hardware` to `Hardware.big(Hardware.get(Tokens.era))` for every era. Check `MediaPane.vfd`, which gates the readout.
6. **Strip and rail forms.** The canvas's `bar`/`rail` modes (the token table: `strip*`/`rail*`) are still drawn by the generic `Templates.js` layouts. Do these after the compact device and MEDIA look right.
7. **Clean-up.** Delete the now-unused `RubberKey.qml` and `TransportKeys.qml`. My `rm` was blocked by the permission classifier, so ask the user.

Then apply the same recipe to the next panel the user picks (clock, system, battery, ...): read its component + Eras + Expanded boards, add a per-era device for it (generalize `Hardware.js` per template, e.g. `Hardware.get(era, template)`), and build its readout.

## Next: the panel manager (asked for, not started)

The user wants to close a panel and have it go into a manager, then open the manager and spawn it straight to the desktop, the top strip or the right rail. The plan:

- **Store.** `Panels.qml` gets a new place, `"shelf"` (closed). Add `close(id)` (remember `before` for undo, then set place to shelf) and `open(id, where)` (home at its last x/y/ws, strip zone `r` at the end, rail at the end). `send()` already does most of the open.
  - The home/strip/rail lists filter by place, so shelved panels drop out on their own.
  - Check other users of `Panels.panels`, e.g. `mediaHome()` and `media()`.
- **Pane.** `panes/PanelsPane.qml` (name `"panels"`), styled like the other panes (`DotText`, `DotButton`, `Line`; `BluetoothPane.qml` is a short example).
  - Rows grouped as ON DESKTOP / IN STRIP / IN RAIL / CLOSED, each with `DESK STRIP RAIL ×` buttons (the lit one is where it is).
  - Plus a NEW section listing `Templates.names` to spawn fresh ones.
- **Wiring.** Add `"panels"` to `Ui.names`, add `PanelsPane {}` in `shell.qml`, and add a DotBus `close` command next to `rm`.
  - Bind **Super+O** (free) in `~/dotfiles/hypr/.config/hypr/lua/binds.lua` as `bind(key(M, "O"), D.ipc("pane toggle panels"), "Panel manager")`.
- **Closing from the panel.** Right-click any panel (desktop, strip, rail) to close it to the shelf, with a 3 s undo through `Panels.undo`. Also show a small × on hover on desktop panels.

## Offscreen test (how the keys bug was found)

Scratch harness: `/tmp/claude-1000/-home-vardhin-dotfiles/cfbaf717-7212-445f-bfef-e1e360011106/scratchpad/keytest/`. It holds stub `Tokens`/`Media` singletons, a `qmldir`, and a `main.qml` that lays out every era's keys and grabs `out.png`.

- Copy the component in with `sed '/import qs.services/d'` and run `QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software qml6 main.qml`.
- `console.log` and `Text` don't show up in that setup. Debug with colored Rectangle swatches.
- MultiEffect glows don't render there.

## Tokyo Night: every panel (2026-10-19)

Source: `~/dotfiles/dot-shell-panels.html` (the canvas exported as static HTML; each board's TOKYO NIGHT column is the spec).

- `tokyo/` is the `qs.tokyo` module. Kit: `Ink` (palette + Tilt Neon from `fonts/`, OFL), `Glass` (dot glass cut round), `Sign`/`Tube` (crisp neon tubes with glow; `tone` pink/red/dim, `inner` cyan tube), `Neon` (big dot lettering), `Words` (5x7 when it fits, else 3x5; a leading kanji word drawn small in front), `Chip` (crisp pill button), `Hit` (click that still lets a hold/drag lift the panel), `Field` (DotInput + hint), `Ring`, `Bars`, `Folder`, `DotPic` (a picture as true-colour dots), `Face` (base: ctx, sink, panel, words, `big`).
- One face per template, compact and expanded (`big`): Clock, Workspaces, System, Battery, Messages, Capture, Caffeine, Tray, Downloads, Files, Clipboard, Todo, Screenshots, Dock. Media stays `MediaTokyo.qml` (+ MEDIA pane).
- `DeskPanel.qml`: `tokyoFace` picks the face (era tokyo, rect, not raw, no own layout/feed); `tokyoRim` gives any other board the pink tube. `DockItem.qml`: in tokyo each docked item is padded and gets a crisp pill on the bar's `plainLayer`.
- Small additive data: `Sys.top` rows have `rss` and `pid`, `Sys.tempHist`/`sysFeed.tempHist`; todo rows have `lists` and `next`; 3x5 gained `% ° ~ * ; | " @ $ → ← ↓ ↑ × • ⌂ ▸ ◂ ✓`.
- Gotchas: `top`, `left` (and other anchor names) are FINAL on Item; don't name properties that. Inside `MatrixText`, `face` is its own property, so faces use `id: root`. Don't give an inline component a property that shadows a layout id (`s`).
- Offscreen check: `/tmp/claude-1000/-home-vardhin-dotfiles/c40ffcac-69f5-4cdd-bc8a-09edbc19b975/scratchpad/h/` (`sync.sh`, `run.sh <page.qml> <out.png>`, stubs). `QT_QUICK_BACKEND=rhi` is what makes the dot shader and glows render offscreen.
