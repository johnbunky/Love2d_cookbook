-- src/characters/states/idle.lua
local Physics = require "src.systems.physics3d"
local idle = {}

function idle.enter(c)
    c.breathTimer = c.breathTimer or 0
    c.swingAngle  = c.swingAngle  or 0
    c.idleTimer   = c.idleTimer   or 0
    c.stepper:reset(c.pos.x, c.pos.y, c.floorZ)
end

function idle.update(c, dt)
    -- sample input BEFORE zeroing — used for transition checks below
    local wantMove = math.abs(c.inputX) + math.abs(c.inputY) > 0
    local wantSit  = c.inputSit

    c.inputX = 0
    c.inputY = 0
    Physics.update(c, dt)

    local breath_speed = c.profile.idle_breath or 0.9
    local fidget       = c.profile.idle_fidget or 1.0

    c.breathTimer = c.breathTimer + dt * breath_speed
    c.idleTimer   = c.idleTimer   + dt * 0.3 * fidget
    c.swingAngle  = c.swingAngle  * (1 - math.min(1, dt * 8))

    c.stepper:update(dt, c.pos.x, c.pos.y, c.pos.z, 0, 0, c.floorZ, c.onGround, c:quadHipRefs())

    if wantMove              then return "walk" end
    if wantSit               then return "sit"  end
    if not c.onGround        then return "fall" end
end

function idle.draw(c, camera)
    local bt     = c.breathTimer
    local it     = c.idleTimer
    local fidget = c.profile.idle_fidget or 1.0

    local breath       = math.sin(bt) * 2.5
    local breath_shrug = math.sin(bt) * 1.5
    local sway = (math.sin(it * 1.1) * 0.6 + math.sin(it * 0.7) * 0.4) * 5.0 * fidget
    local lean = sway * 0.004
    local arm_rest = math.sin(bt * 0.5) * 0.04 * fidget + 0.06

    c.draw.render(c, {
        swingAngle = c.swingAngle * 0.3 + arm_rest,
        spineExtra = breath + breath_shrug,
        sway       = sway,
        lean       = lean,
    }, camera)
end

return idle
