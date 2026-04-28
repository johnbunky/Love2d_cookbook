-- src/characters/states/jump.lua
local Physics = require "src.systems.physics3d"
local jump = {}

local SQUASH_TIME = 0.10

function jump.enter(c)
    Physics.jump(c)
    c.jumpTimer  = 0
    c.jumpSquash = 1.0
    c.stepper:update(0, c.pos.x, c.pos.y, c.pos.z, c.vel.x, c.vel.y, c.floorZ, false, nil)

    if c.springs then
        local kick = (c.profile.arm_swing or 0.5) * 1.2
        c.springs.arm.velocity  =  kick * 8
        c.springs.bob.velocity  = -6
        c.springs.lean.value    =  c.springs.lean.value * 0.3
    end
end

function jump.update(c, dt)
    -- inputX/Y are already set by the demo before update is called
    c.jumpTimer = c.jumpTimer + dt

    Physics.update(c, dt)
    c.stepper:update(dt, c.pos.x, c.pos.y, c.pos.z, c.vel.x, c.vel.y, c.floorZ, false, nil)

    if c.jumpTimer < SQUASH_TIME then
        c.jumpSquash = 1.0 - math.sin(c.jumpTimer / SQUASH_TIME * math.pi) * 0.22
    else
        c.jumpSquash = 1.0
    end

    if c.vel.z < 0 then return "fall" end
end

function jump.draw(c, camera)
    local dt    = c.dt or 0
    local p     = c.profile
    local sp    = c.springs
    local vel_z = c.vel.z

    local jump_vy = math.abs(p.jump_vy or 530)
    local tuck    = math.max(0, vel_z / jump_vy)

    if sp then
        local t_arm = tuck * (p.arm_swing or 0.5) * 0.8
        sp.arm:update(dt, t_arm,  p.arm_stiffness  or 18, p.arm_damping  or 12)
        sp.bob:update(dt, -tuck * 4, p.body_stiffness or 22, p.body_damping or 14)
    end

    c.draw.render(c, {
        swingAngle = sp and sp.arm.value or 0,
        squash     = c.jumpSquash or 1.0,
        airTuck    = tuck,
        bob        = sp and sp.bob.value or 0,
        lean       = sp and sp.lean.value or 0,
    }, camera)
end

return jump
