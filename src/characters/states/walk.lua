-- src/characters/states/walk.lua
local Physics = require "src.systems.physics3d"
local walk = {}

function walk.enter(c)
    c.walkPhase = c.walkPhase or 0
    c.run_n     = 0
    c.speed_n   = 0
end

function walk.update(c, dt)
    Physics.update(c, dt)

    local spd     = math.sqrt(c.vel.x^2 + c.vel.y^2)
    local speed_n = math.min(1, spd / c.profile.max_vx)

    local run_thresh = c.profile.run_threshold or 0.55
    local run_n = math.max(0, (speed_n - run_thresh) / (1 - run_thresh))

    local walk_ps = c.profile.walk_phase_speed or 10
    local run_ps  = c.profile.run_phase_speed  or 16
    c.walkPhase = c.walkPhase + dt * speed_n * (walk_ps + (run_ps - walk_ps) * run_n)

    c.speed_n = speed_n
    c.run_n   = run_n

    -- remember last movement direction so body holds orientation after stopping
    if spd > 4 then
        c.lastDx = c.vel.x / spd
        c.lastDy = c.vel.y / spd
    end

    c.stepper:update(dt, c.pos.x, c.pos.y, c.pos.z, c.vel.x, c.vel.y, c.floorZ, true, c:quadHipRefs())

    if not c.onGround then return "fall" end

    local moving = math.abs(c.inputX) + math.abs(c.inputY) > 0
    if not moving and spd < 2 then return "idle" end
end

function walk.draw(c, camera)
    local ph      = c.walkPhase
    local speed_n = c.speed_n or 0
    local run_n   = c.run_n   or 0
    local p       = c.profile
    local sp      = c.springs
    local dt      = c.dt or 0

    local function blend(a, b) return a + (b - a) * run_n end

    local arm_swing = p.arm_swing or 0
    local bob_amp   = blend(p.walk_bob  or 6,   p.run_bob  or 11)
    local sway_amp  = blend(p.walk_sway or 2.5, p.run_sway or 1.2)

    local t_bob  = math.abs(math.sin(ph)) * bob_amp  * speed_n
    -- sway uses c.facing so hip swings in the correct screen direction regardless
    -- of whether the character last moved in x or depth
    local t_sway = math.cos(ph) * sway_amp * speed_n * c.facing
    local wave_amp = p.walk_wave or sway_amp * 0.6
    local t_wave   = math.sin(ph) * wave_amp * speed_n
    local t_lean   = speed_n * blend(p.lean or 0, p.run_lean or (p.lean or 0) * 2.2)

    -- arm swing: drive spring target, blend with direct value
    local t_arm_direct = math.sin(ph) * blend(arm_swing, p.run_arm_pump or arm_swing*1.6) * speed_n

    local arm_k  = p.arm_stiffness  or 10
    local arm_d  = p.arm_damping    or 6
    local body_k = p.body_stiffness or 14
    local body_d = p.body_damping   or 9

    if sp then
        sp.arm:update(dt,  t_arm_direct, arm_k, arm_d)
        sp.lean:update(dt, t_lean,       body_k, body_d)

        if p.breast then
            local t_breast = sp.bob and sp.bob.velocity * 0.012 or 0
            sp.breast_l:update(dt, -t_breast, 18, 7)
            sp.breast_r:update(dt,  t_breast, 18, 7)
        end
    end

    -- at speed: use direct value (full amplitude); stopping: spring settles to zero
    local arm_val  = t_arm_direct * speed_n + (sp and sp.arm.value or 0) * (1 - speed_n)
    local lean_val = sp and sp.lean.value or t_lean

    local cnt             = blend(p.walk_counter or 0.08, p.run_counter or 0.15)
    local shoulder_rotate = -t_sway * cnt
    local hip_rot         = (p.walk_hip_rotation or 0) * math.cos(ph) * speed_n

    c.draw.render(c, {
        swingAngle     = arm_val,
        bob            = t_bob,
        sway           = t_sway,
        wave           = t_wave,
        lean           = lean_val,
        shoulderRotate = shoulder_rotate,
        hipRotate      = hip_rot,
        speed_n        = speed_n,
        run_n          = run_n,
    }, camera)
end

return walk
