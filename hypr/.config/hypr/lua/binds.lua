-- Every bind has a description: the Dot Shell cheatsheet (Super /) shows it,
-- read live from `hyprctl -j binds`. Binds that share a description and
-- differ only by a digit (workspaces 1..0) collapse into one cheatsheet line.

local M = D.mod
local dsp = hl.dsp

local function bind(keys, action, desc, opts)
    opts = opts or {}
    opts.description = desc
    if type(action) == "string" then
        action = dsp.exec_cmd(action)
    end
    return hl.bind(keys, action, opts)
end
local function key(mods, k)
    return (mods ~= "" and mods .. " + " or "") .. k
end

-- ── Apps ────────────────────────────────────────────────────────────
bind("CTRL + ALT + T", D.terminal, "Terminal")
bind(key(M, "E"), D.browser, "Browser")
bind(key(M, "C"), D.editor, "Editor")
bind(key(M, "F"), D.files, "Files")

-- ── Dot Shell ───────────────────────────────────────────────────────
bind("ALT + space", D.ipc("pane toggle launcher"), "App launcher")
bind(key(M, "X"), D.ipc("dropdown toggle"), "Dropdown terminal")
bind(key(M, "N"), D.ipc("pane toggle notifs"), "Messages")
bind(key(M, "SHIFT + N"), D.ipc("notifs dnd"), "Do not disturb")
bind(key(M, "slash"), D.ipc("pane toggle cheatsheet"), "Shortcuts cheatsheet")
bind(key(M, "SHIFT + C"), D.ipc("caffeine toggle"), "Caffeine (stay awake)")
bind(key(M, "D"), D.ipc("strip toggle"), "Toggle the LED strip")
bind(key(M, "SHIFT + D"), D.ipc("tokens cycleEra"), "Next era")
bind(key(M, "T"), D.ipc("pane toggle eras"), "Era and display settings")
bind(key(M, "W"), D.ipc("pane page eras walls"), "Wallpapers")
bind(key(M, "I"), D.ipc("pane toggle packages"), "Package manager")
bind(key(M, "V"), D.ipc("pane page clip clip"), "Clipboard history")
bind(key(M, "period"), D.ipc("pane page clip symbols"), "Emoji and symbols")
bind(key(M, "M"), D.ipc("pane toggle media"), "Media (now playing)")
bind(key(M, "SHIFT + M"), D.ipc("mediapane open tv"), "Dot TV library")
bind(key(M, "CTRL + M"), "dottv open", "Dot TV window")
bind(key(M, "Tab"), D.ipc("pane toggle overview"), "Switchboard (all workspaces)")
bind(key(M, "SHIFT + S"), D.ipc("scene toggle"), "Era scene (screensaver)")
bind(key(M, "SHIFT + W"), D.ipc("winshade cycle"), "Window LED shading")
bind(key(M, "CTRL + D"), D.dotshell .. " kill; " .. D.dotshell, "Restart Dot Shell")

-- ── Lock ────────────────────────────────────────────────────────────
-- Through logind, so the lock path is the same as idle and suspend.
bind(key(M, "L"), "loginctl lock-session", "Lock screen")

-- ── Screen capture ──────────────────────────────────────────────────
local shot = D.scripts .. "/screenshot.sh "
bind("Print", shot .. "fullscreen", "Screenshot full screen")
bind(key(M, "Print"), shot .. "area", "Screenshot area")
bind(key(M, "SHIFT + Print"), D.ipc("pane toggle capture"), "Capture menu")
bind(key(M, "CTRL + Print"), shot .. "edit-area", "Screenshot area and edit")
bind(key(M, "P"), shot .. "area", "Screenshot area")
bind(key(M, "SHIFT + P"), D.ipc("pane toggle capture"), "Capture menu")
bind(key(M, "ALT + P"), D.ipc("capture rec screen"), "Record screen (again stops)")
bind(key(M, "ALT + C"), D.ipc("capture pick"), "Color picker")

-- ── Screen shader ───────────────────────────────────────────────────
bind(key(M, "SHIFT + H"), D.ipc("night toggle"), "Night warmth")
bind(key(M, "SHIFT + T"), D.ipc("screen toggle"), "Full LED screen")

-- ── Workspaces ──────────────────────────────────────────────────────
-- Through Dot Shell (dotws), so the old workspace is snapshotted before
-- Hyprland moves and can dissolve into dots.
for i = 1, 10 do
    local k = tostring(i % 10)
    bind(key(M, k), "dotws go " .. i, "Go to workspace")
    bind(key(M, "SHIFT + " .. k), "dotws move " .. i, "Move window to workspace")
    bind(key(M, "ALT + " .. k), dsp.window.move({ workspace = tostring(i), follow = false }), "Send window to workspace")
