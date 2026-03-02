-- src/states/examples/lighting.lua
-- Demonstrates: 2D dynamic lights, ambient, attenuation, flicker, CPU tinting

local Utils    = require("src.utils")
local Lighting = require("src.systems.lighting")
local Timer    = require("src.systems.timer")
local Example  = {}

local W, H
local scene
local timer

-- Camera
local camX, camY = 0, 0

-- Player
local player = { x=0, y=0, r=10, lightId=nil }

-- World geometry: walls and objects
local walls   = {}
local objects = {}  -- crates, barrels etc.

-- Input state
local moveDir = { x=0, y=0 }

-- Selected light for editing
local editLightId = nil
local editMode    = false

-- Log
local log = {}
local function addLog(msg)
    table.insert(log, 1, msg)
    if #log > 4 then table.remove(log) end
end

-- -------------------------
-- Build world
-- -------------------------
local function buildWorld()
    walls = {}
    objects = {}

    -- Outer walls
    local function addWall(x, y, w, h, color)
        table.insert(walls, {x=x, y=y, w=w, h=h, color=color or {0.25,0.22,0.18}})
    end

    -- Room layout
    addWall(-400, -300, 800, 20)   -- top
    addWall(-400,  280, 800, 20)   -- bottom
    addWall(-400, -300,  20, 600)  -- left
    addWall( 380, -300,  20, 600)  -- right

    -- Interior walls
    addWall(-100, -300,  20, 220)
    addWall(-100,  -20,  20, 300)
    addWall( 100,  100,  20, 180)
    addWall( 100, -300,  20, 150)
    addWall(-250,  60,  160,  20)

    -- Crates / barrels
    local function addObj(x, y, w, h, color, label)
        table.insert(objects, {x=x, y=y, w=w, h=h, color=color, label=label})
    end
    addObj(-320,  180, 40, 40, {0.45,0.32,0.18}, "CRATE")
    addObj(-270,  180, 40, 40, {0.45,0.32,0.18}, "CRATE")
    addObj( 200,  200, 32, 32, {0.30,0.30,0.38}, "BARREL")
    addObj( 250,  200, 32, 32, {0.30,0.30,0.38}, "BARREL")
    addObj(-320, -200, 48, 48, {0.35,0.28,0.20}, "BOX")
    addObj( 200, -200, 36, 36, {0.30,0.30,0.38}, "BARREL")
    addObj( 150,  -80, 40, 40, {0.45,0.32,0.18}, "CRATE")
end

-- -------------------------
-- World draw helpers
-- -------------------------
local function drawWorldLayer(ambR, ambG, ambB)
    -- Floor tiles
    love.graphics.setColor(
        0.14*(ambR*2+0.5),
        0.12*(ambG*2+0.4),
        0.10*(ambB*2+0.3))
    love.graphics.rectangle("fill", -400, -300, 800, 600)

    -- Tile grid (subtle)
    love.graphics.setColor(0, 0, 0, 0.15)
    for gx = -400, 380, 40 do
        love.graphics.line(gx, -300, gx, 300)
    end
    for gy = -300, 280, 40 do
        love.graphics.line(-400, gy, 400, gy)
    end

    -- Objects (tinted by light at their position)
    for _, obj in ipairs(objects) do
        local cx = obj.x + obj.w/2
        local cy = obj.y + obj.h/2
        local lr, lg, lb = Lighting.sampleAt(scene, cx, cy)
        love.graphics.setColor(
            obj.color[1]*lr,
            obj.color[2]*lg,
            obj.color[3]*lb)
        love.graphics.rectangle("fill", obj.x, obj.y, obj.w, obj.h, 3,3)
        -- Label
        love.graphics.setColor(lr*0.5, lg*0.5, lb*0.5)
        love.graphics.printf(obj.label,
            obj.x, obj.y + obj.h/2 - 6, obj.w, "center")
    end

    -- Walls
    for _, wall in ipairs(walls) do
        local cx = wall.x + wall.w/2
        local cy = wall.y + wall.h/2
        local lr, lg, lb = Lighting.sampleAt(scene, cx, cy)
        love.graphics.setColor(
            wall.color[1]*lr*1.2,
            wall.color[2]*lg*1.2,
            wall.color[3]*lb*1.2)
        love.graphics.rectangle("fill", wall.x, wall.y, wall.w, wall.h)
    end
