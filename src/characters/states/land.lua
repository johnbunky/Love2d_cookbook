-- src/characters/states/land.lua

local land = {}

local BASE_TIME = 0.22   -- was 0.12 — gives more time to show the crouch and recover

function land.enter(c)
    local impact   = c.landImpact or 400
    local impact_n = math.min(1, impact / 600)

    c.landTimer = BASE_TIME * math.min(2.2, impact / 380)
    c.landTotal = c.landTimer

    c.stepper:reset(c.pos.x, c.pos.y, c.floorZ)

    if c.springs then
        -- bob: immediate crouch, NO upward velocity (that caused overshoot → push look)
        c.springs.bob.value    = -impact_n * 40   -- was 22, bigger = more visible crouch
        c.springs.bob.velocity = 0

        -- squash: immediate spine compression
        if c.springs.squash then
            c.springs.squash.value    = 1 - impact_n * 0.32
            c.springs.squash.velocity = 0
        end

        -- arm swings forward
        c.springs.arm.velocity = impact_n * 6

        -- lean tips forward
        c.springs.lean.value    =  impact_n * 0.12
        c.springs.lean.velocity = 0

        -- breast: SET velocity (not add) — fall drives breast to vel~100,
        -- adding -30 to +100 still leaves +70 (breast keeps rising on landing)
        if c.springs.breast_l then
            c.springs.breast_l.velocity = -impact_n * 60  -- SET, overrides fall momentum
            c.springs.breast_r.velocity = -impact_n * 60 * 0.93
        end
    end
end

function land.update(c, dt)
    c.landTimer = c.landTimer - dt
    if c.landTimer <= 0 then
        -- snap bob and squash to rest before handing off to idle/walk
        -- so there's no visual pop when those states don't update the springs
        if c.springs then
            c.springs.bob.value    = 0
            c.springs.bob.velocity = 0
            if c.springs.squash then
                c.springs.squash.value    = 1
                c.springs.squash.velocity = 0
            end
        end
        local moving = math.abs(c.inputX) + math.abs(c.inputY) > 0
        return moving and "walk" or "idle"
    end
end

function land.draw(c, camera)
    local dt = c.dt or 0
    local sp = c.springs
    local p  = c.profile

    if sp then
        sp.bob:update (dt, 0, p.body_stiffness or 10, p.body_damping or 7)
        sp.arm:update (dt, 0, p.arm_stiffness  or 14, p.arm_damping  or 9)
        sp.lean:update(dt, 0, p.lean_stiffness or  9, p.lean_damping or 6)
        if sp.squash then
            sp.squash:update(dt, 1, p.body_stiffness or 10, p.body_damping or 7)
        end
    end

    -- legs briefly reach toward ground at moment of impact, then fold into crouch.
    -- fades from impact_n to 0 over the first 20% of the land state.
    local t          = 1 - (c.landTimer / (c.landTotal or 1))
    local impact_n   = c.landImpact and math.min(1, c.landImpact / 600) or 0
    local ground_ext = math.max(0, 1 - t / 0.20) * impact_n * 0.6

    c.draw.render(c, {
        bob        = sp and math.min(0, sp.bob.value) or 0,
        squash     = (sp and sp.squash) and math.max(0.5, sp.squash.value) or 1,
        lean       = sp and sp.lean.value  or 0,
        swingAngle = sp and sp.arm.value   or 0,
        legExtend  = ground_ext,
    }, camera)
end

return land
