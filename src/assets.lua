-- src/assets.lua
-- Central asset loader and cache.
-- Loads each file once, returns cached version on subsequent calls.
--
-- Usage:
--   local Assets = require("src.assets")
--   local img   = Assets.image("player")        -- loads assets/images/player.png
--   local snd   = Assets.sound("jump", "static")-- loads assets/sounds/jump.wav
--   local font  = Assets.font("hud", 16)        -- loads assets/fonts/hud.ttf at size 16
--   local quad  = Assets.quad("tiles", 0, 0, 32, 32) -- quad into assets/images/tiles.png
--   Assets.preload({ images={"player","tiles"}, sounds={"jump","land"} })
--   Assets.clear()                              -- free everything (between levels etc)

local Assets = {}

local cache = {
    images = {},
    sounds = {},
    fonts  = {},
    quads  = {},
}

-- -------------------------
-- Paths
-- -------------------------
local PATHS = {
    images = "assets/images/",
    sounds = "assets/sounds/",
    fonts  = "assets/fonts/",
}

local IMAGE_EXTS = { ".png", ".jpg", ".jpeg" }
local SOUND_EXTS = { ".wav", ".ogg", ".mp3"  }
local FONT_EXTS  = { ".ttf", ".otf"          }

local function findFile(dir, name, exts)
    for _, ext in ipairs(exts) do
        local path = dir .. name .. ext
        if love.filesystem.getInfo(path) then return path end
    end
    -- already has extension?
    local path = dir .. name
    if love.filesystem.getInfo(path) then return path end
    return nil
end

-- -------------------------
-- Images
-- -------------------------
function Assets.image(name)
    if cache.images[name] then return cache.images[name] end
    local path = findFile(PATHS.images, name, IMAGE_EXTS)
    if not path then
        print("[Assets] image not found: " .. name)
        return nil
    end
    local img = love.graphics.newImage(path)
    img:setFilter("nearest", "nearest")  -- pixel-perfect by default
    cache.images[name] = img
    return img
end

-- -------------------------
-- Sounds
-- -------------------------
-- sourceType: "static" (short sfx) or "stream" (music)
function Assets.sound(name, sourceType)
    sourceType = sourceType or "static"
    local key  = name .. "_" .. sourceType
    if cache.sounds[key] then return cache.sounds[key] end
    local path = findFile(PATHS.sounds, name, SOUND_EXTS)
    if not path then
        print("[Assets] sound not found: " .. name)
        return nil
    end
    local snd = love.audio.newSource(path, sourceType)
    cache.sounds[key] = snd
    return snd
end

-- Clone a sound so multiple instances can play simultaneously
function Assets.soundClone(name)
    local src = Assets.sound(name, "static")
    if not src then return nil end
    return src:clone()
end

-- -------------------------
-- Fonts
-- -------------------------
function Assets.font(name, size)
    size = size or 14
    local key = name .. "_" .. size
    if cache.fonts[key] then return cache.fonts[key] end
    local path = findFile(PATHS.fonts, name, FONT_EXTS)
    local fnt
    if not path then
        -- fall back to love default font at requested size
        print("[Assets] font not found: " .. name .. " — using default")
        fnt = love.graphics.newFont(size)
    else
        fnt = love.graphics.newFont(path, size)
    end
    cache.fonts[key] = fnt
    return fnt
end

-- -------------------------
-- Quads (regions of a spritesheet)
-- -------------------------
-- Returns a Quad into the named image
function Assets.quad(imageName, x, y, w, h)
    local key = imageName .. "_" .. x .. "_" .. y .. "_" .. w .. "_" .. h
    if cache.quads[key] then return cache.quads[key] end
    local img = Assets.image(imageName)
    if not img then return nil end
    local iw, ih = img:getDimensions()
    local q = love.graphics.newQuad(x, y, w, h, iw, ih)
    cache.quads[key] = q
    return q
end

-- -------------------------
-- Preload a batch of assets upfront
-- e.g. Assets.preload({ images={"player","tiles"}, sounds={"jump","land"} })
-- -------------------------
function Assets.preload(batch)
    if batch.images then
        for _, name in ipairs(batch.images) do Assets.image(name) end
    end
    if batch.sounds then
        for _, name in ipairs(batch.sounds) do Assets.sound(name) end
    end
    if batch.fonts then
        for _, entry in ipairs(batch.fonts) do
            Assets.font(entry[1], entry[2])
        end
    end
end

-- -------------------------
-- Clear cache (call between major scenes if needed)
-- -------------------------
function Assets.clear()
    cache.images = {}
    cache.sounds = {}
    cache.fonts  = {}
    cache.quads  = {}
end

-- -------------------------
-- Debug: print all cached assets
-- -------------------------
function Assets.debug()
    print("=== Assets cache ===")
    for k in pairs(cache.images) do print("  image: " .. k) end
    for k in pairs(cache.sounds) do print("  sound: " .. k) end
    for k in pairs(cache.fonts)  do print("  font:  " .. k) end
    print("====================")
end

return Assets
