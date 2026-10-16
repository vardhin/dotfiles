-- Hyprland for the greeter only: no binds, no animations, one job.
-- Installed to /etc/greetd/hyprland.lua by system/install.sh.
-- Dot Shell's greeter (/usr/local/share/dotshell/greeter.qml) logs in through
-- greetd; when it quits, Hyprland exits and greetd starts the session.

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- Where Dot Shell's Export leaves the era, wallpaper and user name.
hl.env("XDG_STATE_HOME", "/var/lib/dotshell-greeter")
hl.env("QT_QPA_PLATFORM", "wayland")
-- The greeter user's home is /, so caches go to /tmp.
hl.env("XDG_CACHE_HOME", "/tmp/dotshell-greeter")

hl.on("hyprland.start", function()
    hl.exec_cmd("qs -p /usr/local/share/dotshell/greeter.qml; hyprctl dispatch 'hl.dsp.exit()'")
end)

hl.config({
    input = {
        kb_options = "fkeys:basic_13-24",
    },
    animations = {
        enabled = false,
    },
    decoration = {
        shadow = { enabled = false },
        blur = { enabled = false },
    },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        background_color = 0x000000,
    },
    ecosystem = {
        no_update_news = true,
        no_donation_nag = true,
    },
    cursor = {
        inactive_timeout = 3,
    },
})
