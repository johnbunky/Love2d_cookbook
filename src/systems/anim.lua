-- src/anim.lua
-- Spritesheet animation module.
--
-- Usage:
--   local Anim = require("src.systems.anim")
--
--   -- Define animations from a spritesheet
--   local sheet = Anim.newSheet(image, frameW, frameH)
--   Anim.addAnim(sheet, "idle", {1},        0.2, true)
--   Anim.addAnim(sheet, "run",  {2,3,4,5},  0.1, true)
--   Anim.addAnim(sheet, "jump", {6},        0.1, false)
--   Anim.addAnim(sheet, "fall", {7},        0.1, false)
--
--   -- Create a player instance
--   local anim = Anim.new(sheet, "idle")
--   Anim.play(anim, "run")
--   Anim.update(anim, dt)
--   Anim.draw(anim, x, y, scaleX, scaleY)

local Assets = require("src.assets")
local Anim   = {}

-- -------------------------
-- Create a sheet from an image
-- image  : love image object OR asset name string
-- frameW : width of a single frame in pixels
-- frameH : height of a single frame in pixels
-- -------------------------
function Anim.newSheet(image, frameW, frameH)
    if type(image) == "string" then
        image = Assets.image(image)
    end
    local iw, ih = image:getDimensions()
    local cols   = math.floor(iw / frameW)
    local rows   = math.floor(ih / frameH)
    local total  = cols * rows

    -- Pre-build all quads (1-indexed)
    local quads = {}
    for i = 1, total do
        local col = (i-1) % cols
        local row = math.floor((i-1) / cols)
        quads[i] = love.graphics.newQuad(
            col * frameW, row * frameH,
            frameW, frameH,
            iw, ih)
    end

    return {
        image  = image,
        frameW = frameW,
        frameH = frameH,
        quads  = quads,
        total  = total,
        anims  = {},       -- named animations added via addAnim()
    }
end

-- -------------------------
-- Add a named animation to a sheet
-- name   : string key e.g. "run"
-- frames : array of 1-based frame indices e.g. {2,3,4,5}
-- fps    : frames per second
-- loop   : true = loops, false = plays once and holds last frame
-- onDone : optional callback when non-looping anim finishes
-- -------------------------
function Anim.addAnim(sheet, name, frames, fps, loop, onDone)
    sheet.anims[name] = {
        frames = frames,
        fps    = fps or 10,
        loop   = loop ~= false,  -- default true
        onDone = onDone,
    }
end

-- -------------------------
-- Create an animation instance from a sheet
-- Instances track current state independently
-- -------------------------
function Anim.new(sheet, startAnim)
    local inst = {
        sheet    = sheet,
        current  = nil,
        frame    = 1,      -- index into current anim's frames table
        timer    = 0,
        done     = false,  -- true when non-looping anim has finished
        flipX    = false,  -- mirror horizontally
    }
    if startAnim then Anim.play(inst, startAnim) end
    return inst
end

-- -------------------------
-- Switch to a named animation (resets if already playing same one)
-- force : if true, restarts even if already on this anim
-- -------------------------
function Anim.play(inst, name, force)
    if not force and inst.current == name then return end
    local sheet = inst.sheet
    assert(sheet.anims[name], "[Anim] unknown animation: " .. tostring(name))
    inst.current = name
    inst.frame   = 1
    inst.timer   = 0
    inst.done    = false
end

-- -------------------------
-- Update animation timer — call every frame
-- -------------------------
function Anim.update(inst, dt)
    if inst.done then return end
    local sheet    = inst.sheet
    local animDef  = sheet.anims[inst.current]
    if not animDef then return end

    inst.timer = inst.timer + dt
    local frameDur = 1 / animDef.fps

    while inst.timer >= frameDur do
        inst.timer = inst.timer - frameDur
        inst.frame = inst.frame + 1

        if inst.frame > #animDef.frames then
            if animDef.loop then
                inst.frame = 1
            else
                inst.frame = #animDef.frames
                inst.done  = true
                if animDef.onDone then animDef.onDone() end
                return
            end
        end
    end
end

-- -------------------------
-- Draw current frame
-- x, y   : draw position (top-left of frame)
-- sx, sy : scale (default 1, 1) — use sx=-1 to flip
-- ox, oy : origin offset (default 0, 0)
-- r      : rotation in radians (default 0)
-- -------------------------
function Anim.draw(inst, x, y, sx, sy, ox, oy, r)
    local sheet   = inst.sheet
    local animDef = sheet.anims[inst.current]
    if not animDef then return end

    sx = sx or 1
    sy = sy or 1
    ox = ox or 0
    oy = oy or 0
    r  = r  or 0

    -- flipX convenience
    if inst.flipX then
        sx = -math.abs(sx)
        ox = ox + sheet.frameW  -- shift origin so it flips in place
    end

    local frameIndex = animDef.frames[inst.frame]
    local quad       = sheet.quads[frameIndex]
    if not quad then return end

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(sheet.image, quad, x, y, r, sx, sy, ox, oy)
end

-- -------------------------
-- Check if current animation matches name
-- -------------------------
function Anim.is(inst, name)
    return inst.current == name
end

-- -------------------------
-- Check if a non-looping animation has finished
-- -------------------------
function Anim.isDone(inst)
    return inst.done
end

return Anim
