-- src/states/examples/post_fx.lua
-- Demonstrates: PostFX pipeline, chaining effects, runtime toggle/tweak

local Utils  = require("src.utils")
local PostFX = require("src.systems.postfx")
local Timer  = require("src.systems.timer")
local Example = {}

local W, H
local timer
local fx           -- PostFX pipeline
local time = 0

-- -------------------------
-- Scene objects
-- -------------------------
local scene_objs = {}
local player = { x=0, y=0, angle=0 }

local function buildScene()
    math.randomseed(42)
    scene_objs = {}
    for i = 1, 24 do
        table.insert(scene_objs, {
            x    = math.random(80, W - 280),
            y    = math.random(80, H - 80),
            size = math.random(15, 50),
            r    = math.random(30,100)/100,
            g    = math.random(30,100)/100,
            b    = math.random(30,100)/100,
            rot  = math.random()*math.pi*2,
            rotV = (math.random()-0.5)*2,
            type = math.random(1,3),
        })
    end
    player.x = (W-200)/2
    player.y = H/2
end

-- -------------------------
-- Effect presets (chains)
-- -------------------------
local presets = {
    {
        name = "Clean",
        desc = "No effects. Raw scene.",
        effects = {},
    },
    {
        name = "Cinematic",
        desc = "Vignette + subtle chromatic aberration.",
        effects = {
            { name="vignette",  params={ strength=0.9  } },
            { name="chromatic", params={ strength=1.2  } },
        },
    },
    {
        name = "Retro CRT",
        desc = "Full CRT: barrel + scanlines + RGB shift.",
        effects = {
            { name="crt",       params={ scanlines=0.3, warp=0.04 } },
            { name="vignette",  params={ strength=1.4  } },
        },
    },
    {
        name = "Dream",
        desc = "Blur + vignette. Soft and hazy.",
        effects = {
            { name="blur",      params={ spread=2.0    } },
            { name="blur",      params={ spread=1.5    } },
            { name="vignette",  params={ strength=0.7  } },
        },
    },
    {
        name = "Pixel Art",
        desc = "Pixelate + vignette. Lo-fi look.",
        effects = {
            { name="pixelate",  params={ pixelSize=5   } },
            { name="vignette",  params={ strength=0.6  } },
        },
    },
    {
        name = "Horror",
        desc = "Grayscale + heavy vignette + chromatic.",
        effects = {
            { name="grayscale", params={ amount=0.85   } },
            { name="vignette",  params={ strength=2.2  } },
            { name="chromatic", params={ strength=2.5  } },
        },
    },
    {
        name = "Psychedelic",
        desc = "Wave distortion + chromatic aberration.",
        effects = {
            { name="wave",      params={ amplitude=8, frequency=12, speed=4 } },
            { name="chromatic", params={ strength=3.0  } },
        },
    },
    {
        name = "Night Vision",
        desc = "Grayscale tinted green + vignette.",
        effects = {
            { name="grayscale", params={ amount=1.0    } },
            { name="tint",      params={ tintR=0.1, tintG=1.0, tintB=0.2 } },
            { name="vignette",  params={ strength=1.8  } },
        },
    },
}

local selected = 1

-- -------------------------
-- Build PostFX pipeline from preset
-- -------------------------
local function applyPreset(presetIdx)
    selected = presetIdx
    PostFX.clear(fx)
    local preset = presets[presetIdx]
    for _, e in ipairs(preset.effects) do
        PostFX.addEffect(fx, e.name, e.params)
    end
end

-- -------------------------
-- Enter
-- -------------------------
function Example.enter()
    W = love.graphics.getWidth()
    H = love.graphics.getHeight()
    timer = Timer.new()
    time  = 0
    fx    = PostFX.new()
    buildScene()
    applyPreset(1)
end

function Example.exit()
    Timer.clear(timer)
    -- Make sure shader is off when leaving
    love.graphics.setShader()
    love.graphics.setCanvas()
end

function Example.update(dt)
    Timer.update(timer, dt)
    time = time + dt
    fx._time = time

    -- Rotate scene objects
    for _, obj in ipairs(scene_objs) do
        obj.rot = obj.rot + obj.rotV * dt
    end

    -- Player movement
    local speed = 180
    local dx, dy = 0, 0
    if love.keyboard.isDown("w","up")    then dy = -1 end
    if love.keyboard.isDown("s","down")  then dy =  1 end
    if love.keyboard.isDown("a","left")  then dx = -1 end
    if love.keyboard.isDown("d","right") then dx =  1 end
    if dx ~= 0 or dy ~= 0 then
        local len = math.sqrt(dx*dx+dy*dy)
        player.x = Utils.clamp(player.x + dx/len*speed*dt, 20, W-220)
        player.y = Utils.clamp(player.y + dy/len*speed*dt, 20, H-20)
        player.angle = math.atan2(dy, dx)
    end
end

