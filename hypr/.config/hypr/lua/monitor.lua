-- Scale 1: one logical pixel is one screen pixel, so the pixel font and Dot
-- Shell's dots land on whole pixels instead of being resampled by 1.2. Text
-- size comes from the font sizes instead (GTK/Qt 16, VS Code zoom 2, Ghostty
-- 16.5 pt = Departure Mono at exactly 2x).
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

hl.config({
    xwayland = {
        force_zero_scaling = true, -- unscale XWayland
    },
})
