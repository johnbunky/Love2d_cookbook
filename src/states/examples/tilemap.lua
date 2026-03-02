-- src/states/examples/tilemap.lua
-- Demonstrates: tile grid, tile types, efficient rendering, camera + physics

local Utils   = require("src.utils")
local Physics = require("src.systems.physics")
local Camera  = require("src.systems.camera")
local Tilemap = require("src.systems.tilemap")
local Example = {}

local MAP = {
    {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,4,0,0,0,0,0,0,0,4,0,0,0,0,0,4,0,0,0,0,0,0,1},
    {1,0,0,0,0,0,2,2,2,0,0,0,0,0,2,2,0,0,0,0,2,2,2,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,4,0,0,0,0,0,0,0,4,0,0,0,0,0,0,0,4,0,0,0,0,0,1},
    {1,1,1,1,1,0,0,0,0,1,1,1,1,0,0,0,1,1,1,1,0,0,0,1,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,4,0,0,4,0,0,0,4,0,0,4,0,0,0,4,0,0,0,0,4,0,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,2,2,0,0,0,2,2,2,0,0,0,2,2,2,2,0,0,0,2,2,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,0,3,3,0,0,0,0,3,3,3,0,0,0,3,3,0,0,0,3,0,0,1},
    {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
}

local W, H
local tm
local cam
local player
local score

function Example.enter()
    W = love.graphics.getWidth()
    H = love.graphics.getHeight()

    tm     = Tilemap.new(MAP, 32)
    cam    = Camera.new(tm.worldW, tm.worldH, W, H, 5)
    player = Physics.newPlayer(2*tm.tileSize, 13*tm.tileSize)
    score  = 0
end

function Example.exit() end

function Example.update(dt)
    local p  = player
    local ts = tm.tileSize

    Physics.updateMovement(p, dt)

    -- X axis
    p.x = p.x + p.vx * dt
    Physics.resolveCollision(p, Tilemap.getSolids(tm, p.x, p.y, p.w, p.h, false))

    -- Y axis with one-way
    local prevY = p.y
    p.y = p.y + p.vy * dt
    local solidsY = Tilemap.getSolids(tm, p.x, p.y, p.w, p.h, p.vy >= 0)
    local filtered = {}
    for _, s in ipairs(solidsY) do
        if s.oneway then
            if (prevY + p.h) <= s.y + 2 then table.insert(filtered, s) end
        else
            table.insert(filtered, s)
        end
    end
    Physics.resolveCollision(p, filtered)
    Physics.finalize(p)

    p.x = Utils.clamp(p.x, 0, tm.worldW - p.w)

    -- Collect coins
    score = score + Tilemap.collect(tm, p, Tilemap.T.COIN)

    -- Hazard
    if Tilemap.checkType(tm, p, Tilemap.T.HAZARD) or p.y > tm.worldH then
        Gamestate.switch(States.gameover, Example)
    end

    Camera.follow(cam, p, dt)
end

function Example.draw()
    Utils.drawBackground()

    Camera.apply(cam)
    Tilemap.draw(tm, cam)
    Physics.drawPlayer(player)
    Camera.clear()

    Utils.drawHUD("TILEMAP", "Arrows/WASD move    SPACE jump    P pause    ESC back")
    love.graphics.setColor(0.9, 0.8, 0.2)
    love.graphics.print("Coins: " .. score, 10, 50)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print("Green = one-way    Red = hazard    Yellow = coin", 10, 570)
end

function Example.keypressed(key)
    Utils.handlePause(key, Example)
end

function Example.mousepressed(x, y, button) end
function Example.touchpressed(id, x, y) end
function Example.gamepadpressed(joystick, button) end

return Example
