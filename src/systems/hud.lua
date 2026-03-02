-- src/hud.lua
-- Reusable HUD components.
--
-- Usage:
--   local HUD = require("src.systems.hud")
--   local bar = HUD.newBar({ max=100, r=0.9, g=0.2, b=0.2 })
--   HUD.setBar(bar, 75)
--   HUD.updateBar(bar, dt)
--   HUD.drawBar(bar, x, y, w, h, label)
--
--   local score = HUD.newScore()
--   HUD.addScore(score, 100)
--   HUD.updateScore(score, dt)
--   HUD.drawScore(score, x, y)
--
--   HUD.drawMinimap(map, player, x, y, w, h)
--   HUD.drawBossBar(bar, x, y, w, h, name)

local Utils = require("src.utils")
local HUD   = {}

-- -------------------------
-- BAR (health, mana, xp, stamina...)
-- -------------------------

function HUD.newBar(config)
    config = config or {}
    local max = config.max or 100
    return {
        max      = max,
        current  = max,       -- actual value
        display  = max,       -- smoothly animated display value
        speed    = config.speed or 3,   -- lerp speed
        -- bar color
        r = config.r or 0.2,
        g = config.g or 0.8,
        b = config.b or 0.3,
        -- ghost bar (shows recent damage, drains slower)
        ghost        = max,
        ghostSpeed   = config.ghostSpeed or 0.8,
        ghostR       = config.ghostR or 0.9,
        ghostG       = config.ghostG or 0.6,
        ghostB       = config.ghostB or 0.1,
        ghostDelay   = 0,     -- countdown before ghost starts draining
        ghostDelayMax= config.ghostDelay or 0.6,
    }
end

function HUD.setBar(bar, value)
    local prev    = bar.current
    bar.current   = Utils.clamp(value, 0, bar.max)
    if bar.current < prev then
        -- took damage — reset ghost delay
        bar.ghostDelay = bar.ghostDelayMax
    end
end

function HUD.fillBar(bar)
    bar.current = bar.max
    bar.display = bar.max
    bar.ghost   = bar.max
end

function HUD.updateBar(bar, dt)
    bar.display = Utils.lerp(bar.display, bar.current, bar.speed * dt)

    if bar.ghostDelay > 0 then
        bar.ghostDelay = bar.ghostDelay - dt
    else
        if bar.ghost > bar.display then
            bar.ghost = Utils.lerp(bar.ghost, bar.display, bar.ghostSpeed * dt)
        end
    end
end

-- Draw a bar at x,y with size w,h
-- label : optional string shown inside bar
function HUD.drawBar(bar, x, y, w, h, label)
    local fillW  = math.max(0, (bar.display / bar.max) * w)
    local ghostW = math.max(0, (bar.ghost   / bar.max) * w)

    -- background
    love.graphics.setColor(0.1, 0.1, 0.12)
    love.graphics.rectangle("fill", x, y, w, h, 3, 3)

    -- ghost (damage indicator)
    if ghostW > fillW then
        love.graphics.setColor(bar.ghostR, bar.ghostG, bar.ghostB, 0.7)
        love.graphics.rectangle("fill", x, y, ghostW, h, 3, 3)
    end

    -- main fill
    love.graphics.setColor(bar.r, bar.g, bar.b)
    love.graphics.rectangle("fill", x, y, fillW, h, 3, 3)

    -- shine
    love.graphics.setColor(1, 1, 1, 0.08)
    love.graphics.rectangle("fill", x, y, fillW, h/2, 3, 3)

    -- border
    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.rectangle("line", x, y, w, h, 3, 3)

    -- label
    if label then
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.printf(label, x, y + h/2 - 7, w, "center")
    end

    -- value text
    local valText = string.format("%d / %d", math.ceil(bar.current), bar.max)
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.printf(valText, x, y + h/2 - 7, w, "center")
end

-- -------------------------
-- SCORE
-- -------------------------

function HUD.newScore()
    return {
        value   = 0,
        display = 0,
        popScale= 1,     -- >1 when score pops
        popSpeed= 8,
        popMax  = 1.5,
        floaters= {},    -- floating +N texts
    }
end

function HUD.addScore(score, amount)
    score.value   = score.value + amount
    score.popScale = score.popMax
    -- spawn floater
    table.insert(score.floaters, {
        text  = "+" .. amount,
        x     = 0,
        y     = 0,
        life  = 1.0,
        maxLife=1.0,
        vy    = -60,
    })
end

function HUD.updateScore(score, dt)
    score.display  = Utils.lerp(score.display, score.value, 10 * dt)
    score.popScale = Utils.lerp(score.popScale, 1, score.popSpeed * dt)

    for i = #score.floaters, 1, -1 do
        local f = score.floaters[i]
        f.y    = f.y + f.vy * dt
        f.life = f.life - dt
        if f.life <= 0 then table.remove(score.floaters, i) end
    end
