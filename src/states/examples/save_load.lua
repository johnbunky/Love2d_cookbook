-- src/states/examples/save_load.lua
-- Demonstrates: love.filesystem read/write, JSON-like serialization, save slots

local Utils      = require("src.utils")
local Timer      = require("src.systems.timer")
local SaveManager= require("src.systems.savemanager")
local Example = {}

local W, H
local timer
local time = 0

-- -------------------------
-- Simple serializer (no deps)
-- -------------------------
local function serialize(val, indent)
    indent = indent or 0
    local t = type(val)
    if t == "number"  then return tostring(val) end
    if t == "boolean" then return tostring(val) end
    if t == "string"  then return string.format("%q", val) end
    if t == "table" then
        local lines = {}
        local pad   = string.rep("  ", indent+1)
        local isArr = (#val > 0)
        for k, v in pairs(val) do
            local key = isArr and "" or (tostring(k).."=")
            table.insert(lines, pad .. key .. serialize(v, indent+1))
        end
        local open, close = isArr and "{" or "{", "}"
        return open .. "\n" .. table.concat(lines, ",\n") .. "\n" .. string.rep("  ",indent) .. close
    end
    return "nil"
end

local function deserialize(str)
    local fn = load("return " .. str)
    if fn then
        local ok, val = pcall(fn)
        if ok then return val end
    end
    return nil
end

-- -------------------------
-- Save / Load via love.filesystem
-- -------------------------
local SAVE_DIR  = "saves/"
local NUM_SLOTS = 3

local function slotPath(slot)
    return SAVE_DIR .. "slot" .. slot .. ".sav"
end

local function ensureDir()
    if not love.filesystem.getInfo(SAVE_DIR) then
        love.filesystem.createDirectory(SAVE_DIR)
    end
end

local function saveGame(slot, data)
    return SaveManager.save(slot, data)
end

local function loadGame(slot)
    return SaveManager.load(slot)
end

local function deleteSlot(slot)
    SaveManager.delete(slot)
end

local function slotInfo(slot)
    return SaveManager.info(slot)
end

-- -------------------------
-- Game state to save/load
-- -------------------------
local gameData = {
    playerName  = "Hero",
    level       = 1,
    hp          = 100,
    gold        = 0,
    playtime    = 0,
    checkpoint  = "town",
    inventory   = {"sword", "potion"},
    achievements= { first_kill=false, explorer=false },
}

-- -------------------------
-- UI state
-- -------------------------
local selectedSlot = 1
local message      = nil
local messageTimer = 0
local messageOk    = true
local slotData     = {}   -- cached slot info

local editingName  = false
local nameBuffer   = ""

local function setMessage(msg, ok)
    message      = msg
    messageTimer = 3.0
    messageOk    = ok ~= false
end

local function refreshSlots()
    slotData = {}
    for i = 1, NUM_SLOTS do
        local data, err = loadGame(i)
        local info       = slotInfo(i)
        slotData[i]      = { data=data, info=info, err=err }
    end
end

-- -------------------------
-- Enter / Exit
-- -------------------------
function Example.enter()
    W, H  = love.graphics.getWidth(), love.graphics.getHeight()
    timer = Timer.new()
    time  = 0
    SaveManager.setup("saves/", NUM_SLOTS)
    refreshSlots()
    gameData.playtime = 0
end

function Example.exit()
    Timer.clear(timer)
end

-- -------------------------
-- Update
-- -------------------------
function Example.update(dt)
    Timer.update(timer, dt)
    time             = time + dt
    gameData.playtime = gameData.playtime + dt
    if messageTimer > 0 then messageTimer = messageTimer - dt end

    -- Simulate gold trickling in
    gameData.gold = math.floor(time * 3.5)
    gameData.hp   = 80 + math.floor(math.sin(time*0.4)*20)
end

-- -------------------------
-- Draw
-- -------------------------
local function formatTime(secs)
    local m = math.floor(secs/60)
    local s = math.floor(secs%60)
    return string.format("%02d:%02d", m, s)
end

local function drawSlot(i, x, y, w, h)
    local sel  = (i == selectedSlot)
    local sd   = slotData[i]
    local data = sd and sd.data
    local info = sd and sd.info

    -- Background
    love.graphics.setColor(sel and 0.10 or 0.07,
                           sel and 0.16 or 0.10,
                           sel and 0.30 or 0.18, 0.95)
    love.graphics.rectangle("fill", x, y, w, h, 6,6)
    love.graphics.setColor(sel and 0.35 or 0.20,
                           sel and 0.55 or 0.30,
                           sel and 0.90 or 0.50)
    love.graphics.rectangle("line", x, y, w, h, 6,6)

    -- Slot number
    love.graphics.setColor(sel and 0.5 or 0.35,
                           sel and 0.7 or 0.45,
                           sel and 1.0 or 0.65)
    love.graphics.printf("SLOT "..i, x+10, y+8, w-20, "left")

    if data then
        -- Saved data display
        love.graphics.setColor(0.85, 0.90, 1.0)
        love.graphics.printf(data.playerName or "?", x+10, y+28, w/2, "left")
        love.graphics.setColor(0.6, 0.75, 0.95)
        love.graphics.printf("Lv."..( data.level or "?"), x+w/2, y+28, w/2-10, "right")

        love.graphics.setColor(0.5, 0.65, 0.85)
        love.graphics.printf("HP: "..(data.hp or "?").."  Gold: "..(data.gold or "?"),
            x+10, y+48, w-20, "left")
        love.graphics.printf("?? "..(data.checkpoint or "?"),
            x+10, y+64, w-20, "left")
        love.graphics.printf("? "..formatTime(data.playtime or 0),
            x+10, y+80, w-20, "left")
        if info then
            love.graphics.setColor(0.35, 0.45, 0.65)
            love.graphics.printf(info.size.." bytes", x+w-80, y+80, 70, "right")
        end
    else
        -- Empty slot
        love.graphics.setColor(0.3, 0.38, 0.55)
        love.graphics.printf("— empty —", x+10, y+50, w-20, "center")
    end
end

function Example.draw()
    love.graphics.setColor(0.06, 0.08, 0.14)
    love.graphics.rectangle("fill", 0, 0, W, H)

    love.graphics.setColor(0.5, 0.7, 1.0)
    love.graphics.printf("SAVE / LOAD", 0, 20, W, "center")

    -- Current game state panel
    local gx, gy = 40, 60
    love.graphics.setColor(0.08, 0.12, 0.22, 0.95)
    love.graphics.rectangle("fill", gx, gy, 280, 200, 6,6)
    love.graphics.setColor(0.3, 0.45, 0.75)
    love.graphics.rectangle("line", gx, gy, 280, 200, 6,6)
    love.graphics.setColor(0.5, 0.7, 1.0)
    love.graphics.printf("Current Game", gx+10, gy+8, 260, "left")

    love.graphics.setColor(0.7, 0.85, 1.0)
    local lines = {
        "Name:       " .. (editingName and (nameBuffer.."_") or gameData.playerName),
        "Level:      " .. gameData.level,
        "HP:         " .. gameData.hp,
        "Gold:       " .. gameData.gold,
        "Checkpoint: " .. gameData.checkpoint,
        "Playtime:   " .. formatTime(gameData.playtime),
        "Inventory:  " .. table.concat(gameData.inventory, ", "),
    }
    for i, line in ipairs(lines) do
        if i == 1 and editingName then
            love.graphics.setColor(0.3, 1.0, 0.5)
        else
            love.graphics.setColor(0.65, 0.80, 1.0)
        end
        love.graphics.print(line, gx+14, gy+28 + (i-1)*22)
    end

    -- Quick actions
    love.graphics.setColor(0.3, 0.45, 0.7)
    love.graphics.printf("N - rename  L - level up  C - next checkpoint",
        gx+10, gy+180, 260, "center")

    -- Save slots
    local sx = W/2 - 10
    love.graphics.setColor(0.5, 0.7, 1.0)
    love.graphics.printf("Save Slots", sx, gy, W/2-50, "left")

    local slotH = 105
    local slotW = W/2 - 50
    for i = 1, NUM_SLOTS do
        drawSlot(i, sx, gy+24 + (i-1)*(slotH+8), slotW, slotH)
    end

    -- Message banner
    if messageTimer > 0 then
        local alpha = math.min(1, messageTimer)
        love.graphics.setColor(messageOk and 0.1 or 0.3,
                               messageOk and 0.4 or 0.1,
                               messageOk and 0.15 or 0.1, alpha*0.9)
        love.graphics.rectangle("fill", W/2-180, H-90, 360, 40, 6,6)
        love.graphics.setColor(messageOk and 0.3 or 0.8,
                               messageOk and 1.0 or 0.3,
                               messageOk and 0.5 or 0.3, alpha)
        love.graphics.rectangle("line", W/2-180, H-90, 360, 40, 6,6)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.printf(message or "", W/2-170, H-80, 340, "center")
    end

    Utils.drawHUD("SAVE / LOAD",
        "1/2/3 slot    F5 save    F9 load    DEL delete    N rename    ESC back")
end

-- -------------------------
-- Input
-- -------------------------
function Example.keypressed(key)
    if editingName then
        if key == "return" or key == "escape" then
            if key == "return" and #nameBuffer > 0 then
                gameData.playerName = nameBuffer
            end
            editingName = false
            nameBuffer  = ""
        elseif key == "backspace" then
            nameBuffer = nameBuffer:sub(1, -2)
        end
        return
    end

    if key == "1" then selectedSlot = 1
    elseif key == "2" then selectedSlot = 2
    elseif key == "3" then selectedSlot = 3
    elseif key == "up" then
        selectedSlot = (selectedSlot - 2) % NUM_SLOTS + 1
    elseif key == "down" then
        selectedSlot = selectedSlot % NUM_SLOTS + 1

    elseif key == "f5" then
        local ok, err = saveGame(selectedSlot, gameData)
        if ok then
            setMessage("Saved to slot " .. selectedSlot)
            refreshSlots()
        else
            setMessage("Save failed: " .. tostring(err), false)
        end

    elseif key == "f9" then
        local data, err = loadGame(selectedSlot)
        if data then
            -- Restore fields (not playtime)
            gameData.playerName   = data.playerName  or gameData.playerName
            gameData.level        = data.level        or gameData.level
            gameData.gold         = data.gold         or gameData.gold
            gameData.checkpoint   = data.checkpoint   or gameData.checkpoint
            gameData.inventory    = data.inventory    or gameData.inventory
            gameData.achievements = data.achievements or gameData.achievements
            setMessage("Loaded slot " .. selectedSlot)
        else
            setMessage("Load failed: " .. tostring(err), false)
        end

    elseif key == "delete" or key == "backspace" then
        deleteSlot(selectedSlot)
        setMessage("Deleted slot " .. selectedSlot)
        refreshSlots()

    elseif key == "n" then
        editingName = true
        nameBuffer  = gameData.playerName

    elseif key == "l" then
        gameData.level = gameData.level + 1
        setMessage("Level up! Now level " .. gameData.level)

    elseif key == "c" then
        local checkpoints = {"town","dungeon","castle","forest","volcano"}
        local idx = 1
        for i, cp in ipairs(checkpoints) do
            if cp == gameData.checkpoint then idx = i; break end
        end
        gameData.checkpoint = checkpoints[idx % #checkpoints + 1]
    end

    Utils.handlePause(key, Example)
end

function Example.textinput(text)
    if editingName and #nameBuffer < 16 then
        nameBuffer = nameBuffer .. text
    end
end

return Example
