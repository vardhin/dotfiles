-- Dot Shell ↔ Hyprland.
--
-- Plugins (built by `install.sh --plugins`, loaded by lua/autostart.lua; loading
-- one reloads this config, so the `if hl.plugin.X` blocks run once it is in):
--   Hypr-DarkWindow  per-window GLSL: shaders/dotled.glsl, shaders/dotglass.glsl
--   dynamic-cursors  the cursor stretches with speed, shake to find it
--
-- State: Dot Shell's Export writes ~/.local/state/dotshell/hypr.lua on every
-- era or display change (era ramp, pitch, dot size and shape, the `winshade`
-- token) and then runs `hyprctl eval 'dotshell.apply()'`. Nothing here has to
-- be edited by hand for an era change.

dotshell = dotshell or {}

local home = os.getenv("HOME")
local stateFile = (os.getenv("XDG_STATE_HOME") or (home .. "/.local/state")) .. "/dotshell/hypr.lua"
-- shaders/ next to hyprland.lua, wherever the config lives.
local shaderDir = (debug.getinfo(1, "S").source:match("^@(.*)/lua/[^/]*$") or (home .. "/.config/hypr")) .. "/shaders/"

-- Defaults until Dot Shell has written its state once (phosphor amber).
local defaults = {
    winshade = "off",       -- off | dim (unfocused windows as dots) | all (+ glass on the focused one)
    pitch = 5,
    dotSize = 0.7,
    square = false,
    lit = { 1.0, 0.69, 0.25 },
    mid = { 0.55, 0.33, 0.1 },
    unlit = { 0.09, 0.05, 0.02 },
    glass = 0.18,
    frosted = false,        -- panes on blurred glass (the `frosted` token)
    panes = "launcher|session|notifs|cheatsheet|calendar|audio|brightness|wifi|bluetooth|battery|eras|packages|media|capture|clip|overview|toasts|osd|polkit",
}

function dotshell.state()
    local ok, t = pcall(dofile, stateFile)
    local s = {}
    for k, v in pairs(defaults) do s[k] = v end
    if ok and type(t) == "table" then
        for k, v in pairs(t) do s[k] = v end
    end
    return s
end

-- ── Hypr-DarkWindow ─────────────────────────────────────────────────
local dw = hl.plugin.darkwindow
if dw then
    hl.config({ plugin = { darkwindow = { load_shaders = "" } } })
    dw.load_shader("dotled", { path = shaderDir .. "dotled.glsl", fade_in_speed = 4, fade_out_speed = 3 })
    dw.load_shader("dotglass", { path = shaderDir .. "dotglass.glsl", fade_in_speed = 4, fade_out_speed = 3 })
    -- The theme flip: close in 0.5 s, open in 0.6 s (shaders/dotflip.glsl).
    dw.load_shader("dotflip", { path = shaderDir .. "dotflip.glsl", fade_in_speed = 5, fade_out_speed = 6 })
end

local active = {}

-- (Re)build the shading rules from the state file. Rules cannot be changed
-- in place, so the old ones are switched off and new ones made.
function dotshell.apply()
    for _, r in ipairs(active) do
        r:set_enabled(false)
    end
    active = {}

    local s = dotshell.state()

    -- Frosted panes: Hyprland blurs what is behind them; the shell makes the
    -- glass between the dots translucent. Fully opaque pixels stay as they are.
    if s.frosted then
        active[#active + 1] = hl.layer_rule({
            name = "dotshell-frosted",
            match = { namespace = "^dotshell-(" .. s.panes .. ")$" },
            blur = true,
            ignore_alpha = 0.05,
        })
    end

    local shading = dw ~= nil and (s.winshade == "dim" or s.winshade == "all")

    -- Brightness is the focus cue without the plugin; the dots replace it.
    hl.config({ decoration = { dim_inactive = not shading } })
    if not shading then
        return
    end

    local grid = { pitch = s.pitch, dotSize = s.dotSize, square = s.square and 1 or 0 }

    -- Half brightness: the lit ramp is brighter than most windows, and an
    -- unfocused window must read as dimmer than the focused one.
    local led = { lit = s.lit, glow = s.mid, unlit = s.unlit, bright = 0.5 }
    for k, v in pairs(grid) do led[k] = v end
    active[#active + 1] = hl.window_rule({
        name = "dotshell-winshade-led",
        match = { focus = false },
        ["darkwindow:shade"] = dw.build_rule_effect({ shader = "dotled", args = led }),
    })

    if s.winshade == "all" then
        local glass = { strength = s.glass }
        for k, v in pairs(grid) do glass[k] = v end
        active[#active + 1] = hl.window_rule({
            name = "dotshell-winshade-glass",
            match = { focus = true },
            ["darkwindow:shade"] = dw.build_rule_effect({ shader = "dotglass", args = glass }),
        })
    end
