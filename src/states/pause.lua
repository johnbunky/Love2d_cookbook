-- src/states/pause.lua
-- Pauses whatever state called it and returns to it on resume.
-- Usage: Gamestate.switch(States.pause, callerState)

local Pause = {}

local previous = nil  -- state to return to on resume

function Pause.enter(caller)
    previous = caller or States.menu
end

function Pause.exit()
    previous = nil
end

function Pause.update(dt) end

function Pause.draw()
    -- Draw what the previous state drew, frozen
    if previous and previous.draw then
        previous.draw()
    end

    -- Dark overlay on top
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("PAUSED", 0, 220, love.graphics.getWidth(), "center")
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.printf("P  or  ESC  to resume", 0, 275, love.graphics.getWidth(), "center")
    love.graphics.printf("M  for main menu",       0, 315, love.graphics.getWidth(), "center")
end

local function resume()
    if previous then Gamestate.resume(previous) end
end

function Pause.keypressed(key)
    if key == "p" or key == "escape" then resume() end
    if key == "m" then Gamestate.switch(States.menu) end
end

function Pause.mousepressed(x, y, button) end

function Pause.touchpressed(id, x, y)
    resume()
end

function Pause.gamepadpressed(joystick, button)
    if button == "start" then resume() end
end

return Pause
