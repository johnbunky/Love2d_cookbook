-- src/systems/health.lua
-- Health, damage types, resistances, status effects, iframes, regen.
-- Engine-agnostic — no LÖVE calls.
--
-- Usage:
--   local Health = require("src.systems.health")
--
--   local hp = Health.new({ max=100, armor=5 })
--   Health.damage(hp, 25, "physical")
--   Health.damage(hp, 15, "fire")
--   Health.heal(hp, 20)
--   Health.update(hp, dt)
--
--   hp.onDamage  = function(hp, amount, dtype, actual) end
--   hp.onDeath   = function(hp) end
--   hp.onRegen   = function(hp, amount) end
--   hp.onStatus  = function(hp, status, action) end  -- action: "add","tick","remove"

local Health = {}

-- -------------------------
-- Damage types
-- -------------------------
Health.DMG = {
    PHYSICAL = "physical",
    FIRE     = "fire",
    ICE      = "ice",
    POISON   = "poison",
    LIGHTNING= "lightning",
    TRUE     = "true",     -- bypasses all resistances and armor
}

-- Default status tick config
local STATUS_CONFIG = {
    burning   = { interval=0.5,  dmgType="fire",    dmgPerStack=4  },
    poisoned  = { interval=1.0,  dmgType="poison",  dmgPerStack=6  },
    lightning = { interval=0.25, dmgType="lightning",dmgPerStack=3 },
}

-- -------------------------
-- Create a new health component
-- config:
--   max       : max hp (default 100)
--   armor     : flat physical damage reduction (default 0)
--   regen     : hp per second when out of combat (default 0)
--   regenDelay: seconds after last hit before regen starts (default 3)
--   iframeTime: invincibility seconds after physical hit (default 0.5)
--   resist    : { fire=0..1, ice=0..1, poison=0..1, lightning=0..1 }
-- -------------------------
function Health.new(config)
    config = config or {}
    local max = config.max or 100
    return {
        current    = max,
        max        = max,
        armor      = config.armor      or 0,
        regen      = config.regen      or 0,
        regenDelay = config.regenDelay or 3.0,
        regenTimer = 0,
        iframeTime = config.iframeTime or 0.5,
        iframes    = 0,
        dead       = false,

        resist = {
            fire      = config.resist and config.resist.fire      or 0,
            ice       = config.resist and config.resist.ice       or 0,
            poison    = config.resist and config.resist.poison    or 0,
            lightning = config.resist and config.resist.lightning or 0,
        },

        statuses   = {},   -- active status effects

        -- Callbacks (set after creation)
        onDamage   = nil,
        onDeath    = nil,
        onRegen    = nil,
        onStatus   = nil,
    }
end

-- -------------------------
-- Internal: clamp hp and check death
-- -------------------------
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function checkDeath(hp)
    if not hp.dead and hp.current <= 0 then
        hp.current = 0
        hp.dead    = true
        if hp.onDeath then hp.onDeath(hp) end
    end
end

-- -------------------------
-- Apply damage
-- Returns actual damage dealt
-- -------------------------
function Health.damage(hp, amount, dtype)
    if hp.dead then return 0 end
    dtype = dtype or Health.DMG.PHYSICAL

    local actual = amount

    if dtype == Health.DMG.PHYSICAL then
        if hp.iframes > 0 then return 0 end
        actual = math.max(1, amount - hp.armor)
        hp.iframes    = hp.iframeTime
        hp.regenTimer = hp.regenDelay

    elseif dtype == Health.DMG.TRUE then
        actual = amount  -- bypasses everything
        hp.regenTimer = hp.regenDelay

    else
        -- Elemental — apply resistance
        local res = hp.resist[dtype] or 0
        actual = math.floor(amount * (1 - res))
        hp.regenTimer = hp.regenDelay
    end

    actual = math.max(0, actual)
    hp.current = clamp(hp.current - actual, 0, hp.max)

    if hp.onDamage then hp.onDamage(hp, amount, dtype, actual) end
    checkDeath(hp)
    return actual
end

-- -------------------------
-- Heal
-- Returns actual amount healed
-- -------------------------
function Health.heal(hp, amount)
    if hp.dead then return 0 end
    local prev    = hp.current
    hp.current    = clamp(hp.current + amount, 0, hp.max)
    local actual  = hp.current - prev
    if actual > 0 and hp.onRegen then hp.onRegen(hp, actual) end
    return actual
