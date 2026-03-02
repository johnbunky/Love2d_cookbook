-- src/states/examples/topdown_movement.lua
-- Demonstrates: 4-directional movement, boundary clamping, obstacle collision
-- Input: WASD/arrows, click/tap to move (point-and-click), gamepad

local Utils   = require("src.utils")
local Example = {}

local W, H
local player    = {}
local obstacles = {}
local target    = nil   -- click-to-move destination { x, y }
local clickMarker = nil -- visual { x, y, life }

-- How close to target before stopping
local ARRIVE_DIST = 4

function Example.enter()
    W = love.graphics.getWidth()
    H = love.graphics.getHeight()

    player = {
        x     = 50,
        y     = 50,
        w     = 32,
        h     = 32,
        speed = 180,
    }

    target      = nil
    clickMarker = nil

    obstacles = {
        { x=150, y=120, w=120, h=30  },
        { x=400, y=200, w=30,  h=150 },
        { x=250, y=350, w=200, h=30  },
        { x=550, y=100, w=30,  h=200 },
        { x=100, y=400, w=30,  h=120 },
    }
end

function Example.exit() end

local function setTarget(x, y)
    -- clamp to screen and offset to center on player
    target = {
        x = Utils.clamp(x - player.w/2, 0, W - player.w),
        y = Utils.clamp(y - player.h/2, 0, H - player.h),
    }
    clickMarker = { x=x, y=y, life=0.6 }
end

function Example.update(dt)
    local oldX, oldY = player.x, player.y
    local dx, dy = 0, 0

    -- Keyboard / gamepad input
    if Input.isDown("left")  then dx = dx - 1 end
    if Input.isDown("right") then dx = dx + 1 end
    if Input.isDown("up")    then dy = dy - 1 end
    if Input.isDown("down")  then dy = dy + 1 end

    if dx ~= 0 or dy ~= 0 then
        -- keyboard overrides click-to-move
        target = nil
        if dx ~= 0 and dy ~= 0 then
            dx = dx * 0.7071
            dy = dy * 0.7071
        end
    elseif target then
        -- click-to-move: steer toward target
        local tx = target.x - player.x
        local ty = target.y - player.y
        local dist = math.sqrt(tx*tx + ty*ty)
        if dist < ARRIVE_DIST then
            target = nil
        else
            dx = tx / dist
            dy = ty / dist
        end
    end

    -- Mouse hold to drag
    if Input.isMouseDown(1) then
        setTarget(Input.mouseX, Input.mouseY)
    end

    player.x = player.x + dx * player.speed * dt
    player.y = player.y + dy * player.speed * dt
    player.x = Utils.clamp(player.x, 0, W - player.w)
    player.y = Utils.clamp(player.y, 0, H - player.h)

    -- Collision X
    if Utils.hitsAny({x=player.x, y=oldY, w=player.w, h=player.h}, obstacles) then
        player.x = oldX
        if target then target.x = oldX end  -- cancel target on obstacle hit
    end
    -- Collision Y
    if Utils.hitsAny({x=player.x, y=player.y, w=player.w, h=player.h}, obstacles) then
        player.y = oldY
        if target then target.y = oldY end
    end

    -- Fade click marker
    if clickMarker then
        clickMarker.life = clickMarker.life - dt
        if clickMarker.life <= 0 then clickMarker = nil end
    end
end

function Example.draw()
    Utils.drawBackground()
    Utils.drawObstacles(obstacles)

    -- Target indicator
    if target then
        love.graphics.setColor(0.2, 0.85, 0.4, 0.3)
        love.graphics.rectangle("fill", target.x, target.y, player.w, player.h)
        love.graphics.setColor(0.2, 0.85, 0.4, 0.6)
        love.graphics.rectangle("line", target.x, target.y, player.w, player.h)
        -- line from player to target
        love.graphics.setColor(0.2, 0.85, 0.4, 0.25)
        love.graphics.line(
            player.x + player.w/2, player.y + player.h/2,
            target.x  + player.w/2, target.y  + player.h/2)
    end

    -- Click marker (ripple)
    if clickMarker then
        local t = 1 - clickMarker.life / 0.6
        local r = 6 + t * 14
        local a = clickMarker.life / 0.6
        love.graphics.setColor(1, 1, 0.4, a * 0.8)
        love.graphics.circle("line", clickMarker.x, clickMarker.y, r)
        love.graphics.circle("line", clickMarker.x, clickMarker.y, r * 0.5)
    end

    -- Player
    love.graphics.setColor(0.2, 0.85, 0.4)
    love.graphics.rectangle("fill", player.x, player.y, player.w, player.h)
    love.graphics.setColor(0.3, 1, 0.5)
    love.graphics.rectangle("line", player.x, player.y, player.w, player.h)

    Utils.drawHUD("TOP-DOWN MOVEMENT",
        "WASD/Arrows move    Click/tap to walk there    P pause    ESC back")
end

function Example.keypressed(key)
    Utils.handlePause(key, Example)
end

function Example.mousepressed(x, y, button)
    if button == 1 then setTarget(x, y) end
end

function Example.touchpressed(id, x, y)
    setTarget(x, y)
end

return Example