end

dotshell.apply()

-- ── Theme flip ──────────────────────────────────────────────────────
-- Dot Shell's Export calls this around an era change, for the windows of
-- the apps it recolors live (services/Export.qml, `live`):
--   dotshell.flip("close", { "0x…", … }, { pitch, dotSize, square, back, rim, gap })
--     each window's dots turn over to the blank board and stay there
--   dotshell.flip("open")
--     every closed window turns back over, now in the new colors
-- A dispatched shader wins over the winshade rules, so a shaded window
-- leaves its dots for the flip and takes them back afterwards. Dispatching
-- the same shader again removes it, so the dispatcher is kept per window.
-- Survives config reloads; the shell opens everything again when it starts.
dotshell.flipped = dotshell.flipped or {}

function dotshell.flip(phase, addrs, look)
    if not dw then
        return
    end
    if phase == "close" then
        look = look or {}
        local args = {
            pitch = look.pitch or 5,
            dotSize = look.dotSize or 0.7,
            square = look.square and 1 or 0,
            back = look.back or { 0.1, 0.1, 0.1 },
            rim = look.rim or { 1, 1, 1 },
            gap = look.gap or { 0, 0, 0 },
        }
        for _, a in ipairs(addrs or {}) do
            if not dotshell.flipped[a] then
                local shade = dw.dsp_shade({ shader = "dotflip", args = args, window = "address:" .. a })
                if pcall(shade) then
                    dotshell.flipped[a] = shade
                end
            end
        end
    else
        for _, shade in pairs(dotshell.flipped) do
            pcall(shade)
        end
        dotshell.flipped = {}
    end
end

-- ── Home ────────────────────────────────────────────────────────────
-- The home workspace (the `home` token) holds the desk panels and no
-- windows: one that opens there moves to the first empty workspace, and
-- focus follows it. Floating windows (dialogs, pickers) stay put. hl.on
-- subscriptions are dropped on every reload, so this registers once per load.
hl.on("window.open", function(w)
    local h = dotshell.state().home
    if not h or w.floating or w.workspace.id ~= h then
        return
    end
    hl.dispatch(hl.dsp.window.move({ workspace = "empty", window = "address:" .. w.address, follow = true }))
end)

-- ── dynamic-cursors ─────────────────────────────────────────────────
-- Stretch with speed (a pixel cursor smeared like a fast LED), shake to find
-- it, and nearest-neighbour scaling always, so a magnified cursor stays a
-- block of pixels.
if hl.plugin.dynamic_cursors then
    hl.config({ plugin = { dynamic_cursors = {
        enabled = true,
        mode = "stretch",
        threshold = 2,
        stretch = { limit = 3000, activation = "quadratic", window = 100 },
        shake = { enabled = true, threshold = 6.0, base = 4.0, speed = 4.0, timeout = 1500 },
        hyprcursor = { nearest = 2, enabled = true },
    } } })
    -- The text beam leans instead: a stretched I-beam is hard to aim.
    hl.plugin.dynamic_cursors.shape_rule({ shape = "text", mode = "tilt" })
end
