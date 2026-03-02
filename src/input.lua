-- src/input.lua
-- Unified input: keyboard, mouse, gamepad, touch → named actions.
--
-- Actions:  left  right  up  down  jump  pause  confirm  back  attack
--
-- Usage:
--   Input.update(dt)
--   Input.isDown("jump")        -- held this frame
--   Input.isPressed("jump")     -- pressed this frame
--   Input.isReleased("jump")    -- released this frame
--
--   Input.mouseX, Input.mouseY  -- current mouse position
--   Input.isMouseDown(1)        -- left button held
--   Input.mousePressed(1)       -- left button pressed this frame
--   Input.mouseReleased(1)      -- left button released this frame
--   Input.isHover(x, y, w, h)   -- mouse over rect
--   Input.mouseWheelY           -- scroll this frame (-1, 0, +1)
--
--   Input.setVirtualJoystick(vj) -- register touch joystick (set by virtual_joystick)

local Input = {}

-- -------------------------
-- Action bindings
-- -------------------------
local bindings = {
    left    = { {type="key",value="left"},  {type="key",value="a"}, {type="gamepad",value="leftx-"} },
    right   = { {type="key",value="right"}, {type="key",value="d"}, {type="gamepad",value="leftx+"} },
    up      = { {type="key",value="up"},    {type="key",value="w"}, {type="gamepad",value="lefty-"} },
    down    = { {type="key",value="down"},  {type="key",value="s"}, {type="gamepad",value="lefty+"} },
    jump    = { {type="key",value="space"}, {type="gamepad",value="a"}, {type="touchaction",value="jump"} },
    pause   = { {type="key",value="p"},     {type="gamepad",value="start"} },
    confirm = { {type="key",value="return"},{type="gamepad",value="a"} },
    back    = { {type="key",value="escape"},{type="gamepad",value="b"} },
    attack  = { {type="key",value="z"},     {type="mousebutton",value=1}, {type="gamepad",value="x"}, {type="touchaction",value="attack"} },
}

-- -------------------------
-- Internal state
-- -------------------------
local current   = {}
local previous  = {}

-- Mouse
local mb        = { cur={}, prev={} }
Input.mouseX    = 0
Input.mouseY    = 0
Input.mouseWheelY = 0

-- Touch
local touches   = {}     -- { id, x, y }
local touchActions = {}  -- { action=bool } fed by virtual joystick

-- Gamepad
local AXIS_THRESHOLD = 0.5
local gamepads = {}

-- Virtual joystick reference (optional, set by virtual_joystick example)
local virtualJoystick = nil

-- -------------------------
-- Internal helpers
-- -------------------------

local function isBindingDown(b)
    if b.type == "key" then
        return love.keyboard.isDown(b.value)
    elseif b.type == "mousebutton" then
        return love.mouse.isDown(b.value)
    elseif b.type == "touchaction" then
        return touchActions[b.value] == true
    elseif b.type == "gamepad" then
        for _, gp in ipairs(gamepads) do
            if gp:isGamepad() then
                local axis, dir = b.value:match("^(.+)([%+%-])$")
                if axis then
                    local v = gp:getGamepadAxis(axis)
                    if dir == "+" and v >  AXIS_THRESHOLD then return true end
                    if dir == "-" and v < -AXIS_THRESHOLD then return true end
                else
                    if gp:isGamepadDown(b.value) then return true end
                end
            end
        end
    end
    return false
end

local function isActionDown(action)
    local list = bindings[action]
    if not list then return false end
    for _, b in ipairs(list) do
        if isBindingDown(b) then return true end
    end
    -- also check virtual joystick axes for left/right/up/down
    if virtualJoystick then
        local vj = virtualJoystick
        if action == "left"  and vj.dx < -0.3 then return true end
        if action == "right" and vj.dx >  0.3 then return true end
        if action == "up"    and vj.dy < -0.3 then return true end
        if action == "down"  and vj.dy >  0.3 then return true end
    end
    return false
end

-- -------------------------
-- Public API
-- -------------------------

function Input.update(dt)
    -- snapshot previous
    previous = current
    current  = {}
    for action in pairs(bindings) do
        current[action] = isActionDown(action)
    end

    -- mouse buttons
    mb.prev = {}
    for k, v in pairs(mb.cur) do mb.prev[k] = v end
    mb.cur = {}
    for i = 1, 5 do mb.cur[i] = love.mouse.isDown(i) end
    Input.mouseX, Input.mouseY = love.mouse.getPosition()

    -- reset wheel (set via wheelmoved callback)
    -- (don't reset here — reset after state reads it)
end

-- Called by main.lua after all states have updated
function Input.lateUpdate()
    Input.mouseWheelY = 0
end

-- Actions
function Input.isDown(action)     return current[action]  == true end
function Input.isPressed(action)  return current[action]  == true and previous[action] ~= true end
function Input.isReleased(action) return current[action]  ~= true and previous[action] == true end

-- Mouse buttons
function Input.isMouseDown(btn)    return mb.cur[btn]  == true end
function Input.mousePressed(btn)   return mb.cur[btn]  == true and mb.prev[btn] ~= true end
function Input.mouseReleased(btn)  return mb.cur[btn]  ~= true and mb.prev[btn] == true end

-- Hover
function Input.isHover(x, y, w, h)
    return Input.mouseX >= x and Input.mouseX <= x + w
       and Input.mouseY >= y and Input.mouseY <= y + h
end

-- Touch list (raw)
function Input.getTouches() return touches end

-- Set a touch action (called by virtual joystick)
function Input.setTouchAction(action, value)
    touchActions[action] = value
end

-- Register virtual joystick so axes feed into isDown()
function Input.setVirtualJoystick(vj)
    virtualJoystick = vj
end

-- Add/remove bindings at runtime
function Input.bind(action, binding)
    if not bindings[action] then bindings[action] = {} end
    table.insert(bindings[action], binding)
end

-- -------------------------
-- love callbacks — called from main.lua
-- -------------------------

function Input.wheelmoved(x, y)
    Input.mouseWheelY = y
end

function Input.gamepadAdded(joystick)
    table.insert(gamepads, joystick)
end

function Input.gamepadRemoved(joystick)
    for i, gp in ipairs(gamepads) do
        if gp == joystick then table.remove(gamepads, i); break end
    end
end

function Input.touchpressed(id, x, y)
    table.insert(touches, { id=id, x=x, y=y })
end

function Input.touchreleased(id, x, y)
    for i, t in ipairs(touches) do
        if t.id == id then table.remove(touches, i); break end
    end
end

function Input.touchmoved(id, x, y)
    for _, t in ipairs(touches) do
        if t.id == id then t.x = x; t.y = y; break end
    end
end

return Input
