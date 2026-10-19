# Handoff: Dot Shell panels, one era at a time

Written 2026-10-18, rewritten 2026-10-19 for the next Claude Code chat. When the user says **"continue from handoff"**, do the "START HERE" section below, start to finish, for the next era. Read the whole file before touching anything; the dated sections further down say how each finished era was built.

## START HERE: perfect the next era

**Done eras:** Tokyo Night (`tokyo/`), VFD (`vfd/`), Frutiger Aero (`aero/`).
**Next era: Game Boy (`gameboy`)**, its design column header is `GAME BOY`. After that, in `Eras.qml` order: nixie, flap, nightvision, vapor, arcade, blueprint, then the ones before tokyo that are not done (phosphor, nineties, matrix). If the user names a different era, do that one.

"Perfect the era" means **everything below, in one go**, not one panel then stop. The user was angry when only System was done for aero ("you only did cpu panel, every other panel is slop"). Do all the panels, then ask for a screenshot.

### 1. Read the design for the era

- Source: `~/dotfiles/dot-shell-panels.html` (the canvas exported as static HTML). Each board has one column per era; that column is the spec.
- Cut the era's column out of every board and render it (tools in `~/dotfiles/dot-shell-tools/`, output into your scratchpad):
  - `python3 -I ~/dotfiles/dot-shell-tools/extract.py ~/dotfiles/dot-shell-panels.html <scratch>/<era> "GAME BOY"` (the third argument is the start of the era's column header: `GAME BOY`, `NIXIE`, `SPLIT-FLAP`, `NIGHT VISION`, `VAPORWAVE`, `ARCADE`, `BLUEPRINT`, `PHOSPHOR`, `90S NIGHTS`, `MATRIX`; quote it).
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

- After every save: `timeout 5 qs log -p ~/.config/quickshell/dotshell 2>&1 | grep -E "Reloading|Loaded|caused|Failed" | tail -3`. Wait a few seconds; you want the last line "Configuration Loaded" with no `caused by` after it. Older errors further up (PanelNode[540], DeskPanel[51], TopStrip[147/203], LauncherPane `pad`) are stale.
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

## (History) the original plan for the media panel in the other eras

Superseded: Tokyo, VFD and aero media faces exist (`MediaTokyo.qml`, `MediaDevice.qml`, `aero/Media.qml`). Kept for the `Hardware.js` notes.

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

## Panel manager (done)

`panes/PanelsPane.qml` (Super+O), `Panels.close(id)` / `Panels.open(id, where)`, right-click a panel to close it to the shelf.

## Offscreen test

Harness: `~/dotfiles/dot-shell-tools/harness/`. `./run.sh <page.qml> <out.png>` runs `sync.sh` (mirrors root QML + `tokyo/ vfd/ aero/` into `w/` with service stubs from `stubs/`), then renders with `QT_QUICK_BACKEND=rhi QT_QPA_PLATFORM=offscreen qml6`. Pages are `a<face>.qml` (one per aero face, with sample `ctx`): copy one, swap `import "aero" as V` for the new era dir and add it to the `for d in tokyo vfd aero` lists in `sync.sh`. Stubs: Tokens (era "vfd" colours; set `Tokens.era` etc. in `Component.onCompleted` for another era), Feeds, Notifs, Power, Media, Lyrics, LyricLine, Spectrum, MatchVideo, Process. Write the PNGs to your scratchpad, not the repo.

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
