-- src/characters/states/land.lua
local land = {}

local BASE_TIME   = 0.12
local CROUCH_PEAK = 0.35

function land.enter(c)
    local impact  = c.landImpact or 400
    c.landTimer   = BASE_TIME * math.min(2.2, impact / 380)
    c.landTotal   = c.landTimer
    c.stepper:reset(c.pos.x, c.pos.y, c.floorZ)

    if c.springs then
        local impact_n = math.min(1, impact / 600)
        c.springs.bob.velocity  = -impact_n * 12
        c.springs.arm.velocity  =  impact_n * 6
        c.springs.lean.velocity =  impact_n * 0.08
    end
end

function land.update(c, dt)
    c.landTimer = c.landTimer - dt
    if c.landTimer <= 0 then
        local moving = math.abs(c.inputX) + math.abs(c.inputY) > 0
        return moving and "walk" or "idle"
    end
end

function land.draw(c, camera)
    local dt  = c.dt or 0
    local t   = 1 - (c.landTimer / c.landTotal)
    local sp  = c.springs
    local p   = c.profile

    local squash
    if t < CROUCH_PEAK then
        squash = 1 - (t / CROUCH_PEAK) * 0.38
    else
        local rise = (t - CROUCH_PEAK) / (1 - CROUCH_PEAK)
        squash = 0.62 + rise * 0.38
    end

    local lean = (1 - t) * (p.lean or 0.1) * 0.5

    if sp then
        sp.arm:update(dt, 0, p.arm_stiffness or 18, p.arm_damping or 12)
        sp.bob:update(dt, 0, p.body_stiffness or 22, p.body_damping or 14)
    end

    c.draw.render(c, {
        squash     = squash,
        lean       = lean,
        swingAngle = sp and sp.arm.value or 0,
        bob        = sp and sp.bob.value or 0,
    }, camera)
end

return land
