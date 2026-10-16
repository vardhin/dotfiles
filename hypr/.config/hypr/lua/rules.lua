-- Window and layer rules. https://wiki.hypr.land/Configuring/Basics/Window-Rules/

local function rule(match, effects)
    effects.match = match
    return hl.window_rule(effects)
end

local center60 = { size = "(monitor_w*0.6) (monitor_h*0.6)", center = true, float = true }
local quarter  = { float = true, move = "(monitor_w*0.25) (monitor_h*0.25)", size = "960 540" }

-- ── Float what needs it ─────────────────────────────────────────────
rule({ class = "^(org.pulseaudio.pavucontrol)$" }, { float = true })
rule({ class = "^()$", title = "^(Picture in picture)$" }, { float = true })
rule({ class = "^()$", title = "^(Save File)$" }, { float = true })
rule({ class = "^()$", title = "^(Open File)$" }, { float = true })
rule({ class = "^(LibreWolf)$", title = "^(Picture-in-Picture)$" }, { float = true })
rule({ class = "^(xdg-desktop-portal-gtk|xdg-desktop-portal-kde|xdg-desktop-portal-hyprland)(.*)$" }, { float = true })
rule({ class = "^(CachyOSHello)$" }, { float = true })
rule({ class = "^(zenity)$" }, { float = true })
rule({ class = "^(yad)$" }, { float = true })
rule({ class = "^()$", title = "^(Steam - Self Updater)$" }, { float = true })
rule({ class = "^(xfce4-appfinder)$" }, { float = true, size = "550 400" })

-- ── Glass ───────────────────────────────────────────────────────────
rule({ class = "^(thunar|nemo|org.gnome.Nautilus)$" }, { opacity = "0.92" })
rule({ class = "^(discord|armcord|webcord)$" }, { opacity = "0.96" })
rule({ title = "^(QQ|Telegram)$" }, { opacity = "0.95" })
rule({ title = "^(NetEase Cloud Music Gtk4)$" }, { opacity = "0.95" })
-- Firefox frosted glass (native + Flatpak)
rule({ class = "^(firefox|org.mozilla.firefox)$" }, { opacity = "0.92 override 0.92 override" })

-- ── Picture-in-picture and small viewers ────────────────────────────
rule({ title = "^(Picture-in-Picture)$" }, quarter)
rule({ title = "^(imv|mpv|danmufloat|termfloat|nemo|ncmpcpp)$" }, quarter)
rule({ title = "^(danmufloat)$" }, { pin = true })

-- ── Apps with a home ────────────────────────────────────────────────
rule({ class = "^(org\\.telegram\\.desktop)$" }, { float = true, size = "1330 815" })
rule({ class = "^(vesktop)$" }, { workspace = "10 silent" })
rule({ class = "^(Spotify)$" }, { workspace = "9 silent" })

-- ── Dot Shell's own windows ─────────────────────────────────────────
-- Dropdown terminal (Super X): Ghostty parked on a silent workspace when hidden.
rule({ class = "^(dotshell\\.dropdown)$" }, {
    float = true,
    size = "(monitor_w*0.6) (monitor_h*0.5)",
    move = "(monitor_w*0.2) (monitor_h*0.06)",
})
-- Package manager actions (yay / pacman) run in their own Ghostty.
rule({ class = "^(dotshell\\.pkg)$" }, center60)
-- Dot TV (dottv): mpv with the TV library, floating like a set on the desk.
rule({ class = "^(dottv)$" }, { float = true, center = true, size = "(monitor_w*0.5) (monitor_h*0.5)" })

-- ── Lexicon shell overlay ───────────────────────────────────────────
rule({ class = "^([Ll]exicon-frontend)$" }, {
    float = true,
    fullscreen = true,
    pin = true,
    no_anim = true,
    opacity = "0.85 override 0.85 override",
    xray = true,
})

-- ── General ─────────────────────────────────────────────────────────
rule({ class = ".*" }, { suppress_event = "maximize" })
-- XWayland drag fix.
rule({ class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false }, { no_focus = true })

-- ── Layers ──────────────────────────────────────────────────────────
-- Dot Shell panes are opaque LED panels: no blur. Its window effects
-- (panes/WindowFx.qml) time their own dots, and its workspace dissolve
-- (panes/WorkspaceFx.qml) must cover the screen at once: no layer fades.
hl.layer_rule({ match = { namespace = "^(dotshell-fx)$" }, no_anim = true })
hl.layer_rule({ match = { namespace = "^(dotshell-wsfx)$" }, no_anim = true })
