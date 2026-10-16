-- Dot Shell ↔ Hyprland.
--
-- Plugins (installed with hyprpm, loaded by `hyprpm reload` at start; loading
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

    local led = { lit = s.lit, mid = s.mid, unlit = s.unlit }
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
