-- src/physics.lua
-- Shared platformer physics — constants, player creation, movement, collision.
--
-- Usage A (simple — rect list):
--   Physics.update(player, platforms, dt)
--
-- Usage B (split axis — tilemap):
--   Physics.updateMovement(player, dt)   -- velocity & input only
--   player.x = player.x + player.vx * dt
--   -- your own X collision here
--   player.y = player.y + player.vy * dt
--   -- your own Y collision here
--   Physics.finalize(player)             -- clamp, reset jump if grounded

local Utils   = require("src.utils")
local Physics = {}

-- -------------------------
-- Default constants
-- -------------------------
Physics.defaults = {
    w           = 28,
    h           = 36,
    walkSpeed   = 200,
    accel       = 1200,
    friction    = 1800,
    airAccel    = 600,
    gravity     = 900,
    jumpForce   = -380,
    jumpHold    = -200,
    jumpHoldMax = 0.2,
    maxFall     = 600,
    coyoteTime  = 0.1,
    jumpBuffer  = 0.1,
}

-- -------------------------
-- Create a new player table
-- -------------------------
function Physics.newPlayer(x, y, config)
    config = config or {}
    local cfg = {}
    for k, v in pairs(Physics.defaults) do
        cfg[k] = config[k] or v
    end
    return {
        x = x, y = y,
        w = cfg.w, h = cfg.h,
        vx = 0, vy = 0,
        onGround     = false,
        jumping      = false,
        jumpHoldTime = 0,
        coyoteTimer  = 0,
        jumpBuffer   = 0,
        cfg = cfg,
    }
end

-- -------------------------
-- Movement only — updates velocity from input, no position change
-- Call this before moving and colliding
-- -------------------------
function Physics.updateMovement(p, dt)
    local cfg = p.cfg

    -- Horizontal input
    local dx = 0
    if Input.isDown("left")  then dx = -1 end
    if Input.isDown("right") then dx =  1 end

    local accel = p.onGround and cfg.accel or cfg.airAccel
    if dx ~= 0 then
        p.vx = Utils.clamp(p.vx + dx * accel * dt, -cfg.walkSpeed, cfg.walkSpeed)
    else
        local friction = p.onGround and cfg.friction or cfg.friction * 0.3
        if p.vx > 0 then p.vx = math.max(0, p.vx - friction * dt)
        elseif p.vx < 0 then p.vx = math.min(0, p.vx + friction * dt) end
    end

    -- Coyote time
    if p.onGround then p.coyoteTimer = cfg.coyoteTime
    else p.coyoteTimer = math.max(0, p.coyoteTimer - dt) end

    -- Jump buffer
    p.jumpBuffer = math.max(0, p.jumpBuffer - dt)
    if Input.isPressed("jump") then p.jumpBuffer = cfg.jumpBuffer end

    -- Jump trigger
    if p.jumpBuffer > 0 and p.coyoteTimer > 0 and not p.jumping then
        p.vy           = cfg.jumpForce
        p.jumping      = true
        p.jumpHoldTime = 0
        p.coyoteTimer  = 0
        p.jumpBuffer   = 0
    end

    -- Variable jump hold
    if p.jumping and Input.isDown("jump") then
        if p.jumpHoldTime < cfg.jumpHoldMax and p.vy < 0 then
            p.vy           = p.vy + cfg.jumpHold * dt
            p.jumpHoldTime = p.jumpHoldTime + dt
        end
    end
    if Input.isReleased("jump") then p.jumping = false end

    -- Gravity
    p.vy = Utils.clamp(p.vy + cfg.gravity * dt, -999, cfg.maxFall)
end

-- -------------------------
-- Finalize — call after collision resolution
-- -------------------------
function Physics.finalize(p)
    if p.onGround then p.jumping = false end
end

-- -------------------------
-- AABB collision resolution against rect list
-- -------------------------
function Physics.resolveCollision(p, platforms)
    p.onGround = false
    for _, plat in ipairs(platforms) do
        if Utils.rectOverlap(p, plat) then
            local overlapLeft  = (p.x + p.w) - plat.x
            local overlapRight = (plat.x + plat.w) - p.x
            local overlapTop   = (p.y + p.h) - plat.y
            local overlapBot   = (plat.y + plat.h) - p.y
            local minX = math.min(overlapLeft, overlapRight)
            local minY = math.min(overlapTop,  overlapBot)
            if minY < minX then
                if overlapTop < overlapBot then
                    p.y = plat.y - p.h
                    p.vy = 0
                    p.onGround = true
                else
                    p.y = plat.y + plat.h
                    p.vy = 0
                end
            else
                if overlapLeft < overlapRight then p.x = plat.x - p.w
                else p.x = plat.x + plat.w end
                p.vx = 0
            end
        end
    end
end

-- -------------------------
-- Convenience: full update for simple rect-list worlds
-- -------------------------
function Physics.update(p, platforms, dt)
    Physics.updateMovement(p, dt)
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    Physics.resolveCollision(p, platforms)
    Physics.finalize(p)
end

-- -------------------------
-- Draw player
-- -------------------------
function Physics.drawPlayer(p, r, g, b)
    r, g, b = r or 0.2, g or 0.85, b or 0.4
    love.graphics.setColor(r, g, b)
    love.graphics.rectangle("fill", p.x, p.y, p.w, p.h)
    love.graphics.setColor(r + 0.1, g + 0.1, b + 0.1)
    love.graphics.rectangle("line", p.x, p.y, p.w, p.h)
end

return Physics
