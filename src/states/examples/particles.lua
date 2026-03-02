-- src/states/examples/particles.lua
-- Demonstrates: particle systems, emitter types, blending, pooling
-- fire, smoke, sparks, snow, explosion, trail, magic

local Utils   = require("src.utils")
local Input   = require("src.input")
local Example = {}

local W, H
local systems   = {}   -- active particle systems
local selected  = 1    -- current emitter type

-- -------------------------
-- Particle pool (reuse tables to avoid GC pressure)
-- -------------------------
local POOL_SIZE = 2000
local pool      = {}
local poolIdx   = 0

local function newParticle()
    poolIdx = poolIdx + 1
    if poolIdx > POOL_SIZE then poolIdx = 1 end
    local p = pool[poolIdx]
    if not p then
        p = {}
        pool[poolIdx] = p
    end
    return p
end

-- -------------------------
-- Emitter definitions
-- -------------------------
local emitters = {}

-- FIRE
emitters.fire = {
    label = "Fire",
    key   = "1",
    rate  = 40,          -- particles per second
    burst = 0,
    spawn = function(x, y)
        local p = newParticle()
        local spread = math.random(-18, 18)
        p.x    = x + spread
        p.y    = y
        p.vx   = spread * 0.6 + math.random(-15, 15)
        p.vy   = math.random(-90, -50)
        p.life = math.random(50, 90) / 100
        p.maxLife = p.life
        p.size = math.random(6, 16)
        p.type = "fire"
        return p
    end,
    draw = function(p)
        local t  = p.life / p.maxLife
        local r  = 1
        local g  = Utils.lerp(0.1, 0.7, t)
        local b  = 0
        local a  = Utils.lerp(0, 0.9, t)
        local sz = p.size * t
        love.graphics.setColor(r, g, b, a)
        love.graphics.circle("fill", p.x, p.y, sz)
    end,
    blend = "add",
}

-- SMOKE
emitters.smoke = {
    label = "Smoke",
    key   = "2",
    rate  = 12,
    burst = 0,
    spawn = function(x, y)
        local p = newParticle()
        p.x    = x + math.random(-10, 10)
        p.y    = y
        p.vx   = math.random(-20, 20)
        p.vy   = math.random(-35, -15)
        p.life = math.random(120, 200) / 100
        p.maxLife = p.life
        p.size = math.random(8, 18)
        p.rot  = math.random() * math.pi * 2
        p.rotV = (math.random() - 0.5) * 1.2
        p.type = "smoke"
        return p
    end,
    draw = function(p)
        local t  = p.life / p.maxLife
        local g  = Utils.lerp(0.15, 0.45, t)
        local a  = Utils.lerp(0, 0.35, t)
        local sz = p.size * (2 - t)
        love.graphics.setColor(g, g, g, a)
        love.graphics.circle("fill", p.x, p.y, sz)
    end,
    blend = "alpha",
}

-- SPARKS
emitters.sparks = {
    label = "Sparks",
    key   = "3",
    rate  = 0,
    burst = 60,
    spawn = function(x, y)
        local p = newParticle()
        local angle = math.random() * math.pi * 2
        local speed = math.random(80, 320)
        p.x    = x
        p.y    = y
        p.vx   = math.cos(angle) * speed
        p.vy   = math.sin(angle) * speed - 60
        p.life = math.random(30, 70) / 100
        p.maxLife = p.life
        p.gravity = 280
        p.size = math.random(2, 4)
        p.type = "spark"
        return p
    end,
    draw = function(p)
        local t  = p.life / p.maxLife
        local a  = t
        love.graphics.setColor(1, Utils.lerp(0.3, 1.0, t), 0, a)
        love.graphics.circle("fill", p.x, p.y, p.size * t)
    end,
    blend = "add",
}

