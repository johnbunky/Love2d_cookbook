-- src/systems/settings.lua
-- Schema-driven settings manager with persistence
-- Pure logic is LÖVE-free; load/save uses love.filesystem
-- Usage:
--   local Settings = require("src.systems.settings")
--   Settings.setup("settings.cfg", DEFAULTS)
--   Settings.load()
--   local vol = Settings.get("audio", "masterVolume")
--   Settings.set("audio", "masterVolume", 0.8)
--   Settings.save()
--   Settings.reset()           -- back to defaults
--   local dirty = Settings.isDirty()

local Settings = {}

local _file     = "settings.cfg"
local _defaults = {}
local _current  = {}
local _dirty    = false

-- -------------------------
-- Deep copy helper
-- -------------------------
local function deepCopy(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do copy[k] = deepCopy(v) end
    return copy
end

-- -------------------------
-- Flatten to key=value lines: "category.key=value"
-- -------------------------
local function flatten(s)
    local lines = {}
    for cat, vals in pairs(s) do
        for k, v in pairs(vals) do
            table.insert(lines, cat .. "." .. k .. "=" .. tostring(v))
        end
    end
    table.sort(lines)
    return table.concat(lines, "\n")
end

-- -------------------------
-- Parse key=value lines back into a settings table
-- Uses defaults for type coercion and unknown-key protection
-- -------------------------
local function parse(str, base)
    local s = deepCopy(base)
    for line in str:gmatch("[^\n]+") do
        local cat, key, val = line:match("([^.]+)%.([^=]+)=(.*)")
        if cat and s[cat] and s[cat][key] ~= nil then
            local bt = type(s[cat][key])
            if     bt == "boolean" then s[cat][key] = (val == "true")
            elseif bt == "number"  then s[cat][key] = tonumber(val) or s[cat][key]
            elseif bt == "string"  then s[cat][key] = val
            end
        end
    end
    return s
end

-- -------------------------
-- Public API
-- -------------------------
function Settings.setup(file, defaults)
    _file     = file     or "settings.cfg"
    _defaults = defaults or {}
    _current  = deepCopy(_defaults)
    _dirty    = false
end

function Settings.load()
    local info = love.filesystem.getInfo(_file)
    if not info then _current = deepCopy(_defaults); return false end
    local str = love.filesystem.read(_file)
    if not str then _current = deepCopy(_defaults); return false end
    _current = parse(str, _defaults)
    _dirty   = false
    return true
end

function Settings.save()
    love.filesystem.write(_file, flatten(_current))
    _dirty = false
end

function Settings.reset()
    _current = deepCopy(_defaults)
    _dirty   = true
end

function Settings.get(category, key)
    if _current[category] then
        return _current[category][key]
    end
    return nil
end

function Settings.set(category, key, value)
    if _current[category] and _current[category][key] ~= nil then
        _current[category][key] = value
        _dirty = true
        return true
    end
    return false
end

-- Adjust a numeric value by delta, clamped to min/max
function Settings.adjust(category, key, delta, minVal, maxVal)
    local v = Settings.get(category, key)
    if type(v) == "number" then
        v = math.max(minVal, math.min(maxVal, v + delta))
        v = math.floor(v * 1000 + 0.5) / 1000  -- round to 3dp
        Settings.set(category, key, v)
    end
end

-- Toggle a boolean value
function Settings.toggle(category, key)
    local v = Settings.get(category, key)
    if type(v) == "boolean" then
        Settings.set(category, key, not v)
    end
end

-- Cycle through enum values (list of options)
function Settings.cycle(category, key, options, delta)
    local v   = Settings.get(category, key)
    local n   = #options
    local idx = 1
    for i, opt in ipairs(options) do
        if opt == v then idx = i; break end
    end
    idx = (idx - 1 + delta + n) % n + 1
    Settings.set(category, key, options[idx])
end

function Settings.isDirty()  return _dirty         end
function Settings.all()      return deepCopy(_current) end
function Settings.defaults() return deepCopy(_defaults) end
function Settings.deleteFile()
    love.filesystem.remove(_file)
    _current = deepCopy(_defaults)
    _dirty   = false
end

return Settings
