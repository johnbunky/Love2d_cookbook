-- src/systems/tween.lua
-- Deterministic interpolation from A to B in exactly N seconds.
-- Use instead of Spring when you need predictable timing (UI, cutscenes).
-- Pure Lua — no engine dependencies.
--
-- USAGE:
--   local Tween = require "src.systems.tween"
--   local t = Tween.new(0, 1, 0.5, "quad_out")
--   t:update(dt)
--   -- read: t.value
--   -- check: t.done
--
-- EASINGS:
--   linear
--   quad_in   quad_out   quad_inout
--   cubic_in  cubic_out  cubic_inout
--   back_out                          -- overshoots then settles (UI pop)
--   elastic_out                       -- springy bounce at end
--   bounce_out                        -- physical bounce at end

local Tween = {}
Tween.__index = Tween

-- ─── easing functions (t = 0..1) ─────────────────────────────────────────────
local easings = {
    linear      = function(t) return t end,

    quad_in     = function(t) return t*t end,
    quad_out    = function(t) return 1-(1-t)*(1-t) end,
    quad_inout  = function(t)
        if t < 0.5 then return 2*t*t
        else return 1 - (-2*t+2)^2 / 2 end
    end,

    cubic_in    = function(t) return t*t*t end,
    cubic_out   = function(t) return 1-(1-t)^3 end,
    cubic_inout = function(t)
        if t < 0.5 then return 4*t*t*t
        else return 1 - (-2*t+2)^3 / 2 end
    end,

    back_out    = function(t)
        local c1 = 1.70158
        local c3 = c1 + 1
        return 1 + c3*(t-1)^3 + c1*(t-1)^2
    end,

    elastic_out = function(t)
        if t == 0 then return 0 end
        if t == 1 then return 1 end
        return 2^(-10*t) * math.sin((t*10 - 0.75) * (2*math.pi) / 3) + 1
    end,

    bounce_out  = function(t)
        local n1, d1 = 7.5625, 2.75
        if t < 1/d1     then return n1*t*t
        elseif t < 2/d1 then t = t - 1.5/d1;   return n1*t*t + 0.75
        elseif t < 2.5/d1 then t = t - 2.25/d1; return n1*t*t + 0.9375
        else                   t = t - 2.625/d1; return n1*t*t + 0.984375
        end
    end,
}

-- ─── constructor ─────────────────────────────────────────────────────────────

-- Create a new tween.
--   from     start value
--   to       end value
--   duration seconds
--   easing   string (see list above) or custom function(t) → 0..1
--   callback optional function called once when tween completes
function Tween.new(from, to, duration, easing, callback)
    assert(duration and duration > 0, "Tween: duration must be > 0")
    local ease_fn = type(easing) == "function" and easing
                 or easings[easing or "linear"]
    assert(ease_fn, "Tween: unknown easing '" .. tostring(easing) .. "'")
    return setmetatable({
        from     = from,
        to       = to,
        duration = duration,
        ease     = ease_fn,
        callback = callback,
        elapsed  = 0,
        value    = from,
        done     = false,
    }, Tween)
end

-- ─── update ──────────────────────────────────────────────────────────────────

function Tween:update(dt)
    if self.done then return end
    self.elapsed = self.elapsed + dt
    local t = math.min(1, self.elapsed / self.duration)
    self.value = self.from + (self.to - self.from) * self.ease(t)
    if t >= 1 then
        self.value = self.to
        self.done  = true
        if self.callback then self.callback() end
    end
end

-- Restart the tween from the beginning.
function Tween:reset()
    self.elapsed = 0
    self.value   = self.from
    self.done    = false
end

-- Change target without restarting — continues from current value.
function Tween:retarget(to, duration, easing)
    self.from     = self.value
    self.to       = to
    self.duration = duration or self.duration
    if easing then
        local ease_fn = type(easing) == "function" and easing or easings[easing]
        assert(ease_fn, "Tween: unknown easing '" .. tostring(easing) .. "'")
        self.ease = ease_fn
    end
    self.elapsed = 0
    self.done    = false
end

return Tween
