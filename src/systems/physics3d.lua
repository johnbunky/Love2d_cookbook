-- src/systems/physics3d.lua
-- Simple 3-axis character physics with gravity, acceleration, drag, and
-- ground collision. Designed for the z-up world convention.
-- Pure Lua — no engine dependencies.
--
-- WORLD AXES:
--   x = left / right
--   y = depth (into/out of screen)
--   z = height  (gravity pulls z downward)
--
-- ENTITY FIELDS REQUIRED:
--   entity.pos        { x, y, z }        world position
--   entity.vel        { x, y, z }        world velocity
--   entity.inputX     number  -1 / 0 / 1 horizontal input
--   entity.inputY     number  -1 / 0 / 1 depth input
--   entity.groundZ    number              height of the ground below entity
--   entity.onGround   boolean             set by Physics.update each frame
--   entity.profile    table               see PROFILE FIELDS below
--
-- PROFILE FIELDS USED:
--   accel      acceleration force (pixels/sec²)
--   drag       friction coefficient — higher = stops faster  (try 6–12)
--   max_vx     top horizontal speed (pixels/sec)
--   jump_vy    jump impulse magnitude (stored positive or negative, always negated)

local Physics = {}

local GRAVITY = 900   -- pixels/sec² downward (z-axis)

-- Advance entity physics by dt seconds.
-- Sets entity.onGround = true when the entity lands.
function Physics.update(entity, dt)
    local p   = entity.profile
    local pos = entity.pos
    local vel = entity.vel

    -- ── Horizontal (x) ───────────────────────────────────────────────────
    local ix = entity.inputX or 0
    if ix ~= 0 then
        vel.x = vel.x + ix * p.accel * dt
        vel.x = math.max(-p.max_vx, math.min(p.max_vx, vel.x))
    else
        vel.x = vel.x * (1 - math.min(1, p.drag * dt))
        if math.abs(vel.x) < 1 then vel.x = 0 end
    end

    -- ── Depth (y) — same as x but slightly slower ─────────────────────────
    local iy    = entity.inputY or 0
    local max_vy = p.max_vx * 0.85
    if iy ~= 0 then
        vel.y = vel.y + iy * p.accel * 0.85 * dt
        vel.y = math.max(-max_vy, math.min(max_vy, vel.y))
    else
        vel.y = vel.y * (1 - math.min(1, p.drag * dt))
        if math.abs(vel.y) < 1 then vel.y = 0 end
    end

    -- ── Height (z) — gravity ──────────────────────────────────────────────
    vel.z = vel.z - GRAVITY * dt

    -- ── Integrate ─────────────────────────────────────────────────────────
    pos.x = pos.x + vel.x * dt
    pos.y = pos.y + vel.y * dt
    pos.z = pos.z + vel.z * dt

    -- ── Ground collision ──────────────────────────────────────────────────
    local gz = entity.groundZ or 0
    entity.onGround = false
    if pos.z <= gz and vel.z <= 0 then
        pos.z       = gz
        vel.z       = 0
        entity.onGround = true
    end
end

-- Apply an upward impulse for jumping.
-- profile.jump_vy may be stored as a negative legacy value; we always use
-- the absolute magnitude so it correctly pushes z upward.
function Physics.jump(entity)
    entity.vel.z = math.abs(entity.profile.jump_vy)
end

return Physics
