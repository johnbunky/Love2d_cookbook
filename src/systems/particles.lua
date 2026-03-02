-- src/systems/particles.lua
-- Particle pool, emitter definitions, update logic.
-- Engine-agnostic — no LÖVE calls.
-- Drawing is handled by the caller using the data in each particle.
--
-- Usage:
--   local Particles = require("src.systems.particles")
--
--   local pool = Particles.newPool(2000)
--
--   -- Define an emitter
--   local fire = Particles.newEmitter({
--       rate  = 40,
--       burst = 0,
--       spawn = function(x, y) return Particles.preset.fire(x, y) end,
--   })
--
--   -- Emit
--   Particles.emit(pool, fire, x, y)           -- burst or start continuous
--   Particles.update(pool, dt)
--
--   -- Draw (caller iterates)
--   for _, p in ipairs(pool.active) do
--       -- use p.x, p.y, p.size, p.r, p.g, p.b, p.alpha, p.life/p.maxLife
--   end

local Particles = {}

-- -------------------------
-- Pool
-- -------------------------
function Particles.newPool(maxSize)
    return {
        maxSize = maxSize or 2000,
        active  = {},
        _store  = {},   -- recycled particle tables
    }
end

local function acquire(pool)
    local p = table.remove(pool._store)
    if not p then p = {} end
    return p
end

local function release(pool, p)
    -- clear fields to avoid stale data
    for k in pairs(p) do p[k] = nil end
    table.insert(pool._store, p)
end

-- -------------------------
-- Emitter definition
-- rate  : particles per second (0 = burst only)
-- burst : particles on each emit() call
-- spawn : function(x, y) → particle table
--         Required fields: x, y, vx, vy, life, maxLife
--         Optional: size, r, g, b, alpha, gravity, vr (rot velocity),
--                   ax, ay (acceleration), drag
-- -------------------------
function Particles.newEmitter(config)
    return {
        rate    = config.rate  or 0,
        burst   = config.burst or 0,
        spawn   = config.spawn,
        _timer  = 0,
    }
end

-- -------------------------
-- Emit particles from emitter at x,y
-- For continuous emitters call every frame; for burst call once
-- -------------------------
function Particles.emit(pool, emitter, x, y, dt)
    dt = dt or 0
    local spawned = 0
    local max     = pool.maxSize

    -- Burst
    if emitter.burst > 0 then
        for _ = 1, emitter.burst do
            if #pool.active < max then
                local p = acquire(pool)
                local data = emitter.spawn(x, y)
                for k, v in pairs(data) do p[k] = v end
                table.insert(pool.active, p)
                spawned = spawned + 1
            end
        end
    end

    -- Continuous
    if emitter.rate > 0 and dt > 0 then
        emitter._timer = emitter._timer + dt
        local count    = math.floor(emitter._timer * emitter.rate)
        if count > 0 then
            emitter._timer = emitter._timer - count / emitter.rate
            for _ = 1, count do
                if #pool.active < max then
                    local p    = acquire(pool)
                    local data = emitter.spawn(x, y)
                    for k, v in pairs(data) do p[k] = v end
                    table.insert(pool.active, p)
                    spawned = spawned + 1
                end
            end
        end
    end

    return spawned
end

-- -------------------------
-- Update all active particles
-- -------------------------
function Particles.update(pool, dt)
    local active = pool.active
    local i = #active
    while i >= 1 do
        local p = active[i]
        p.life = p.life - dt

        if p.life <= 0 then
            table.remove(active, i)
            release(pool, p)
        else
            -- Position
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt

            -- Gravity
            if p.gravity then
                p.vy = p.vy + p.gravity * dt
            end

            -- Acceleration
            if p.ax then p.vx = p.vx + p.ax * dt end
            if p.ay then p.vy = p.vy + p.ay * dt end

            -- Drag
            if p.drag then
                local factor = 1 - math.min(1, p.drag * dt)
                p.vx = p.vx * factor
                p.vy = p.vy * factor
            end

            -- Rotation
            if p.vr then
                p.rot = (p.rot or 0) + p.vr * dt
            end

            -- Wobble (sinusoidal x drift)
            if p.wobble then
                p.wobbleT  = (p.wobbleT or 0) + dt * (p.wobbleSpeed or 3)
                p.x        = p.x + math.sin(p.wobbleT) * (p.wobbleAmp or 1) * dt
            end

            -- Computed alpha (life-based fade)
            local t      = p.life / p.maxLife
            p.alpha      = (p.alphaFn and p.alphaFn(t)) or t
            p.drawSize   = p.size * ((p.sizeFn and p.sizeFn(t)) or 1)
        end

        i = i - 1
    end
end

-- -------------------------
-- Clear all particles
-- -------------------------
function Particles.clear(pool)
    for _, p in ipairs(pool.active) do
        release(pool, p)
    end
    pool.active = {}
end

-- -------------------------
-- Count active particles
-- -------------------------
function Particles.count(pool)
    return #pool.active
end

-- -------------------------
-- Presets — pure data, no drawing
-- Each returns a table with all particle fields set
-- -------------------------
Particles.preset = {}

