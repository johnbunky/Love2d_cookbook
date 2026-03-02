-- src/states/examples/day_night.lua
-- Demonstrates: DayCycle + Lighting systems, sky color, stars, sun/moon, ambient tinting

local Utils    = require("src.utils")
local DayCycle = require("src.systems.daycycle")
local Lighting = require("src.systems.lighting")
local Timer    = require("src.systems.timer")
local Example  = {}

local W, H
local dc       -- DayCycle instance
local scene    -- Lighting scene
local timer

-- Light handles
local torchL, torchR, windowL

-- World messages
local events = {}
local function addEvent(msg)
    table.insert(events, 1, { text=msg, life=3.0 })
    if #events > 5 then table.remove(events) end
end

-- Stars
local stars = {}
local function makeStars()
    math.randomseed(99)
    stars = {}
    for _ = 1, 160 do
        table.insert(stars, {
            x       = math.random(0, W),
            y       = math.random(0, H * 0.60),
            r       = math.random() * 1.8 + 0.3,
            bright  = math.random(60, 100) / 100,
            twinkle = math.random() * math.pi * 2,
        })
    end
end

-- -------------------------
-- Scene objects (static geometry)
-- -------------------------
local function drawGround(ambR, ambG, ambB)
    -- Sky is drawn by caller; we just draw earth
    love.graphics.setColor(
        0.12 * (ambR + 0.3),
        0.20 * (ambG + 0.2),
        0.10 * (ambB + 0.2))
    love.graphics.rectangle("fill", 0, H*0.62, W, H*0.38)

    -- Grass edge
    love.graphics.setColor(
        0.10 * (ambR*2 + 0.4),
        0.28 * (ambG*2 + 0.3),
        0.08 * (ambB + 0.2))
    love.graphics.rectangle("fill", 0, H*0.62, W, 8)
end

local function drawTrees(ambR, ambG, ambB)
    local treePositions = {80, 160, 580, 680, 740}
    for _, tx in ipairs(treePositions) do
        -- Trunk
        love.graphics.setColor(
            0.25*(ambR+0.2), 0.18*(ambG+0.1), 0.08*(ambB+0.1))
        love.graphics.rectangle("fill", tx-5, H*0.48, 10, H*0.15)
        -- Canopy
        love.graphics.setColor(
            0.08*(ambR*2+0.5), 0.22*(ambG*2+0.4), 0.06*(ambB+0.2))
        love.graphics.polygon("fill",
            tx-28, H*0.50,
            tx,    H*0.32,
            tx+28, H*0.50)
        love.graphics.polygon("fill",
            tx-22, H*0.43,
            tx,    H*0.27,
            tx+22, H*0.43)
    end
end

local function drawBuilding(ambR, ambG, ambB)
    local bx, by, bw, bh = W*0.38, H*0.38, W*0.24, H*0.26
    -- Wall
    love.graphics.setColor(
        0.40*(ambR+0.3), 0.35*(ambG+0.2), 0.28*(ambB+0.1))
    love.graphics.rectangle("fill", bx, by, bw, bh)
    -- Roof
    love.graphics.setColor(
        0.28*(ambR+0.2), 0.20*(ambG+0.1), 0.16*(ambB+0.1))
    love.graphics.polygon("fill",
        bx-10,    by,
        bx+bw/2,  by - H*0.10,
        bx+bw+10, by)
    -- Door
    love.graphics.setColor(
        0.20*(ambR+0.1), 0.15*(ambG+0.1), 0.10*(ambB+0.1))
    love.graphics.rectangle("fill", bx+bw/2-14, by+bh-44, 28, 44)
    -- Windows (drawn separately with light tint)
end

