-- Session start (hyprlang's exec-once).
hl.on("hyprland.start", function()
    -- Session environment for D-Bus activated apps and portals (slow app launch fix).
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")

    -- Start on home (workspace 11, the desk panels).
    hl.exec_cmd("dotws go 11")

    -- Boot sound at mpv's own volume; the sink volume is never touched.
    hl.exec_cmd("mpv --no-video --really-quiet --volume=60 ~/.config/hypr/sounds/boot.wav")

    -- Plugins (window shaders, dynamic cursor), built by `install.sh --plugins`
    -- against this Hyprland; lua/dotshell.lua configures them once they have
    -- loaded. Hyprland refuses ones built for another version.
    hl.exec_cmd("sh -c 'for p in ~/.local/lib/hypr-plugins/*.so; do [ -e \"$p\" ] && hyprctl plugin load \"$p\"; done'")

    -- Dot Shell (Quickshell) is the whole shell: strip, wallpaper,
    -- notifications, OSD, launcher, panes, lock and idle, polkit agent, screen
    -- shader. See ~/.config/quickshell/dotshell/shell.qml.
    hl.exec_cmd(D.dotshell)

    -- Keep clipboard contents after the source app closes.
    hl.exec_cmd("wl-clip-persist --clipboard regular")
end)
