-- src/states/examples/animation.lua
-- Demonstrates: spritesheet animation with idle/run/jump/fall states
-- Uses a procedurally generated spritesheet — no image files needed

local Utils   = require("src.utils")
local Physics = require("src.systems.physics")
local Anim    = require("src.systems.anim")
local Example = {}

local W, H
local player
local platforms
local anim

-- Frame layout on our generated sheet (8 frames, 1 row):
-- 1=idle  2=idle2  3=run1  4=run2  5=run3  6=run4  7=jump  8=fall
local FRAME_W = 40
local FRAME_H = 56
local FRAMES  = 8

-- -------------------------
-- Generate a spritesheet at runtime
-- Each frame is a colored rect with a number and label
-- -------------------------
local function makeProceduralSheet()
    local iw = FRAME_W * FRAMES
    local ih = FRAME_H
    local canvas = love.graphics.newCanvas(iw, ih)

    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)

    local frameData = {
        { r=0.2, g=0.6, b=0.9, label="idle" },
        { r=0.2, g=0.5, b=0.8, label="idle" },
        { r=0.2, g=0.8, b=0.4, label="run"  },
        { r=0.1, g=0.9, b=0.3, label="run"  },
        { r=0.2, g=0.8, b=0.4, label="run"  },
        { r=0.1, g=0.9, b=0.3, label="run"  },
        { r=0.9, g=0.8, b=0.2, label="jump" },
        { r=0.9, g=0.4, b=0.2, label="fall" },
    }

    local font = love.graphics.newFont(9)
    love.graphics.setFont(font)

    for i, fd in ipairs(frameData) do
        local fx = (i-1) * FRAME_W
        -- body
        love.graphics.setColor(fd.r, fd.g, fd.b)
        love.graphics.rectangle("fill", fx+2, 2, FRAME_W-4, FRAME_H-4, 4, 4)
        -- eyes
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", fx+12, 14, 5)
        love.graphics.circle("fill", fx+28, 14, 5)
        love.graphics.setColor(0.1, 0.1, 0.1)
        love.graphics.circle("fill", fx+13, 14, 2.5)
        love.graphics.circle("fill", fx+29, 14, 2.5)
        -- legs (vary per frame for run cycle)
        love.graphics.setColor(fd.r*0.7, fd.g*0.7, fd.b*0.7)
        local legOff = (i >= 3 and i <= 6) and ((i%2==1) and 6 or -6) or 0
        love.graphics.rectangle("fill", fx+6,  FRAME_H-18+legOff, 10, 14)
        love.graphics.rectangle("fill", fx+24, FRAME_H-18-legOff, 10, 14)
        -- label
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.printf(fd.label .. "\n" .. i, fx, FRAME_H-18, FRAME_W, "center")
    end

    love.graphics.setCanvas()
    love.graphics.setColor(1, 1, 1)

    -- Convert canvas to image
    local imgData = canvas:newImageData()
    return love.graphics.newImage(imgData)
end

function Example.enter()
    W = love.graphics.getWidth()
    H = love.graphics.getHeight()

    player    = Physics.newPlayer(100, 400)
    platforms = {
        { x=0,   y=500, w=800, h=60 },
        { x=100, y=370, w=150, h=16 },
        { x=340, y=290, w=140, h=16 },
        { x=560, y=210, w=160, h=16 },
        { x=620, y=370, w=120, h=16 },
    }

    -- Build sheet and define animations
    local sheet = Anim.newSheet(makeProceduralSheet(), FRAME_W, FRAME_H)
    Anim.addAnim(sheet, "idle", {1, 2},       2,  true)
    Anim.addAnim(sheet, "run",  {3, 4, 5, 6}, 10, true)
    Anim.addAnim(sheet, "jump", {7},          10, false)
    Anim.addAnim(sheet, "fall", {8},          10, false)

    anim = Anim.new(sheet, "idle")
end

function Example.exit() end

-- Choose animation state based on player physics state
local function chooseAnim(p)
    if not p.onGround then
        if p.vy < 0 then return "jump" end
        return "fall"
    end
    if math.abs(p.vx) > 20 then return "run" end
    return "idle"
end

function Example.update(dt)
    Physics.update(player, platforms, dt)
    player.x = Utils.clamp(player.x, 0, W - player.w)

    if player.y > H + 100 then
        Gamestate.switch(States.gameover, Example)
    end

    -- Flip sprite based on movement direction
    if player.vx < -10 then anim.flipX = true
    elseif player.vx > 10 then anim.flipX = false end

    -- Switch animation state
    local state = chooseAnim(player)
    Anim.play(anim, state)
    Anim.update(anim, dt)
end

function Example.draw()
    Utils.drawBackground()
    Utils.drawObstacles(platforms)

    -- Draw animated sprite centered on player physics body
    local p   = player
    local ox  = (FRAME_W - p.w) / 2
    local oy  = (FRAME_H - p.h)
    Anim.draw(anim, p.x - ox, p.y - oy)

    -- Debug: show physics body outline
    love.graphics.setColor(0, 1, 0, 0.3)
    love.graphics.rectangle("line", p.x, p.y, p.w, p.h)

    -- Spritesheet preview at bottom
    love.graphics.setColor(0.15, 0.15, 0.2)
    love.graphics.rectangle("fill", 0, H-80, W, 80)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print("Spritesheet:", 10, H-72)

    local sheet = anim.sheet
    for i = 1, FRAMES do
        local qx = 160 + (i-1) * (FRAME_W + 4)
        local qy = H - 72
        -- highlight active frame
        local animDef = sheet.anims[anim.current]
        if animDef and animDef.frames[anim.frame] == i then
            love.graphics.setColor(1, 1, 0, 0.5)
            love.graphics.rectangle("fill", qx-2, qy-2, FRAME_W+4, FRAME_H+4)
        end
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(sheet.image, sheet.quads[i], qx, qy)
    end

    -- State label
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(string.format(
        "state: %-6s  frame: %d  flipX: %s",
        anim.current, anim.frame, tostring(anim.flipX)), 10, H-28)

    Utils.drawHUD("ANIMATION",
        "Arrows/WASD move    SPACE jump    P pause    ESC back")
end

function Example.keypressed(key)
    Utils.handlePause(key, Example)
end

function Example.mousepressed(x, y, button) end
function Example.touchpressed(id, x, y) end
function Example.gamepadpressed(joystick, button) end

return Example