-- SNOW
emitters.snow = {
    label = "Snow",
    key   = "4",
    rate  = 25,
    burst = 0,
    spawn = function(x, y)
        local p = newParticle()
        p.x    = x + math.random(-W/2, W/2)
        p.y    = y - math.random(0, 40)
        p.vx   = math.random(-25, 25)
        p.vy   = math.random(30, 70)
        p.life = math.random(300, 600) / 100
        p.maxLife = p.life
        p.size = math.random(2, 6)
        p.wobble = math.random() * math.pi * 2
        p.type = "snow"
        return p
    end,
    draw = function(p)
        local t = p.life / p.maxLife
        local a = math.min(1, t * 3) * math.min(1, (1-t) * 5 + 0.2)
        love.graphics.setColor(0.85, 0.92, 1.0, a)
        love.graphics.circle("fill", p.x, p.y, p.size)
    end,
    blend = "alpha",
}

-- EXPLOSION (burst)
emitters.explosion = {
    label = "Explosion",
    key   = "5",
    rate  = 0,
    burst = 120,
    spawn = function(x, y)
        local p = newParticle()
        local angle = math.random() * math.pi * 2
        local speed = math.random(40, 380)
        p.x    = x + math.cos(angle) * math.random(0, 20)
        p.y    = y + math.sin(angle) * math.random(0, 20)
        p.vx   = math.cos(angle) * speed
        p.vy   = math.sin(angle) * speed
        p.life = math.random(25, 80) / 100
        p.maxLife = p.life
        p.size = math.random(4, 22)
        p.gravity = math.random(50, 150)
        p.type = "explosion"
        return p
    end,
    draw = function(p)
        local t  = p.life / p.maxLife
        local r  = 1
        local g  = Utils.lerp(0, 0.6, t)
        local b  = Utils.lerp(0, 0.1, t)
        local a  = t * 0.9
        love.graphics.setColor(r, g, b, a)
        love.graphics.circle("fill", p.x, p.y, p.size * t)
    end,
    blend = "add",
}

-- TRAIL (follows mouse)
emitters.trail = {
    label = "Magic Trail",
    key   = "6",
    rate  = 80,
    burst = 0,
    spawn = function(x, y)
        local p = newParticle()
        p.x    = x + math.random(-6, 6)
        p.y    = y + math.random(-6, 6)
        p.vx   = math.random(-30, 30)
        p.vy   = math.random(-30, 30)
        p.life = math.random(30, 60) / 100
        p.maxLife = p.life
        p.size = math.random(3, 9)
        p.hue  = math.random()
        p.type = "trail"
        return p
    end,
    draw = function(p)
        local t  = p.life / p.maxLife
        -- cycle through hues
        local h  = (p.hue + (1-t)*0.3) % 1
        local r, g, b = 0, 0, 0
        local i  = math.floor(h*6)
        local f  = h*6 - i
        if     i==0 then r,g,b=1,f,0
        elseif i==1 then r,g,b=1-f,1,0
        elseif i==2 then r,g,b=0,1,f
        elseif i==3 then r,g,b=0,1-f,1
        elseif i==4 then r,g,b=f,0,1
        else         r,g,b=1,0,1-f end
        love.graphics.setColor(r, g, b, t)
        love.graphics.circle("fill", p.x, p.y, p.size * t)
    end,
    blend = "add",
}

-- MAGIC CIRCLE (burst ring)
emitters.magic = {
    label = "Magic Burst",
    key   = "7",
    rate  = 0,
    burst = 80,
    spawn = function(x, y)
        local p = newParticle()
        local angle = math.random() * math.pi * 2
        local r     = math.random(20, 60)
        p.x    = x + math.cos(angle) * r
        p.y    = y + math.sin(angle) * r
        p.vx   = math.cos(angle) * math.random(30, 100)
        p.vy   = math.sin(angle) * math.random(30, 100) - 40
        p.life = math.random(60, 120) / 100
        p.maxLife = p.life
        p.size = math.random(3, 10)
        p.hue  = angle / (math.pi*2)
        p.type = "magic"
        return p
    end,
    draw = function(p)
        local t  = p.life / p.maxLife
        local h  = p.hue
        local r, g, b = 0,0,0
        local i = math.floor(h*6)
        local f = h*6 - i
        if     i==0 then r,g,b=1,f,0
        elseif i==1 then r,g,b=1-f,1,0
        elseif i==2 then r,g,b=0,1,f
        elseif i==3 then r,g,b=0,1-f,1
        elseif i==4 then r,g,b=f,0,1
        else         r,g,b=1,0,1-f end
        love.graphics.setColor(r, g, b, t)
        love.graphics.circle("fill", p.x, p.y, p.size * t)
    end,
    blend = "add",
}

