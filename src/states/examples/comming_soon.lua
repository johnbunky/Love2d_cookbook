-- src/states/examples/camera.lua
local Example = {}

function Example.enter() end
function Example.exit()  end
function Example.update(dt) end

function Example.draw()
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("comming soon", 0, 240, love.graphics.getWidth(), "center")
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.printf("coming soon -- ESC to go back", 0, 290, love.graphics.getWidth(), "center")
end

function Example.keypressed(key) end
function Example.mousepressed(x, y, button) end
function Example.touchpressed(id, x, y) end
function Example.gamepadpressed(joystick, button) end

return Example
