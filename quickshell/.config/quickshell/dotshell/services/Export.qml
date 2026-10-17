pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Era export: the era on screen (after the wallpaper hue, see Tokens.hue)
// becomes the theme of the apps around the shell. Rewritten whenever the era
// changes; nothing here goes into the repo.
//
//   Ghostty  ~/.config/ghostty/dotshell.conf   included by the repo's config
//            (config-file = ?dotshell.conf), reloaded with SIGUSR2
//   Neovim   ~/.local/share/nvim/site/colors/dotshell.lua   `:colorscheme dotshell`;
//            running nvims that use it reload it
//   GTK 3    ~/.local/share/themes/DotShell/gtk-3.0/gtk{,-dark}.css   a theme
//            of era colors over the theme you had (remembered in
//            ${XDG_STATE_HOME}/dotshell/gtk-base). GTK never rereads gtk.css in
//            a running app, but it reloads a theme when the theme name
//            changes, so each new era swaps gtk-theme between DotShell and
//            DotShell-B (a link to it): running GTK 3 apps, Firefox's chrome
//            among them, recolor live. ~/.config/gtk-3.0/gtk.css is kept
//            empty when ours: colors there would outrank the theme forever
//   GTK 4    ~/.config/gtk-4.0/gtk.css   only when missing or written by us
//            (first line has "dotshell:"); libadwaita's named colors and
//            variables. libadwaita reads it at start only, and only that file
//            outranks libadwaita's own colors, so Files (Nautilus) is restarted
//            under the theme flip with its windows kept (`dotreopen`)
//            Also flips org.gnome.desktop.interface color-scheme dark/light.
//   Qt       ~/.config/qt6ct/colors/dotshell.conf   pick it once in qt6ct
//   greeter  /var/lib/dotshell-greeter/dotshell/{tokens.json,wallpaper,user}
//            the login screen's copy of the era, display tokens, wallpaper and
//            user name (greeter.qml runs as `greeter`, which cannot read ~);
//            only when system/install.sh has made that folder ours
//   mpv      ${XDG_STATE_HOME}/dotshell/mpv-led.conf   the LED video shader's
//            colors, pitch and depth (mpv/.config/mpv/shaders/dotled.glsl);
//            Dot TV loads it at start, `dottv led reload` while it runs
//   Firefox  <profile>/chrome/userChrome.css, userContent.css   in every
//            install's default profile (installs.ini), guarded like GTK;
//            user.js gets a dotshell block that turns userChrome on. The
//            chrome takes its colors from GTK system colors (the DotShell
//            theme), so it follows an era live; userContent (new tab, about:
//            pages) is read at start only
//   rmpc     ~/.config/rmpc/themes/dotshell.ron   the repo's config.ron picks
//            it; rmpc hot-reloads it
//   cava     ~/.config/cava/themes/dotshell   the repo's config picks it;
//            running cavas reload colors on SIGUSR2
//   Hyprland ${XDG_STATE_HOME}/dotshell/hypr.lua   the era ramp, the dot grid
//            and the `winshade` token for the per-window LED shading
//            (hypr/.config/hypr/lua/dotshell.lua); `dotshell.apply()` is run
//            in Hyprland's Lua right after
//   cursor   ~/.local/share/icons/DotShell   a pixel cursor theme drawn in the
//            era's tubes (hyprcursor and XCursor, by the `dotcursor` script);
//            set live with `hyprctl setcursor` and in gsettings
//   VSCode   ~/.config/{Code,Code - OSS,VSCodium,Cursor}/User/settings.json
//            the era as workbench, terminal and syntax colors over the
//            built-in Modern theme; merged in, guarded (see vscodeMerge).
//            VSCode recolors live
//   sounds   ${XDG_STATE_HOME}/dotshell/sounds/<era>/*.wav   the era's UI
//            sounds (services/Sound.qml), synthesized by `dotsound`
//
// Theme flip: on an era change the windows of the apps that recolor live
// (`live`, below) turn over as flip dots before the export and back after
// it, so no app is ever seen switching colors (see "Theme flip").
//
// matugen only picks the hue (Tokens.qml); the export keeps the era's own
// levels instead of a Material palette, so the apps share the era's mood.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || home + "/.config"
    readonly property string dataHome: Quickshell.env("XDG_DATA_HOME") || home + "/.local/share"
    readonly property string marker: "dotshell:"
    readonly property string greeterDir: "/var/lib/dotshell-greeter/dotshell"

    // ── Color helpers ───────────────────────────────────────────────
    function hex(c: color): string {
        const h = v => Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16).padStart(2, "0");
        return "#" + h(c.r) + h(c.g) + h(c.b);
    }
    function mix(a: string, b: string, t: real): string {
        const x = Qt.color(a), y = Qt.color(b);
        return hex(Qt.rgba(x.r + (y.r - x.r) * t, x.g + (y.g - x.g) * t, x.b + (y.b - x.b) * t, 1));
    }
    function argb(c: string): string {
        return "#ff" + hex(Qt.color(c)).slice(1);
    }

    // The era as app colors: background, text, the three tubes and 16 ANSI.
    function palette(e: var): var {
        const light = !!e.light;
        const bg = e.glass;
        const fg = light ? e.ansi[0] : e.ansi[7];
        const ansi = e.ansi.slice(0, 8);
        // Brights: lifted toward white on dark glass, pressed toward ink on light.
        const bright = ansi.map((c, i) => i === 0 ? mix(bg, fg, 0.45) : light ? mix(c, "#000000", 0.18) : mix(c, "#ffffff", 0.25));
        return {
            id: e.id,
            name: e.name,
            light: light,
            bg: bg,
            fg: fg,
            s0: e.slots[0],
            s1: e.slots[1],
            s2: e.slots[2],
            unlit: e.unlit,
            dim: mix(bg, fg, 0.45),
            raised: mix(bg, e.unlit, 0.6),
            sel: e.unlit,
            ansi: ansi.concat(bright)
        };
    }

    // ── Ghostty ─────────────────────────────────────────────────────
    function ghostty(p: var): string {
        let s = "# " + marker + " generated by Dot Shell (services/Export.qml) for the " + p.name + " era.\n" + "# Rewritten on every era change; edit Eras.qml instead.\n" + "background = " + p.bg + "\n" + "foreground = " + p.fg + "\n" + "cursor-color = " + p.s0 + "\n" + "cursor-text = " + p.bg + "\n" + "selection-background = " + p.sel + "\n" + "selection-foreground = " + p.fg + "\n";
        for (let i = 0; i < 16; i++)
            s += "palette = " + i + "=" + p.ansi[i] + "\n";
        return s;
    }

    // ── Neovim ──────────────────────────────────────────────────────
    function nvim(p: var): string {
        const a = p.ansi;
        const c = {
            bg: p.bg, fg: p.fg, s0: p.s0, s1: p.s1, s2: p.s2, unlit: p.unlit, dim: p.dim, raised: p.raised,
            red: a[1], green: a[2], yellow: a[3], blue: a[4], magenta: a[5], cyan: a[6]
        };
        const groups = [
            ["Normal", "fg = c.fg, bg = c.bg"],
            ["NormalFloat", "fg = c.fg, bg = c.raised"],
            ["FloatBorder", "fg = c.s1, bg = c.raised"],
            ["WinSeparator", "fg = c.unlit"],
            ["Comment", "fg = c.dim"],
            ["Constant", "fg = c.s1"],
            ["String", "fg = c.green"],
            ["Character", "fg = c.green"],
            ["Number", "fg = c.yellow"],
            ["Boolean", "fg = c.yellow"],
            ["Identifier", "fg = c.fg"],
            ["Function", "fg = c.s0"],
            ["Statement", "fg = c.s2"],
            ["Keyword", "fg = c.s2"],
            ["Operator", "fg = c.fg"],
            ["PreProc", "fg = c.magenta"],
            ["Type", "fg = c.cyan"],
            ["Special", "fg = c.s1"],
            ["Delimiter", "fg = c.dim"],
            ["Underlined", "fg = c.s0, underline = true"],
            ["Error", "fg = c.red"],
            ["Todo", "fg = c.bg, bg = c.s2"],
            ["LineNr", "fg = c.unlit"],
            ["CursorLineNr", "fg = c.s0"],
            ["CursorLine", "bg = c.raised"],
            ["ColorColumn", "bg = c.raised"],
            ["SignColumn", "bg = c.bg"],
            ["Visual", "bg = c.unlit"],
            ["Search", "fg = c.bg, bg = c.s1"],
            ["IncSearch", "fg = c.bg, bg = c.s0"],
            ["CurSearch", "fg = c.bg, bg = c.s0"],
            ["MatchParen", "fg = c.s0, bold = true"],
            ["StatusLine", "fg = c.s0, bg = c.raised"],
            ["StatusLineNC", "fg = c.dim, bg = c.bg"],
            ["TabLine", "fg = c.dim, bg = c.bg"],
            ["TabLineSel", "fg = c.s0, bg = c.raised"],
            ["TabLineFill", "bg = c.bg"],
            ["Pmenu", "fg = c.fg, bg = c.raised"],
            ["PmenuSel", "fg = c.bg, bg = c.s0"],
            ["PmenuThumb", "bg = c.s1"],
            ["Folded", "fg = c.dim, bg = c.raised"],
            ["NonText", "fg = c.unlit"],
            ["Directory", "fg = c.s1"],
            ["Title", "fg = c.s2, bold = true"],
            ["DiagnosticError", "fg = c.red"],
            ["DiagnosticWarn", "fg = c.yellow"],
            ["DiagnosticInfo", "fg = c.blue"],
            ["DiagnosticHint", "fg = c.cyan"],
            ["DiagnosticOk", "fg = c.green"],
            ["DiffAdd", "fg = c.green"],
            ["DiffChange", "fg = c.yellow"],
            ["DiffDelete", "fg = c.red"],
            ["DiffText", "fg = c.bg, bg = c.yellow"],
            ["Added", "fg = c.green"],
            ["Changed", "fg = c.yellow"],
            ["Removed", "fg = c.red"]
        ];
        let s = "-- " + marker + " generated by Dot Shell (services/Export.qml) for the " + p.name + " era.\n" + "-- Rewritten on every era change; edit Eras.qml instead.\n" + "vim.cmd('highlight clear')\n" + "if vim.fn.exists('syntax_on') == 1 then vim.cmd('syntax reset') end\n" + "vim.o.background = '" + (p.light ? "light" : "dark") + "'\n" + "vim.g.colors_name = 'dotshell'\n\n" + "local c = {\n";
        for (const k of Object.keys(c))
            s += "  " + k + " = '" + c[k] + "',\n";
        s += "}\nlocal function hl(g, o) vim.api.nvim_set_hl(0, g, o) end\n\n";
        for (const g of groups)
            s += "hl('" + g[0] + "', { " + g[1] + " })\n";
        s += "\nlocal t = { " + p.ansi.map(x => "'" + x + "'").join(", ") + " }\n" + "for i = 0, 15 do vim.g['terminal_color_' .. i] = t[i + 1] end\n";
        return s;
    }

    // ── GTK (3 and 4 / libadwaita) ──────────────────────────────────
    // GTK 3: the DotShell theme's body (the script puts an @import of your
    // base theme above it). Named colors for apps that read them, and the
    // widgets Firefox takes its system colors from: window (-moz-dialog),
    // headerbar (-moz-headerbar), entry (Field), selection (SelectedItem),
    // links (-moz-nativehyperlinktext, visited), disabled labels (GrayText).
    function gtk3Theme(p: var): string {
        const def = (n, v) => "@define-color " + n + " " + v + ";\n";
        return "/* " + marker + " generated by Dot Shell for the " + p.name + " era; rewritten on every era change. */\n" + def("theme_bg_color", p.bg) + def("theme_fg_color", p.fg) + def("theme_base_color", p.bg) + def("theme_text_color", p.fg) + def("theme_selected_bg_color", p.s0) + def("theme_selected_fg_color", p.bg) + def("insensitive_fg_color", p.dim) + def("borders", p.unlit) + def("link_color", p.s1) + def("accent_color", p.s0) + def("accent_bg_color", p.s0) + def("accent_fg_color", p.bg) + def("window_bg_color", p.bg) + def("window_fg_color", p.fg) + def("view_bg_color", p.bg) + def("view_fg_color", p.fg) + def("headerbar_bg_color", p.raised) + def("headerbar_fg_color", p.fg) + `
window.background, .background { background-color: ${p.bg}; color: ${p.fg}; }
headerbar, .titlebar, headerbar.titlebar { background: ${p.raised}; color: ${p.fg}; border-color: ${p.unlit}; box-shadow: none; }
.view, textview text, iconview, treeview.view { background-color: ${p.bg}; color: ${p.fg}; }
entry, spinbutton:not(.vertical) { background-color: ${p.raised}; color: ${p.fg}; border-color: ${p.unlit}; }
*:selected, *:selected:focus, selection, .view:selected, entry selection, textview text selection { background-color: ${p.s0}; color: ${p.bg}; }
*:link, button:link, label:link { color: ${p.s1}; }
*:visited, button:visited, label:visited { color: ${p.s2}; }
label:disabled { color: ${p.dim}; }
menu, .menu, .context-menu, popover.background, tooltip.background { background-color: ${p.raised}; color: ${p.fg}; }
menuitem:hover { background-color: ${p.unlit}; color: ${p.s0}; }
`;
    }

    // GTK 4: named colors and libadwaita's CSS variables, which libadwaita
    // 1.6+ widgets read instead (Nautilus, the file manager). (GTK 3 gets a
    // marker-only file: its colors live in the theme above.)
    function gtk(p: var, four: bool): string {
        if (!four)
            return "/* " + marker + " written by Dot Shell: GTK 3 colors come from the DotShell theme (~/.local/share/themes/DotShell), which follows the era live. Delete this line to keep the file as your own. */\n";
        const def = (n, v) => "@define-color " + n + " " + v + ";\n";
        const vars = [["accent-color", p.s0], ["accent-bg-color", p.s0], ["accent-fg-color", p.bg], ["window-bg-color", p.bg], ["window-fg-color", p.fg], ["view-bg-color", p.bg], ["view-fg-color", p.fg], ["headerbar-bg-color", p.raised], ["headerbar-fg-color", p.fg], ["headerbar-backdrop-color", p.bg], ["sidebar-bg-color", p.raised], ["sidebar-fg-color", p.fg], ["sidebar-backdrop-color", p.bg], ["secondary-sidebar-bg-color", p.bg], ["secondary-sidebar-fg-color", p.fg], ["card-bg-color", p.raised], ["card-fg-color", p.fg], ["dialog-bg-color", p.raised], ["dialog-fg-color", p.fg], ["popover-bg-color", p.raised], ["popover-fg-color", p.fg], ["thumbnail-bg-color", p.raised], ["thumbnail-fg-color", p.fg]];
        const root = four ? ":root {\n" + vars.map(v => "  --" + v[0] + ": " + v[1] + ";\n").join("") + "}\n" : "";
        return "/* " + marker + " generated by Dot Shell for the " + p.name + " era. Delete this line to keep the file as your own. */\n" + root + def("accent_color", p.s0) + def("accent_bg_color", p.s0) + def("accent_fg_color", p.bg) + def("window_bg_color", p.bg) + def("window_fg_color", p.fg) + def("view_bg_color", p.bg) + def("view_fg_color", p.fg) + def("headerbar_bg_color", p.raised) + def("headerbar_fg_color", p.fg) + def("headerbar_backdrop_color", p.bg) + def("sidebar_bg_color", p.raised) + def("sidebar_fg_color", p.fg) + def("card_bg_color", p.raised) + def("card_fg_color", p.fg) + def("dialog_bg_color", p.raised) + def("dialog_fg_color", p.fg) + def("popover_bg_color", p.raised) + def("popover_fg_color", p.fg) + def("theme_bg_color", p.bg) + def("theme_fg_color", p.fg) + def("theme_base_color", p.bg) + def("theme_text_color", p.fg) + def("theme_selected_bg_color", p.s0) + def("theme_selected_fg_color", p.bg) + def("borders", p.unlit);
    }

    // ── Qt (qt6ct color scheme) ─────────────────────────────────────
    // Roles in QPalette order: WindowText Button Light Midlight Dark Mid Text
    // BrightText ButtonText Base Window Shadow Highlight HighlightedText Link
    // LinkVisited AlternateBase NoRole ToolTipBase ToolTipText PlaceholderText Accent
    function qt(p: var): string {
        const roles = (fg, bg) => [fg, p.raised, mix(p.raised, "#ffffff", 0.2), mix(p.raised, "#ffffff", 0.1), mix(p.bg, "#000000", 0.3), p.unlit, fg, p.s0, fg, bg, p.bg, "#000000", p.s0, p.bg, p.s1, p.s2, p.raised, p.bg, p.raised, p.fg, p.dim, p.s0].map(argb).join(", ");
        const active = roles(p.fg, p.bg);
        const disabled = roles(p.dim, p.bg);
        return "; " + marker + " generated by Dot Shell for the " + p.name + " era.\n[ColorScheme]\nactive_colors=" + active + "\ndisabled_colors=" + disabled + "\ninactive_colors=" + active + "\n";
    }

    // ── mpv (Dot TV's LED shader) ───────────────────────────────────
    // The MEDIA pane's SCREEN settings (Tv.screen) in the era's colors, so the
    // Dot TV window looks like the pane. color = raw turns the shader off
    // (the `# dottv-led off` line, read by `dottv led reload`).
    function mpv(e: var): string {
        const sc = Tv.screen;
        const shapeOf = s => s === "square" ? 1 : s === "bubble" ? 2 : 0;
        const modes = { era: 0, mono: 1, "8": 2, "16": 3, "24": 4, raw: 4 };
        const f = v => String(Math.round(v * 1000) / 1000);
        const rgb = (name, c) => {
            const q = Qt.color(c);
            return [[name + "r", q.r], [name + "g", q.g], [name + "b", q.b]];
        };
        const kv = [["pitch", sc.pitch], ["dotsize", sc.dotSize / 100], ["shape", sc.shape === "era" ? shapeOf(e.shape) : shapeOf(sc.shape)], ["mode", modes[sc.color]], ["dither", sc.dither ? 1 : 0], ["glow", sc.glow / 100]].concat(rgb("r0", e.ramp[0]), rgb("r1", e.ramp[1]), rgb("r2", e.ramp[2]), rgb("r3", e.ramp[3]), rgb("tb", e.slots[0]), rgb("un", e.unlit), rgb("gl", e.glass));
        return "# " + marker + " generated by Dot Shell for the " + e.name + " era (Dot TV's LED shader).\n# dottv-led " + (sc.color === "raw" ? "off" : "on") + "\nglsl-shader-opts=" + kv.map(x => x[0] + "=" + f(x[1])).join(",") + "\n";
    }

    // ── Firefox ─────────────────────────────────────────────────────
    // The chrome as a sign board: era colors, the pixel font, no rounded
    // corners, no titlebar buttons (Hyprland has none either), and the
    // selected tab or field marked by a lit outline rather than a fill.
    // The colors are GTK system colors, not the era's hex values: Firefox
    // rereads those when the DotShell GTK theme is swapped, so the chrome
    // follows each era without a restart. Light or dark follows
    // org.gnome.desktop.interface color-scheme, also set by the export.
    function firefoxChrome(p: var): string {
        return "/* " + marker + " generated by Dot Shell. Delete this line to keep the file as your own. */\n" + `:root {
  --dot-bg: -moz-dialog;
  --dot-fg: -moz-dialogtext;
  --dot-raised: -moz-headerbar;
  --dot-unlit: color-mix(in srgb, var(--dot-fg) 16%, var(--dot-bg));
  --dot-dim: GrayText;
  --dot-s0: SelectedItem;
  --dot-s1: -moz-nativehyperlinktext;
  --dot-s2: -moz-nativevisitedhyperlinktext;
  /* Departure Mono only stays crisp at whole multiples of 11 px. */
  --dot-font: "DepartureMono Nerd Font", "Departure Mono", monospace;
  --dot-font-size: 22px;
}

/* Firefox's own tokens (names as of Firefox 157). Set on the toolbars and
   panels as well as the root, since some are redefined there. */
:root, #navigator-toolbox, toolbar, #urlbar, #searchbar, panel, menupopup, #sidebar-main, #sidebar-box {
  --toolbox-background-color: var(--dot-bg) !important;
  --toolbox-background-color-inactive: var(--dot-bg) !important;
  --toolbox-text-color: var(--dot-fg) !important;
  --toolbox-text-color-inactive: var(--dot-dim) !important;
  --toolbar-background-color: var(--dot-bg) !important;
  --toolbar-bg-color: var(--dot-bg) !important;
  --toolbar-text-color: var(--dot-fg) !important;
  --toolbar-border-color: var(--dot-unlit) !important;
  --toolbar-field-background-color: var(--dot-raised) !important;
  --toolbar-field-background-color-focus: var(--dot-raised) !important;
  --toolbar-field-text-color: var(--dot-fg) !important;
  --toolbar-field-text-color-focus: var(--dot-s0) !important;
  --toolbar-field-border-color: var(--dot-unlit) !important;
  --toolbar-field-border-color-focus: var(--dot-s0) !important;
  --toolbarbutton-icon-fill: var(--dot-fg) !important;
  --toolbarbutton-icon-fill-attention: var(--dot-s2) !important;
  --toolbarbutton-background-color-hover: var(--dot-unlit) !important;
  --toolbarbutton-background-color-active: var(--dot-raised) !important;
  --toolbarbutton-outline-color-selected: var(--dot-s0) !important;
  --toolbarseparator-color: var(--dot-unlit) !important;
  --tabs-navbar-separator-color: var(--dot-unlit) !important;
  --tab-background-color: transparent !important;
  --tab-background-color-hover: var(--dot-raised) !important;
  --tab-background-color-selected: var(--dot-bg) !important;
  --tab-text-color: var(--dot-dim) !important;
  --tab-text-color-hover: var(--dot-fg) !important;
  --tab-text-color-selected: var(--dot-s0) !important;
  --tab-border-color-selected: var(--dot-s0) !important;
  --tab-box-shadow-selected: none !important;
  --tab-loading-fill: var(--dot-s1) !important;
  --tab-attention-dot-color: var(--dot-s2) !important;
  --tabpanel-background-color: var(--dot-bg) !important;
  --chrome-content-separator-color: var(--dot-unlit) !important;
  --urlbar-background-color: var(--dot-raised) !important;
  --urlbar-background-color-focus: var(--dot-raised) !important;
  --urlbar-box-background-color: var(--dot-raised) !important;
  --urlbar-box-background-color-hover: var(--dot-unlit) !important;
  --urlbar-box-text-color: var(--dot-fg) !important;
  --urlbarview-background-color-hover: var(--dot-unlit) !important;
  --urlbarview-background-color-selected: var(--dot-unlit) !important;
  --urlbarview-text-color-selected: var(--dot-s0) !important;
  --urlbarview-text-color-secondary: var(--dot-dim) !important;
  --urlbarview-text-color-action: var(--dot-s1) !important;
  --urlbarview-separator-color: var(--dot-unlit) !important;
  --panel-background-color: var(--dot-raised) !important;
  --panel-text-color: var(--dot-fg) !important;
  --panel-border-color: var(--dot-s1) !important;
  --panel-box-shadow: none !important;
  --panel-list-background-color: var(--dot-raised) !important;
  --panel-list-text-color: var(--dot-fg) !important;
  --panel-list-border-color: var(--dot-s1) !important;
  --panel-list-box-shadow: none !important;
  --sidebar-launcher-surface-color: var(--dot-bg) !important;
  --sidebar-border-color: var(--dot-unlit) !important;
  --focus-outline-color: var(--dot-s0) !important;
  --link-color: var(--dot-s1) !important;
  --color-accent-primary: var(--dot-s0) !important;
  --color-accent-primary-hover: var(--dot-s1) !important;
  --color-accent-primary-active: var(--dot-s2) !important;
  --button-background-color-primary: var(--dot-s0) !important;
  --button-text-color-primary: var(--dot-bg) !important;
  --background-color-box: var(--dot-raised) !important;
  --background-color-canvas: var(--dot-bg) !important;
  --text-color: var(--dot-fg) !important;
  --border-radius-xsmall: 0 !important;
  --border-radius-small: 0 !important;
  --border-radius-medium: 0 !important;
  --border-radius-large: 0 !important;
  --border-radius-xlarge: 0 !important;
  --border-radius-circle: 0 !important;
  --button-border-radius: 0 !important;
  --tab-border-radius: 0 !important;
  --toolbarbutton-border-radius: 0 !important;
  --urlbar-border-radius: 0 !important;
  --urlbar-inner-border-radius: 0 !important;
  --urlbar-background-border-radius: 0 !important;
  --urlbarview-border-radius: 0 !important;
  --panel-border-radius: 0 !important;
  --panel-list-border-radius: 0 !important;
  --panel-item-button-border-radius: 0 !important;
}

#navigator-toolbox, #nav-bar, #TabsToolbar, #PersonalToolbar, #titlebar {
  background: var(--dot-bg) !important;
  color: var(--dot-fg) !important;
  border-color: var(--dot-unlit) !important;
}

/* The pixel font across the chrome. */
#navigator-toolbox, #navigator-toolbox :is(input, label, description, .toolbarbutton-text),
#urlbar, #urlbar input, .urlbarView, .tab-label, #sidebar-box, #sidebar-main,
menupopup, menu, menuitem, panel, panelview, findbar, #statuspanel-label {
  font-family: var(--dot-font) !important;
  font-size: var(--dot-font-size) !important;
}
.tab-label { text-transform: uppercase; }

/* Tabs: square, unfilled; the selected one is a lit outline. */
.tab-background {
  border-radius: 0 !important;
  box-shadow: none !important;
  margin-block: 2px !important;
}
.tabbrowser-tab[selected] .tab-background,
.tabbrowser-tab[multiselected] .tab-background {
  background: var(--dot-bg) !important;
  outline: 1px solid var(--dot-s0) !important;
  outline-offset: -1px !important;
}
.tabbrowser-tab:not([selected]) .tab-label { color: var(--dot-dim) !important; }
.tab-close-button { border-radius: 0 !important; }

/* Fields and panels: square, one-dot borders. */
#urlbar-background, #searchbar, .urlbar-input-box, #urlbar[breakout-extend] #urlbar-background {
  border-radius: 0 !important;
  box-shadow: none !important;
}
#urlbar[focused] #urlbar-background { outline: 1px solid var(--dot-s0) !important; outline-offset: -1px !important; }
menupopup, panel { --panel-border-radius: 0 !important; --panel-shadow-margin: 0 !important; }
menupopup::part(content), panel::part(content) { border-radius: 0 !important; box-shadow: none !important; }
menuitem[_moz-menuactive], menu[_moz-menuactive] { background: var(--dot-unlit) !important; color: var(--dot-s0) !important; }

/* No window buttons (Hyprland has no window chrome). */
.titlebar-buttonbox-container, .titlebar-spacer { display: none !important; }
`;
    }

    // New tab, home and the about: pages in the era; scrollbars everywhere.
    // Site pages keep their own colors.
    function firefoxContent(p: var): string {
        return "/* " + marker + " generated by Dot Shell for the " + p.name + " era. Delete this line to keep the file as your own. */\n" + `:root { scrollbar-color: ${p.s1} transparent; }

@-moz-document url("about:newtab"), url("about:home"), url("about:blank"), url("about:privatebrowsing"), url-prefix("about:preferences"), url-prefix("about:addons") {
  :root, body {
    --newtab-background-color: ${p.bg} !important;
    --newtab-background-color-secondary: ${p.raised} !important;
    --newtab-text-primary-color: ${p.fg} !important;
    --newtab-primary-action-background: ${p.s0} !important;
    --in-content-page-background: ${p.bg} !important;
    --in-content-page-color: ${p.fg} !important;
    --in-content-box-background: ${p.raised} !important;
    --in-content-primary-button-background: ${p.s0} !important;
    --in-content-primary-button-text-color: ${p.bg} !important;
    --color-accent-primary: ${p.s0} !important;
    --background-color-canvas: ${p.bg} !important;
    --background-color-box: ${p.raised} !important;
    --text-color: ${p.fg} !important;
    --border-radius-small: 0 !important;
    --border-radius-medium: 0 !important;
    --border-radius-large: 0 !important;
    background-color: ${p.bg} !important;
    color: ${p.fg} !important;
  }
  ::selection { background: ${p.unlit}; color: ${p.s0}; }
}
`;
    }

    // ── VSCode ──────────────────────────────────────────────────────
    // Settings, not a theme extension: VSCode watches settings.json and
    // recolors live. The built-in Modern theme (dark or light, after the era)
    // is the base; the workbench, the terminal and the syntax are overridden
    // with the era's colors, like Neovim's groups above.
    function vscode(p: var): var {
        const a = p.ansi;
        const [red, green, yellow, blue, magenta, cyan] = [a[1], a[2], a[3], a[4], a[5], a[6]];
        const clear = "#00000000";
        // #rrggbbaa: VSCode reads the last pair as alpha.
        const al = (c, x) => hex(Qt.color(c)) + x;
        const colors = {
            "focusBorder": p.s0, "foreground": p.fg, "descriptionForeground": p.dim, "errorForeground": red,
            "widget.border": p.unlit, "widget.shadow": clear, "selection.background": p.sel, "sash.hoverBorder": p.s0,
            "textLink.foreground": p.s1, "textLink.activeForeground": p.s0, "icon.foreground": p.fg,
            "editor.background": p.bg, "editor.foreground": p.fg, "editorCursor.foreground": p.s0,
            "editorLineNumber.foreground": p.unlit, "editorLineNumber.activeForeground": p.s0,
            "editor.selectionBackground": p.sel, "editor.inactiveSelectionBackground": p.raised,
            "editor.lineHighlightBackground": p.raised, "editor.lineHighlightBorder": clear,
            "editor.findMatchBackground": al(p.s0, "55"), "editor.findMatchHighlightBackground": al(p.s1, "40"),
            "editor.wordHighlightBackground": p.unlit, "editor.wordHighlightStrongBackground": p.unlit,
            "editorIndentGuide.background1": p.unlit, "editorIndentGuide.activeBackground1": p.dim,
            "editorWhitespace.foreground": p.unlit, "editorRuler.foreground": p.unlit,
            "editorBracketMatch.background": clear, "editorBracketMatch.border": p.s0,
            "editorGutter.background": p.bg, "editorGutter.addedBackground": green,
            "editorGutter.modifiedBackground": yellow, "editorGutter.deletedBackground": red,
            "editorError.foreground": red, "editorWarning.foreground": yellow, "editorInfo.foreground": blue,
            "editorOverviewRuler.border": p.bg,
            "editorWidget.background": p.raised, "editorWidget.border": p.s1,
            "editorSuggestWidget.background": p.raised, "editorSuggestWidget.border": p.s1,
            "editorSuggestWidget.foreground": p.fg, "editorSuggestWidget.selectedBackground": p.unlit,
            "editorSuggestWidget.selectedForeground": p.s0, "editorSuggestWidget.highlightForeground": p.s0,
            "editorHoverWidget.background": p.raised, "editorHoverWidget.border": p.s1,
            "editorGroup.border": p.unlit, "editorGroupHeader.tabsBackground": p.bg, "editorGroupHeader.noTabsBackground": p.bg,
            "tab.activeBackground": p.bg, "tab.inactiveBackground": p.bg, "tab.hoverBackground": p.raised,
            "tab.activeForeground": p.s0, "tab.inactiveForeground": p.dim, "tab.unfocusedActiveForeground": p.fg,
            "tab.border": p.bg, "tab.activeBorderTop": p.s0, "tab.unfocusedActiveBorderTop": p.unlit,
            "titleBar.activeBackground": p.bg, "titleBar.activeForeground": p.fg,
            "titleBar.inactiveBackground": p.bg, "titleBar.inactiveForeground": p.dim, "titleBar.border": p.unlit,
            "activityBar.background": p.bg, "activityBar.foreground": p.s0, "activityBar.inactiveForeground": p.dim,
            "activityBar.border": p.unlit, "activityBar.activeBorder": p.s0,
            "activityBarBadge.background": p.s2, "activityBarBadge.foreground": p.bg,
            "sideBar.background": p.bg, "sideBar.foreground": p.fg, "sideBar.border": p.unlit,
            "sideBarTitle.foreground": p.s1, "sideBarSectionHeader.background": p.bg,
            "sideBarSectionHeader.foreground": p.s1, "sideBarSectionHeader.border": p.unlit,
            "list.activeSelectionBackground": p.unlit, "list.activeSelectionForeground": p.s0,
            "list.inactiveSelectionBackground": p.raised, "list.inactiveSelectionForeground": p.fg,
            "list.hoverBackground": p.raised, "list.focusOutline": p.s0, "list.highlightForeground": p.s0,
            "statusBar.background": p.raised, "statusBar.foreground": p.s0, "statusBar.border": p.unlit,
            "statusBar.noFolderBackground": p.raised, "statusBar.debuggingBackground": p.s2, "statusBar.debuggingForeground": p.bg,
            "statusBarItem.remoteBackground": p.s0, "statusBarItem.remoteForeground": p.bg,
            "panel.background": p.bg, "panel.border": p.unlit, "panelTitle.activeForeground": p.s0,
            "panelTitle.inactiveForeground": p.dim, "panelTitle.activeBorder": p.s0,
            "terminal.background": p.bg, "terminal.foreground": p.fg, "terminalCursor.foreground": p.s0,
            "terminal.selectionBackground": p.sel,
            "input.background": p.raised, "input.foreground": p.fg, "input.border": p.unlit,
            "input.placeholderForeground": p.dim, "inputOption.activeBorder": p.s0,
            "dropdown.background": p.raised, "dropdown.foreground": p.fg, "dropdown.border": p.unlit,
            "button.background": p.s0, "button.foreground": p.bg, "button.hoverBackground": p.s1,
            "button.secondaryBackground": p.raised, "button.secondaryForeground": p.fg,
            "badge.background": p.s2, "badge.foreground": p.bg, "progressBar.background": p.s0,
            "scrollbarSlider.background": al(p.unlit, "99"), "scrollbarSlider.hoverBackground": al(p.dim, "99"),
            "scrollbarSlider.activeBackground": al(p.s1, "99"),
            "menu.background": p.raised, "menu.foreground": p.fg, "menu.selectionBackground": p.unlit,
            "menu.selectionForeground": p.s0, "menu.border": p.s1, "menu.separatorBackground": p.unlit,
            "quickInput.background": p.raised, "quickInput.foreground": p.fg,
            "quickInputList.focusBackground": p.unlit, "quickInputList.focusForeground": p.s0,
            "pickerGroup.foreground": p.s1, "pickerGroup.border": p.unlit,
            "notifications.background": p.raised, "notifications.foreground": p.fg, "notifications.border": p.s1,
            "notificationCenterHeader.background": p.raised,
            "breadcrumb.foreground": p.dim, "breadcrumb.focusForeground": p.s0,
            "breadcrumb.activeSelectionForeground": p.s0, "breadcrumbPicker.background": p.raised,
            "gitDecoration.addedResourceForeground": green, "gitDecoration.modifiedResourceForeground": yellow,
            "gitDecoration.deletedResourceForeground": red, "gitDecoration.untrackedResourceForeground": cyan,
            "gitDecoration.ignoredResourceForeground": p.unlit
        };
        const ansiNames = ["Black", "Red", "Green", "Yellow", "Blue", "Magenta", "Cyan", "White"];
        for (let i = 0; i < 16; i++)
            colors["terminal.ansi" + (i < 8 ? "" : "Bright") + ansiNames[i % 8]] = a[i];
        const rule = (scope, fg, fontStyle) => fontStyle ? { scope: scope, settings: { foreground: fg, fontStyle: fontStyle } } : { scope: scope, settings: { foreground: fg } };
        return {
            "dotshell.era": p.name,
            "workbench.colorTheme": p.light ? "Default Light Modern" : "Default Dark Modern",
            "workbench.colorCustomizations": colors,
            "editor.tokenColorCustomizations": {
                textMateRules: [
                    rule(["comment", "punctuation.definition.comment"], p.dim),
                    rule(["string", "string.quoted", "string.template"], green),
                    rule(["constant.numeric", "constant.language"], yellow),
                    rule(["constant", "variable.other.constant", "support.constant"], p.s1),
                    rule(["keyword", "storage", "storage.modifier", "keyword.control"], p.s2),
                    rule(["keyword.operator"], p.fg),
                    rule(["entity.name.function", "support.function", "meta.function-call"], p.s0),
                    rule(["entity.name.type", "entity.name.class", "support.type", "support.class", "storage.type"], cyan),
                    rule(["variable", "variable.parameter", "variable.other"], p.fg),
                    rule(["punctuation", "meta.brace"], p.dim),
                    rule(["meta.preprocessor", "keyword.control.directive", "entity.name.function.preprocessor"], magenta),
                    rule(["entity.name.tag"], p.s2),
                    rule(["entity.other.attribute-name"], p.s1),
                    rule(["markup.heading", "entity.name.section"], p.s2, "bold"),
                    rule(["markup.underline.link"], p.s0, "underline"),
                    rule(["invalid"], red)
                ]
            },
            "editor.semanticTokenColorCustomizations": {
                enabled: true,
                rules: {
                    "function": p.s0, "method": p.s0, "type": cyan, "class": cyan, "interface": cyan, "enum": cyan,
                    "typeParameter": cyan, "keyword": p.s2, "variable": p.fg, "parameter": p.fg, "property": p.fg,
                    "enumMember": p.s1, "variable.readonly": p.s1, "namespace": p.s1, "string": green,
                    "number": yellow, "comment": p.dim, "macro": magenta
                }
            }
        };
    }

    // ── rmpc ────────────────────────────────────────────────────────
    // Only the colors; layout and formats stay rmpc's defaults.
    function rmpc(p: var): string {
        const q = c => '"' + c + '"';
        return "// " + marker + " generated by Dot Shell (services/Export.qml) for the " + p.name + " era.\n" + `#![enable(implicit_some)]
#![enable(unwrap_newtypes)]
#![enable(unwrap_variant_newtypes)]
(
    background_color: None,
    text_color: ${q(p.fg)},
    header_background_color: None,
    modal_background_color: ${q(p.raised)},
    preview_label_style: (fg: ${q(p.s2)}),
    preview_metadata_group_style: (fg: ${q(p.s1)}, modifiers: "Bold"),
    highlighted_item_style: (fg: ${q(p.s0)}, modifiers: "Bold"),
    current_item_style: (fg: ${q(p.bg)}, bg: ${q(p.s0)}, modifiers: "Bold"),
    borders_style: (fg: ${q(p.unlit)}),
    highlight_border_style: (fg: ${q(p.s1)}),
    level_styles: (
        info: (fg: ${q(p.s1)}, bg: ${q(p.bg)}),
        warn: (fg: ${q(p.ansi[3])}, bg: ${q(p.bg)}),
        error: (fg: ${q(p.ansi[1])}, bg: ${q(p.bg)}),
        debug: (fg: ${q(p.ansi[2])}, bg: ${q(p.bg)}),
        trace: (fg: ${q(p.ansi[5])}, bg: ${q(p.bg)}),
    ),
    progress_bar: (
        symbols: ["█", "█", "█", "·", "█"],
        track_style: (fg: ${q(p.unlit)}),
        elapsed_style: (fg: ${q(p.s0)}),
        thumb_style: (fg: ${q(p.s0)}),
        use_track_when_empty: true,
    ),
    scrollbar: (
        symbols: ["│", "█", "▲", "▼"],
        track_style: (fg: ${q(p.unlit)}),
        ends_style: (fg: ${q(p.s1)}),
        thumb_style: (fg: ${q(p.s1)}),
    ),
    tab_bar: (
        active_style: (fg: ${q(p.bg)}, bg: ${q(p.s0)}, modifiers: "Bold"),
        inactive_style: (fg: ${q(p.dim)}),
    ),
)
`;
    }

    // ── cava (terminal) ─────────────────────────────────────────────
    // The era's ramp bottom to top, like the shell's own VU bars.
    function cava(e: var): string {
        const r = e.ramp.slice(1).concat(e.slots).map(c => hex(Qt.color(c))).filter((c, i, a) => a.indexOf(c) === i);
        let s = "# " + marker + " generated by Dot Shell for the " + e.name + " era.\n[color]\ngradient = 1\n";
        r.forEach((c, i) => s += "gradient_color_" + (i + 1) + " = '" + hex(Qt.color(c)) + "'\n");
        return s;
    }

    // ── Hyprland (window shading) ───────────────────────────────────
    function lua3(c: string): string {
        const q = Qt.color(c);
        const f = v => (Math.round(v * 1000) / 1000).toString();
        return "{ " + f(q.r) + ", " + f(q.g) + ", " + f(q.b) + " }";
    }
    // Layer namespaces of the panes (dotshell-<name>), for the frosted blur.
    readonly property var paneNames: Ui.names.concat(["toasts", "osd", "polkit"])
    function hyprState(e: var): string {
        return "-- " + marker + " generated by Dot Shell (services/Export.qml) for the " + e.name + " era.\n" + "-- Read by hypr/.config/hypr/lua/dotshell.lua; rewritten on every era or display change.\n" + "return {\n" + "    winshade = \"" + Tokens.winshade + "\",\n" + "    pitch = " + Tokens.pitch + ",\n" + "    dotSize = " + Tokens.dotSize + ",\n" + "    square = " + (e.shape === "square") + ",\n" + "    lit = " + lua3(e.ramp[3]) + ",\n" + "    mid = " + lua3(e.ramp[2]) + ",\n" + "    unlit = " + lua3(e.ramp[0]) + ",\n" + "    glass = " + (e.light ? 0.12 : 0.18) + ",\n" + "    frosted = " + Tokens.frosted + ",\n" + "    home = " + Tokens.home + ",\n" + "    panes = \"" + paneNames.join("|") + "\",\n" + "}\n";
    }

    // ── Cursor and sounds: arguments for the dotcursor / dotsound scripts ──
    // (filled in by their own sections below; "" skips the step)
    // The cursor: the era's first tube lit, the second as accent, a rim of
    // its glass so it reads over any window; dots shaped like the era's.
    function cursorArgs(e: var): string {
        return "--lit " + hex(Qt.color(e.slots[0])) + " --accent " + hex(Qt.color(e.slots[1])) + " --rim " + hex(Qt.color(e.glass)) + " --shape " + (e.shape || "round");
    }
    // The era's sound pack (services/Sound.qml plays it); only the era on
    // screen is synthesized, and an era already made is skipped.
    function soundArgs(e: var): string {
        return Tokens.sounds === "off" ? "" : "--era " + (e.id ?? Tokens.era) + " --dir " + Tokens.dir + "/sounds";
    }

    // ── Writing ─────────────────────────────────────────────────────
    // One shell per export: (path, text, guard) triples; guarded files are
    // only replaced when missing, empty or already ours, `ifdir` files only when
    // their folder exists and is writable. Writes are atomic.
    // Firefox: every install's default profile (installs.ini), else every
    // *.default* profile; userChrome/userContent are guarded, user.js only
    // gets its dotshell block replaced.
    readonly property string script: "