-- DUST (heavy sand-like particles, fall down with gravity)
emitters.dust = {
    label = "Dust",
    key   = "8",
    rate  = 0,
    burst = 45,
    spawn = function(x, y)
        local p = newParticle()
        p.x    = x + math.random(-20, 20)
        p.y    = y
        p.vx   = math.random(-60, 60)
        p.vy   = math.random(-80, -20)   -- initial upward kick
        p.life = math.random(60, 110) / 100
        p.maxLife = p.life
        p.size = math.random(3, 7)       -- small solid grains
        p.gravity = math.random(180, 280) -- falls back down fast
        p.rot  = math.random() * math.pi * 2
        p.rotV = (math.random() - 0.5) * 4
        p.type = "dust"
        -- vary grain color: sandy tan to light brown
        local shade = math.random(70, 100) / 100
        p.r = 0.76 * shade
        p.g = 0.62 * shade
        p.b = 0.38 * shade
        return p
    end,
    draw = function(p)
        local t = p.life / p.maxLife
        local a = math.min(1, t * 4) * t  -- solid at peak, fade at end
        love.graphics.setColor(p.r, p.g, p.b, a)
        love.graphics.rectangle("fill",
            p.x - p.size/2, p.y - p.size/2,
            p.size, p.size)
    end,
    blend = "alpha",
}

local emitterList = {
    "fire","smoke","sparks","snow","explosion","trail","magic","dust"
}

-- -------------------------
-- System management
-- -------------------------
local function newSystem(type, x, y)
    local def = emitters[type]
    local sys = {
        type    = type,
        def     = def,
        x       = x, y = y,
        particles = {},
        timer   = 0,
        continuous = def.rate > 0,
    }
    -- Burst: spawn all at once
    if def.burst > 0 then
        for _ = 1, def.burst do
            table.insert(sys.particles, def.spawn(x, y))
        end
    end
    return sys
end

function Example.enter()
    W = love.graphics.getWidth()
    H = love.graphics.getHeight()
    systems  = {}
    selected = 1
    -- Spawn default fire at center bottom
    table.insert(systems, newSystem("fire", W/2, H/2))
end

function Example.exit() end

function Example.update(dt)
    local etype = emitterList[selected]
    local def   = emitters[etype]

    -- Continuous emitters follow mouse or stay put
    for _, sys in ipairs(systems) do
        if sys.continuous then
            if sys.type == "trail" then
                sys.x, sys.y = love.mouse.getPosition()
            end
            sys.timer = sys.timer + dt
            local count = math.floor(sys.timer * sys.def.rate)
            if count > 0 then
                sys.timer = sys.timer - count / sys.def.rate
                for _ = 1, count do
                    table.insert(sys.particles, sys.def.spawn(sys.x, sys.y))
                end
            end
        end
    end

    -- Update all particles
    for _, sys in ipairs(systems) do
        for i = #sys.particles, 1, -1 do
            local p = sys.particles[i]
            p.x    = p.x + p.vx * dt
            p.y    = p.y + p.vy * dt
            if p.gravity then p.vy = p.vy + p.gravity * dt end
            if p.wobble  then
                p.wobble = p.wobble + dt * 2
                p.x = p.x + math.sin(p.wobble) * 0.5
            end
            if p.rotV then p.rot = (p.rot or 0) + p.rotV * dt end
            p.life = p.life - dt
            if p.life <= 0 then table.remove(sys.particles, i) end
        end
    end

    -- Remove finished burst systems
    for i = #systems, 1, -1 do
        local sys = systems[i]
        if not sys.continuous and #sys.particles == 0 then
            table.remove(systems, i)
        end
    end
end

