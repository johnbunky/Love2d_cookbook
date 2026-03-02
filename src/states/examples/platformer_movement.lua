-- src/states/examples/platformer_movement.lua
-- Demonstrates: gravity, variable jump, coyote time, jump buffer, acceleration

local Utils   = require("src.utils")
local Physics = require("src.systems.physics")
local Example = {}

local W, H
local player
local platforms

function Example.enter()
    W = love.graphics.getWidth()
    H = love.graphics.getHeight()

    player = Physics.newPlayer(100, 300)

    platforms = {
        { x = 0,   y = 550, w = 300, h = 50 },
        { x = 500, y = 550, w = 300, h = 50 },
        { x = 100, y = 420, w = 150, h = 16 },
        { x = 320, y = 340, w = 120, h = 16 },
        { x = 500, y = 260, w = 150, h = 16 },
        { x = 220, y = 210, w = 100, h = 16 },
        { x = 600, y = 180, w = 120, h = 16 },
        { x = 460, y = 400, w = 16,  h = 150 },
    }
end

function Example.exit() end

function Example.update(dt)
    Physics.update(player, platforms, dt)

    player.x = Utils.clamp(player.x, 0, W - player.w)

    if player.y > H + 100 then
        Gamestate.switch(States.gameover, Example)
    end
end

function Example.draw()
    Utils.drawBackground()
    Utils.drawObstacles(platforms)
    Physics.drawPlayer(player)

    -- Debug info
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print(string.format(
        "vx: %.0f  vy: %.0f  ground: %s  coyote: %.2f",
        player.vx, player.vy, tostring(player.onGround), player.coyoteTimer), 10, 50)

    Utils.drawHUD("PLATFORMER MOVEMENT",
        "Arrows/WASD move    SPACE jump (hold for higher)    P pause    ESC back")
end

function Example.keypressed(key)
    Utils.handlePause(key, Example)
end

function Example.mousepressed(x, y, button) end
function Example.touchpressed(id, x, y) end
function Example.gamepadpressed(joystick, button) end

return Example
