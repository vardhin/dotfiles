-- Dot TV, the player side (the library side is ~/.local/bin/dottv).
--
-- Does nothing unless mpv was started by `dottv` (script-opts dottv-library=DIR).
-- Then, for files in the library (DIR/<youtube id>-<height>.mp4):
--   titles      the title from DIR/video-meta.json becomes the media title,
--               so MPRIS and the window show it instead of the file name
--   play counts DIR/play-counts.json, +1 each time a file starts
--   Endless Mix user-data/dottv/mix = true keeps the playlist topped up with
--               shuffled library tracks, never the same one twice in a row
--   L           toggles the LED dot shader (~~/shaders/dotled.glsl)
--
-- The playlist after the current entry is the queue: `dottv play --queue ID`.

local mp = require "mp"
local utils = require "mp.utils"
local options = require "mp.options"

local opts = { library = "" }
options.read_options(opts, "dottv")
if opts.library == "" then
    return
end

local lib = opts.library:gsub("/$", "")
local META = lib .. "/video-meta.json"
local COUNTS = lib .. "/play-counts.json"
local SHADER = "~~/shaders/dotled.glsl"
local AHEAD = 3

local function read_json(path)
    local f = io.open(path, "r")
    if not f then
        return {}
    end
    local text = f:read("*a")
    f:close()
    return utils.parse_json(text) or {}
end

local function write_json(path, value)
    local tmp = path .. ".tmp"
    local f = io.open(tmp, "w")
    if not f then
        return
    end
    f:write(utils.format_json(value))
    f:close()
    os.rename(tmp, path)
end

-- "<lib>/<id>-480.mp4" -> "<id>"; nil outside the library.
local function library_id(path)
    if not path then
        return nil
    end
    local dir, file = utils.split_path(path)
    if dir:gsub("/$", "") ~= lib then
        return nil
    end
    return file:match("^(.+)%-%d%d%d%d?%.mp4$")
end

-- Highest-quality file per id.
local function scan()
    local files = utils.readdir(lib, "files") or {}
    local best = {}
    for _, f in ipairs(files) do
        local id, q = f:match("^(.+)%-(%d%d%d%d?)%.mp4$")
        if id and (not best[id] or tonumber(q) > best[id].q) then
            best[id] = { q = tonumber(q), path = lib .. "/" .. f }
        end
    end
    return best
end

-- ── Titles ──────────────────────────────────────────────────────────
mp.add_hook("on_load", 50, function()
    local id = library_id(mp.get_property("path"))
    if not id then
        return
    end
    local meta = read_json(META)[id]
    if meta and meta.title and meta.title ~= "" then
        mp.set_property("file-local-options/force-media-title", meta.title)
    end
end)

-- ── Play counts ─────────────────────────────────────────────────────
mp.register_event("file-loaded", function()
    local id = library_id(mp.get_property("path"))
    if not id then
        return
    end
    local counts = read_json(COUNTS)
    counts[id] = (tonumber(counts[id]) or 0) + 1
    write_json(COUNTS, counts)
end)

-- ── Endless Mix ─────────────────────────────────────────────────────
local bag = {}
local last = nil

local function take()
    if #bag == 0 then
        local all = scan()
        for id, f in pairs(all) do
            bag[#bag + 1] = { id = id, path = f.path }
        end
        for i = #bag, 2, -1 do
            local j = math.random(i)
            bag[i], bag[j] = bag[j], bag[i]
        end
        -- Never the same track twice in a row across a reshuffle.
        if #bag > 1 and bag[#bag].id == last then
            bag[1], bag[#bag] = bag[#bag], bag[1]
        end
    end
    local t = table.remove(bag)
    if t then
        last = t.id
    end
    return t
end

local function mixing()
    return mp.get_property_native("user-data/dottv/mix") == true
end

local function top_up()
    if not mixing() then
        return
    end
    local count = mp.get_property_number("playlist-count", 0)
    local pos = mp.get_property_number("playlist-pos", -1)
    local idle = mp.get_property_native("idle-active")
    -- Idle at the end of the playlist: everything in it has played.
    local ahead = (idle or pos < 0) and 0 or count - pos - 1
    for _ = ahead + 1, AHEAD do
        local t = take()
        if not t then
            mp.osd_message("Endless Mix: the library is empty")
            mp.set_property_native("user-data/dottv/mix", false)
            return
        end
        mp.commandv("loadfile", t.path, "append")
    end
    if idle then
        mp.set_property_number("playlist-pos", count)
    end
    -- An endless playlist stays short: drop all but the last few played.
    for _ = 1, (mp.get_property_number("playlist-pos", 0)) - 8 do
        mp.commandv("playlist-remove", "0")
    end
end

math.randomseed(os.time())
mp.observe_property("user-data/dottv/mix", "native", function(_, on)
    if on then
        bag = {}
        top_up()
    end
end)
mp.observe_property("playlist-pos", "number", function()
    top_up()
end)
mp.observe_property("idle-active", "bool", function(_, idle)
    if idle then
        top_up()
    end
end)

-- ── LED shader ──────────────────────────────────────────────────────
mp.add_key_binding("L", "dottv-led", function()
    mp.commandv("change-list", "glsl-shaders", "toggle", SHADER)
    local on = false
    for _, s in ipairs(mp.get_property_native("glsl-shaders") or {}) do
        if s == SHADER or s:match("dotled%.glsl$") then
            on = true
        end
    end
    mp.osd_message(on and "LED on" or "LED off")
end)
