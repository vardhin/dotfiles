-- Environment. The third argument (true) also pushes the variable to D-Bus
-- and systemd, as hyprlang's `envd` did.

-- The cursor is Dot Shell's own pixel theme in the era's colors (Export
-- writes ~/.local/share/icons/DotShell for both hyprcursor and XCursor);
-- Bibata Amber stays as the fallback until the first export.
local cursorTheme = "DotShell"
do
    local f = io.open(os.getenv("HOME") .. "/.local/share/icons/DotShell/index.theme", "r")
    if f then f:close() else cursorTheme = "Bibata-Modern-Amber" end
end
hl.env("XCURSOR_THEME", cursorTheme, true)
hl.env("HYPRCURSOR_THEME", cursorTheme, true)
hl.env("HYPRCURSOR_SIZE", "24", true)
hl.env("XCURSOR_SIZE", "24", true)
hl.env("QT_CURSOR_SIZE", "24", true)

hl.env("PATH", os.getenv("HOME") .. "/.local/bin:" .. (os.getenv("PATH") or ""))

hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")

hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("GDK_BACKEND", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("SDL_VIDEODRIVER", "wayland")

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- TERM is left to each terminal; a global value breaks ssh, tmux and other terminals.
hl.env("TERMINAL", D.terminal)
