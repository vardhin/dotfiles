-- Zero chrome. The screen is one LED panel: windows tile edge to edge,
-- separated only by a single unlit-dot gutter. No borders, rounding or
-- shadows. Focus is shown by brightness: unfocused windows are dimmed, or,
-- with the plugin and the `winshade` token, drawn as LED dots (lua/dotshell.lua).
-- Dot Shell sets the gaps at runtime when LED borders are on.

D.gutter = 2 -- gutter between windows = 2 x gaps_in; one dot at the default pitch

hl.config({
    general = {
        border_size = 0,
        gaps_in = D.gutter,
        gaps_out = 0,
        gaps_workspaces = 0,
    },

    decoration = {
        rounding = 0,
        active_opacity = 1,
        inactive_opacity = 1,
        fullscreen_opacity = 1,

        -- Focus by brightness.
        dim_inactive = true,
        dim_strength = 0.2,

        shadow = {
            enabled = false,
        },

        -- For translucent windows (Firefox, Discord, the dropdown terminal).
        blur = {
            enabled = true,
            size = 8,
            passes = 3,
            vibrancy = 0.17,
            vibrancy_darkness = 0.1,
            new_optimizations = true,
            xray = false,
            noise = 0.02,
            special = true,
            popups = true,
            popups_ignorealpha = 0.2,
        },
    },

    animations = {
        enabled = true,
    },

    misc = {
        animate_manual_resizes = false,
        animate_mouse_windowdragging = false,
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        mouse_move_enables_dpms = true,
        key_press_enables_dpms = true,
        always_follow_on_dnd = true,
        layers_hog_keyboard_focus = true,
        focus_on_activate = true,
        enable_swallow = true,
        swallow_regex = "^(com\\.mitchellh\\.ghostty)$",
    },
})

local function bezier(name, x1, y1, x2, y2)
    hl.curve(name, { type = "bezier", points = { { x1, y1 }, { x2, y2 } } })
end
bezier("glacialFlow", 0.25, 0.46, 0.45, 0.94)
bezier("crystalGrow", 0.34, 1.4, 0.64, 1)
bezier("frostBite", 0.68, -0.55, 0.265, 1.55)
bezier("breathing", 0.37, 0, 0.63, 1)
bezier("linear", 0, 0, 1, 1)
bezier("linear_fast", 1, 0, 1, 1)

-- Windows only fade: Dot Shell draws their open/close as LED dots on an
-- overlay (panes/WindowFx.qml), and a popin or slide would move the window
-- out from under the dots. Workspaces: Dot Shell turns this one off while its
-- dissolve (`wsfx`) is on, and puts it back from services/WsFx.qml.
hl.animation({ leaf = "fadeIn",     enabled = true, speed = 3,  bezier = "linear" })
hl.animation({ leaf = "fadeOut",    enabled = true, speed = 3,  bezier = "linear" })
hl.animation({ leaf = "fadeDim",    enabled = true, speed = 8,  bezier = "glacialFlow" })
hl.animation({ leaf = "layersIn",   enabled = true, speed = 10, bezier = "glacialFlow", style = "fade" })
hl.animation({ leaf = "layersOut",  enabled = true, speed = 10, bezier = "frostBite",   style = "fade" })
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 3,  bezier = "linear",      style = "popin 100%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3,  bezier = "linear",      style = "popin 100%" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5,  bezier = "breathing",   style = "slidefade" })
