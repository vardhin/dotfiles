-- Hyprland, Lua config (Hyprland 0.55+ reads this before hyprland.conf).
--
-- One module per concern under lua/. Each is loaded through require(), which
-- Hyprland makes fault-isolated: a mistake in one module is listed in the
-- config errors and the rest still loads, so a typo in the rules never costs
-- you the keybinds.
--
-- Dot Shell talks to this config in Lua as well (services/Hypr.qml):
-- `hyprctl eval` for options, hl.dsp.* for dispatchers, and dotshell.apply()
-- (lua/dotshell.lua) for the per-window LED shading.

require("lua.defaults")    -- programs, the Dot Shell command (D = shared table)
require("lua.environment") -- env vars, cursor
require("lua.monitor")     -- outputs
require("lua.input")       -- keyboard, touchpad
require("lua.look")        -- zero chrome, blur, curves and animations
require("lua.rules")       -- window and layer rules
require("lua.binds")       -- every bind, with a description for the cheatsheet
require("lua.autostart")   -- session start
require("lua.dotshell")    -- plugins (window shaders, cursor), Dot Shell state bridge