-- -------------------------
-- Scene drawing (captured by PostFX)
-- -------------------------
local function drawScene()
    -- Background
    love.graphics.setColor(0.07, 0.08, 0.13)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Grid
    love.graphics.setColor(0.11, 0.13, 0.19)
    for x = 0, W, 48 do love.graphics.line(x,0,x,H) end
    for y = 0, H, 48 do love.graphics.line(0,y,W,y) end

    -- Concentric glow rings
    for i = 6, 1, -1 do
        local t = i/6
        love.graphics.setColor(0.15*t, 0.25*t, 0.5*t, 0.4)
        love.graphics.circle("fill", (W-200)/2, H/2, i*55)
    end

    -- Shapes
    for _, obj in ipairs(scene_objs) do
        love.graphics.push()
        love.graphics.translate(obj.x, obj.y)
        love.graphics.rotate(obj.rot)
        love.graphics.setColor(obj.r, obj.g, obj.b)
        if     obj.type == 1 then
            love.graphics.rectangle("fill", -obj.size/2,-obj.size/2, obj.size,obj.size, 4,4)
        elseif obj.type == 2 then
            love.graphics.circle("fill", 0, 0, obj.size/2)
        else
            love.graphics.polygon("fill",
                0, -obj.size/2,
                obj.size/2, obj.size/2,
                -obj.size/2, obj.size/2)
        end
        love.graphics.pop()
    end

    -- Player
    love.graphics.push()
    love.graphics.translate(player.x, player.y)
    love.graphics.rotate(player.angle)
    love.graphics.setColor(0.3, 0.9, 0.5)
    love.graphics.polygon("fill", 16,0, -10,10, -10,-10)
    love.graphics.setColor(0.5,1.0,0.7)
    love.graphics.polygon("line", 16,0, -10,10, -10,-10)
    love.graphics.pop()

    -- Title text (good test for blur/CRT)
    love.graphics.setColor(0.85, 0.85, 0.90)
    love.graphics.printf("POST FX PIPELINE", 0, H*0.06, W-200, "center")
    love.graphics.setColor(0.35, 0.45, 0.65)
    love.graphics.printf("chain effects, toggle, tweak", 0, H*0.06+22, W-200, "center")
end

-- -------------------------
-- Sidebar (drawn AFTER PostFX so it's unaffected)
-- -------------------------
local PANEL_W = 200

local function drawSidebar()
    local px = W - PANEL_W
    love.graphics.setColor(0.06, 0.07, 0.12, 0.97)
    love.graphics.rectangle("fill", px, 0, PANEL_W, H)
    love.graphics.setColor(0.22, 0.32, 0.52)
    love.graphics.line(px, 0, px, H)

    love.graphics.setColor(0.5, 0.7, 1.0)
    love.graphics.printf("POST FX", px, 10, PANEL_W, "center")

    local itemH = 34
    for i, preset in ipairs(presets) do
        local iy  = 36 + (i-1)*itemH
        local sel = (i == selected)

        if sel then
            love.graphics.setColor(0.15, 0.28, 0.52)
            love.graphics.rectangle("fill", px+4, iy, PANEL_W-8, itemH-2, 4,4)
            love.graphics.setColor(0.35, 0.60, 1.0)
            love.graphics.rectangle("line", px+4, iy, PANEL_W-8, itemH-2, 4,4)
        end

        love.graphics.setColor(sel and 1 or 0.65, sel and 1 or 0.65, sel and 1 or 0.70)
        love.graphics.printf(preset.name, px+8, iy+4, PANEL_W-30, "left")
        love.graphics.setColor(0.3, 0.4, 0.6)
        love.graphics.printf("["..i.."]", px+4, iy+4, PANEL_W-8, "right")

        -- Effect chain dots
        if #preset.effects > 0 then
            for j = 1, #preset.effects do
                love.graphics.setColor(0.3, 0.55, 0.9, sel and 0.9 or 0.4)
                love.graphics.circle("fill", px+10+(j-1)*10, iy+itemH-7, 3)
            end
        end
    end

    -- Selected preset details
    local preset = presets[selected]
    local dy = 36 + #presets*itemH + 12

    love.graphics.setColor(0.22, 0.32, 0.52)
    love.graphics.line(px, dy-4, W, dy-4)

    love.graphics.setColor(0.6, 0.75, 1.0)
    love.graphics.printf(preset.name, px+8, dy, PANEL_W-16, "left")
    dy = dy + 18

    love.graphics.setColor(0.45, 0.55, 0.70)
    love.graphics.printf(preset.desc, px+8, dy, PANEL_W-16, "left")
    dy = dy + 36

    -- Effect chain
    if #preset.effects == 0 then
        love.graphics.setColor(0.35, 0.45, 0.60)
        love.graphics.print("  (no effects)", px+8, dy)
    else
        love.graphics.setColor(0.40, 0.55, 0.80)
        love.graphics.print("Chain:", px+8, dy)
        dy = dy + 16
        for j, e in ipairs(preset.effects) do
            love.graphics.setColor(0.3, 0.55, 0.9)
            love.graphics.print(j..". "..e.name, px+12, dy)
            dy = dy + 14
        end
    end

    -- Controls hint
    love.graphics.setColor(0.28, 0.36, 0.52)
    love.graphics.printf(
        "WASD move player\n1-"..#presets.." select preset",
        px+8, H-52, PANEL_W-16, "left")
end

function Example.draw()
    -- Capture scene through PostFX (only scene area, not sidebar)
    -- We use a scissor-aware approach: capture full canvas, draw panel on top
    PostFX.beginCapture(fx)
        drawScene()
    PostFX.endCapture(fx)
    PostFX.render(fx)

    -- Sidebar drawn after — unaffected by any shader
    drawSidebar()

    Utils.drawHUD("POST FX",
        "1-"..#presets.." preset    WASD move    ESC back")
end

function Example.keypressed(key)
    local n = tonumber(key)
    if n and n >= 1 and n <= #presets then
        applyPreset(n)
        return
    end
    Utils.handlePause(key, Example)
end

function Example.mousepressed(x, y, button)
    if button ~= 1 then return end
    local px    = W - PANEL_W
    local itemH = 34
    if x >= px then
        for i = 1, #presets do
            local iy = 36 + (i-1)*itemH
            if y >= iy and y < iy+itemH then
                applyPreset(i)
                return
            end
        end
    end
end

function Example.touchpressed(id, x, y)
    Example.mousepressed(x, y, 1)
end

return Example
