-- src/characters/states/fall.lua
local Physics = require "src.systems.physics3d"
local fall = {}

function fall.update(c, dt)
    -- inputX/Y are already set by the demo before update is called
    Physics.update(c, dt)
    c.stepper:update(dt, c.pos.x, c.pos.y, c.pos.z, c.vel.x, c.vel.y, c.floorZ, false, nil)

    if c.onGround then
        c.landImpact = math.abs(c.vel.z)
        return "land"
    end
end

function fall.draw(c, camera)
    local dt    = c.dt or 0
    local p     = c.profile
    local sp    = c.springs
    local vel_z = c.vel.z

    local extend = math.min(1, -vel_z / 400)

    if sp then
        local t_arm = -(p.arm_swing or 0.5) * extend * 0.3
        sp.arm:update(dt, t_arm, p.arm_stiffness or 18, p.arm_damping or 12)
        sp.bob:update(dt, extend * 3, p.body_stiffness or 22, p.body_damping or 14)
    end

    local ant_lean = extend * (p.lean or 0.1) * 0.35

    c.draw.render(c, {
        swingAngle = sp and sp.arm.value or 0,
        legExtend  = extend,
        lean       = ant_lean,
        bob        = sp and sp.bob.value or 0,
        squash     = 1.0 + extend * 0.08,
    }, camera)
end

return fall
