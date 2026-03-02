-- src/states/gameover.lua
local Gameover = {}

local caller = nil

function Gameover.enter(fromState)
    caller = fromState or States.menu
end

function Gameover.exit()
    caller = nil
end

function Gameover.update(dt) end

function Gameover.draw()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    love.graphics.setColor(0.9, 0.2, 0.2)
    love.graphics.printf("GAME OVER", 0, 220, love.graphics.getWidth(), "center")
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.printf("R  to retry    M  for menu", 0, 310, love.graphics.getWidth(), "center")
end

function Gameover.keypressed(key)
    if key == "r" then
        Gamestate.switch(caller)
    end
    if key == "m" or key == "escape" then
        Gamestate.switch(States.menu)
    end
end

function Gameover.mousepressed(x, y, button) end

function Gameover.touchpressed(id, x, y)
    Gamestate.switch(caller)
end

function Gameover.gamepadpressed(joystick, button)
    if button == "start" or button == "a" then
        Gamestate.switch(caller)
    end
end

return Gameover
