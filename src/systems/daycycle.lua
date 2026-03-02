-- src/systems/daycycle.lua
-- Time of day cycle: color interpolation, callbacks, speed control.
-- Engine-agnostic, no LÖVE calls.
--
-- Usage:
--   local DayCycle = require("src.systems.daycycle")
--   local dc = DayCycle.new({ duration=120 })  -- 120 second full day
--
--   dc.onSunrise = function(dc) spawnBirds() end
--   dc.onSunset  = function(dc) spawnFireflies() end
--   dc.onHour    = function(dc, hour) print("hour "..hour) end
--
--   DayCycle.update(dc, dt)
--
--   local sky = DayCycle.getSkyColor(dc)   -- {r,g,b}
--   local amb = DayCycle.getAmbientColor(dc)
--   local sun = DayCycle.getSunColor(dc)
--   local t   = dc.time       -- 0..1 normalized day progress
--   local h   = dc.hour       -- 0..23

local DayCycle = {}

-- -------------------------
-- Color keyframes
-- Each entry: { time=0..1, sky={r,g,b}, ambient={r,g,b}, sun={r,g,b} }
-- time 0 = midnight, 0.25 = sunrise, 0.5 = noon, 0.75 = sunset
-- -------------------------
local DEFAULT_KEYFRAMES = {
    { time=0.00, sky={0.02,0.03,0.10}, ambient={0.05,0.05,0.12}, sun={0.0, 0.0, 0.0}  },  -- midnight
    { time=0.20, sky={0.02,0.03,0.10}, ambient={0.05,0.05,0.12}, sun={0.0, 0.0, 0.0}  },  -- pre-dawn
    { time=0.25, sky={0.55,0.25,0.10}, ambient={0.45,0.30,0.20}, sun={0.9, 0.5, 0.2}  },  -- sunrise
    { time=0.30, sky={0.50,0.65,0.90}, ambient={0.55,0.55,0.65}, sun={1.0, 0.85,0.6}  },  -- morning
    { time=0.50, sky={0.30,0.55,0.95}, ambient={0.70,0.70,0.80}, sun={1.0, 0.95,0.85} },  -- noon
    { time=0.70, sky={0.50,0.60,0.85}, ambient={0.60,0.55,0.50}, sun={1.0, 0.85,0.5}  },  -- afternoon
    { time=0.75, sky={0.65,0.28,0.08}, ambient={0.50,0.28,0.18}, sun={0.95,0.45,0.15} },  -- sunset
    { time=0.80, sky={0.15,0.08,0.18}, ambient={0.15,0.10,0.20}, sun={0.2, 0.05,0.1}  },  -- dusk
    { time=1.00, sky={0.02,0.03,0.10}, ambient={0.05,0.05,0.12}, sun={0.0, 0.0, 0.0}  },  -- midnight (wrap)
}

-- -------------------------
-- Lerp between two colors
-- -------------------------
local function lerpColor(a, b, t)
    return {
        a[1] + (b[1]-a[1])*t,
        a[2] + (b[2]-a[2])*t,
        a[3] + (b[3]-a[3])*t,
    }
end

