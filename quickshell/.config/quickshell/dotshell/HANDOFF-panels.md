# Handoff: Dot Shell panels, one era at a time

Written 2026-10-18, rewritten 2026-10-19 for the next Claude Code chat. When the user says **"continue from handoff"**, do the "START HERE" section below, start to finish, for the next era. Read the whole file before touching anything; the dated sections further down say how each finished era was built.

## START HERE: perfect the next era

**Done eras:** Tokyo Night (`tokyo/`), VFD (`vfd/`), Frutiger Aero (`aero/`), Blueprint (`blueprint/`), Vaporwave (`vapor/`), Split-Flap (`flap/`), Nixie (`nixie/`, built 2026-10-20 on request), 90s Nights (`nineties/`, built 2026-10-20 on request), Night Vision (`nightvision/`, built 2026-10-21 on request, waiting on the user's screenshot).
**Every era is done.** Matrix, Game Boy and Arcade were deleted on 2026-10-21 (the user did not like them). If the user names an era to redo or a new one to build, follow the steps below for it.

"Perfect the era" means **everything below, in one go**, not one panel then stop. The user was angry when only System was done for aero ("you only did cpu panel, every other panel is slop"). Do all the panels, then ask for a screenshot.

### 1. Read the design for the era

- Source: `~/dotfiles/dot-shell-panels.html` (the canvas exported as static HTML). Each board has one column per era; that column is the spec.
- Cut the era's column out of every board and render it (tools in `~/dotfiles/dot-shell-tools/`, output into your scratchpad):
  - `python3 -I ~/dotfiles/dot-shell-tools/extract.py ~/dotfiles/dot-shell-panels.html <scratch>/<era> "NIXIE"` (the third argument is the start of the era's column header: `NIXIE`, `SPLIT-FLAP`, `NIGHT VISION`, `VAPORWAVE`, `BLUEPRINT`, `90S NIGHTS`; quote it).
  - Files are `<board>-<n>.html`: `-0` is compact + strip + rail, `-2` is expanded, `now-3` the expanded media, `now-4` popped, `dnd-1` the Drag & dock board.
  - `~/dotfiles/dot-shell-tools/render.sh <scratch>/<era>` screenshots them all to `<scratch>/<era>/png/` (headless Firefox, 2x, trimmed). Look at every PNG with Read.
- Read the HTML too (strip `<style>`, collapse SVG) to see which parts are dots (`.dm` / `.pn` classes) and which are crisp, and to get exact colours, radii, gradients and font sizes. Fonts the design uses are not installed: fetch the OFL face into `fonts/` (e.g. `curl -L https://github.com/google/fonts/raw/main/ofl/<name>/<File>.ttf`) with its `OFL.txt`, load with `FontLoader` in the era's `Ink`.

### 2. Build `<era>/` (module `qs.<era>`), like `aero/`, `vfd/`, `tokyo/`

- `Ink.qml` singleton: the era's palette + font.
- A small kit of the era's materials (plate/glass/case, keys, cards, rules), then **one face per template, compact and expanded (`big`)**: System, Clock, Battery, Caffeine, Capture, Messages, Todo, Clipboard, Workspaces, and media compact (`<era>/Media.qml`, registered in `DeskPanel.devices`). The user's scope so far is these; Tray, Downloads, Files, Screenshots, Dock keep the generic board unless asked.
- Faces extend `T.Face` (`import qs.tokyo as T`) and use `T.Hit` for clicks (a hold/drag still lifts the panel), `T.Field` for text input, `T.DotPic` for pictures. Read the VFD face of the same template first: it has all the data fields and actions (`ctx.*`, `run("…")`) to copy.
- Every feature the generic board had must still work in the face (clicks, actions, inputs, keys).
- Dots vs crisp: dot parts go on a DotSurface (or aero's `Dots` for lit-only eras); crisp parts (plates, keys, rules, cards) are plain QML placed in px = dots × `Tokens.pitch`. Small words in `MatrixText` 5x7/3x5 (5x7 when it fits, else 3x5); only big numbers/titles in the era font at dot scale. Varela-at-4-dots style tiny fonts are unreadable; don't.
- Wire into `DeskPanel.qml`: `<era>Face` / `<era>Faces` exactly like `aeroFace`/`aeroFaces` (add the face's Component only after its file exists).
- Check each face offscreen (below) against the design render before wiring it.

### 3. The rest of the era, in the same go

- **MEDIA pane (Super M) and the message centre (Super N) and notification popups must follow the era too, with all their features.** The user rejected slimmed-down replacements ("the styled messages and media panels should still have all features"). Do it by skinning the real panes, never by replacing them:
  - Notifications: add the era to `NotifLook.js` (card fill/rule, live accent, inks, keys, heading, from its Messages boards). `NotifCard`, `NotifKey`, `MessagesPane`, `ToastStack` already read it.
  - Pane frame: add the era to `Pane.frame` / `PaneFrame.qml` (`eraFrame` panes: toasts, message centre).
  - MEDIA: `MediaPane.hardware` uses `Hardware.js` devices for vfd/tokyo; aero uses `skyGlass`. Give the new era its device or frame there.
  - Clicking the Media panel opens MEDIA; clicking a notification on the Messages panel opens the message centre. Keep it that way.
- **Strip and rail: NO per-item borders/casings/pills.** The user: "remove the panel borders in the strip and rail across eras, why did you even put em". Docked items stay plain dots on the bar. Only a whole-bar material change is OK when the era needs it (aero: `BarChrome.qml` sky glass + `DotSurface.bare`).

### 4. Check, then hand over

- After every save, read the **real log file** (timestamped): `grep -aE "Reloading|Loaded|ERROR" /run/user/1000/quickshell/by-pid/$(pgrep -f 'qs -p .*dotshell' | head -1)/log.log | tail -6`. You want the newest line "Configuration Loaded" with no ERROR after it. **Don't trust `qs log -p …`**: on 2026-10-19 it showed old lines only, every vapor reload had actually failed, the shell kept the old config, and the user screenshotted generic boards. A failed reload keeps the previous config running, so the screen can look fine while your code never loaded.
- Era component names must not match a root `qs` type or a `qs.services` singleton: imports win over the era dir's own file (vapor's `Line` lost to root `Line.qml`, hence `Trace`).
- Then append a dated section for the era at the bottom of this file (kit, faces, what is not done, data you added), like the aero one.
- Then `notify-send "Claude" "<≤2 lines: what is ready, what to screenshot>"` as the **very last tool call**, and end the turn.

### The user's rules (all sessions)

- Dot Shell hot-reloads on every save and the user watches it live. Every save must leave a working shell. Change a shared table and its readers in the same save, or add new fields next to old ones (see "The mistake" below). Never rename/remove a property something else still reads.
- When you need the user: short `notify-send "Claude" "…"` (≤2 lines), and it must be the **last** tool call of the turn. No log checks after it.
- Never take screenshots or open panes yourself to look. Ask the user.
- The user gets impatient with silence: in long turns, write a one-line progress note between steps.
- Follow the design accurately; generic boards are "garbage slop". Do the whole era, not a pilot.
- Don't invent decoration the user didn't ask for, even if a design board shows it (the strip/rail casings came from the Drag & dock board and were rejected).
- `rm` is aliased interactive here: use `command rm -f` for files you created, or it hangs.
- "Delete panel X" means drop its desktop form only (keep the strip item).

### Gotchas met so far

- QML: `top`, `left` and other anchor names are FINAL on Item; `state` is Item's own property; don't name properties that. Don't give an inline component or delegate a property that shadows an id in scope (`ink`, `s`, `words`).
- `sink: sink` (or any `x: x`) inside an object that has its own `sink` property binds it to ITSELF (undefined), not to the outer id. Every docked button was dead from this. Expose the id as a property (`readonly property QtObject actions: sink`) and pass `sink: root.actions`.
- `MultiEffect` has `saturation`, not `saturationEnabled`.
- `DotText` fills its parent's height and centres; give it an explicit `height: Tokens.fontPx` when placing it by y.
- Big era-font text at dot scale: antialiased edges fade; aero's `bubble.frag` snaps alpha past ~0.55 to whole dots. Don't outline to thicken (fills counters).
- zsh: `$S[0]` indexes a string; use `${S}`.
- MatrixText 5x7 lacks `<` `>`; 3x5 lacks `[ ] # < > _ =`. Add glyphs to `Matrix.js` first if you need them.

## Ground rules (from the user)

See "The user's rules" in START HERE.

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
- The 9 eras are tokyo, nineties, vfd, aero, nixie, flap, nightvision, vapor and blueprint. They match `Eras.qml`. Each has a dark and a light tone (the `tone` token): era panels write their colors as authored for the era's own tone, as pairs `Ink.c(own, other)` (every Ink color and every literal, the other tone's value authored by hand, never computed); Hardware.js and NotifLook.js tables go through the era's `map` and patches in Palettes.js, which also holds each era's other-tone palette. Glows go through `Tokens.neon` (off when a dark era is drawn light); aero's gloss and shadows through `Ink.gloss(a)` / `Ink.shade(a)`.
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
  - `head` (title band: vapor title bar, flap header, blueprint caption)
  - `bezel`, `window` (radius/pill, shade, scan, gloss, vignette, sunken bevel, frame + mark)
  - `side` (nixie tubes)
  - `keys` (at bottom or right; stretch/start/center/end/free; per-key style)
  - `readout` options (art, legends, prefix/cursor, bar style, flaps, rain, time)
  - Helpers: `get(era)` fills in the defaults, `big(hw)` gives the full-pane form (pill/skew → rounded rect, keys in a row), `layout(hw, w, h)` gives the rects, plus `platePath`/`windowPath`/`rounded`/`skewed`/`ink`/`icons`.
- `Faceplate.qml`, `WindowGlass.qml`, `DeviceKey.qml` and `DeviceKeys.qml` render any of those entries. All key styles were checked offscreen; see "Offscreen test" below. Tokyo's glow-only neon rings can't be checked offscreen, because MultiEffect doesn't render in the software backend.

## (History) the original plan for the media panel in the other eras

Superseded: Tokyo, VFD and aero media faces exist (`MediaTokyo.qml`, `MediaDevice.qml`, `aero/Media.qml`). Kept for the `Hardware.js` notes.

Switch them **one era at a time**, each in a working state, and get the user's screenshot before moving on.

1. **Readout.**
   - Generalize `VfdReadout.qml` into `MediaReadout.qml`, driven by `hw.readout`. Keep `VfdReadout.qml` working until the switch.
   - Add art (square/round, real album art as dots via an `Image` in the canvas, with a placeholder when there's none).
   - Add the bar styles: segments, blocks, lives, line + knob, chevrons, text `[####----]`, box, tube, dim (dimension line), flap.
   - Add: a fixed legend word (`//SIGNAL.LOCKED`, `TGT ACQ · CH 02`), the `> ` prefix with a blinking cursor, flap tiles with a seam behind the title cells, a reticle over round art (nightvision), and `time: none` for nixie.
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

## Panel manager (done)

`panes/PanelsPane.qml` (Super+O), `Panels.close(id)` / `Panels.open(id, where)`, right-click a panel to close it to the shelf.

## Offscreen test

Harness: `~/dotfiles/dot-shell-tools/harness/`. `./run.sh <page.qml> <out.png>` runs `sync.sh` (mirrors root QML + `tokyo/ vfd/ aero/` into `w/` with service stubs from `stubs/`), then renders with `QT_QUICK_BACKEND=rhi QT_QPA_PLATFORM=offscreen qml6`. Pages are `a<face>.qml` (one per aero face, with sample `ctx`): copy one, swap `import "aero" as V` for the new era dir and add it to the `for d in tokyo vfd aero blueprint vapor` lists in `sync.sh`. `mkv.sh a<face>.qml` does that for vapor (Tokens set to the vapor palette) and renders `v<face>.png` into a scratchpad path written in the script: change it. Stubs: Tokens (era "vfd" colours; set `Tokens.era` etc. in `Component.onCompleted` for another era), Feeds, Notifs, Power, Media, Lyrics, LyricLine, Spectrum, MatchVideo, Process. Write the PNGs to your scratchpad, not the repo.

### Older note: how the keys bug was found

Scratch harness: (old /tmp copy; now `~/dotfiles/dot-shell-tools/harness/`). It holds stub `Tokens`/`Media` singletons, a `qmldir`, and a `main.qml` that lays out every era's keys and grabs `out.png`.

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
- Offscreen check: (old /tmp copy; now `~/dotfiles/dot-shell-tools/harness/`) (`sync.sh`, `run.sh <page.qml> <out.png>`, stubs). `QT_QUICK_BACKEND=rhi` is what makes the dot shader and glows render offscreen.

## VFD: desktop panels (2026-10-19)

The user's prompt for this round, to reuse for the next era: "Refer to the dot-shell-panels.html in the root directory and make the currently available desktop panels accurately follow the design principle, like the media panel did. Finish one era, then slowly tackle all the other eras." Tokyo Night and VFD are done. **Next era: Frutiger Aero** (`aero`; the boards' FRUTIGER AERO column, BUBBLE DOTS).

Scope the user set: only the panels below. The user stopped the session at Tray. Don't extend VFD further unless asked.

- `vfd/` is the `qs.vfd` module. It's the car stereo's head unit, from the VFD columns.
  - Kit:
    - `Ink`: cyan/amber/green/red/teal/deep/ghost, plus the gunmetal plate and key colours.
    - `Unit`: the plate plus the sunken dot window. Children are in dots. `over` holds crisp parts placed in px from the window's first dot (`px()`). `foot` + `deck` are keys under the window; `side` + `rack` are keys to its right.
    - `Digits`: big 5x7 numerals, `size`× scale, spaced dots from size 3, with unlit 8s behind (`cells`, `mask`).
    - `Bar`: segment bar. `Hist`: dotted history columns. `Box`: crisp rule round a dot rect. `Key`: gunmetal hard key (`on` ring, `ink` legend colour, `led` lamp strip).
  - It reuses `qs.tokyo` as `T` for `Face`, `Hit`, `Field` and `DotPic`.
- Faces, compact and expanded: **System, Clipboard, Todo, Clock, Workspaces, Battery, Messages, Capture, Caffeine**. Media stays `MediaDevice.qml`.
  - **Not done in VFD** (they keep the generic board): Tray, Downloads, Files, Screenshots, Dock.
- `DeskPanel.qml`: `vfdFace`/`vfdFaces`, the same pattern as tokyo. Add a face's Component only after its file exists.
- Small additive changes:
  - `MatrixText.dot` (lit part of each scaled cell).
  - 5x7 gained `° ~ • × ▸ ◂ ✓ → ← ↓ ↑`.
  - `Notifs.forget(ts)` plus the action `notifs forget TS`, for the ERASE key.
- No backend exists for the design's clipboard PIN, alarm (clock), steps (todo), or capture delay/after/pause/mark. Those were left out or replaced with real data (UTC, week, weekday).
- Offscreen check: (old /tmp copy; now `~/dotfiles/dot-shell-tools/harness/`) (`run.sh <page.qml> <out.png>`). It mirrors root, `tokyo/` and `vfd/` as real modules, and `stubs/Tokens.qml` is set to vfd.
- The design per era, rendered: `extract2.py` in that scratchpad cuts one era's column out of every board. Render each with `firefox --headless --screenshot` (add `zoom:2` to the body). Change `'VFD'` in the script to `'FRUTIGER'` for aero.

## Frutiger Aero: desktop panels (2026-10-19)

Aero has **no unlit dot grid** anywhere in its boards: every dot is lit ink (`.dm`) straight on a crisp glossy plate. So it does not use DotSurface:

- `shaders/bubble.frag` + `aero/Dots.qml`: a lit-only bubble-dot layer (children in dots, as on a DotSurface). Texel alpha past ~0.55 is a whole dot, below that it fades, so `opacity: 0.3` reads as a faint dot. Dot size is capped at 0.88 of the pitch so dots stay separate bubbles.
- Kit in `aero/` (`qs.aero`): `Ink` (palette + Varela Round from `fonts/`, OFL), `Sky` (the plate: white, sky horizon, rim, shadow, gloss), `Say` (big Varela in dots), `Card` (white glass card, optional ring), `Key` (glossy button: plain/lit/red/green/ghost), `Orb` (marble), `Dial` (gauge), `Clockface`, `Desk` (workspace tile), `Geo` (window layout via hyprctl). Faces reuse `qs.tokyo` as `T` for `Face`, `Hit`, `Field`, `DotPic`.
- Pattern per face: crisp parts (cards, keys, pills) placed in px = dots × pitch, then one `Dots` over them for the words. Small words are 5x7/3x5 MatrixText (5x7 when it fits); only big numbers use `Say`.
- Faces, compact and expanded: System, Clock, Battery, Caffeine, Capture, Messages, Todo, Clipboard (wooden board, steel clip, paper), Workspaces; media compact is `aero/Media.qml` (in `DeskPanel.devices`). Not done: Tray, Downloads, Files, Screenshots, Dock.
- Additive data: `Sys.load`/`Sys.tasks` (from /proc/loadavg) in `sysFeed`.
- Offscreen: (old /tmp copy; now `~/dotfiles/dot-shell-tools/harness/`) (`run.sh a<face>.qml out.png`; media stubs added). Design renders per era: `../aero/png/`.
- Panes in aero: `Pane.skyGlass: true` (set on MEDIA and the message centre) draws the pane as `Aero.Sky` with its DotSurface in `bare` mode (DotSurface.bare uses bubble.frag: lit dots only, no unlit grid). Every pane feature stays; other panes can opt in the same way.

## Strip and rail (2026-10-19)

No per-item casings in the strip or rail (tried, the user rejected them: keep docked items as plain dots on the bar). Aero only: `BarChrome.qml` is the sky-glass bar under a `bare` DotSurface (TopStrip.qml, panes/SideBar.qml). `RailButton` centres the icon's ink (TextMetrics), not its advance.

## Notifications (2026-10-19)

`NotifLook.js` is each finished era's notification look from the Messages boards (card fill/rule, accent for the live one, app/words/body/time inks, keys, heading). `NotifCard.qml` (toasts and live cards), `NotifKey.qml` (era keys; plain eras get a DotButton) and `MessagesPane.qml` (log grouped by app on ruled cards in those eras) read it; other eras keep the plain layout. `Pane.eraFrame` frames a pane per era: aero sky glass (same as `skyGlass`), Tokyo a neon sign (pink tube, cyan inner tube, rounded dot glass), VFD a gunmetal unit with a smoked sunken window (`PaneFrame.qml`). On for the toasts and the message centre.

## Blueprint: every panel (2026-10-19)

Done out of order (the user asked for blueprint after aero). In the BLUEPRINT boards the **compact** panels are almost all crisp (Share Tech Mono words, drawn figures and title-block tables on gridded paper); only the strip/rail and the **expanded** sheets use dots. Like aero there is no unlit grid: lit dots straight on the paper.

- `blueprint/` is `qs.blueprint`. Kit: `Ink` (paper `#0b3a75`, grid, rule `#a9cdfa`, ink `#e8f1ff`, white, done `#3d72b8`, warn; Share Tech Mono from `fonts/`, OFL), `Paper` (the sheet: fill, 12 px grid, rim), `Dots` (lit-only dots via `bubble.frag`, faint white glow), `Pen` (crisp word), `Say` (big Share Tech Mono in dots), `Stroke` (SVG path, solid/dashed, via Shape), `Box`, `Key` (dashed, or solid white when `on`), `Tag` (boxed word: OPEN, Paste), `Table` (label | value title block; `cells` for a component value), `Sheet` (expanded "SHEET n — TITLE … REV A" heading), `Hatch` (45° section hatching), `Bars` (hollow dot columns from a history), `Dial` (FIG. 3 clock drawing).
- Faces, compact and expanded: System (FIG. 4 load chart / SHEET 4), Clock (FIG. 3 / SHEET 2 calendar), Battery (FIG. 5 cell section / SHEET 5 discharge), Caffeine (FIG. 7 switch S1, animated blade / SHEET 8), Capture (FIG. 6 frustum + MODE/T/DO block / SHEET 7), Messages (numbered NOTES / SHEET 6 by app; DND greys the sheet), Todo (punch list), Clipboard (CLIPPINGS — NOTES, N-1…), Workspaces (PLAN — LEVEL 1 rooms / SHEET 3 floor plans; reuses `qs.aero` `Geo`). Media compact: `blueprint/Media.qml` (FIG. 1: framed cover, seek line, round keys, lyric in dots, TITLE/BY/SHOW block; SHOW boxes what exists: video, vis, lyrics). Not done: Tray, Downloads, Files, Screenshots, Dock.
- `DeskPanel.qml`: `blueprintFace`/`blueprintFaces`, `devices.blueprint`.
- Panes: `Pane.frame` is "blueprint" for `skyGlass`/`eraFrame` panes in that era (MEDIA, message centre, toasts): `Bp.Paper` behind a `bare` DotSurface. `NotifLook.js` has `blueprint`.
- Design boards with no backend were swapped for real data: no DELAY/AFTER (capture), PAUSE/MARK, Pin, events (calendar footer shows week + UTC), SHT/REV numbers are fixed words.
- Offscreen: `dot-shell-tools/harness/mk.sh a<face>.qml` makes `b<face>.qml` (blueprint, Tokens slots set) and renders it to the scratchpad path in the script.

## VFD strip and rail (2026-10-19)

The user said the VFD strip and rail "still don't follow the design principles". Fixed, still with no per-item casings:

- Bar material: `vfd/Dash.qml` (gunmetal plate, lit edge, black rule at the desktop, glass) under the bar's DotSurface and `vfd/Smoke.qml` (top shadow + black lip) over it: the whole strip/rail is one head unit with ONE long sunken window. `TopStrip.qml` / `panes/SideBar.qml` grow by `pad` (1.5 dots) each side in vfd only; the strip's real height is what `Pane.stripH` reads.
- Docked forms: `vfd/Docked.qml` (a `T.Face`) draws the strip and rail forms of media, clock, workspaces, system, battery, messages, capture, caffeine, clipboard, todo from the VFD boards' small forms: teal small print (3x5), cyan readings (5x7), amber counts/accents, red alarms, segment `Bar`s with ghost cells, `Digits` over unlit 88:88. `DockItem.qml` loads it (`vfdForm`) instead of `PanelNode` for those templates in vfd; a form's whole-item click is its `action`, a form with none falls through to the peek. Tray, downloads, files, shots, dock keep the generic forms.
- Strip status words (VOL/BRT/net/BT) and the window title are 5x7 MatrixText in vfd (`StatusWord.vfd`). 5x7 gained `⌂`.
- Offscreen: `dot-shell-tools/harness/vdock.qml` (all forms) and `vdock2.qml` (with the plate).

## Tokyo Night strip and rail (2026-10-19)

Same treatment as VFD's, still no per-item pills (the boards draw every strip/rail item in its own neon pill; the user rejects those):

- Bar material: `tokyo/Edge.qml`, one pink neon tube where the bar meets the desktop (strip bottom, rail left) plus a faint pink spill back over the glass (the Drag & dock board's bar: `box-shadow: 0 1px 0 #ff3cac`). `TopStrip.qml` / `panes/SideBar.qml` grow by `edge` (4 px) in tokyo only; the rail paints glass under that band.
- Docked forms: `tokyo/Docked.qml` (a `Face`), loaded by `DockItem.qml` (`tokyoForm`) for media, clock, workspaces, system, battery, messages, capture, caffeine, clipboard, todo. Inks from the boards: readings cyan, small print violet, titles/marks pink, alarms red. Pictograms are dot patterns (`Pix`: rows of digits, n = inks[n-1]): cup, dashed frame, rings, discs, sheets, vinyl, 11-dot transport rings. System uses rising wedges; battery a cyan cell with pink blocks; album art is a masked disc of dots (vinyl when none). Rail clipboard shows the last 4 copies as slots (click pastes).
- Strip words: `StatusWord.tokyo`, 5x7, label violet + reading cyan; the window title is 5x7 violet.
- Offscreen: `dot-shell-tools/harness/tdock.qml` (all forms + the edge, pitch 5).

## Vaporwave: every panel (2026-10-19)

Done on request after blueprint (out of order). In the VAPORWAVE boards every panel is a **Windows 95 window**: lilac face with a double bevel, a violet → pink → cyan title bar (icon, `name.exe`, `_ □ ×`), push buttons, and readouts on **dark dot screens with unlit dots** (`.pn`, which is just the era's own DotSurface: glass `#130a24`, unlit `#2d1b4e`). Words on the lilac or on white sheets are lit-only dots (`.dm`) with a pink glow.

- `vapor/` is `qs.vapor`. Kit: `Ink` (face `#c9b8e8`, hi, shade `#3d1d63`, mid `#8a6fb8`, ink `#130a24`, violet/pink/cyan, yellow `#fffb96`, red; VT323 from `fonts/`, OFL), `Win` (the window + title bar; `bodyY` is where contents start; □ runs `panel expand`/`panel fold`, `_`/× fold, `closed()` on ×; `controls` max/help/close; `boxed` keys for the media player), `Bevel` (raised/sunk, `outer` mid ring), `Well` (sunken frame, `paper` = white sheet), `Crt` (sunken DotSurface screen, `grid` cyan rules, `radius` + `shape` for round), `Dots` (lit-only, bubble.frag, pink glow), `Pen` (crisp VT323), `Say` (VT323 in dots), `Key` (push button, `on` = hot pink, `glyph` prev/next/play/pause/stop/rec via `Glyph`), `Meter` (progress bar of violet/cyan blocks, `seek`), `Line` (dotted history line), `Bars` (solid dot columns), `Check` (check box).
- **Don't call a component `Screen`** (clashes with Qt's attached Screen) – that's why the screen is `Crt`. Don't put a property named like an id in scope (Media had `side`).
- Faces, compact and expanded: System (taskmgr.exe Performance / Processes: pick a row, End Task = `run kill PID`, Switch To = `jump`, New Task = `launcher`), Clock (date_time.exe: round dot dial + time screen, OK = expand, Calendar = `pane calendar` / calendar screen with ◂ ▸), Battery (power_meter.exe / Details: graph, 4 readings, PROFILE steps the profile), Caffeine (display.cpl: check box toggles, Wait field / Screen Saver timers), Capture (capture.exe recorder: ✂ shot, ● rec, region/window target, ■ stop, mic / Options), Messages (inbox.exe message box, OK = message centre, Clear all; DND greys it / History on a white sheet with live action keys, Open/Clear/Do Not Disturb), Todo (todo.txt — Notepad, next task on the sunset bar / lists), Clipboard (clipbrd.exe / search, kinds, Contents page with Paste/Delete), Workspaces (pager.exe tiles / overview; uses `qs.aero` Geo). Media compact: `vapor/Media.qml` (now_playing.exe: cover screen + matched video, title/artist screen, seek Meter, transport keys, time, VID VIS LYR → `pane media`). Not done: Tray, Downloads, Files, Screenshots, Dock.
- No backend, dropped: capture pause/mark/delay/after, clipboard Pin, the "N of M steps" todo line, drag-to-move in the pager.
- `DeskPanel.qml`: `vaporFace`/`vaporFaces`, `devices.vapor`.
- Panes: `Pane.frame` is "vapor" for `skyGlass`/`eraFrame` panes. The pane gets `head` (22 px) for the title bar above the dots, `bezel` 8, and `title`/`icon` (MEDIA: now_playing.exe, message centre: inbox.exe — History, toasts: inbox.exe). `skyGlass` panes (MEDIA) keep the dark dot screen; `eraFrame`-only panes (`vaporSheet`: message centre, toasts) are a white sheet with a bare DotSurface. × closes the pane. `NotifLook.js` has `vapor` (dark ink on white, pink apps, violet rules).
- Strip and rail (same day, after the user asked): `vapor/Taskbar.qml` is the lilac Win95 taskbar (white outer edge, shade + mid ring at the desktop) under a `bare` DotSurface in `TopStrip.qml` / `panes/SideBar.qml`. `vapor/Docked.qml` is `tokyo/Docked.qml` re-inked (readings ink, small print deep violet, marks pink, alarms red, dim tracks mid violet), loaded by `DockItem.qml` (`vaporForm`) for the ten templates. `StatusWord` and the window title are 5x7 in vapor (label violet, reading ink). No per-item casings. Offscreen: `dot-shell-tools/harness/vdockv.qml`.

## Split-Flap: every panel (2026-10-19)

Done on request (out of order). Every SPLIT-FLAP board is a **departure board**: near-black housing `#141414` with a 2 px `#2a2a2a` rim, Silkscreen small print across the top ("SYSTEM STATUS … ● NOMINAL"), and rows of **flap tiles** (top half `#262626`, hinge `#0b0b0b`, bottom `#1e1e1e`) with letters in lit **square** dots: off-white `#f2f2e6`, dim `#bdbdb0`, yellow `#ffd400` readings, orange `#ff8c00` warnings, red `#ff5a36` alarms. `.pn` screens (clock time, battery graph/cards, MEDIA) are the era's own DotSurface.

- `shaders/flap.frag` (+ .qsb, compiled with `/usr/lib/qt6/bin/qsb --glsl "100 es,120,150" --hlsl 50 --msl 12`): lit-only square dots. `DotSurface.bare` now uses it when `Tokens.current.shape === "square"` (only flap uses bare among square eras).
- `flap/` is `qs.flap`. Kit: `Ink` (palette; colours `upper`/`lower`, not `top`/`bottom`, those are FINAL; Silkscreen + VT323 from `fonts/`, OFL), `Dots` (lit square dots), `Print` (crisp Silkscreen), `Say` (VT323 in dots), `Housing` (board + header, `status`/`statusAction`, `screws`), `Tile`, **`Flaps`** (a row of tiles, `spans` of [text, color], 5x7 or 3x5, `cells`, `lit` tiles yellow, changed letters spin and settle left to right, `page` pages long lines), `Rows` (stacked Flaps that pick 5x7/3x5 to fit; `least`; per-line `action`), `Big` (one big tile, VT323 digit, spins), `Key` (flap-dark key; `on` yellow, `tone` red/orange; `glyph` prev/next/play/pause), `Tag` (small yellow tag), `Card`, `Glass` (dot screen), `Cols` (history columns), `Rack` (strip/rail housing), `Docked`.
- Faces, compact and expanded: System (rows CPU/MEM/TEMP + state word / TOP: cards, process table, KILL FOCUS NEW TASK), Clock (4 big tiles + date row → `pane calendar` / DEPARTURES calendar of tiles, ◂ ▸), Battery (POWER rows / 24 HOURS graph + RATE HEALTH CYCLES PROFILE), Caffeine (SCREEN rows, first row toggles / timers keys, holders, idle timings), Capture (STUDIO rows + SHOT REC REGION WINDOW, ON AIR when recording / CAPTURE DESK), Messages (ARRIVALS: time + app rows → message centre, status toggles DND (dims) / by-app cards with live action tags, OPEN CLEAR DND), Todo (TODAY'S RUNS flap rows, next ruled yellow, add field / lists), Clipboard (rows, newest yellow, swatch/thumb / search, kinds, preview with PASTE DEL), Workspaces (a row per workspace, or a tile per workspace when short / PLATFORMS cards via `qs.aero` Geo). Media compact `flap/Media.qml` (title tiles paging, artist, yellow seek segments, time tiles, keys, VID VIS LYR orange). Not done: Tray, Downloads, Files, Screenshots, Dock.
- `DeskPanel.qml`: `flapFace`/`flapFaces`, `devices.flap`.
- Panes: `Pane.frame` is "flap" for `skyGlass`/`eraFrame`; `Fl.Housing` behind, `head` 22 with `caption` + "● `captionStatus`" (new Pane props; MEDIA: NOW PLAYING / ON AIR with screws, message centre: ARRIVALS · ALL MESSAGES / LIVE|HELD, toasts: ARRIVALS / n IN). MEDIA keeps its dot screen; `flapSheet` panes are bare (square dots on the housing). `NotifLook.js` has `flap`.
- Strip and rail: `Fl.Rack` under a bare DotSurface (TopStrip, SideBar). `Fl.Docked` (via `DockItem.flapForm`) draws readings on flap tiles **drawn in dots** (`Tiles`; a picked tile is deep amber with a yellow letter — dark letters on yellow dots vanish into the gaps). No per-item casings. `StatusWord.flap`: 5x7, label grey, reading off-white; window title grey 5x7. Offscreen: `dot-shell-tools/harness/fdock.qml`; faces: `mkf.sh a<face>.qml [pitch]`.
- No backend, dropped: capture PAUSE/MARK/DELAY/AFTER, clipboard PIN, todo steps.
- Reload gotcha seen today: a save to `DeskPanel.qml` didn't trigger a reload once; `touch shell.qml` did. Always confirm a fresh "Configuration Loaded" timestamp.

## Nixie: every panel (2026-10-20)

Done on request (out of order). In the NIXIE boards every **compact** panel is valve-era kit in a **walnut case** (grain bands `#3a1d0e #5a2e16 #3e1f0f #5a2e16`, a 2 px brass `#b8863b` rule inside the edge, a dark 2 px one inside that): glass nixie tubes (honeycomb mesh, dim "8" behind, `#ffc285` digit in dots), brass pill keys, round brass knobs, ivory paper (`#efe2c4`) with dark dot words, a moving-coil meter, a toggle switch, a camera lens. Every **expanded** panel is the same case holding one `.pn` dot screen ruled in brass (the era's DotSurface: glass `#0a0503`, unlit `#2b130a`), except Messages/Todo/Clipboard, which stay on wood with ivory paper. Glow: orange halo on lit dots (Tokens.neon).

- `nixie/` is `qs.nixie`. Kit: `Ink` (palette + Nixie One `fonts/NixieOne.ttf` (OFL, fetched), Silkscreen, Share Tech Mono; strip inks `ink label pink mid face` for Docked), `Wood` (case; `dome` for an arched top, `rule`), `Dots` (lit round dots via bubble.frag + orange halo; `soft` for dark ink on paper), `Say` (Nixie One in dots), **`Word`** (big word in dots: Nixie One from `serifAt` (13) dots, else 5x7 scaled by whole dots, so small tubes/titles stay readable), `Print` (crisp Silkscreen brass), `Pen` (crisp Nixie One orange line), `Glow` (crisp lamp with halo), `Mesh`, `Tube` (one tube, digit via Word; `lit`, `ink`, `mesh`, `ghost`, `dome`), `Tubes` (a row from a string, ":" = colon lamps), `Glass` (brass-ruled DotSurface), `Case` (expanded: Wood + Glass 12 px in; faces map px→screen dots with `dx/dy` using `box.screen.surface.x/y`), `Card` (rounded warm rule on a screen, `on` = bright + glow), `Paper`, `Key` (brass pill; `on` polished, `tone` "hot" red-orange glowing / "lit" orange; `radius` 3 = media tabs), `Knob`, `Bars`, `Meter`, `Lever`, `Lens`, `Rack` (strip/rail walnut, brass edge), `Docked` (copy of `vapor/Docked.qml`, inks via Ink aliases).
- Faces, compact and expanded: System (three glass level tubes + numbers / TOP cards, process table, KILL FOCUS NEW TASK), Clock (4 tubes + 2 small seconds tubes, colon lamps, date → `pane calendar` / time big, month ◂ ▸, today in a glowing card), Battery (meter + amber number + state + time / 72% big, history Bars in a card with alarm rules, RATE HEALTH CYCLES PROFILE cards, PROFILE steps), Caffeine (switch toggles, minutes on two tubes / STAYING AWAKE, timer keys, holders, idle cards), Capture (lens, plates-today or seconds-on-air on tubes, ON AIR lamp blinks, SHOT REC REGION WINDOW / STOP MIC / TARGET AUDIO TAKE key rows + plates in ivory frames), Messages (count tubes + TELEGRAMS → `dnd toggle`, typed ivory slips → message centre; DND greys all / title, ivory cards by app with live action keys, OPEN CLEAR DND), Todo (ivory pad, boxes with red ×, next washed orange, add line / lists on brass tabs, boxed add line, priority), Clipboard (ivory slips, swatch in a brass ring, newest warm / FIND slip, kind keys, list, STRIP sheet with PASTE DELETE), Workspaces (arched case, floors as small tubes round a brass arc, needle points at the current, FLOOR + name + windows / arched cards with orange window frames). Media compact `nixie/Media.qml` (position on tubes, title/artist screen, seek tube, knobs, VID VIS LYR tabs; elsewhere → `pane media`). Not done: Tray, Downloads, Files, Screenshots, Dock.
- `DeskPanel.qml`: `nixieFace`/`nixieFaces`, `devices.nixie`.
- Panes: `Pane.frame` "nixie" for `skyGlass`/`eraFrame`: `Nx.Wood` behind, bezel 12; MEDIA keeps its dot screen inside a brass rule; `nixieSheet` panes (message centre, toasts) are bare dots on the wood. `NotifLook.js` has `nixie` (ivory cards, tan rule, orange live, brass keys).
- Strip and rail: `Nx.Rack` under a bare DotSurface (TopStrip, SideBar), `DockItem.nixieForm` → `Nx.Docked`; `StatusWord.nixie` (label brass, reading digit); window title brass 5x7. No per-item casings.
- No backend, dropped: capture PAUSE/MARK/DELAY/AFTER, clipboard PIN, todo steps, clock events.
- Offscreen: `dot-shell-tools/harness/mkn.sh a<face>.qml [pitch]` → `n<face>.qml`, `ndock.qml` (strip/rail forms). The stub `Tokens` gained `flipped`, `neon`, `ink()`. Glows (MultiEffect) still don't render offscreen.

## 90s Nights: every panel (2026-10-20)

Done on request (out of order). The 90S NIGHTS boards draw most compact panels as a **slanted neon sign** (skewX −10°, a 3 px rim in the sunset `linear-gradient(135deg, #ffe600, #ff2e97 40%, #1fa8ff)`, dark round-dot glass `#0a0514`/unlit `#22123a`), big words in Audiowide italic filled yellow → pink, small print electric blue, readings yellow. Some boards were gadgets instead (a magenta pager, a camcorder body, straight notebook paper/clipboard). **The user rejected that mix** ("some slanted, some straight, no cohesion"; then "they still dont have same kind of borders, same kind of slant"). Rule now: **every compact panel is the same slanted sunset-rim sign** (`Plate`); the pager's LCD and the camcorder's viewfinder sit *inside* it, leaned the same 10° (`Leaning`); todo is cream paper inside the same rim and slant. **Every expanded panel and pane is the same upright sunset-rim sign** (`Plate { slant: false }`). Keep it that way for any new face.

- `nineties/` is `qs.nineties` (imported as `Ni`). Kit: `Ink` (palette pairs, Audiowide `fonts/Audiowide.ttf` (OFL, fetched) + VT323; `sunset`/`chrome`/`rim` gradient stop lists; strip inks `ink label pink mid face`), **`Plate`** (rim + dot glass DotSurface cut to the parallelogram; `slant`, `paper`, `dots`, `inside` = crisp layer masked to the glass, `leftAt(y)`/`rightAt(y)` = the glass's inner edges in px; contents in dots), `Leaning` (shears a whole gadget 10° inside a Plate), `Lean` (the Matrix4x4 skewX for any item), `Grad` (gradient-fills its children's ink via MultiEffect mask; works on dot canvases), `Word` (Audiowide from `fontAt` dots, else 5x7 scaled by whole dots; `stops`), `Say`, `Pen` (crisp Audiowide), `Mono` (crisp VT323, OSD shadow), `Key` (leaning outline key; `on` yellow, `tone` chrome/hot/pink/red/dim, `glyph`), `Glyph`, `Pill` (candy pill / yellow tag), `Osd` (camcorder key), `Rim` (open sunset frame), `Stat` (6° deep-violet card), `Cols` (history columns canvas, `up`/`low`/`warn`), `Fader`, `Can` (chrome battery; not `Cell`: Docked has an inline `Cell`), `Rocker`, `Sun`, `Channel`, `Chevrons`, `Pager`/`Cam` (with `bare`), `Ruled`, `Box`, `Slip`, `Dots` (lit-only bubble dots, `halo`), `Edge` (strip pink / rail blue 3 px rule), `Docked` (copy of nixie's, Ink aliases).
- Faces, compact and expanded: System (faders + TURBO = power profile performance toggle / TOP cards + process table + KILL FOCUS NEW TASK TURBO), Clock (chrome time, AM/PM, date → `pane calendar`, the striped sun in dots / calendar, today on a sunset slab), Battery (chrome can + percent / HISTORY, solid yellow where it charged, dashed alarm rules, PROFILE steps), Caffeine (rocker toggles, WIDE AWAKE / CHILL MODE / timers), Capture (viewfinder OSD: STBY/● REC blink, battery bars, counter, SHOT REC REGION WINDOW, STOP MIC / MENU · CAMERA rows TARGET AUDIO TAKE + recent), Messages (pager LCD: count, newest, LED, READ CLEAR, BEEP!/HOLD = dnd toggle, DND greys / PAGES by app, live actions as yellow tags, READ CLEAR HOLD), Todo (ruled paper, ♥, highlight next / lists on a yellow slab), Clipboard (tilted slips stepped along the slant / search, kinds, preview with Paste Delete), Workspaces (CH 02 · WEB + channel buttons / overview of leaning boxes). Media compact `nineties/Media.qml`. Not done: Tray, Downloads, Files, Screenshots, Dock.
- Wired: `DeskPanel` (`ninetiesFace`/`ninetiesFaces`, `devices.nineties`), `DockItem.ninetiesForm`, `StatusWord.nineties`, `TopStrip`/`SideBar` (`edge` 3 px + `Ni.Edge`, title 5x7 blue; the bar stays dark dot glass, not bare), `Pane.frame` "nineties" (`Ni.Plate` upright, bezel 9; MEDIA, message centre, toasts keep normal dot glass), `NotifLook.nineties`.
- Additive: `Matrix.js` 5x7 and 3x5 gained `♥`.
- No backend, dropped: capture PAUSE/MARK/DELAY/AFTER, clipboard Pin, todo steps, calendar events, audio SYSTEM.
- Gotchas hit again: `left`/`right`/`top` are FINAL (Plate uses `leftAt`/`rightAt`, rows use `rowTop`); a readonly property named like an id in scope resolves to the id (`title`).
- Offscreen: `dot-shell-tools/harness/mki.sh n<face>.qml` (nixie pages → `i<face>.qml`, nineties Tokens), `idock.qml`.
- Jagged slants (the user caught them): a DotSurface `shape` cuts by whole dots, so a slanted edge is a staircase. `Plate` draws the slanted rim as an odd-even **ring over** the glass and pulls the dot mask half a dot in from each slanted side; anything sheared with `Lean` needs `antialiasing: true` on its Rectangles, and `Leaning` shears inside a `layer.samples: 4` layer.

## Night Vision: every panel (2026-10-21)

Done on request (out of order). In the NIGHT VISION boards every panel is **one green phosphor dot screen** (the era's own DotSurface: glass `#040a03`, unlit `#0d260b`), cut to a rounded eyepiece and darkened toward its rim (`radial-gradient(ellipse 60% 70%, green .08 → black .75)`). **Compact = elliptic pill** (`80px / 70px`), **expanded = CRT squircle** (`120px / 60px`) with a 2 px `#0f3a0c` inner ring. Inks: lit `#7dff6a`, bright `#d6ffc9` (readings, picked), dim `#2fae2a` (small print). Crisp parts: 1 px green rules `#2b8a22`, white boxes round the picked/next row, white reticle corners, crosshair + ring, solid lit keys with dark words. Share Tech Mono.

- `nightvision/` is `qs.nightvision` (imported as `Nv`). Kit: `Ink` (pairs; `shade`/`bloom` for the vignette, `hover`; strip aliases `ink label pink red mid face`), **`Scope`** (glass + shaped DotSurface + vignette Canvas + CRT ring; `crt`, `dark`, `dots`, `cornerX/Y` overrides; children in dots, `over` = crisp layer; `px/py/dx/dy` map dots↔px since the grid is centred), `Key` (rule outline; `on` lit fill, `tone` bright/dim, `boxed`, `spacing`), `Box` (rule; `tone` bright/lit/deep, `dashed`, `bloom`), `Brackets`, `Say` (Share Tech Mono in dots, **bold** so strokes are a whole dot), `Pen`, `Cols`, `Trace` (ECG sweep, spikes = CPU), `Reticle`, `Pic` (picture mapped to the phosphor: DotSurface `imageMode`), `Edge`, `Docked` (copy of nineties').
- Faces, compact and expanded: System (VITALS · HOST trace + CPU/MEM/TEMP / TOP cards, process table with white box on the picked row, KILL FOCUS NEW TASK), Clock (reticle corners, LOCAL · E hh:mm, 24 h time, zulu · date → `pane calendar` / OPS CALENDAR, today ringed, ◂ ▸), Battery (PWR · CELL 1 cells between bright end rules, EST 3H41 / HISTORY chart, dashed alarm rules, dashed RATE HEALTH CYCLES PROFILE cards; PROFILE steps), Caffeine (SENTRY · DISPLAY, ON WATCH / STOOD DOWN, click toggles / timers keys, OTHER SENTRIES, STAND-DOWN SCHEDULE), Capture (BODYCAM finder: STBY or ● REC T+mm:ss blinking, SHOT REC REGION WINDOW (AREA/WIN when narrow), picked target boxed / TARGET AUDIO TAKE key rows + EVIDENCE thumbs in green), Messages (COMMS · n INBOUND, SILENT/CLEAR words, zulu-stamped rows → message centre; DND greys / COMMS LOG by app behind a green rule, live action keys, ACK CLEAR SILENT), Todo (MISSION OBJECTIVES, ✓/○, next boxed white, + ASSIGN OBJECTIVE field / lists as lit tabs, boxed add line, priority), Clipboard (intercepts, newest boxed, colours as phosphor discs, images in green dots / QRY, kind keys, INTERCEPT preview, PASTE DEL), Workspaces (SECTORS boxes with a lit contact per window, current white + haze / overview with windows as lit frames; `qs.aero` Geo). Media compact `nightvision/Media.qml` (round target art in green under a crosshair, TGT ACQ · CH 02, title, RNG seek dots (click seeks), transport glyphs via `qs.nineties` Glyph, [vid] [vis] [lyr]). Not done: Tray, Downloads, Files, Screenshots, Dock.
- Wired: `DeskPanel` (`nightvisionFace`/`nightvisionFaces`, `devices.nightvision`), `DockItem.nightvisionForm`, `StatusWord.nightvision` (label dim, reading bright), `TopStrip`/`SideBar` (`edge` 1 px + `Nv.Edge`, title dim 5x7; bar stays the green dot glass), `Pane.frame` "nightvision" (`Nv.Scope { crt; dots: false; cornerX 80; cornerY 40 }`, bezel 16, the pane's dots cut by `Pane.nvShape` to 64 x 24 px elliptic corners; MEDIA, message centre, toasts), `NotifLook.nightvision`, `Palettes.js` nightvision map gained `#2b8a22`.
- No backend, dropped: capture PAUSE/MARK/DELAY/AFTER, clipboard PIN, todo steps, calendar events.
- Gotchas: an `id: state` broke (Item's own property) — use other names. 3x5 `#` exists but reads like H. Expanded panels are small (caffeine 384x240), so the CRT radii scale with size (`min(w*.17,100)` / `min(h*.14,50)`).
- Offscreen: `dot-shell-tools/harness/mkg.sh i<face>.qml` (90s pages → `g<face>.qml`, nightvision Tokens), renders to the scratchpad path in the script.

## Tokyo Night / 90s Nights split (2026-10-21)

The user found the two eras too alike (both hot pink/cyan neon on purple-black) and wants a **peaceful** workspace: no confetti, nothing loud. Recoloured both; layouts untouched. Ink role names were kept (so `pink`/`blue`/`yellow` no longer describe the colour), see the header comments in `tokyo/Ink.qml` and `nineties/Ink.qml`.

- **Tokyo Night = RAIN CITY**: folke/tokyonight.nvim *night* (glass `#16161e`, unlit `#292e42`, tube blue `#7aa2f7`, readings cyan `#7dcfff`, small print `#bb9af7`, rules `#3b4261`, alarm `#f7768e`, new `Ink.orange` `#ff9e64` for the leading kanji word in `Words` and the clock's weekday kanji). Glow 0.35; Sign is one 2 px tube, the inner rule is a dim unlit 1 px line; Neon/Chip/Tube/Edge halos softened. ANSI is Tokyo Night's own. Light tone is Tokyo Night Day.
- **90s Nights = QUIET STORM**: a 1997 bedroom after midnight. Glass `#120d17` (aubergine), unlit `#2a1f30`, Jazz-cup teal `#36c9b8` (rim, small print), plum `#c776c4` (marks), glow-star `#dff57e` (readings), cream `#f6ead8`, coral alarm `#ff7a6b`. Plate rim is a solid 2 px teal (no sunset), Audiowide upright (no italic), glows roughly halved, no "!!" in words. Light tone is "Jazz cup paper" (off-white, muted teal/plum/olive).
- Scenes: tokyo rain is slower and sparser, with a street and puddle reflections; nineties is a new GLOW STARS scene (fading ceiling stars, crescent moon, slow lava lamp); the sunset grid became `sunsetGrid()`, used only by vapor.
- Offscreen check: harness pages `x<face>.qml` (copies of `i*`/`tdock` with the new tokens).
- Same day, after the user's look on the home workspace: 90s was too washed out, then "purple, not teal (Tokyo has teal)". Now: glass `#120d17`, unlit `#2a1f30`, **orchid `#c776c4` is the core** (`Ink.blue`: rim, strip + rail edge, small print, big words with pale orchid `#e8b4e4`), rose `#e57ba9` marks (`Ink.pink`), glow-star `#dff57e` readings, cream `#f6ead8`, glow 0.35. The notebook and slips are dark paper (`#1f1727` / `#2a1f33`) with cream ink. The clock's sun is a dim glow-star crescent moon (`Sun.qml`, a Canvas). Teal survives only as ANSI cyan and the pager LCD. Light tone "LILAC PAPER".

## 2026-10-21: notes, docked workspaces

- Notes are one-per-kind now (`Panels.spawn` and PanelsPane treat `deskOnly` like the home set). NotesPanel: empty, it sits in the era's casing (tokyo Sign+Glass, vfd Unit, aero Sky, blueprint Paper, vapor Win "Notepad", flap Housing, nixie Wood, nineties Plate, nightvision Scope); with text, only the words. The "notes" grip label is gone; the margins still drag.
- Docked workspaces in every era are `DockWs.qml` (DockItem `wsForm`, ahead of the era Docked forms, which still hold unused stripWs/railWs). Wall-to-wall cells, the current one marked per era (neon tube, VFD invert, aero bubble, blueprint/NV corner brackets, vapor push keys, flap tiles, nixie tube envelopes, 90s slant chip), a dot per window, + for an empty one. No peek on workspaces. DockItem hold-to-lift is 350 ms (was 200, ate slow clicks).
- House glyph `⌂` redrawn in Matrix.js (roof, eaves, walls, door).
