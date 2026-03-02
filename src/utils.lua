-- src/utils.lua
-- Shared helpers used across all examples.
-- Usage: local Utils = require("src.utils")

local Utils = {}

-- -------------------------
-- Math
-- -------------------------

function Utils.clamp(val, min, max)
    if val < min then return min end
    if val > max then return max end
    return val
end

function Utils.lerp(a, b, t)
    return a + (b - a) * t
end

function Utils.distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

function Utils.sign(x)
    if x > 0 then return 1
    elseif x < 0 then return -1
    else return 0 end
end

-- Normalize a 2D vector — returns dx, dy scaled to length 1
-- If vector is zero, returns 0, 0
function Utils.normalize(dx, dy)
    local len = math.sqrt(dx * dx + dy * dy)
    if len == 0 then return 0, 0 end
    return dx / len, dy / len
end

-- -------------------------
-- Collision
-- -------------------------

-- AABB overlap test for two rect tables { x, y, w, h }
function Utils.rectOverlap(a, b)
    return a.x < b.x + b.w
       and b.x < a.x + a.w
       and a.y < b.y + b.h
       and b.y < a.y + a.h
end

-- Returns true if obj overlaps any rect in list
function Utils.hitsAny(obj, list)
    for _, r in ipairs(list) do
        if Utils.rectOverlap(obj, r) then return true end
    end
    return false
end

-- Circle overlap test
function Utils.circleOverlap(ax, ay, ar, bx, by, br)
    return Utils.distance(ax, ay, bx, by) < ar + br
end

-- -------------------------
-- Drawing helpers
-- -------------------------

-- Fill the screen with a solid color
function Utils.drawBackground(r, g, b)
    love.graphics.setColor(r or 0.12, g or 0.12, b or 0.15)
    love.graphics.rectangle("fill", 0, 0,
        love.graphics.getWidth(), love.graphics.getHeight())
end

-- Draw a list of obstacles { x, y, w, h }
function Utils.drawObstacles(obstacles, fr, fg, fb, lr, lg, lb)
    fr, fg, fb = fr or 0.35, fg or 0.35, fb or 0.45
    lr, lg, lb = lr or 0.5,  lg or 0.5,  lb or 0.6
    for _, o in ipairs(obstacles) do
        love.graphics.setColor(fr, fg, fb)
        love.graphics.rectangle("fill", o.x, o.y, o.w, o.h)
        love.graphics.setColor(lr, lg, lb)
        love.graphics.rectangle("line", o.x, o.y, o.w, o.h)
    end
end

-- Draw a small HUD label and hint at the top of the screen
function Utils.drawHUD(title, hint)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(title, 10, 10)
    if hint then
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.print(hint, 10, 30)
    end
end

-- -------------------------
-- Pause helper
-- Call this in any example's keypressed to support pausing
-- -------------------------
function Utils.handlePause(key, callerState)
    if key == "p" then
        Gamestate.switch(States.pause, callerState)
    end
end

return Utils
