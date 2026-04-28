-- src/systems/spring.lua
-- Damped spring: drives a numeric value toward a target with lag and overshoot.
-- Pure Lua — no engine dependencies.
--
-- USAGE:
--   local Spring = require "src.systems.spring"
--   local s = Spring.new(0)              -- initial value
--   s:update(dt, target, stiffness, damping)
--   -- read s.value each frame
--
-- TUNING GUIDE:
--   stiffness  higher = snappier chase, lower = more lag (try 8–35)
--   damping    higher = less overshoot / bounce (try 6–20)
--   Examples:
--     arm swing:   stiffness=10, damping=6   → floaty, some overshoot
--     camera lean: stiffness=14, damping=9   → medium
--     UI pop-in:   stiffness=30, damping=18  → snappy, little bounce

local Spring = {}
Spring.__index = Spring

-- Create a new spring starting at `initial` (default 0).
function Spring.new(initial)
    return setmetatable({
        value    = initial or 0,
        velocity = 0,
    }, Spring)
end

-- Advance the spring toward `target` by one timestep.
--   stiffness : how fast value chases target
--   damping   : energy loss per second (prevents endless oscillation)
function Spring:update(dt, target, stiffness, damping)
    local accel   = (target - self.value) * stiffness
    self.velocity = self.velocity + accel * dt
    self.velocity = self.velocity * math.max(0, 1 - damping * dt)
    self.value    = self.value + self.velocity * dt
end

-- Snap instantly to value without spring motion.
-- Call this on state enter to avoid a pop from a stale previous value.
function Spring:reset(value)
    self.value    = value or 0
    self.velocity = 0
end

return Spring
