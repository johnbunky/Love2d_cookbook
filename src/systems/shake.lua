-- src/shake.lua
-- Reusable trauma-based screen shake.
-- Usage:
--   local Shake = require("src.systems.shake")
--   local shake = Shake.new()
--   Shake.add(shake, 0.5)        -- add trauma (0..1)
--   Shake.update(shake, dt)      -- call every frame
--   Shake.apply(shake, W, H)     -- call before drawing world
--   Shake.clear()                -- call after drawing world

local Utils = require("src.utils")
local Shake = {}

function Shake.new(config)
    config = config or {}
    return {
        trauma   = 0,
        decay    = config.decay    or 1.2,
        maxAngle = config.maxAngle or 5,
        maxOffX  = config.maxOffX  or 18,
        maxOffY  = config.maxOffY  or 12,
        ox = 0, oy = 0, angle = 0,
    }
end

function Shake.add(s, amount)
    s.trauma = Utils.clamp(s.trauma + amount, 0, 1)
end

function Shake.update(s, dt)
    s.trauma = math.max(0, s.trauma - s.decay * dt)
    local intensity = s.trauma * s.trauma
    local t = love.timer.getTime()
    s.ox    = intensity * s.maxOffX  * math.sin(t * 89.0)
    s.oy    = intensity * s.maxOffY  * math.sin(t * 97.0)
    s.angle = intensity * s.maxAngle * math.sin(t * 73.0)
end

function Shake.apply(s, W, H)
    love.graphics.push()
    local cx, cy = W / 2, H / 2
    love.graphics.translate(cx, cy)
    love.graphics.rotate(math.rad(s.angle))
    love.graphics.translate(-cx + s.ox, -cy + s.oy)
end

function Shake.clear()
    love.graphics.pop()
end

return Shake
