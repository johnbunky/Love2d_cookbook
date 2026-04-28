-- src/characters/states/sit.lua
-- Triggered by inputSit=true. Lowers hip toward floor; stand by inputSit or any movement.
local sit = {}

local SIT_TIME = 0.40

function sit.enter(c)
    c.sitPhase   = "sitting_down"
    c.sit_t      = 0
    c.sitDir     = 1
    c.sitFloorZ  = c.floorZ
    c.sitStandGZ = c.groundZ

    local fwd = c.facing * 14
    local f1  = c.stepper.feet[1]
    local f2  = c.stepper.feet[2]
    f1.x, f1.y, f1.z = c.pos.x + fwd - 8, c.pos.y, c.sitFloorZ
    f2.x, f2.y, f2.z = c.pos.x + fwd + 8, c.pos.y, c.sitFloorZ
    f1.planted, f2.planted = true, true

    if c.springs then
        c.springs.arm:reset(0)
        c.springs.sway:reset(0)
        c.springs.lean:reset(0)
    end
end

function sit.update(c, dt)
    c.inputX = 0
    c.inputY = 0

    c.sit_t = math.max(0, math.min(1,
        c.sit_t + c.sitDir * dt / SIT_TIME))

    local st      = c.sit_t * c.sit_t * (3 - 2 * c.sit_t)
    local sit_gz  = c.sitFloorZ  + c.leg_len * 0.28
    local target_z = c.sitStandGZ + (sit_gz - c.sitStandGZ) * st

    c.pos.z    = c.pos.z + (target_z - c.pos.z) * math.min(1, dt * 10)
    c.vel.z    = 0
    c.onGround = true

    c.stepper.feet[1].planted = true
    c.stepper.feet[2].planted = true

    if c.sitPhase == "sitting_down" and c.sit_t >= 1 then
        c.sitPhase = "seated"
    end

    if c.sitPhase == "seated" then
        -- stand up when sit is pressed again or any movement input arrives
        local wantStand = c.inputSit
                       or math.abs(c.inputX) + math.abs(c.inputY) > 0
        if wantStand then
            c.sitPhase = "standing_up"
            c.sitDir   = -1
        end
    end

    if c.sitPhase == "standing_up" and c.sit_t <= 0 then
        c.groundZ = c.sitStandGZ
        c.pos.z   = c.sitStandGZ
        c.vel.z   = 0
        return "idle"
    end
end

function sit.draw(c, camera)
    local t  = c.sit_t
    local st = t * t * (3 - 2 * t)
    local p  = c.profile
    local dt = c.dt or 0

    local lean = st * 0.30

    if c.springs then
        c.springs.arm:update(dt, st * (p.arm_swing or 0.5) * 0.4,
            p.arm_stiffness or 18, p.arm_damping or 12)
    end

    local breath = math.sin((c.breathTimer or 0) * 0.9) * 1.5 * (1 - st * 0.6)
    local sway   = math.sin((c.idleTimer  or 0) * 0.6) * 2.0 * (1 - st * 0.8)

    c.draw.render(c, {
        swingAngle = c.springs and c.springs.arm.value or 0,
        lean       = lean,
        spineExtra = breath,
        sway       = sway,
    }, camera)
end

return sit
