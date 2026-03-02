-- src/systems/timer.lua
-- Lightweight timer system. Engine-agnostic — no LÖVE calls.
--
-- Three timer types:
--   after   : fire once after N seconds
--   every   : fire repeatedly every N seconds
--   tween   : interpolate a value over N seconds
--
-- Usage:
--   local Timer = require("src.systems.timer")
--   local t = Timer.new()
--
--   Timer.after(t, 2.0, function() print("2s later") end)
--
--   Timer.every(t, 0.5, function() print("tick") end)
--
--   local handle = Timer.every(t, 1.0, function(i) print("rep "..i) end, 5)
--   Timer.cancel(t, handle)   -- cancel before it finishes
--
--   Timer.tween(t, 1.5, obj, "x", 0, 400, "linear")
--   Timer.tween(t, 1.0, obj, "alpha", 1, 0, "quad")
--
--   Timer.update(t, dt)       -- call every frame
--   Timer.clear(t)            -- cancel everything

local Timer = {}

-- -------------------------
-- Easing functions
-- -------------------------
local easing = {}

easing.linear = function(t) return t end
easing.quad   = function(t) return t * t end
easing.cubic  = function(t) return t * t * t end
easing.quart  = function(t) return t * t * t * t end

easing.quadout  = function(t) return 1 - (1-t)*(1-t) end
easing.cubicout = function(t) local u=1-t; return 1-u*u*u end

easing.sin    = function(t) return 1 - math.cos(t * math.pi * 0.5) end
easing.sinout = function(t) return math.sin(t * math.pi * 0.5) end
easing.sinInOut = function(t) return 0.5 - math.cos(math.pi*t)*0.5 end

easing.bounce = function(t)
    if t < 1/2.75 then
        return 7.5625 * t * t
    elseif t < 2/2.75 then
        t = t - 1.5/2.75
        return 7.5625*t*t + 0.75
    elseif t < 2.5/2.75 then
        t = t - 2.25/2.75
        return 7.5625*t*t + 0.9375
    else
        t = t - 2.625/2.75
        return 7.5625*t*t + 0.984375
    end
end

easing.elastic = function(t)
    if t == 0 or t == 1 then return t end
    return -math.pow(2, 10*(t-1)) * math.sin((t-1.1)*5*math.pi)
end

easing.back = function(t)
    local s = 1.70158
    return t*t*((s+1)*t - s)
end

-- -------------------------
-- Create a new timer group
-- -------------------------
function Timer.new()
    return {
        entries  = {},
        nextId   = 1,
    }
end

-- -------------------------
-- Internal: add entry
-- -------------------------
local function addEntry(t, entry)
    local id = t.nextId
    t.nextId = t.nextId + 1
    entry.id = id
    table.insert(t.entries, entry)
    return id
end

-- -------------------------
-- Fire once after `delay` seconds
-- Returns handle to cancel
-- -------------------------
function Timer.after(t, delay, fn)
    return addEntry(t, {
        type    = "after",
        delay   = delay,
        elapsed = 0,
        fn      = fn,
        done    = false,
    })
end

-- -------------------------
-- Fire every `interval` seconds
-- count : max repetitions (nil = infinite)
-- Returns handle to cancel
-- -------------------------
function Timer.every(t, interval, fn, count)
    return addEntry(t, {
        type     = "every",
        interval = interval,
        elapsed  = 0,
        fn       = fn,
        count    = count,
        fired    = 0,
        done     = false,
    })
end

-- -------------------------
-- Tween object[key] from `from` to `to` over `duration`
-- easingName : "linear","quad","quadout","cubic","cubicout",
--              "sin","sinout","sinInOut","bounce","elastic","back"
-- onDone     : optional callback when tween completes
-- -------------------------
function Timer.tween(t, duration, obj, key, from, to, easingName, onDone)
    obj[key] = from
    return addEntry(t, {
        type     = "tween",
        duration = duration,
        elapsed  = 0,
        obj      = obj,
        key      = key,
        from     = from,
        to       = to,
        ease     = easing[easingName] or easing.linear,
        onDone   = onDone,
        done     = false,
    })
end

-- -------------------------
-- Cancel a timer by handle
-- -------------------------
function Timer.cancel(t, id)
    for i, e in ipairs(t.entries) do
        if e.id == id then
            table.remove(t.entries, i)
            return true
        end
    end
    return false
end

-- -------------------------
-- Update all timers — call every frame
-- -------------------------
function Timer.update(t, dt)
    for i = #t.entries, 1, -1 do
        local e = t.entries[i]

        if e.type == "after" then
            e.elapsed = e.elapsed + dt
            if e.elapsed >= e.delay then
                e.fn()
                e.done = true
            end

        elseif e.type == "every" then
            e.elapsed = e.elapsed + dt
            while e.elapsed >= e.interval do
                e.elapsed = e.elapsed - e.interval
                e.fired   = e.fired + 1
                e.fn(e.fired)
                if e.count and e.fired >= e.count then
                    e.done = true
                    break
                end
            end

        elseif e.type == "tween" then
            e.elapsed = e.elapsed + dt
            local progress = math.min(1, e.elapsed / e.duration)
            local eased    = e.ease(progress)
            e.obj[e.key]   = e.from + (e.to - e.from) * eased
            if progress >= 1 then
                e.obj[e.key] = e.to   -- snap to exact end value
                if e.onDone then e.onDone() end
                e.done = true
            end
        end

        if e.done then
            table.remove(t.entries, i)
        end
    end
end

-- -------------------------
-- Cancel all timers
-- -------------------------
function Timer.clear(t)
    t.entries = {}
end

-- -------------------------
-- Count active timers (debug)
-- -------------------------
function Timer.count(t)
    return #t.entries
end

-- -------------------------
-- Convenience: global timer (module-level singleton)
-- -------------------------
Timer.global = Timer.new()

function Timer.globalUpdate(dt)
    Timer.update(Timer.global, dt)
end

return Timer
