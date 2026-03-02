-- src/systems/vjoystick.lua
-- Virtual joystick state machine — zero LÖVE dependencies
-- Handles: floating origin, deadzone, clamped knob, multi-touch ID tracking
-- Usage:
--   local VJoystick = require("src.systems.vjoystick")
--   local vj = VJoystick.new({ radius=70, deadzone=0.12 })
--
--   -- In mousepressed / touchpressed:
--   vj:activate(x, y, touchId)
--
--   -- In mousemoved / touchmoved:
--   vj:move(x, y, touchId)
--
--   -- In mousereleased / touchreleased:
--   vj:release(touchId)
--
--   -- In update / draw:
--   local ax, ay = vj:axes()          -- -1..1
--   local bx, by = vj:base()          -- center of outer ring
--   local kx, ky = vj:knob()          -- knob screen position
--   local active = vj:isActive()

local VJoystick = {}
VJoystick.__index = VJoystick

-- -------------------------
-- Constructor
-- -------------------------
function VJoystick.new(opts)
    opts = opts or {}
    local self = setmetatable({}, VJoystick)
    self.radius   = opts.radius   or 70
    self.knobR    = opts.knobR    or 28
    self.deadzone = opts.deadzone or 0.12
    -- Floating origin: base moves to touch point
    self.floating = opts.floating ~= false
    -- Fixed position (used when floating=false)
    self.defaultX = opts.x or 130
    self.defaultY = opts.y or 400
    -- Internal state
    self._bx      = self.defaultX
    self._by      = self.defaultY
    self._kx      = self.defaultX
    self._ky      = self.defaultY
    self._ax      = 0
    self._ay      = 0
    self._active  = false
    self._touchId = nil
    return self
end

-- -------------------------
-- Activate: finger/mouse pressed
-- -------------------------
function VJoystick:activate(x, y, touchId, clampFn)
    if self._active then return false end  -- already in use
    if self.floating then
        -- Float base to touch point, optionally clamped by caller
        self._bx = clampFn and clampFn(x, "x") or x
        self._by = clampFn and clampFn(y, "y") or y
    end
    self._kx      = self._bx
    self._ky      = self._by
    self._ax      = 0
    self._ay      = 0
    self._active  = true
    self._touchId = touchId
    self:move(x, y, touchId)
    return true
end

-- -------------------------
-- Move: finger/mouse dragged
-- -------------------------
function VJoystick:move(x, y, touchId)
    if not self._active then return end
    if touchId ~= nil and touchId ~= self._touchId then return end
    local dx   = x - self._bx
    local dy   = y - self._by
    local dist = math.sqrt(dx*dx + dy*dy)
    -- Clamp knob to radius
    if dist > self.radius then
        dx = dx / dist * self.radius
        dy = dy / dist * self.radius
    end
    self._kx = self._bx + dx
    self._ky = self._by + dy
    -- Raw axis values
    local ax = dx / self.radius
    local ay = dy / self.radius
    -- Apply circular deadzone
    if math.sqrt(ax*ax + ay*ay) < self.deadzone then
        ax, ay = 0, 0
    end
    self._ax = ax
    self._ay = ay
end

-- -------------------------
-- Release: finger/mouse lifted
-- -------------------------
function VJoystick:release(touchId)
    if touchId ~= nil and touchId ~= self._touchId then return end
    self._active  = false
    self._touchId = nil
    self._ax      = 0
    self._ay      = 0
    -- Return knob to center
    self._kx = self._bx
    self._ky = self._by
    -- Reset base to default if floating
    if self.floating then
        self._bx = self.defaultX
        self._by = self.defaultY
        self._kx = self.defaultX
        self._ky = self.defaultY
    end
end

-- -------------------------
-- Override axes from keyboard (for desktop fallback)
-- Call this in update() when keyboard input detected
-- -------------------------
function VJoystick:setAxes(ax, ay)
    if not self._active then
        self._ax = ax
        self._ay = ay
    end
end

-- -------------------------
-- Getters
-- -------------------------
function VJoystick:axes()     return self._ax, self._ay     end
function VJoystick:axisX()   return self._ax               end
function VJoystick:axisY()   return self._ay               end
function VJoystick:base()    return self._bx, self._by     end
function VJoystick:knob()    return self._kx, self._ky     end
function VJoystick:isActive() return self._active          end
function VJoystick:touchId()  return self._touchId         end

-- Magnitude of input (0..1)
function VJoystick:magnitude()
    return math.sqrt(self._ax*self._ax + self._ay*self._ay)
end

-- Angle in radians (0 = right, clockwise)
function VJoystick:angle()
    if self:magnitude() < self.deadzone then return 0 end
    return math.atan2(self._ay, self._ax)
end

return VJoystick
