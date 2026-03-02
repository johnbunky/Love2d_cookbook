-- src/systems/leaderboard.lua
-- Persistent sorted leaderboard with file I/O
-- Pure score logic is LÖVE-free; load/save uses love.filesystem
-- Usage:
--   local LB = require("src.systems.leaderboard")
--   LB.setup("scores.sav", 10)
--   LB.load()
--   LB.add("ACE", 5200)
--   local entries = LB.entries()    -- sorted table { {name, score, date} }
--   local rank    = LB.rankOf(5200) -- position or nil if not on board
--   LB.save()
--   LB.clear()

local Leaderboard = {}

local _file    = "highscores.sav"
local _maxSize = 10
local _entries = {}   -- { { name, score, date } }

function Leaderboard.setup(file, maxSize)
    _file    = file    or "highscores.sav"
    _maxSize = maxSize or 10
    _entries = {}
end

-- Sort descending by score
local function sort()
    table.sort(_entries, function(a, b) return a.score > b.score end)
end

-- Trim to max size
local function trim()
    while #_entries > _maxSize do table.remove(_entries) end
end

function Leaderboard.add(name, score)
    table.insert(_entries, {
        name  = tostring(name),
        score = tonumber(score) or 0,
        date  = os.time(),
    })
    sort()
    trim()
end

function Leaderboard.entries()
    return _entries
end

function Leaderboard.count()
    return #_entries
end

-- Returns 1-based rank if score qualifies, nil otherwise
function Leaderboard.rankOf(score)
    -- Would it fit?
    if #_entries < _maxSize then return #_entries + 1 end
    for i, e in ipairs(_entries) do
        if score > e.score then return i end
    end
    return nil
end

function Leaderboard.qualifies(score)
    return Leaderboard.rankOf(score) ~= nil
end

function Leaderboard.clear()
    _entries = {}
end

-- Serialize to pipe-delimited text (human-readable)
function Leaderboard.save()
    local lines = {}
    for _, e in ipairs(_entries) do
        table.insert(lines, string.format("%d|%s|%d",
            e.score, e.name:gsub("|",""), e.date))
    end
    love.filesystem.write(_file, table.concat(lines, "\n"))
end

function Leaderboard.load()
    _entries = {}
    local info = love.filesystem.getInfo(_file)
    if not info then return end
    local str = love.filesystem.read(_file)
    if not str then return end
    for line in str:gmatch("[^\n]+") do
        local score, name, date = line:match("(%d+)|([^|]+)|(%d+)")
        if score then
            table.insert(_entries, {
                score = tonumber(score),
                name  = name,
                date  = tonumber(date),
            })
        end
    end
    sort()
end

function Leaderboard.deleteFile()
    love.filesystem.remove(_file)
    _entries = {}
end

return Leaderboard