function Example.draw()
    love.graphics.setColor(0.06, 0.07, 0.10)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Draw all systems
    for _, sys in ipairs(systems) do
        local blend = sys.def.blend or "alpha"
        if blend == "add" then
            love.graphics.setBlendMode("add")
        else
            love.graphics.setBlendMode("alpha")
        end
        for _, p in ipairs(sys.particles) do
            sys.def.draw(p)
        end
        love.graphics.setBlendMode("alpha")

        -- Emitter origin dot (for continuous)
        if sys.continuous and sys.type ~= "trail" then
            love.graphics.setColor(1, 1, 1, 0.15)
            love.graphics.circle("line", sys.x, sys.y, 8)
        end
    end

    -- Reset color
    love.graphics.setColor(1, 1, 1)

    -- Particle count
    local total = 0
    for _, sys in ipairs(systems) do total = total + #sys.particles end
    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.print(string.format("particles: %d   systems: %d", total, #systems), 10, 10)

    -- Emitter selector buttons
    love.graphics.setColor(0.12, 0.14, 0.18)
    love.graphics.rectangle("fill", 0, H-70, W, 70)

    local bw  = 90
    local bh  = 44
    local gap = 8
    local totalW = #emitterList * (bw+gap) - gap
    local sx  = (W - totalW) / 2

    for i, etype in ipairs(emitterList) do
        local def  = emitters[etype]
        local bx   = sx + (i-1)*(bw+gap)
        local by   = H - 58
        local sel  = (i == selected)
        local mx, my   = love.mouse.getPosition()
        local hover= mx>=bx and mx<=bx+bw and my>=by and my<=by+bh

        if sel then
            love.graphics.setColor(0.25, 0.4, 0.6)
        elseif hover then
            love.graphics.setColor(0.2, 0.28, 0.38)
        else
            love.graphics.setColor(0.14, 0.18, 0.24)
        end
        love.graphics.rectangle("fill", bx, by, bw, bh, 5,5)
        love.graphics.setColor(sel and 0.5 or 0.3, sel and 0.7 or 0.45, sel and 1.0 or 0.6)
        love.graphics.rectangle("line", bx, by, bw, bh, 5,5)

        love.graphics.setColor(sel and 1 or 0.7, sel and 1 or 0.7, sel and 1 or 0.7)
        love.graphics.printf("[" .. def.key .. "] " .. def.label, bx, by+6, bw, "center")
        love.graphics.setColor(0.4,0.4,0.5)
        love.graphics.printf(def.rate>0 and "continuous" or "burst", bx, by+26, bw, "center")
    end

    Utils.drawHUD("PARTICLES",
        "1-8 select type    Click to place    C clear    P pause    ESC back")
end

local function placeEmitter(x, y)
    local etype = emitterList[selected]
    local def   = emitters[etype]
    if def.rate > 0 then
        -- Replace continuous emitter
        for i = #systems, 1, -1 do
            if systems[i].continuous then
                table.remove(systems, i)
            end
        end
    end
    table.insert(systems, newSystem(etype, x, y))
end

function Example.keypressed(key)
    local n = tonumber(key)
    if n and n >= 1 and n <= #emitterList then
        selected = n
        -- Replace current emitter with selected type at center
        local etype = emitterList[selected]
        local def   = emitters[etype]
        -- Keep position of last system if exists, else center
        local x = systems[#systems] and systems[#systems].x or W/2
        local y = systems[#systems] and systems[#systems].y or H/2
        -- Remove old continuous emitters, keep burst results
        for i = #systems, 1, -1 do
            if systems[i].continuous then table.remove(systems, i) end
        end
        table.insert(systems, newSystem(etype, x, y))
        return
    end
    if key == "c" then
        systems = {}
        return
    end
    Utils.handlePause(key, Example)
end

function Example.mousepressed(x, y, button)
    if button == 1 then
        -- Don't place on button bar
        if y < H - 70 then placeEmitter(x, y) end
    end
end

function Example.touchpressed(id, x, y)
    if y < H - 70 then
        placeEmitter(x, y)
    else
        -- Check button taps
        local bw  = 90
        local bh  = 44
        local gap = 8
        local totalW = #emitterList*(bw+gap)-gap
        local sx  = (W-totalW)/2
        for i = 1, #emitterList do
            local bx = sx + (i-1)*(bw+gap)
            local by = H - 58
            if x>=bx and x<=bx+bw and y>=by and y<=by+bh then
                selected = i
                return
            end
        end
    end
end

return Example