end
bind(key(M, "SHIFT + E"), "dotws go empty", "Empty workspace")
bind(key(M, "mouse_down"), "dotws go e+1", "Next workspace")
bind(key(M, "mouse_up"), "dotws go e-1", "Previous workspace")
bind("ALT + Tab", "dotws go previous", "Last workspace")

-- ── Windows ─────────────────────────────────────────────────────────
bind(key(M, "left"), dsp.focus({ direction = "left" }), "Focus left")
bind(key(M, "right"), dsp.focus({ direction = "right" }), "Focus right")
bind(key(M, "up"), dsp.focus({ direction = "up" }), "Focus up")
bind(key(M, "down"), dsp.focus({ direction = "down" }), "Focus down")
bind(key(M, "mouse:272"), dsp.window.drag(), "Move window (drag)", { mouse = true })
bind(key(M, "mouse:273"), dsp.window.resize(), "Resize window (drag)", { mouse = true })
bind(key(M, "Q"), dsp.window.close(), "Close window")
bind("ALT + Return", dsp.window.fullscreen(), "Fullscreen")
bind(key(M, "J"), dsp.layout("togglesplit"), "Toggle split")
bind(key(M, "K"), dsp.group.toggle(), "Toggle group")
bind(key(M, "SHIFT + F"), dsp.window.float({ action = "toggle" }), "Toggle floating")

-- ── Power ───────────────────────────────────────────────────────────
bind(key(M, "BackSpace"), D.ipc("pane toggle session"), "Session menu")
bind("XF86PowerOff", "systemctl suspend", "Suspend (locks first)")
bind(key(M, "XF86PowerOff"), "pkill -SIGINT electron; systemctl poweroff", "Power off")
bind(key(M, "SHIFT + XF86PowerOff"), "pkill -SIGINT electron; systemctl reboot", "Reboot")

-- ── Volume & brightness ─────────────────────────────────────────────
-- The Dot Shell OSD reacts to the change itself; nothing to call here.
local function hold() return { locked = true, repeating = true } end
bind("XF86AudioRaiseVolume", "pactl set-sink-volume @DEFAULT_SINK@ +5%", "Volume up", hold())
bind("XF86AudioLowerVolume", "pactl set-sink-volume @DEFAULT_SINK@ -5%", "Volume down", hold())
bind("XF86AudioMute", "pactl set-sink-mute @DEFAULT_SINK@ toggle", "Mute", { locked = true })
bind("XF86MonBrightnessUp", "brightnessctl set +5%", "Brightness up", hold())
bind("XF86MonBrightnessDown", "brightnessctl set 5%-", "Brightness down", hold())

-- ── Media ───────────────────────────────────────────────────────────
-- The player Dot Shell follows (the one playing, or the one picked with S in
-- the MEDIA pane), so the keys and the strip always agree.
bind("XF86AudioPlay", D.ipc("media toggle"), "Play or pause", { locked = true })
bind("XF86AudioPause", D.ipc("media toggle"), "Play or pause", { locked = true })
bind("XF86AudioNext", D.ipc("media next"), "Next track", { locked = true })
bind("XF86AudioPrev", D.ipc("media previous"), "Previous track", { locked = true })

-- ── Zoom (cursor) ───────────────────────────────────────────────────
-- Plain Lua now: no hyprctl round trips, no awk.
local function zoom(f)
    return function()
        local z = hl.get_config("cursor.zoom_factor") or 1
        if f == 0 then
            z = (math.abs(z - 1) < 0.001) and 1.5 or 1
        else
            z = math.max(1, z * f)
        end
        hl.config({ cursor = { zoom_factor = z } })
    end
end
bind(key(M, "Z"), zoom(0), "Toggle zoom")
bind(key(M, "equal"), zoom(1.1), "Zoom in", { repeating = true })
bind(key(M, "minus"), zoom(0.9), "Zoom out", { repeating = true })
bind(key(M, "KP_Add"), zoom(1.1), "Zoom in", { repeating = true })
bind(key(M, "KP_Subtract"), zoom(0.9), "Zoom out", { repeating = true })

-- ── Lexicon shell overlay ───────────────────────────────────────────
bind(key(M, "grave"),
    "pkill -x lexicon-frontend && hyprctl dispatch 'hl.dsp.focus({ last = true })' || ~/Documents/git/lexicon/lexicon-frontend/src-tauri/target/release/lexicon-frontend",
    "Lexicon overlay")

hl.config({
    binds = {
        allow_workspace_cycles = true,
        workspace_back_and_forth = true,
        workspace_center_on = 1,
        movefocus_cycles_fullscreen = true,
        window_direction_monitor_fallback = true,
    },
})
