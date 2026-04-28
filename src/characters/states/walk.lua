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
    local t_arm  = math.sin(ph) * blend(arm_swing, p.run_arm_pump or arm_swing*1.6) * speed_n
    local bob_amp  = blend(p.walk_bob  or 6,   p.run_bob  or 11)
    local sway_amp = blend(p.walk_sway or 2.5, p.run_sway or 1.2)

    local t_bob  = math.abs(math.sin(ph)) * bob_amp  * speed_n
    local t_sway = math.sin(ph) * sway_amp * speed_n
    local t_lean = (p.lean or 0.12) * math.abs(c.vel.x + c.vel.y * 0.5) / (p.max_vx or 220)
    t_lean = t_lean * blend(1, p.run_lean and p.run_lean / (p.lean or 0.12) or 2)

    local wave_amp = blend(p.walk_wave or 4.0, 0)
    local t_wave   = math.sin(ph) * wave_amp * speed_n

    local counter_amp = blend(p.walk_counter or 0.08, p.run_counter or 0.15)
    local t_shoulder  = -math.sin(ph) * counter_amp * speed_n

    if sp then
        sp.arm:update(dt,  t_arm,  p.arm_stiffness  or 10, p.arm_damping  or 6)
        sp.bob:update(dt,  t_bob,  p.body_stiffness or 14, p.body_damping or 9)
        sp.sway:update(dt, t_sway, p.body_stiffness or 14, p.body_damping or 9)
        sp.lean:update(dt, t_lean, p.body_stiffness or 14, p.body_damping or 9)

        -- breast physics (only when profile.breast is defined)
        if p.breast then
            local t_breast = sp.bob.velocity * 0.012
            sp.breast_l:update(dt, -t_breast, 18, 7)
            sp.breast_r:update(dt,  t_breast, 18, 7)
        end
    end

    c.draw.render(c, {
        swingAngle    = sp and sp.arm.value  or t_arm,
        bob           = sp and sp.bob.value  or t_bob,
        sway          = sp and sp.sway.value or t_sway,
        lean          = sp and sp.lean.value or t_lean,
        wave          = t_wave,
        shoulderRotate= t_shoulder,
        speed_n       = speed_n,
        run_n         = run_n,
    }, camera)
end

return walk