local function drawWindows(ambR, ambG, ambB)
    local bx, by, bw, bh = W*0.38, H*0.38, W*0.24, H*0.26
    local isNight = DayCycle.isNight(dc)

    -- Window glow color
    local wr, wg, wb
    if isNight then
        -- Warm candlelight
        local r, g, b = Lighting.sampleAt(scene, bx+bw*0.25, by+bh*0.35)
        wr, wg, wb = r*1.4, g*0.9, b*0.4
    else
        wr = ambR*0.7 + 0.1
        wg = ambG*0.7 + 0.1
        wb = ambB*0.8 + 0.2
    end
    love.graphics.setColor(wr, wg, wb)
    love.graphics.rectangle("fill", bx+bw*0.18, by+bh*0.28, 24, 20)
    love.graphics.rectangle("fill", bx+bw*0.62, by+bh*0.28, 24, 20)
end

-- -------------------------
-- Sun / Moon drawing
-- -------------------------
local function drawCelestials(skyR, skyG, skyB, sunR, sunG, sunB)
    local angle  = DayCycle.getSunAngle(dc)
    local radius = math.min(W, H) * 0.44
    -- Sun arc: left horizon to right horizon across top of sky area
    local cx = W * 0.5
    local cy = H * 0.62  -- horizon y

    local sx = cx + math.cos(angle) * radius
    local sy = cy - math.sin(angle) * radius

    -- Night: draw moon on opposite side
    local mx = cx - math.cos(angle) * radius * 0.85
    local my = cy + math.sin(angle) * radius * 0.85

    local nightness = DayCycle.getNightness(dc)
    local dayness   = 1 - nightness

    -- Sun
    if dayness > 0.05 and sy < H * 0.62 then
        love.graphics.setColor(sunR, sunG, sunB, dayness)
        love.graphics.circle("fill", sx, sy, 28)
        -- Glow
        love.graphics.setColor(sunR, sunG*0.8, sunB*0.3, dayness*0.25)
        love.graphics.circle("fill", sx, sy, 52)
    end

    -- Moon
    if nightness > 0.05 and my < H * 0.62 then
        love.graphics.setColor(0.92, 0.90, 0.80, nightness)
        love.graphics.circle("fill", mx, my, 22)
        -- Crescent shadow
        love.graphics.setColor(skyR*0.3, skyG*0.3, skyB*0.4, nightness)
        love.graphics.circle("fill", mx+10, my-4, 18)
    end
end

-- -------------------------
-- Draw light halos (canvas-less approximation)
-- -------------------------
local function drawLightHalos()
    local lights = Lighting.getVisible(scene, 0, 0, W, H)
    for _, l in ipairs(lights) do
        -- Soft additive glow rings
        for i = 1, 4 do
            local alpha = l._curIntensity * 0.06 * (5-i)
            local rad   = l.radius * (i/4)
            love.graphics.setColor(l.r, l.g, l.b, alpha)
            love.graphics.circle("fill", l.x, l.y, rad)
        end
        -- Bright core
        love.graphics.setColor(l.r, l.g*0.9, l.b*0.6, l._curIntensity*0.7)
        love.graphics.circle("fill", l.x, l.y, 8)
    end
end

-- -------------------------
-- Enter
-- -------------------------
function Example.enter()
    W = love.graphics.getWidth()
    H = love.graphics.getHeight()

    timer = Timer.new()

    -- Day cycle: 40 second full day, start at dawn
    dc = DayCycle.new({ duration=40, startTime=0.22 })

    dc.onSunrise  = function() addEvent("Sunrise -- birds begin to sing") end
    dc.onNoon     = function() addEvent("High noon -- the sun beats down") end
    dc.onSunset   = function() addEvent("Sunset -- the sky turns crimson") end
    dc.onDusk     = function() addEvent("Dusk -- lights flicker on") end
    dc.onMidnight = function() addEvent("Midnight -- silence falls") end
    dc.onHour     = function(d, h)
        if h % 6 == 0 then
            addEvent(string.format("%02d:00", h))
        end
    end

    -- Lighting scene
    scene = Lighting.newScene({ ambient={0.05, 0.05, 0.10} })

    -- Two torches flanking the building door
    local bx = W*0.38
    local by = H*0.38
    local bw = W*0.24
    local bh = H*0.26
    torchL = Lighting.addLight(scene, {
        x=bx+bw*0.18, y=by+bh*0.75,
        r=1.0, g=0.6, b=0.2,
        radius=120, intensity=0.0,
        flicker=0.35, flickerSpeed=7,
    })
    torchR = Lighting.addLight(scene, {
        x=bx+bw*0.82, y=by+bh*0.75,
        r=1.0, g=0.55, b=0.18,
        radius=120, intensity=0.0,
        flicker=0.40, flickerSpeed=9,
    })
    -- Window light
    windowL = Lighting.addLight(scene, {
        x=bx+bw*0.5, y=by+bh*0.35,
        r=0.95, g=0.75, b=0.3,
        radius=90, intensity=0.0,
        flicker=0.1, flickerSpeed=3,
    })

    makeStars()
    events = {}