local function rnd(a, b) return a + math.random() * (b - a) end
local function rndInt(a, b) return math.random(a, b) end

Particles.preset.fire = function(x, y)
    local spread = rnd(-18, 18)
    return {
        x=x+spread, y=y,
        vx=spread*0.6 + rnd(-15,15),
        vy=rnd(-90,-50),
        life=rnd(0.5, 0.9), maxLife=rnd(0.5,0.9),
        size=rnd(6,16),
        r=1, g=rnd(0.2,0.7), b=0,
        drag=0.5,
        alphaFn = function(t) return t * 0.9 end,
        sizeFn  = function(t) return t end,
        blend   = "add",
    }
end

Particles.preset.smoke = function(x, y)
    local sz = rnd(8, 20)
    return {
        x=x+rnd(-10,10), y=y,
        vx=rnd(-20,20), vy=rnd(-35,-15),
        life=rnd(1.2,2.0), maxLife=2.0,
        size=sz,
        r=rnd(0.3,0.5), g=rnd(0.3,0.5), b=rnd(0.3,0.5),
        vr=rnd(-0.6,0.6),
        alphaFn = function(t) return t * 0.35 end,
        sizeFn  = function(t) return 2-t end,
        blend   = "alpha",
    }
end

Particles.preset.spark = function(x, y)
    local angle = math.random() * math.pi * 2
    local speed = rnd(80, 320)
    return {
        x=x, y=y,
        vx=math.cos(angle)*speed, vy=math.sin(angle)*speed - 60,
        life=rnd(0.3,0.7), maxLife=0.7,
        size=rnd(2,4),
        r=1, g=rnd(0.5,1.0), b=0,
        gravity=280,
        alphaFn = function(t) return t end,
        sizeFn  = function(t) return t end,
        blend   = "add",
    }
end

Particles.preset.blood = function(x, y)
    local angle = math.random() * math.pi * 2
    local speed = rnd(40, 200)
    return {
        x=x, y=y,
        vx=math.cos(angle)*speed, vy=math.sin(angle)*speed - 30,
        life=rnd(0.4,0.8), maxLife=0.8,
        size=rnd(3,7),
        r=0.75, g=0.05, b=0.05,
        gravity=320,
        drag=1.5,
        alphaFn = function(t) return math.min(1, t*3) end,
        sizeFn  = function(t) return 1 end,
        blend   = "alpha",
    }
end

Particles.preset.dust = function(x, y)
    local shade = rnd(0.7, 1.0)
    return {
        x=x+rnd(-20,20), y=y,
        vx=rnd(-60,60), vy=rnd(-80,-20),
        life=rnd(0.6,1.1), maxLife=1.1,
        size=rnd(3,7),
        r=0.76*shade, g=0.62*shade, b=0.38*shade,
        gravity=rnd(180,280),
        alphaFn = function(t) return math.min(1,t*4)*t end,
        sizeFn  = function(t) return 1 end,
        blend   = "alpha",
    }
end

Particles.preset.snow = function(x, y, screenW)
    return {
        x=x + rnd(-(screenW or 400)/2, (screenW or 400)/2),
        y=y - rnd(0,40),
        vx=rnd(-25,25), vy=rnd(30,70),
        life=rnd(3.0,6.0), maxLife=6.0,
        size=rnd(2,6),
        r=0.85, g=0.92, b=1.0,
        wobble=true, wobbleSpeed=2, wobbleAmp=8,
        alphaFn = function(t)
            return math.min(1, t*3) * math.min(1, (1-t)*5+0.2)
        end,
        sizeFn = function(t) return 1 end,
        blend  = "alpha",
    }
end

Particles.preset.explosion = function(x, y)
    local angle = math.random() * math.pi * 2
    local speed = rnd(40, 380)
    return {
        x=x + math.cos(angle)*rnd(0,20),
        y=y + math.sin(angle)*rnd(0,20),
        vx=math.cos(angle)*speed,
        vy=math.sin(angle)*speed,
        life=rnd(0.25,0.8), maxLife=0.8,
        size=rnd(4,22),
        r=1, g=rnd(0.1,0.6), b=0,
        gravity=rnd(50,150),
        alphaFn = function(t) return t*0.9 end,
        sizeFn  = function(t) return t end,
        blend   = "add",
    }
end

Particles.preset.magic = function(x, y, hue)
    hue = hue or math.random()
    -- HSV to RGB
    local h = hue * 6
    local i = math.floor(h)
    local f = h - i
    local r,g,b
    if     i==0 then r,g,b=1,f,0
    elseif i==1 then r,g,b=1-f,1,0
    elseif i==2 then r,g,b=0,1,f
    elseif i==3 then r,g,b=0,1-f,1
    elseif i==4 then r,g,b=f,0,1
    else         r,g,b=1,0,1-f end
    return {
        x=x+rnd(-6,6), y=y+rnd(-6,6),
        vx=rnd(-40,40), vy=rnd(-40,40),
        life=rnd(0.3,0.6), maxLife=0.6,
        size=rnd(3,9),
        r=r, g=g, b=b,
        alphaFn = function(t) return t end,
        sizeFn  = function(t) return t end,
        blend   = "add",
    }
end

return Particles