-- -------------------------
-- Sample a color channel from keyframes at time t (0..1)
-- -------------------------
local function sampleKeyframes(keyframes, t, channel)
    -- Find surrounding keyframes
    local k1, k2 = keyframes[1], keyframes[#keyframes]
    for i = 1, #keyframes-1 do
        if keyframes[i].time <= t and keyframes[i+1].time >= t then
            k1 = keyframes[i]
            k2 = keyframes[i+1]
            break
        end
    end
    local span = k2.time - k1.time
    local f    = span > 0 and (t - k1.time) / span or 0
    return lerpColor(k1[channel], k2[channel], f)
end

-- -------------------------
-- Create a new day cycle
-- config:
--   duration   : real seconds per full day (default 60)
--   startTime  : starting normalized time 0..1 (default 0.25 = sunrise)
--   keyframes  : custom color table (optional)
--   paused     : start paused (default false)
-- -------------------------
function DayCycle.new(config)
    config = config or {}
    local dc = {
        duration   = config.duration  or 60,
        time       = config.startTime or 0.25,  -- 0..1
        hour       = 0,
        speed      = 1.0,
        paused     = config.paused or false,
        keyframes  = config.keyframes or DEFAULT_KEYFRAMES,

        -- Callbacks
        onSunrise  = nil,  -- function(dc)
        onSunset   = nil,  -- function(dc)
        onDawn     = nil,  -- function(dc)
        onDusk     = nil,  -- function(dc)
        onMidnight = nil,  -- function(dc)
        onNoon     = nil,  -- function(dc)
        onHour     = nil,  -- function(dc, hour)

        _lastHour  = -1,
        _firedEvents = {},
    }
    dc.hour = math.floor(dc.time * 24)
    return dc
end

-- -------------------------
-- Update
-- -------------------------
function DayCycle.update(dc, dt)
    if dc.paused then return end

    dc.time = dc.time + (dt / dc.duration) * dc.speed
    if dc.time >= 1.0 then
        dc.time = dc.time - 1.0
        -- Reset fired events on day wrap
        dc._firedEvents = {}
    end

    local hour = math.floor(dc.time * 24)
    if hour ~= dc._lastHour then
        dc.hour = hour
        dc._lastHour = hour
        if dc.onHour then dc.onHour(dc, hour) end
    end

    -- Fire named events once per day
    local function fireOnce(key, fn)
        if fn and not dc._firedEvents[key] then
            dc._firedEvents[key] = true
            fn(dc)
        end
    end

    if dc.time >= 0.25 and dc.time < 0.27 then fireOnce("sunrise",  dc.onSunrise)  end
    if dc.time >= 0.75 and dc.time < 0.77 then fireOnce("sunset",   dc.onSunset)   end
    if dc.time >= 0.20 and dc.time < 0.22 then fireOnce("dawn",     dc.onDawn)     end
    if dc.time >= 0.78 and dc.time < 0.80 then fireOnce("dusk",     dc.onDusk)     end
    if dc.time >= 0.50 and dc.time < 0.52 then fireOnce("noon",     dc.onNoon)     end
    if dc.time >= 0.99 or  dc.time < 0.01 then fireOnce("midnight", dc.onMidnight) end
end

-- -------------------------
-- Color accessors
-- -------------------------
function DayCycle.getSkyColor(dc)
    return sampleKeyframes(dc.keyframes, dc.time, "sky")
end

function DayCycle.getAmbientColor(dc)
    return sampleKeyframes(dc.keyframes, dc.time, "ambient")
end

function DayCycle.getSunColor(dc)
    return sampleKeyframes(dc.keyframes, dc.time, "sun")
end

-- Convenience: get all three at once
function DayCycle.getColors(dc)
    return
        DayCycle.getSkyColor(dc),
        DayCycle.getAmbientColor(dc),
        DayCycle.getSunColor(dc)
end

-- -------------------------
-- Helpers
-- -------------------------
function DayCycle.setTime(dc, t)
    dc.time      = t % 1.0
    dc.hour      = math.floor(dc.time * 24)
    dc._lastHour = dc.hour
    dc._firedEvents = {}
end

function DayCycle.setHour(dc, hour)
    DayCycle.setTime(dc, hour / 24)
end

function DayCycle.isNight(dc)
    return dc.time < 0.22 or dc.time > 0.78
end

function DayCycle.isDay(dc)
    return dc.time >= 0.28 and dc.time <= 0.72
end

-- 0..1 brightness (useful for star/moon visibility)
function DayCycle.getNightness(dc)
    if DayCycle.isDay(dc) then return 0 end
    if dc.time < 0.22 then
        return 1 - dc.time / 0.22
    else
        return (dc.time - 0.78) / 0.22
    end
end

-- Sun angle in radians: 0 = horizon east, pi/2 = zenith, pi = horizon west
function DayCycle.getSunAngle(dc)
    -- Sunrise at 0.25, noon at 0.5, sunset at 0.75
    return (dc.time - 0.25) / 0.5 * math.pi
end

-- Sun position as normalized direction vector {x, y}
function DayCycle.getSunDir(dc)
    local angle = DayCycle.getSunAngle(dc)
    return { x = math.cos(angle), y = math.sin(angle) }
end

function DayCycle.toString(dc)
    local h = math.floor(dc.time * 24)
    local m = math.floor((dc.time * 24 - h) * 60)
    return string.format("%02d:%02d  (%.3f)", h, m, dc.time)
end

return DayCycle
