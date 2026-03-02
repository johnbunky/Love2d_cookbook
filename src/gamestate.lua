-- gamestate.lua
-- Simple state machine. Each state is a table with any of:
--   state.enter()        called when switching to this state
--   state.exit()         called when leaving this state
--   state.update(dt)
--   state.draw()
--   state.keypressed(key)
--   state.mousepressed(x, y, button)
--   state.touchpressed(id, x, y)
--   state.gamepadpressed(joystick, button)

local Gamestate = {}

local current = nil

local function call(fn, ...)
    if current and current[fn] then
        current[fn](...)
    end
end

function Gamestate.switch(newstate, ...)
    if current and current.exit then current.exit() end
    current = newstate
    if current and current.enter then current.enter(...) end
end

-- Resume a state without calling enter()  -  use this to unpause
function Gamestate.resume(newstate)
    if current and current.exit then current.exit() end
    current = newstate
end

function Gamestate.current()
    return current
end

-- These are hooked into love callbacks in main.lua
function Gamestate.update(dt)   call("update", dt)   end
function Gamestate.draw()       call("draw")         end

function Gamestate.wheelmoved(x, y)   call("wheelmoved", x, y)          end
function Gamestate.keyreleased(key)   call("keyreleased", key)          end
function Gamestate.textinput(text)    call("textinput", text)           end
function Gamestate.joystickadded(j)   call("joystickadded", j)          end
function Gamestate.joystickremoved(j) call("joystickremoved", j)        end

function Gamestate.keypressed(key)
    call("keypressed", key)
end
function Gamestate.mousepressed(x, y, button)
    call("mousepressed", x, y, button)
end
function Gamestate.mousemoved(x, y, dx, dy)
    call("mousemoved", x, y, dx, dy)
end
function Gamestate.mousereleased(x, y, button)
    call("mousereleased", x, y, button)
end
function Gamestate.touchpressed(id, x, y, dx, dy, pressure)
    call("touchpressed", id, x, y, dx, dy, pressure)
end
function Gamestate.touchreleased(id, x, y)
    call("touchreleased", id, x, y)
end
function Gamestate.touchmoved(id, x, y)
    call("touchmoved", id, x, y)
end
function Gamestate.gamepadpressed(joystick, button)
    call("gamepadpressed", joystick, button)
end

return Gamestate
