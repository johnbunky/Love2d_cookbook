-- src/states/examples/platformer_level.lua
-- A complete mini platformer level: moving platforms, checkpoint, goal, timer

local Utils   = require("src.utils")
local Physics = require("src.systems.physics")
local Camera  = require("src.systems.camera")
local Shake   = require("src.systems.shake")
local Tilemap = require("src.systems.tilemap")
local Example = {}

local MAP = {
    {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,0,0,3,3,3,3,3,0,0,0,0,3,3,3,3,3,0,0,0,0,0,0,0,0,0,3,3,3,3,3,0,0,0,0,0,0,1},
    {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
}

local W, H
local tm
local cam
local shake
local player
local movingPlatforms
local checkpoint
local goal
local timer
local won

local function initLevel()
    local ts   = tm.tileSize
    player     = Physics.newPlayer(2*ts, 15*ts)
    cam        = Camera.new(tm.worldW, tm.worldH, W, H, 5)
    shake      = Shake.new()
    timer      = 0
    won        = false
    checkpoint = { x=2*ts, y=15*ts, active=false, w=ts, h=2*ts }
    goal       = { x=37*ts, y=12*ts, w=ts, h=2*ts }

    movingPlatforms = {
        { x=22*ts, y=12*ts, w=3*ts, h=ts/2, vx=0,  vy=-60, minY=7*ts,  maxY=12*ts },
        { x=26*ts, y=8*ts,  w=3*ts, h=ts/2, vx=60, vy=0,   minX=24*ts, maxX=30*ts },
        { x=30*ts, y=10*ts, w=3*ts, h=ts/2, vx=0,  vy=50,  minY=8*ts,  maxY=12*ts },
    }
end

function Example.enter()
    W  = love.graphics.getWidth()
    H  = love.graphics.getHeight()
    tm = Tilemap.new(MAP, 32)
    initLevel()
end

function Example.exit() end

function Example.update(dt)
    if won then return end
    timer = timer + dt

    -- Moving platforms
    for _, mp in ipairs(movingPlatforms) do
        mp.x = mp.x + mp.vx * dt
        mp.y = mp.y + mp.vy * dt
        if mp.minX and (mp.x < mp.minX or mp.x + mp.w > mp.maxX) then
            mp.vx = -mp.vx
            mp.x  = Utils.clamp(mp.x, mp.minX, mp.maxX - mp.w)
        end
        if mp.minY and (mp.y < mp.minY or mp.y + mp.h > mp.maxY) then
            mp.vy = -mp.vy
            mp.y  = Utils.clamp(mp.y, mp.minY, mp.maxY - mp.h)
        end
    end

    local p = player
    Physics.updateMovement(p, dt)

    -- X axis
    p.x = p.x + p.vx * dt
    local solidsX = Tilemap.getSolids(tm, p.x, p.y, p.w, p.h, false)
    for _, mp in ipairs(movingPlatforms) do table.insert(solidsX, mp) end
    Physics.resolveCollision(p, solidsX)

    -- Y axis
    local prevY = p.y
    p.y = p.y + p.vy * dt
    local solidsY = Tilemap.getSolids(tm, p.x, p.y, p.w, p.h, false)
    for _, mp in ipairs(movingPlatforms) do table.insert(solidsY, mp) end
    Physics.resolveCollision(p, solidsY)
    Physics.finalize(p)

    -- Carry on moving platform
    for _, mp in ipairs(movingPlatforms) do
        if Utils.rectOverlap({x=p.x, y=p.y+p.h, w=p.w, h=2}, mp) then
            p.x = p.x + mp.vx * dt
            p.y = p.y + mp.vy * dt
        end
    end

    p.x = Utils.clamp(p.x, 0, tm.worldW - p.w)

    -- Hazard / fall
    if Tilemap.checkType(tm, p, Tilemap.T.HAZARD) or p.y > tm.worldH then
        Shake.add(shake, 0.6)
        if checkpoint.active then
            p.x, p.y, p.vx, p.vy = checkpoint.x, checkpoint.y, 0, 0
        else
            Gamestate.switch(States.gameover, Example)
        end
    end

    -- Checkpoint
    if Utils.rectOverlap(p, checkpoint) then checkpoint.active = true end

    -- Goal
    if Utils.rectOverlap(p, goal) then
        won = true
        Shake.add(shake, 0.4)
    end

    Shake.update(shake, dt)
    Camera.follow(cam, p, dt)
end

function Example.draw()
    Utils.drawBackground(0.08, 0.10, 0.14)

    Shake.apply(shake, W, H)
    love.graphics.scale(cam.zoom, cam.zoom)
    love.graphics.translate(-cam.x, -cam.y)

    Tilemap.draw(tm, cam)

    -- Moving platforms
    for _, mp in ipairs(movingPlatforms) do
        love.graphics.setColor(0.55, 0.75, 0.45)
        love.graphics.rectangle("fill", mp.x, mp.y, mp.w, mp.h)
        love.graphics.setColor(0.7, 0.9, 0.6)
        love.graphics.rectangle("line", mp.x, mp.y, mp.w, mp.h)
    end

    -- Checkpoint flag
    local ts = tm.tileSize
    local cc = checkpoint.active and {0.2,0.9,0.4} or {0.6,0.6,0.6}
    love.graphics.setColor(cc[1], cc[2], cc[3])
    love.graphics.rectangle("fill", checkpoint.x, checkpoint.y, 6, 2*ts)
    love.graphics.polygon("fill",
        checkpoint.x+6, checkpoint.y,
        checkpoint.x+26, checkpoint.y+10,
        checkpoint.x+6, checkpoint.y+20)

    -- Goal flag
    love.graphics.setColor(1, 0.85, 0.1)
    love.graphics.rectangle("fill", goal.x, goal.y, 6, goal.h)
    love.graphics.polygon("fill",
        goal.x+6, goal.y,
        goal.x+30, goal.y+12,
        goal.x+6, goal.y+24)
    love.graphics.setColor(1, 1, 0.4, 0.25)
    love.graphics.rectangle("fill", goal.x, goal.y, goal.w, goal.h)

    Physics.drawPlayer(player)

    Shake.clear()

    Utils.drawHUD("PLATFORMER LEVEL",
        "Arrows/WASD move    SPACE jump    P pause    ESC back")
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.printf(string.format("%.2fs", timer), 0, 10, W, "center")
    if checkpoint.active then
        love.graphics.setColor(0.2, 0.9, 0.4)
        love.graphics.print("CHECKPOINT ?", 10, 50)
    end

    if won then
        love.graphics.setColor(0, 0, 0, 0.65)
        love.graphics.rectangle("fill", 0, 0, W, H)
        love.graphics.setColor(1, 0.85, 0.1)
        love.graphics.printf("YOU WIN!", 0, 200, W, "center")
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(string.format("Time: %.2fs", timer), 0, 260, W, "center")
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.printf("R to replay    ESC for menu", 0, 320, W, "center")
    end
end

function Example.keypressed(key)
    if won and key == "r" then initLevel() return end
    Utils.handlePause(key, Example)
end

function Example.mousepressed(x, y, button) end
function Example.touchpressed(id, x, y) end
function Example.gamepadpressed(joystick, button) end

return Example