end

-- x,y = anchor position for score display
function HUD.drawScore(score, x, y)
    local s    = score.popScale
    local text = string.format("%06d", math.floor(score.display))

    -- shadow
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.printf(text, x+2*s, y+2*s, 200, "left")

    love.graphics.setColor(1, 0.9, 0.2)
    love.graphics.printf(text, x, y, 200, "left")

    -- floaters
    for _, f in ipairs(score.floaters) do
        local alpha = f.life / f.maxLife
        love.graphics.setColor(1, 1, 0.3, alpha)
        love.graphics.print(f.text, x + 90, y + f.y)
    end
end

-- Set floater spawn position relative to score display
function HUD.setFloaterOrigin(score, x, y)
    for _, f in ipairs(score.floaters) do
        if f.life == f.maxLife then
            f.x = x
            f.y = y
        end
    end
end

-- -------------------------
-- MINIMAP
-- -------------------------

-- tm     : tilemap object (from src/tilemap.lua)
-- player : { x, y, w, h }
-- x,y,w,h: minimap screen position and size
function HUD.drawMinimap(tm, player, x, y, w, h)
    local scaleX = w / tm.worldW
    local scaleY = h / tm.worldH

    -- background
    love.graphics.setColor(0.05, 0.05, 0.08, 0.85)
    love.graphics.rectangle("fill", x, y, w, h, 2, 2)

    -- tiles
    local ts = tm.tileSize
    for row = 1, tm.rows do
        for col = 1, tm.cols do
            local t = tm.map[row][col]
            if t ~= 0 then
                local tx = x + (col-1) * ts * scaleX
                local ty = y + (row-1) * ts * scaleY
                local tw = math.max(1, ts * scaleX)
                local th = math.max(1, ts * scaleY)

                if t == 1 then
                    love.graphics.setColor(0.4, 0.5, 0.6)
                elseif t == 2 then
                    love.graphics.setColor(0.4, 0.7, 0.3)
                elseif t == 3 then
                    love.graphics.setColor(0.8, 0.2, 0.2)
                else
                    love.graphics.setColor(0.8, 0.7, 0.1)
                end
                love.graphics.rectangle("fill", tx, ty, tw, th)
            end
        end
    end

    -- player dot
    local px = x + (player.x + player.w/2) * scaleX
    local py = y + (player.y + player.h/2) * scaleY
    love.graphics.setColor(0.2, 1, 0.4)
    love.graphics.circle("fill", px, py, 3)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.circle("line", px, py, 3)

    -- border
    love.graphics.setColor(0.4, 0.4, 0.55)
    love.graphics.rectangle("line", x, y, w, h, 2, 2)
end

-- -------------------------
-- BOSS BAR (dramatic full-width bar at bottom)
-- -------------------------

function HUD.drawBossBar(bar, x, y, w, h, name)
    local fillW  = math.max(0, (bar.display / bar.max) * w)
    local ghostW = math.max(0, (bar.ghost   / bar.max) * w)

    -- dark backdrop
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", x-4, y-24, w+8, h+30, 4, 4)

    -- boss name
    if name then
        love.graphics.setColor(0.9, 0.3, 0.3)
        love.graphics.printf(name, x, y-20, w, "center")
    end

    -- background
    love.graphics.setColor(0.1, 0.05, 0.05)
    love.graphics.rectangle("fill", x, y, w, h, 3, 3)

    -- ghost
    if ghostW > fillW then
        love.graphics.setColor(0.7, 0.3, 0.1, 0.8)
        love.graphics.rectangle("fill", x, y, ghostW, h, 3, 3)
    end

    -- fill with gradient-like segments
    local segments = 5
    for i = 1, segments do
        local t    = (i-1) / segments
        local segX = x + (fillW * t)
        local segW = fillW / segments
        local bright = 1 - t * 0.3
        love.graphics.setColor(0.85 * bright, 0.15, 0.15)
        love.graphics.rectangle("fill", segX, y, segW, h)
    end

    -- shine
    love.graphics.setColor(1, 1, 1, 0.06)
    love.graphics.rectangle("fill", x, y, fillW, h/2, 3, 3)

    -- border
    love.graphics.setColor(0.6, 0.2, 0.2)
    love.graphics.rectangle("line", x, y, w, h, 3, 3)

    -- skull icons per segment
    local skulls = 5
    for i = 1, skulls-1 do
        local sx = x + (w / skulls) * i
        love.graphics.setColor(0.3, 0.1, 0.1)
        love.graphics.line(sx, y, sx, y+h)
    end
end

return HUD