end

-- -------------------------
-- Revive with optional hp amount
-- -------------------------
function Health.revive(hp, amount)
    hp.dead     = false
    hp.iframes  = 0
    hp.current  = clamp(amount or hp.max, 1, hp.max)
    hp.statuses = {}
end

-- -------------------------
-- Apply a status effect
-- type     : "burning", "poisoned", "frozen", "lightning", or custom
-- duration : seconds
-- stacks   : how many stacks to add (default 1, max 5)
-- -------------------------
function Health.applyStatus(hp, statusType, duration, stacks)
    if hp.dead then return end
    stacks = stacks or 1

    -- Find existing
    for _, s in ipairs(hp.statuses) do
        if s.type == statusType then
            s.duration = math.max(s.duration, duration)
            s.stacks   = math.min((s.stacks or 1) + stacks, 5)
            if hp.onStatus then hp.onStatus(hp, s, "add") end
            return
        end
    end

    local s = {
        type     = statusType,
        duration = duration,
        stacks   = stacks,
        tickT    = 0,
    }
    table.insert(hp.statuses, s)
    if hp.onStatus then hp.onStatus(hp, s, "add") end
end

-- -------------------------
-- Remove a status effect
-- -------------------------
function Health.removeStatus(hp, statusType)
    for i, s in ipairs(hp.statuses) do
        if s.type == statusType then
            if hp.onStatus then hp.onStatus(hp, s, "remove") end
            table.remove(hp.statuses, i)
            return
        end
    end
end

-- -------------------------
-- Check if status is active
-- -------------------------
function Health.hasStatus(hp, statusType)
    for _, s in ipairs(hp.statuses) do
        if s.type == statusType then return s end
    end
    return nil
end

-- -------------------------
-- Modify resistance at runtime
-- -------------------------
function Health.setResist(hp, dtype, value)
    hp.resist[dtype] = clamp(value, 0, 1)
end

function Health.addResist(hp, dtype, value)
    hp.resist[dtype] = clamp((hp.resist[dtype] or 0) + value, 0, 1)
end

-- -------------------------
-- Update — call every frame
-- Handles: iframes, status ticks, status expiry, regen
-- -------------------------
function Health.update(hp, dt)
    if hp.dead then return end

    -- i-frames
    hp.iframes = math.max(0, hp.iframes - dt)

    -- Status effects
    for i = #hp.statuses, 1, -1 do
        local s   = hp.statuses[i]
        s.duration = s.duration - dt

        -- Tick damage
        local cfg = STATUS_CONFIG[s.type]
        if cfg then
            s.tickT = s.tickT - dt
            if s.tickT <= 0 then
                s.tickT = cfg.interval
                local dmg = cfg.dmgPerStack * (s.stacks or 1)
                Health.damage(hp, dmg, cfg.dmgType)
                if hp.onStatus then hp.onStatus(hp, s, "tick") end
            end
        end

        -- Expiry
        if s.duration <= 0 then
            if hp.onStatus then hp.onStatus(hp, s, "remove") end
            table.remove(hp.statuses, i)
        end
    end

    -- Passive regen (only when no statuses and out of combat)
    if hp.regen > 0 and #hp.statuses == 0 then
        hp.regenTimer = hp.regenTimer - dt
        if hp.regenTimer <= 0 then
            local amount = hp.regen * dt
            if hp.current < hp.max then
                Health.heal(hp, amount)
            end
        end
    end
end

-- -------------------------
-- Normalized 0..1 percentage
-- -------------------------
function Health.percent(hp)
    return hp.current / hp.max
end

-- -------------------------
-- Is alive and above threshold
-- -------------------------
function Health.isAlive(hp)
    return not hp.dead and hp.current > 0
end

-- -------------------------
-- Debug string
-- -------------------------
function Health.toString(hp)
    local statStr = ""
    for _, s in ipairs(hp.statuses) do
        statStr = statStr .. string.format(" [%s x%d %.1fs]", s.type, s.stacks or 1, s.duration)
    end
    return string.format("hp=%d/%d armor=%d iframes=%.2f%s",
        hp.current, hp.max, hp.armor, hp.iframes, statStr)
end

return Health
