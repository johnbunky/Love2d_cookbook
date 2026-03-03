-- src/systems/scale.lua
-- Virtual resolution system: render everything at a fixed size, scale to fit screen.
-- Maintains aspect ratio with letterboxing/pillarboxing (black bars).
--
-- Usage:
--   Scale.init(960, 540)           -- call once in love.load
--   Scale.apply()                  -- before drawing (push transform)
--   Scale.clear()                  -- after drawing (pop transform)
--   Scale.drawBars()               -- draw black bars over letterbox areas
--   x, y = Scale.toVirtual(x, y)  -- convert real -> virtual coords
--   Scale.toggleFullscreen()       -- F key or button
--   Scale.setWindowSize(w, h)      -- PC window resize

local Scale = {}

local VW, VH = 960, 540   -- virtual resolution
local ox, oy = 0, 0        -- letterbox/pillarbox offset in real pixels
local sc     = 1            -- uniform scale factor

function Scale.init(vw, vh)
    VW, VH = vw or 960, vh or 540
    Scale.update()
end

-- Recompute after any window resize or fullscreen toggle
-- Pass rw, rh from love.resize callback to avoid DPI confusion
function Scale.update(rw, rh)
    if not rw or not rh then
        rw, rh = love.window.getMode()
    end
    sc = math.min(rw / VW, rh / VH)
    ox = math.floor((rw - VW * sc) / 2)
    oy = math.floor((rh - VH * sc) / 2)
    -- Store real size for drawBars
    Scale._rw = rw
    Scale._rh = rh
end

-- Push virtual canvas transform
function Scale.apply()
    love.graphics.push()
    love.graphics.translate(ox, oy)
    love.graphics.scale(sc, sc)
end

-- Pop virtual canvas transform
function Scale.clear()
    love.graphics.pop()
end

-- Draw black bars outside the virtual canvas (call AFTER Scale.clear)
function Scale.drawBars()
    if not Scale._rw then return end
    love.graphics.setColor(0, 0, 0)
    local rw, rh = Scale._rw, Scale._rh
    if oy > 0 then
        love.graphics.rectangle("fill", 0, 0,       rw, oy)
        love.graphics.rectangle("fill", 0, rh - oy, rw, oy + 1)
    end
    if ox > 0 then
        love.graphics.rectangle("fill", 0,       0, ox,     rh)
        love.graphics.rectangle("fill", rw - ox, 0, ox + 1, rh)
    end
    love.graphics.setColor(1, 1, 1)
end

-- Convert real screen coords to virtual canvas coords
function Scale.toVirtual(x, y)
    return (x - ox) / sc, (y - oy) / sc
end

-- Accessors
function Scale.width()  return VW end
function Scale.height() return VH end
function Scale.factor() return sc end
function Scale.offset() return ox, oy end

function Scale.isFullscreen()
    return love.window.getFullscreen()
end

function Scale.toggleFullscreen()
    love.window.setFullscreen(not love.window.getFullscreen(), "desktop")
    Scale.update()
end

function Scale.setWindowSize(w, h)
    if not love.window.getFullscreen() then
        love.window.setMode(w, h, { resizable = true, vsync = 1 })
        Scale.update()
    end
end

return Scale