end

local function drawLightHalos()
    local lights = Lighting.getVisible(scene, camX - W/2, camY - H/2, W, H)
    love.graphics.setBlendMode("add")
    for _, l in ipairs(lights) do
        -- Multi-ring soft glow
        for i = 1, 5 do
            local frac  = i / 5
            local alpha = l._curIntensity * 0.07 * (6-i)
            local rad   = l.radius * frac
            love.graphics.setColor(l.r, l.g, l.b, alpha)
            love.graphics.circle("fill", l.x, l.y, rad)
        end
        -- Bright core
        love.graphics.setColor(
            math.min(1, l.r*1.5),
            math.min(1, l.g*1.3),
            math.min(1, l.b),
            l._curIntensity * 0.9)
        love.graphics.circle("fill", l.x, l.y, 6)
    end
    love.graphics.setBlendMode("alpha")
end

local function drawPlayer()
    local lr, lg, lb = Lighting.sampleAt(scene, player.x, player.y)
    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.ellipse("fill", player.x+3, player.y+5, player.r, player.r*0.5)
    -- Body tinted by light
    love.graphics.setColor(0.4*lr, 0.7*lg, 0.4*lb)
    love.graphics.circle("fill", player.x, player.y, player.r)
    love.graphics.setColor(lr*0.8, lg*0.9, lb*0.8)
    love.graphics.circle("line", player.x, player.y, player.r)
end

-- -------------------------
-- Enter
-- -------------------------
function Example.enter()
    W = love.graphics.getWidth()
    H = love.graphics.getHeight()

    timer = Timer.new()
    buildWorld()

    player.x, player.y = 0, 0

    -- Lighting scene: very dark ambient (dungeon feel)
    scene = Lighting.newScene({ ambient={0.04, 0.04, 0.06} })

    -- Player torch
    player.lightId = Lighting.addLight(scene, {
        x=player.x, y=player.y,
        r=1.0, g=0.75, b=0.4,
        radius=160, intensity=1.0,
        flicker=0.15, flickerSpeed=6,
    })

    -- Fixed torches on walls
    Lighting.addLight(scene, {
        x=-380, y=-100,
        r=1.0, g=0.5, b=0.15,
        radius=130, intensity=0.9,
        flicker=0.3, flickerSpeed=8,
    })
    Lighting.addLight(scene, {
        x=370, y=100,
        r=1.0, g=0.5, b=0.15,
        radius=130, intensity=0.9,
        flicker=0.25, flickerSpeed=7,
    })
    -- Cool blue magic light
    Lighting.addLight(scene, {
        x=200, y=-150,
        r=0.3, g=0.5, b=1.0,
        radius=100, intensity=0.8,
        flicker=0.05, flickerSpeed=2,
    })
    -- Green eerie light
    Lighting.addLight(scene, {
        x=-300, y=200,
        r=0.1, g=0.9, b=0.3,
        radius=90, intensity=0.7,
        flicker=0.1, flickerSpeed=4,
    })

    addLog("WASD move player  |  F toggle flashlight")
    addLog("1-3 add lights  |  L toggle light halos")
end

function Example.exit()
    Timer.clear(timer)
end

-- Show halos toggle
local showHalos = true

function Example.update(dt)
    Timer.update(timer, dt)

    -- Player movement
    local speed = 140
    local dx, dy = 0, 0
    if love.keyboard.isDown("w","up")    then dy = dy - 1 end
    if love.keyboard.isDown("s","down")  then dy = dy + 1 end
    if love.keyboard.isDown("a","left")  then dx = dx - 1 end
    if love.keyboard.isDown("d","right") then dx = dx + 1 end

    if dx ~= 0 or dy ~= 0 then
        local len = math.sqrt(dx*dx+dy*dy)
        player.x = player.x + (dx/len)*speed*dt
        player.y = player.y + (dy/len)*speed*dt
        -- Clamp to room
        player.x = Utils.clamp(player.x, -380, 370)
        player.y = Utils.clamp(player.y, -280, 270)
    end

    -- Move player light
    local pl = Lighting.getLight(scene, player.lightId)
    if pl then
        pl.x = player.x
        pl.y = player.y
    end

    -- Smooth camera follow
    local targetX = player.x
    local targetY = player.y
    camX = Utils.lerp(camX, targetX, 6*dt)
    camY = Utils.lerp(camY, targetY, 6*dt)

    Lighting.update(scene, dt)
