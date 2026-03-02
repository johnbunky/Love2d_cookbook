-- src/states/examples/camera.lua
-- Demonstrates: smooth follow, world bounds, zoom
-- Input: keyboard, mouse wheel, scroll buttons, pinch-to-zoom (touch)

local Utils   = require("src.utils")
local Physics = require("src.systems.physics")
local Camera  = require("src.systems.camera")
local Example = {}

local WORLD_W = 2400
local WORLD_H = 900
local W, H

local cam
local player
local platforms
local zoomTarget
local pinch = { active=false, lastDist=0 }

local function pinchDist()
    local ts = Input.getTouches()
    if #ts >= 2 then
        local dx = ts[1].x - ts[2].x
        local dy = ts[1].y - ts[2].y
        return math.sqrt(dx*dx + dy*dy)
    end
    return 0
end

function Example.enter()
    W = love.graphics.getWidth()
    H = love.graphics.getHeight()

    player     = Physics.newPlayer(100, 600)
    cam        = Camera.new(WORLD_W, WORLD_H, W, H, 4)
    zoomTarget = 1
    pinch      = { active=false, lastDist=0 }

    platforms = {
        { x=0,    y=820, w=400,  h=40 },
        { x=500,  y=820, w=300,  h=40 },
        { x=900,  y=820, w=500,  h=40 },
        { x=1500, y=820, w=400,  h=40 },
        { x=2000, y=820, w=400,  h=40 },
        { x=200,  y=680, w=120,  h=16 },
        { x=420,  y=600, w=100,  h=16 },
        { x=600,  y=700, w=150,  h=16 },
        { x=820,  y=620, w=120,  h=16 },
        { x=1000, y=680, w=100,  h=16 },
        { x=1150, y=560, w=180,  h=16 },
        { x=1400, y=640, w=120,  h=16 },
        { x=1600, y=700, w=100,  h=16 },
        { x=1750, y=580, w=150,  h=16 },
        { x=1950, y=650, w=120,  h=16 },
        { x=2100, y=700, w=200,  h=16 },
        { x=2300, y=620, w=100,  h=16 },
        { x=700,  y=500, w=100,  h=16 },
        { x=1100, y=420, w=120,  h=16 },
        { x=1800, y=460, w=100,  h=16 },
        { x=2200, y=500, w=120,  h=16 },
    }
end

function Example.exit() end

function Example.update(dt)
    Physics.update(player, platforms, dt)
    player.x = Utils.clamp(player.x, 0, WORLD_W - player.w)

    if player.y > WORLD_H + 100 then
        Gamestate.switch(States.gameover, Example)
    end

    -- Keyboard zoom
    if Input.isPressed("confirm") then zoomTarget = zoomTarget + 0.15 end
    if Input.isDown("z") then zoomTarget = zoomTarget - 0.01 end

    -- Mouse wheel zoom — accumulate into target
    if Input.mouseWheelY ~= 0 then
        zoomTarget = zoomTarget + Input.mouseWheelY * 0.12
    end

    -- Pinch-to-zoom (two fingers)
    local ts = Input.getTouches()
    if #ts >= 2 then
        local dist = pinchDist()
        if pinch.active then
            local delta = dist - pinch.lastDist
            zoomTarget = zoomTarget + delta * 0.005
        else
            pinch.active = true
        end
        pinch.lastDist = dist
    else
        pinch.active = false
    end

    -- Clamp target and lerp camera zoom smoothly
    zoomTarget = Utils.clamp(zoomTarget, cam.minZoom, 2.0)

    if math.abs(cam.zoom - zoomTarget) > 0.001 then
        -- Zoom is animating — snap camera to player each frame
        -- so viewport shift never pushes player off screen
        Camera.setZoom(cam, Utils.lerp(cam.zoom, zoomTarget, 12 * dt), player)
    else
        cam.zoom = zoomTarget
        Camera.follow(cam, player, dt)
    end
end

function Example.draw()
    Utils.drawBackground(0.08, 0.10, 0.14)

    Camera.apply(cam)

    love.graphics.setColor(0.2, 0.2, 0.3)
    love.graphics.rectangle("line", 0, 0, WORLD_W, WORLD_H)

    Utils.drawObstacles(platforms)
    Physics.drawPlayer(player)

    -- Distance markers
    love.graphics.setColor(0.25, 0.25, 0.35)
    for i = 0, WORLD_W, 400 do
        love.graphics.line(i, 0, i, WORLD_H)
        love.graphics.print(i, i + 4, 4)
    end

    Camera.clear()

    -- Pinch indicator
    local ts = Input.getTouches()
    if #ts >= 2 then
        love.graphics.setColor(1, 1, 0, 0.5)
        love.graphics.line(ts[1].x, ts[1].y, ts[2].x, ts[2].y)
        love.graphics.circle("line", (ts[1].x+ts[2].x)/2, (ts[1].y+ts[2].y)/2, 10)
    end

    Utils.drawHUD("CAMERA",
        "WASD move    SPACE jump    ENTER/scroll zoom    Pinch zoom (touch)    P pause    ESC back")
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print(string.format(
        "world x: %.0f    zoom: %.1f    cam: %.0f, %.0f",
        player.x, cam.zoom, cam.x, cam.y), 10, 50)
end

function Example.keypressed(key)
    Utils.handlePause(key, Example)
end

function Example.mousepressed(x, y, button)
    if button == 4 then Camera.setZoom(cam, cam.zoom + 0.1) end
    if button == 5 then Camera.setZoom(cam, cam.zoom - 0.1) end
end

return Example