put() {
  f=$1; t=$2; g=$3
  if [ \"$g\" = guard ] && [ -s \"$f\" ] && ! head -n1 \"$f\" | grep -q 'dotshell:'; then
    echo \"dotshell: leaving $f alone (not written by Dot Shell)\" >&2; return
  fi
  if [ \"$g\" = ifdir ] && [ ! -w \"$(dirname \"$f\")\" ]; then return; fi
  mkdir -p \"$(dirname \"$f\")\" && printf '%s' \"$t\" > \"$f.dotshell.tmp\" && mv -f \"$f.dotshell.tmp\" \"$f\"
}
while [ $# -ge 3 ]; do
  put \"$1\" \"$2\" \"$3\"; shift 3
done
ff=$HOME/.mozilla/firefox
if [ -d \"$ff\" ]; then
  profs=$(sed -n 's/^Default=//p' \"$ff/installs.ini\" 2>/dev/null | sort -u)
  [ -n \"$profs\" ] || profs=$(cd \"$ff\" && ls -d *.default* 2>/dev/null)
  printf '%s\\n' \"$profs\" | while IFS= read -r d; do
    [ -n \"$d\" ] || continue
    case $d in /*) ;; *) d=$ff/$d ;; esac
    [ -d \"$d\" ] || continue
    put \"$d/chrome/userChrome.css\" \"$FF_CHROME\" guard
    put \"$d/chrome/userContent.css\" \"$FF_CONTENT\" guard
    { [ -f \"$d/user.js\" ] && sed '/^\\/\\/ dotshell:begin/,/^\\/\\/ dotshell:end/d' \"$d/user.js\"; printf '%s\\n' \"$FF_PREFS\"; } > \"$d/user.js.dotshell.tmp\" &&
      mv -f \"$d/user.js.dotshell.tmp\" \"$d/user.js\"
  done
fi
if [ -n \"$GTK3_THEME\" ] && command -v gsettings >/dev/null; then
  themes=${XDG_DATA_HOME:-$HOME/.local/share}/themes
  cur=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d \"'\")
  case $cur in DotShell|DotShell-B|'') ;; *) printf '%s\\n' \"$cur\" > \"$STATE/gtk-base\" ;; esac
  base=$(cat \"$STATE/gtk-base\" 2>/dev/null)
  imp=; impd=
  for d in \"$themes\" \"$HOME/.themes\" /usr/share/themes; do
    if [ -z \"$imp\" ] && [ -n \"$base\" ] && [ -f \"$d/$base/gtk-3.0/gtk.css\" ]; then
      imp=file://$d/$base/gtk-3.0/gtk.css; impd=$imp
      [ -f \"$d/$base/gtk-3.0/gtk-dark.css\" ] && impd=file://$d/$base/gtk-3.0/gtk-dark.css
    fi
  done
  if [ -z \"$imp\" ]; then
    imp=resource:///org/gtk/libgtk/theme/Adwaita/gtk-contained.css
    impd=resource:///org/gtk/libgtk/theme/Adwaita/gtk-contained-dark.css
  fi
  t=$themes/DotShell
  mkdir -p \"$t/gtk-3.0\" && { [ -e \"$themes/DotShell-B\" ] || ln -s DotShell \"$themes/DotShell-B\"; }
  printf '[Desktop Entry]\\nType=X-GNOME-Metatheme\\nName=DotShell\\nComment=Dot Shell era colors over %s\\n' \"${base:-Adwaita}\" > \"$t/index.theme\"
  printf '@import url(\"%s\");\\n%s' \"$imp\" \"$GTK3_THEME\" > \"$t/gtk-3.0/gtk.css.new\"
  printf '@import url(\"%s\");\\n%s' \"$impd\" \"$GTK3_THEME\" > \"$t/gtk-3.0/gtk-dark.css.new\"
  if cmp -s \"$t/gtk-3.0/gtk.css.new\" \"$t/gtk-3.0/gtk.css\" && cmp -s \"$t/gtk-3.0/gtk-dark.css.new\" \"$t/gtk-3.0/gtk-dark.css\" && [ \"${cur#DotShell}\" != \"$cur\" ]; then
    rm -f \"$t/gtk-3.0/gtk.css.new\" \"$t/gtk-3.0/gtk-dark.css.new\"
  else
    mv -f \"$t/gtk-3.0/gtk.css.new\" \"$t/gtk-3.0/gtk.css\" && mv -f \"$t/gtk-3.0/gtk-dark.css.new\" \"$t/gtk-3.0/gtk-dark.css\"
    # A new name makes every running GTK 3 app load the theme again.
    [ \"$cur\" = DotShell ] && next=DotShell-B || next=DotShell
    gsettings set org.gnome.desktop.interface gtk-theme \"$next\"
  fi
fi
if [ -n \"$VSCODE\" ] && command -v python3 >/dev/null; then
  for d in \"$CONFIG/Code\" \"$CONFIG/Code - OSS\" \"$CONFIG/VSCodium\" \"$CONFIG/Cursor\"; do
    [ -d \"$d/User\" ] && python3 -I -c \"$VSCODE_MERGE\" \"$d/User/settings.json\"
  done
fi
pkill -USR2 -x cava 2>/dev/null
if [ -n \"$WALL\" ] && [ -w \"$GREETER\" ] && [ -f \"$WALL\" ] && ! cmp -s \"$WALL\" \"$GREETER/wallpaper\"; then
  cp -f \"$WALL\" \"$GREETER/wallpaper.tmp\" && chmod 644 \"$GREETER/wallpaper.tmp\" && mv -f \"$GREETER/wallpaper.tmp\" \"$GREETER/wallpaper\"
fi
pkill -USR2 -x ghostty 2>/dev/null
if command -v gsettings >/dev/null; then
  gsettings set org.gnome.desktop.interface color-scheme \"$SCHEME\" 2>/dev/null
fi
if command -v nvim >/dev/null; then
  for s in \"${XDG_RUNTIME_DIR:-/tmp}\"/nvim.*.0; do
    [ -S \"$s\" ] && timeout 2 nvim --server \"$s\" --remote-expr \"execute('if get(g:, \\\"colors_name\\\", \\\"\\\") ==# \\\"dotshell\\\" | colorscheme dotshell | endif')\" >/dev/null 2>&1
  done
fi
if command -v dottv >/dev/null && [ -S \"${XDG_RUNTIME_DIR:-/tmp}/dottv.sock\" ]; then
  timeout 3 dottv led reload >/dev/null 2>&1
fi
if [ -n \"$REOPEN\" ] && command -v dotreopen >/dev/null; then
  dotreopen
fi
# The apps have their new colors: the theme flip may turn the windows back.
echo dotshell:recolored
if [ -n \"$HYPR_APPLY\" ]; then
  hyprctl eval \"$HYPR_APPLY\" >/dev/null 2>&1
fi
if [ -n \"$CURSOR_ARGS\" ] && command -v dotcursor >/dev/null; then
  if dotcursor $CURSOR_ARGS; then
    hyprctl setcursor DotShell 24 >/dev/null 2>&1
    command -v gsettings >/dev/null && gsettings set org.gnome.desktop.interface cursor-theme DotShell 2>/dev/null
  fi
fi
if [ -n \"$SOUND_ARGS\" ] && command -v dotsound >/dev/null; then
  dotsound $SOUND_ARGS
fi
exit 0"

    // VSCode's settings.json is the user's own file: our keys are merged in
    // (the rest kept, in order), and only when it is plain JSON (comments or
    // trailing commas: left alone) and its colors are missing or ours
    // (`dotshell.era` present). Untouched when nothing changed.
    readonly property string vscodeMerge: "
import json, os, sys
f = sys.argv[1]
ours = json.loads(os.environ['VSCODE'])
try:
    with open(f) as h:
        text = h.read()
    s = json.loads(text) if text.strip() else {}
except FileNotFoundError:
    s = {}
except ValueError:
    sys.exit(print('dotshell: leaving ' + f + ' alone (not plain JSON)', file=sys.stderr))
if 'workbench.colorCustomizations' in s and 'dotshell.era' not in s:
    sys.exit(print('dotshell: leaving ' + f + ' alone (colors not set by Dot Shell)', file=sys.stderr))
new = dict(s)
new.update(ours)
if new != s:
    with open(f + '.dotshell.tmp', 'w') as h:
        json.dump(new, h, indent=4, ensure_ascii=False)
        h.write('\\n')
    os.replace(f + '.dotshell.tmp', f)
"

    // What the last run wrote for GTK, so the theme is swapped (and Files
    // restarted) only when the colors really changed, not on a pitch change.
    property string lastGtk3: ""
    property string lastGtk4: ""

    function run(): void {
        const p = palette(Tokens.current);
        const g3 = gtk3Theme(p);
        const g4 = gtk(p, true);
        const reopen = lastGtk4 !== "" && g4 !== lastGtk4 && flip !== "idle";
        const swap = g3 !== lastGtk3;
        lastGtk3 = g3;
        lastGtk4 = g4;
        const files = [
            [configHome + "/ghostty/dotshell.conf", ghostty(p), "own"],
            [dataHome + "/nvim/site/colors/dotshell.lua", nvim(p), "own"],
            [configHome + "/gtk-3.0/gtk.css", gtk(p, false), "guard"],
            [configHome + "/gtk-4.0/gtk.css", gtk(p, true), "guard"],
            [configHome + "/qt6ct/colors/dotshell.conf", qt(p), "own"],
            [Tokens.dir + "/mpv-led.conf", mpv(Tokens.current), "own"],
            [configHome + "/rmpc/themes/dotshell.ron", rmpc(p), "own"],
            [configHome + "/cava/themes/dotshell", cava(Tokens.current), "own"],
            [Tokens.dir + "/hypr.lua", hyprState(Tokens.current), "own"],
            [greeterDir + "/tokens.json", JSON.stringify(Object.assign(Tokens.snapshot(), { wallpaper: greeterDir + "/wallpaper" }), null, 2) + "\n", "ifdir"],
            [greeterDir + "/user", (Quickshell.env("USER") || "") + "\n", "ifdir"]
        ];
        writer.environment = {
            SCHEME: p.light ? "prefer-light" : "prefer-dark",
            HYPR_APPLY: Hypr.lua ? "if dotshell then dotshell.apply() end" : "",
            CURSOR_ARGS: cursorArgs(Tokens.current),
            SOUND_ARGS: soundArgs(Tokens.current),
            GREETER: greeterDir,
            WALL: Tokens.wallpaper,
            CONFIG: configHome,
            STATE: Tokens.dir,
            GTK3_THEME: swap ? g3 : "",
            REOPEN: reopen ? "1" : "",
            VSCODE: JSON.stringify(vscode(p)),
            VSCODE_MERGE: vscodeMerge,
            FF_CHROME: firefoxChrome(p),
            FF_CONTENT: firefoxContent(p),
            FF_PREFS: "// dotshell:begin  written by Dot Shell (services/Export.qml); keep your own prefs outside this block\n" + "user_pref(\"toolkit.legacyUserProfileCustomizations.stylesheets\", true);\n" + "user_pref(\"browser.tabs.inTitlebar\", 1);\n" + "user_pref(\"widget.gtk.rounded-bottom-corners.enabled\", false);\n" + "// dotshell:end"
        };
        writer.command = ["sh", "-c", script, "dotshell-export"].concat(...files);
        if (writer.running)
            pending = true;
        else
            writer.running = true;
    }

    property bool pending: false

    Process {
        id: writer
        stdout: SplitParser {
            onRead: line => {
                if (line === "dotshell:recolored" && root.flip === "closed")
                    settle.restart();
            }
        }
        stderr: SplitParser {
            onRead: line => console.info(line)
        }
        onExited: {
            if (root.pending) {
                root.pending = false;
                root.run();
            }
        }
    }

    // After the cascade has swapped the era (and on start).
    Timer {
        id: debounce
        interval: 600
        onTriggered: root.run()
    }

    // ── Theme flip ──────────────────────────────────────────────────
    // The apps above that recolor while they run, with their window classes
    // (patterns). On an era change their windows on screen turn over as flip
    // dots (hypr/.config/hypr/shaders/dotflip.glsl, through dotshell.flip in
    // hypr/.config/hypr/lua/dotshell.lua): the export runs while they show the
    // blank board, and they turn back once the apps have their new colors.
    // An app added to the export that recolors live joins with a line here.
    // Needs the Hypr-DarkWindow plugin and a Lua config; without them, or with
    // the cascade off, the export just runs.
    readonly property var live: [
        { app: "Ghostty", windows: "com\\.mitchellh\\.ghostty|dotshell\\.dropdown|dotshell\\.pkg" },
        { app: "VSCode", windows: "code|code-oss|Code|VSCodium|codium|Cursor|cursor|com\\.microsoft\\.VSCode" },
        { app: "Firefox", windows: "firefox|org\\.mozilla\\.firefox" },
        { app: "Files", windows: "org\\.gnome\\.Nautilus" },
        { app: "Dot TV", windows: "dottv" }
    ]
    readonly property var liveRe: new RegExp("^(" + live.map(l => l.windows).join("|") + ")$")

    // idle | probing (asking Hyprland) | closing | closed (export running,
    // waiting for the apps)
    property string flip: "idle"

    function startFlip(): void {
        if (flip === "closed") {
            // Another era while the boards are down: export again; the
            // windows open once that one has landed.
            run();
            return;
        }
        if (flip !== "idle")
            return; // the export at the end of the close takes the newest era
        if (!Tokens.cascade || !Hypr.lua) {
            debounce.restart();
            return;
        }
        flip = "probing";
        probe.running = true;
    }

    function rgb(c: string): var {
        const q = Qt.color(c);
        return [q.r, q.g, q.b].map(v => Math.round(v * 1000) / 1000);
    }

    function closeWindows(addrs: var): void {
        const e = Tokens.current;
        const look = {
            pitch: Tokens.pitch,
            dotSize: Tokens.dotSize,
            square: e.shape === "square",
            back: rgb(mix(e.unlit, e.slots[0], 0.12)),
            rim: rgb(e.slots[0]),
            gap: rgb(e.glass)
        };
        Hypr.luaEval("dotshell.flip('close', " + Hypr.lit(addrs) + ", " + Hypr.lit(look) + ")");
        // Files reopening under the boards would otherwise chime.
        Sound.hush(5000);
        flip = "closing";
        // A shaded window first lets go of its LED dots (0.3 s), then flips (0.5 s).
        closeTimer.interval = Tokens.winshade === "off" ? 560 : 860;
        closeTimer.restart();
        holdLimit.restart();
    }

    function openWindows(): void {
        Hypr.luaEval("if dotshell and dotshell.flip then dotshell.flip('open') end");
        flip = "idle";
        closeTimer.stop();
        settle.stop();
        holdLimit.stop();
    }

    // Plugin loaded? Then which live windows are on a visible workspace.
    Process {
        id: probe
        command: ["sh", "-c", "hyprctl plugin list 2>/dev/null | grep -q Hypr-DarkWindow || exit 0; printf '{\"clients\":%s,\"monitors\":%s}' \"$(hyprctl -j clients)\" \"$(hyprctl -j monitors)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                let addrs = [];
                try {
                    const d = JSON.parse(text);
                    const shown = [];
                    for (const m of d.monitors) {
                        shown.push(m.activeWorkspace?.id);
                        if (m.specialWorkspace?.name)
                            shown.push(m.specialWorkspace.id);
                    }
                    addrs = d.clients.filter(c => c.mapped !== false && !c.hidden && shown.includes(c.workspace?.id) && root.liveRe.test(c.class || c.initialClass || "")).map(c => c.address);
                } catch (e) {}
                if (addrs.length === 0) {
                    root.flip = "idle";
                    debounce.restart();
                } else {
                    root.closeWindows(addrs);
                }
            }
        }
    }
    Timer {
        id: closeTimer
        onTriggered: {
            root.flip = "closed";
            root.run();
        }
    }
    // The apps take a moment after their files change (VSCode reads its
    // settings, GTK restyles, Files maps its windows).
    Timer {
        id: settle
        interval: 650
        onTriggered: root.openWindows()
    }
    // Never leave the windows face down.
    Timer {
        id: holdLimit
        interval: 6000
        onTriggered: root.openWindows()
    }

    Connections {
        target: Tokens
        function onCurrentChanged() {
            root.startFlip();
        }
        // The greeter's copy also follows the wallpaper and the dot look.
        function onWallpaperChanged() {
            debounce.restart();
        }
        function onPitchChanged() {
            debounce.restart();
        }
        function onDotSizeChanged() {
            debounce.restart();
        }
        function onDepthChanged() {
            debounce.restart();
        }
        function onWinshadeChanged() {
            debounce.restart();
        }
        function onSoundsChanged() {
            debounce.restart();
        }
        function onFrostedChanged() {
            debounce.restart();
        }
    }
    // Hypr learns the config language after startup: hand Hyprland the state then.
    Connections {
        target: Hypr
        function onLuaChanged() {
            debounce.restart();
            // Windows left face down by a shell that went away mid-flip.
            root.openWindows();
        }
    }
    // The LED video shader follows the MEDIA pane's SCREEN settings.
    Connections {
        target: Tv
        function onScreenChanged() {
            debounce.restart();
        }
    }
    Component.onCompleted: debounce.restart()

    IpcHandler {
        target: "export"

        // dotshell ipc call export run
        function run(): string {
            root.run();
            return Tokens.current.id ?? Tokens.era;
        }
    }
}