end

function Example.draw()
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Camera transform
    love.graphics.push()
    love.graphics.translate(W/2 - camX, H/2 - camY)

    local amb = scene.ambient
    drawWorldLayer(amb[1]*8+0.1, amb[2]*8+0.1, amb[3]*6+0.1)
    if showHalos then drawLightHalos() end
    drawPlayer()

    love.graphics.pop()

    -- HUD panel
    love.graphics.setColor(0.06, 0.08, 0.14, 0.92)
    love.graphics.rectangle("fill", W-200, 30, 190, 100, 6,6)
    love.graphics.setColor(0.35, 0.50, 0.80)
    love.graphics.rectangle("line", W-200, 30, 190, 100, 6,6)
    love.graphics.setColor(0.5, 0.7, 1.0)
    love.graphics.printf("LIGHTING", W-200, 38, 190, "center")
    love.graphics.setColor(0.75, 0.75, 0.85)
    love.graphics.print(string.format(
        "Lights: %d\nPlayer: %.0f, %.0f\nHalos:  %s",
        Lighting.count(scene),
        player.x, player.y,
        showHalos and "ON" or "OFF"),
        W-188, 58)

    -- Ambient swatch
    love.graphics.setColor(
        scene.ambient[1]*4, scene.ambient[2]*4, scene.ambient[3]*4)
    love.graphics.rectangle("fill", W-188, 108, 40, 14, 2,2)
    love.graphics.setColor(0.4,0.5,0.7)
    love.graphics.print("amb", W-142, 108)

    -- Event log
    for i, msg in ipairs(log) do
        local a = math.min(1, i == 1 and 1 or 0.5)
        love.graphics.setColor(0.6, 0.75, 1.0, a)
        love.graphics.print(msg, 10, H - 40 - (i-1)*18)
    end

    Utils.drawHUD("LIGHTING",
        "WASD move    F flashlight    L halos    1 add torch  2 add blue  3 add green    ESC back")
end

function Example.keypressed(key)
    if key == "l" then
        showHalos = not showHalos

    elseif key == "f" then
        -- Toggle player torch
        local pl = Lighting.getLight(scene, player.lightId)
        if pl then
            pl.active = not pl.active
            addLog("Flashlight " .. (pl.active and "ON" or "OFF"))
        end

    elseif key == "1" then
        Lighting.addLight(scene, {
            x=player.x, y=player.y,
            r=1.0, g=0.55, b=0.15,
            radius=120, intensity=0.85,
            flicker=0.3, flickerSpeed=8,
        })
        addLog("Placed torch at "..math.floor(player.x)..","..math.floor(player.y))

    elseif key == "2" then
        Lighting.addLight(scene, {
            x=player.x, y=player.y,
            r=0.2, g=0.4, b=1.0,
            radius=100, intensity=0.9,
            flicker=0.05, flickerSpeed=2,
        })
        addLog("Placed blue light")

    elseif key == "3" then
        Lighting.addLight(scene, {
            x=player.x, y=player.y,
            r=0.1, g=1.0, b=0.3,
            radius=90, intensity=0.8,
            flicker=0.1, flickerSpeed=5,
        })
        addLog("Placed green light")

    elseif key == "c" then
        -- Clear placed lights (keep original 5)
        Lighting.clear(scene)
        scene = Lighting.newScene({ ambient={0.04, 0.04, 0.06} })
        Example.enter()
        addLog("Reset lights")
    end

    Utils.handlePause(key, Example)
end

function Example.touchpressed(id, x, y)
    -- Tap to place torch at world position
    local wx = x - W/2 + camX
    local wy = y - H/2 + camY
    Lighting.addLight(scene, {
        x=wx, y=wy,
        r=1.0, g=0.55, b=0.2,
        radius=120, intensity=0.85,
        flicker=0.3, flickerSpeed=7,
    })
end

return Example