end

function Example.exit()
    Timer.clear(timer)
end

function Example.update(dt)
    Timer.update(timer, dt)

    if not dc.paused then
        DayCycle.update(dc, dt)
    end

    -- Drive light intensity from nightness
    local night = DayCycle.getNightness(dc)
    local lights_on = math.min(1, night * 3)  -- fade in quickly at dusk

    local lL = Lighting.getLight(scene, torchL)
    local lR = Lighting.getLight(scene, torchR)
    local lW = Lighting.getLight(scene, windowL)
    if lL then lL.intensity = lights_on end
    if lR then lR.intensity = lights_on end
    if lW then lW.intensity = lights_on * 0.7 end

    -- Update ambient from day cycle
    local amb = DayCycle.getAmbientColor(dc)
    Lighting.setAmbient(scene, amb[1]*0.5, amb[2]*0.5, amb[3]*0.5)

    Lighting.update(scene, dt)

    -- Update events
    for i = #events, 1, -1 do
        events[i].life = events[i].life - dt
        if events[i].life <= 0 then table.remove(events, i) end
    end
end

function Example.draw()
    local sky = DayCycle.getSkyColor(dc)
    local amb = DayCycle.getAmbientColor(dc)
    local sun = DayCycle.getSunColor(dc)
    local night = DayCycle.getNightness(dc)

    -- Sky
    love.graphics.setColor(sky[1], sky[2], sky[3])
    love.graphics.rectangle("fill", 0, 0, W, H*0.63)

    -- Stars
    if night > 0.05 then
        for _, s in ipairs(stars) do
            s.twinkle = s.twinkle + 0.02
            local b = night * (0.6 + math.sin(s.twinkle)*0.4) * s.bright
            love.graphics.setColor(b, b, b*1.1, night)
            love.graphics.circle("fill", s.x, s.y, s.r)
        end
    end

    drawCelestials(sky[1], sky[2], sky[3], sun[1], sun[2], sun[3])
    drawGround(amb[1], amb[2], amb[3])
    drawTrees(amb[1], amb[2], amb[3])
    drawBuilding(amb[1], amb[2], amb[3])

    -- Light halos (before windows so windows glow on top)
    love.graphics.setBlendMode("add")
    drawLightHalos()
    love.graphics.setBlendMode("alpha")

    drawWindows(amb[1], amb[2], amb[3])

    -- Torch flames
    if DayCycle.isNight(dc) or DayCycle.getNightness(dc) > 0.1 then
        local lL = Lighting.getLight(scene, torchL)
        local lR = Lighting.getLight(scene, torchR)
        if lL and lL.intensity > 0.05 then
            local flicker = lL._curIntensity
            love.graphics.setColor(1.0, 0.6*flicker, 0.1, flicker)
            love.graphics.circle("fill", lL.x, lL.y-4, 5*flicker)
            love.graphics.setColor(1.0, 0.9, 0.4, flicker*0.8)
            love.graphics.circle("fill", lL.x, lL.y-6, 2.5*flicker)
        end
        if lR and lR.intensity > 0.05 then
            local flicker = lR._curIntensity
            love.graphics.setColor(1.0, 0.6*flicker, 0.1, flicker)
            love.graphics.circle("fill", lR.x, lR.y-4, 5*flicker)
            love.graphics.setColor(1.0, 0.9, 0.4, flicker*0.8)
            love.graphics.circle("fill", lR.x, lR.y-6, 2.5*flicker)
        end
    end

    -- Clock + info panel
    love.graphics.setColor(0.06, 0.08, 0.15, 0.88)
    love.graphics.rectangle("fill", W-190, 30, 180, 112, 6,6)
    love.graphics.setColor(0.35, 0.50, 0.80)
    love.graphics.rectangle("line", W-190, 30, 180, 112, 6,6)

    -- Clock face
    love.graphics.setColor(0.5, 0.7, 1.0)
    love.graphics.printf(DayCycle.toString(dc), W-190, 38, 180, "center")

    -- Day progress bar
    love.graphics.setColor(0.15, 0.20, 0.35)
    love.graphics.rectangle("fill", W-178, 60, 156, 10, 3,3)
    local dayPct = dc.time
    local barR, barG, barB = sky[1]*1.5+0.1, sky[2]*1.5+0.1, sky[3]*0.8+0.2
    love.graphics.setColor(math.min(1,barR), math.min(1,barG), math.min(1,barB))
    love.graphics.rectangle("fill", W-178, 60, 156*dayPct, 10, 3,3)

    -- Sun/moon marker on bar
    love.graphics.setColor(1, 1, 0.7)
    love.graphics.circle("fill", W-178 + 156*dayPct, 65, 5)

    -- Phase label
    local phase
    if dc.time < 0.22     then phase = "Night"
    elseif dc.time < 0.27 then phase = "Dawn"
    elseif dc.time < 0.48 then phase = "Morning"
    elseif dc.time < 0.52 then phase = "Noon"
    elseif dc.time < 0.73 then phase = "Afternoon"
    elseif dc.time < 0.78 then phase = "Dusk"
    else                       phase = "Night" end
    love.graphics.setColor(0.75, 0.85, 1.0)
    love.graphics.printf(phase, W-190, 76, 180, "center")

    -- Ambient color swatch
    love.graphics.setColor(amb[1], amb[2], amb[3])
    love.graphics.rectangle("fill", W-178, 96, 48, 36, 3,3)
    love.graphics.setColor(0.5, 0.6, 0.8)
    love.graphics.printf("amb", W-178, 106, 48, "center")
    love.graphics.setColor(sky[1], sky[2], sky[3])
    love.graphics.rectangle("fill", W-122, 96, 48, 36, 3,3)
    love.graphics.setColor(0.5, 0.6, 0.8)
    love.graphics.printf("sky", W-122, 106, 48, "center")
    love.graphics.setColor(sun[1]*0.8+0.2, sun[2]*0.6+0.1, sun[3]*0.3)
    love.graphics.rectangle("fill", W-66, 96, 48, 36, 3,3)
    love.graphics.setColor(0.5, 0.6, 0.8)
    love.graphics.printf("sun", W-66, 106, 48, "center")

    -- Event log
    for i, ev in ipairs(events) do
        local a = math.min(1, ev.life)
        love.graphics.setColor(1, 0.95, 0.6, a)
        love.graphics.printf(ev.text, 0, H*0.68 + (i-1)*20, W, "center")
    end

    Utils.drawHUD("DAY / NIGHT",
        "SPACE pause    < > time warp    J/K skip hour    R reset    ESC back")
end

function Example.keypressed(key)
    if key == "space" then
        dc.paused = not dc.paused
    elseif key == "r" then
        Example.enter()
    elseif key == "," or key == "<" then
        dc.speed = math.max(0.1, dc.speed * 0.5)
    elseif key == "." or key == ">" then
        dc.speed = math.min(32, dc.speed * 2)
    elseif key == "j" then
        DayCycle.setHour(dc, dc.hour - 1)
    elseif key == "k" then
        DayCycle.setHour(dc, dc.hour + 1)
    end
    Utils.handlePause(key, Example)
end

return Example
