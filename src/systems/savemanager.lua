-- src/systems/savemanager.lua
-- Slot-based save/load system using love.filesystem + Serializer
-- Usage:
--   local SM = require("src.systems.savemanager")
--   SM.setup("saves/", 3)                   -- dir, num slots
--   SM.save(1, { level=5, gold=120 })
--   local data = SM.load(1)
--   local info = SM.info(1)                 -- { size, modtime } or nil
--   SM.delete(1)
--   local all  = SM.listAll()               -- { [1]=info, [2]=nil, [3]=info }

local Serializer = require("src.systems.serializer")
local SaveManager = {}

local _dir      = "saves/"
local _numSlots = 3

function SaveManager.setup(dir, numSlots)
    _dir      = dir or "saves/"
    _numSlots = numSlots or 3
    if not love.filesystem.getInfo(_dir) then
        love.filesystem.createDirectory(_dir)
    end
end

local function slotPath(slot)
    return _dir .. "slot" .. slot .. ".sav"
end

function SaveManager.save(slot, data)
    if not love.filesystem.getInfo(_dir) then
        love.filesystem.createDirectory(_dir)
    end
    return love.filesystem.write(slotPath(slot), Serializer.serialize(data))
end

function SaveManager.load(slot)
    return Serializer.read(slotPath(slot))
end

function SaveManager.delete(slot)
    love.filesystem.remove(slotPath(slot))
end

function SaveManager.info(slot)
    local info = love.filesystem.getInfo(slotPath(slot))
    if not info then return nil end
    return { size=info.size, modtime=info.modtime }
end

function SaveManager.exists(slot)
    return love.filesystem.getInfo(slotPath(slot)) ~= nil
end

function SaveManager.listAll()
    local result = {}
    for i = 1, _numSlots do
        result[i] = SaveManager.exists(i) and SaveManager.info(i) or nil
    end
    return result
end

function SaveManager.numSlots()
    return _numSlots
end

return SaveManager
