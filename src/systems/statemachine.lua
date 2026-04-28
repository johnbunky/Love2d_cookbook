-- src/systems/statemachine.lua
-- Generic finite state machine. Owns an entity and drives it through named states.
-- Pure Lua — no engine dependencies.
--
-- USAGE:
--   local StateMachine = require "src.systems.statemachine"
--
--   local sm = StateMachine.new(entity)   -- entity is passed to every state callback
--   sm:add("idle", require "states.idle") -- register a state table
--   sm:enter("idle")                      -- activate initial state
--
--   -- each frame:
--   sm:update(dt)    -- calls current state's update(entity, dt)
--                    -- if update returns a string, transitions to that state
--   sm:draw(camera)  -- calls current state's draw(entity, camera, ...)
--
-- STATE TABLE INTERFACE (all fields optional):
--   state.enter(entity)        called on transition in
--   state.exit(entity)         called on transition out
--   state.update(entity, dt)   return next state name to transition, or nil to stay
--   state.draw(entity, ...)    any extra args from sm:draw() are forwarded here

local StateMachine = {}
StateMachine.__index = StateMachine

-- Create a new state machine bound to `owner`.
-- `owner` is passed as the first argument to every state callback.
function StateMachine.new(owner)
    return setmetatable({
        owner   = owner,
        current = nil,
        name    = nil,
        states  = {},
    }, StateMachine)
end

-- Register a state under `name`. Call before the first sm:enter().
function StateMachine:add(name, state)
    self.states[name] = state
end

-- Transition to the named state immediately.
-- Calls exit() on the outgoing state and enter() on the incoming state.
function StateMachine:enter(name)
    assert(self.states[name], "StateMachine: unknown state '" .. tostring(name) .. "'")
    if self.current and self.current.exit then
        self.current.exit(self.owner)
    end
    self.name    = name
    self.current = self.states[name]
    if self.current.enter then
        self.current.enter(self.owner)
    end
end

-- Advance the current state by dt.
-- If update() returns a state name, transitions there automatically.
function StateMachine:update(dt)
    if not self.current then return end
    if self.current.update then
        local next = self.current.update(self.owner, dt)
        if next then self:enter(next) end
    end
end

-- Draw the current state, forwarding any extra arguments (e.g. camera).
function StateMachine:draw(...)
    if not self.current then return end
    if self.current.draw then
        self.current.draw(self.owner, ...)
    end
end

-- Returns true if the current state name matches `name`.
function StateMachine:is(name)
    return self.name == name
end

return StateMachine
