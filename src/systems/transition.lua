-- src/transition.lua
-- Screen transition effects: fade, slide, circle wipe
--
-- Usage:
--   local Transition = require("src.systems.transition")
--   Transition.to(States.menu, "fade", 0.5)   -- switch state with effect
--   Transition.update(dt)                      -- call in love.update
--   Transition.draw()                          -- call LAST in love.draw

local Transition = {}

-- -------------------------
-- Effects registry
-- Each effect is { update(t), draw(t) }
-- t = 0..1 progress (0=start, 1=end)
-- Phase 1: t goes 0→1 (out) then state switches
-- Phase 2: t goes 1→0 (in)
-- -------------------------

local W, H

local effects = {}

-- FADE — black overlay
effects.fade = {
    draw = function(t)
        love.graphics.setColor(0, 0, 0, t)
        love.graphics.rectangle("fill", 0, 0, W, H)
    end
}

-- FADE WHITE
effects.fadewhite = {
    draw = function(t)
        love.graphics.setColor(1, 1, 1, t)
        love.graphics.rectangle("fill", 0, 0, W, H)
    end
}

-- SLIDE LEFT — new scene slides in from right
effects.slideleft = {
    draw = function(t)
        -- black bar slides in from right, covers screen, then reveals
        love.graphics.setColor(0.08, 0.10, 0.14)
        love.graphics.rectangle("fill", W - W * t, 0, W, H)
    end
}

-- SLIDE RIGHT
effects.slideright = {
    draw = function(t)
        love.graphics.setColor(0.08, 0.10, 0.14)
        love.graphics.rectangle("fill", W * t - W, 0, W, H)
    end
}

-- CIRCLE WIPE — expands from center
effects.circle = {
    draw = function(t)
        -- draw black everywhere EXCEPT the growing circle
        -- use stencil: cut circle hole in black rect
        local cx  = W / 2
        local cy  = H / 2
        local maxR = math.sqrt(cx*cx + cy*cy) + 10

        love.graphics.stencil(function()
            love.graphics.circle("fill", cx, cy, maxR * t)
        end, "replace", 1)

        love.graphics.setStencilTest("less", 1)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("fill", 0, 0, W, H)
        love.graphics.setStencilTest()
    end
}

-- DISSOLVE — random pixel noise (approximated with many small rects)
effects.dissolve = {
    draw = function(t)
        math.randomseed(42)  -- consistent pattern
        love.graphics.setColor(0, 0, 0)
        local count = math.floor(t * 800)
        for _ = 1, count do
            local rx = math.random(0, W - 20)
            local ry = math.random(0, H - 20)
            love.graphics.rectangle("fill", rx, ry, 20, 20)
        end
    end
}

-- -------------------------
-- State
-- -------------------------
local state = {
    active   = false,
    phase    = "out",    -- "out" = covering, "in" = revealing
    t        = 0,        -- 0..1
    duration = 0.4,
    effect   = "fade",
    nextState = nil,
    nextArgs  = nil,
    onDone   = nil,
}

-- -------------------------
-- Trigger a transition to a new gamestate
-- targetState : state table to switch to
-- effect      : "fade", "fadewhite", "slideleft", "slideright", "circle", "dissolve"
-- duration    : seconds for each half (out + in), default 0.4
-- onDone      : optional callback after full transition completes
-- -------------------------
function Transition.to(targetState, effect, duration, onDone, ...)
    if state.active then return end  -- don't interrupt ongoing transition
    W = love.graphics.getWidth()
    H = love.graphics.getHeight()

    state.active    = true
    state.phase     = "out"
    state.t         = 0
    state.duration  = duration or 0.4
    state.effect    = effects[effect] or effects.fade
    state.nextState = targetState
    state.nextArgs  = {...}
    state.onDone    = onDone
end

-- -------------------------
-- Update — call every frame
-- -------------------------
function Transition.update(dt)
    if not state.active then return end

    state.t = state.t + dt / state.duration

    if state.t >= 1 then
        state.t = 1
        if state.phase == "out" then
            -- Switch state at the peak (fully covered)
            Gamestate.switch(state.nextState, unpack(state.nextArgs))
            state.phase = "in"
            state.t     = 1
        else
            -- Fully revealed — done
            state.active = false
            if state.onDone then state.onDone() end
        end
    end
end

-- -------------------------
-- Draw — call LAST in love.draw (after all game content)
-- -------------------------
function Transition.draw()
    if not state.active then return end
    W = love.graphics.getWidth()
    H = love.graphics.getHeight()

    -- t goes 0→1 when covering (out), 1→0 when revealing (in)
    local drawT = state.phase == "out" and state.t or (1 - state.t)
    state.effect.draw(drawT)

    love.graphics.setColor(1, 1, 1)
end

-- -------------------------
-- Check if a transition is currently running
-- -------------------------
function Transition.isActive()
    return state.active
end

return Transition
