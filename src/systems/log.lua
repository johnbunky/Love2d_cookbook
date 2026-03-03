-- src/systems/log.lua
-- Simple logger: console + on-screen overlay + file output
-- Usage:
--   Log.info("player spawned at", x, y)
--   Log.warn("texture missing:", name)
--   Log.error("nil value in update")
--   Log.draw()           -- call in love.draw to show overlay (toggle with F2)
--   Log.toggle()         -- show/hide overlay
--   Log.clear()

local Log = {}

local entries  = {}
local MAX      = 40        -- max lines kept in memory
local visible  = false     -- overlay on/off
local logFile  = "game.log"

local LEVELS = {
    info  = { label="INFO ",  color={0.6, 0.9, 0.6} },
    warn  = { label="WARN ",  color={1.0, 0.85, 0.3} },
    error = { label="ERROR",  color={1.0, 0.4, 0.4} },
    debug = { label="DEBUG",  color={0.6, 0.7, 1.0} },
}

local function write(level, ...)
    local parts = {
        string.format("[%.3f]", love.timer and love.timer.getTime() or 0),
        LEVELS[level].label
    }
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        table.insert(parts, tostring(v))
    end
    local line = table.concat(parts, " ")

    -- Print to console
    print(line)

    -- Store for overlay
    table.insert(entries, { text=line, color=LEVELS[level].color })
    if #entries > MAX then table.remove(entries, 1) end

    -- Append to file (only after love.filesystem is ready)
    if love.filesystem then
        pcall(function() love.filesystem.append(logFile, line .. "\n") end)
    end
end

function Log.info(...)  write("info",  ...) end
function Log.warn(...)  write("warn",  ...) end
function Log.error(...) write("error", ...) end
function Log.debug(...) write("debug", ...) end
function Log.clear()    entries = {} end
function Log.toggle()   visible = not visible end

-- Draw on-screen overlay (call at end of love.draw, outside Scale.apply)
function Log.draw()
    if not visible then return end
    local W, H = love.window.getMode()
    local lh = 16
    local maxLines = math.floor(H / lh) - 2
    local start = math.max(1, #entries - maxLines)

    -- Background
    love.graphics.setColor(0, 0, 0, 0.65)
    love.graphics.rectangle("fill", 0, 0, W, math.min(#entries, maxLines) * lh + 4)

    love.graphics.setFont(love.graphics.newFont(12))
    for i = start, #entries do
        local e = entries[i]
        love.graphics.setColor(e.color[1], e.color[2], e.color[3], 0.95)
        love.graphics.print(e.text, 4, (i - start) * lh + 2)
    end
    love.graphics.setColor(1, 1, 1)
end

-- Call in keypressed to toggle with F2
function Log.keypressed(key)
    if key == "f2" then Log.toggle() end
end

return Log
