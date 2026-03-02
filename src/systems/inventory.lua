-- src/systems/inventory.lua
-- Grid-based inventory: slots, stacking, item registry, equip, transfer.
-- Engine-agnostic — no LÖVE calls.
--
-- Usage:
--   local Inventory = require("src.systems.inventory")
--
--   -- Register item types once (global)
--   Inventory.register("sword",  { name="Iron Sword",  icon="sword",  maxStack=1,  weight=3.0, damage=12 })
--   Inventory.register("potion", { name="Health Potion", icon="potion", maxStack=10, weight=0.5 })
--
--   -- Create an inventory
--   local inv = Inventory.new({ cols=5, rows=4 })
--
--   -- Add items
--   Inventory.add(inv, "potion", 3)
--   Inventory.add(inv, "sword",  1)
--
--   -- Query
--   Inventory.count(inv, "sword")
--   Inventory.has(inv, "potion", 2)
--
--   -- Remove
--   Inventory.remove(inv, "potion", 1)
--
--   -- Move slot to slot (within same or different inventory)
--   Inventory.move(inv, slotIdx, inv, targetIdx)
--
--   -- Equip slots
--   local eq = Inventory.newEquipment({ "head","chest","legs","mainhand","offhand" })
--   Inventory.equip(inv, slotIdx, eq, "mainhand")
--   Inventory.unequip(eq, "mainhand", inv)

local Inventory = {}

-- -------------------------
-- Item registry (global, shared across all inventories)
-- -------------------------
local registry = {}

function Inventory.register(id, data)
    assert(type(id)   == "string", "item id must be a string")
    assert(type(data) == "table",  "item data must be a table")
    data.id       = id
    data.maxStack = data.maxStack or 1
    registry[id]  = data
end

function Inventory.getItem(id)
    return registry[id]
end

-- -------------------------
-- Slot structure
-- { id=itemId, count=n }  or  nil (empty)
-- -------------------------

-- -------------------------
-- Create inventory
-- config:
--   cols, rows : grid size
--   maxWeight  : optional weight limit (nil = unlimited)
-- -------------------------
function Inventory.new(config)
    config    = config or {}
    local cols = config.cols or 5
    local rows = config.rows or 4
    local slots = {}
    for i = 1, cols * rows do slots[i] = nil end
    return {
        cols      = cols,
        rows      = rows,
        size      = cols * rows,
        slots     = slots,
        maxWeight = config.maxWeight,
        -- callbacks
        onChange  = nil,   -- function(inv, slotIdx, oldSlot, newSlot)
    }
end

-- -------------------------
-- Internal helpers
-- -------------------------
local function notify(inv, idx, old, new)
    if inv.onChange then inv.onChange(inv, idx, old, new) end
end

local function totalWeight(inv)
    local w = 0
    for i = 1, inv.size do
        local slot = inv.slots[i]
        if slot then
            local item = registry[slot.id]
            if item and item.weight then
                w = w + item.weight * slot.count
            end
        end
    end
    return w
end

local function firstSlotWith(inv, id)
    for i = 1, inv.size do
        local slot = inv.slots[i]
        if slot and slot.id == id then return i, slot end
    end
    return nil
end

local function firstEmptySlot(inv)
    for i = 1, inv.size do
        if inv.slots[i] == nil then return i end
    end
    return nil
end

-- -------------------------
-- Add items to inventory
-- Returns: remainder that didn't fit (0 = all added)
-- -------------------------
function Inventory.add(inv, id, count)
    count = count or 1
    local item = registry[id]
    assert(item, "unknown item id: " .. tostring(id))

    -- Weight check
    if inv.maxWeight then
        local addW = (item.weight or 0) * count
        if totalWeight(inv) + addW > inv.maxWeight then
            return count  -- none added
        end
    end

    local remaining = count

    -- Try to stack onto existing slots first
    if item.maxStack > 1 then
        for i = 1, inv.size do
            local slot = inv.slots[i]
            if slot and slot.id == id then
                local space = item.maxStack - slot.count
                if space > 0 then
                    local add   = math.min(space, remaining)
                    local old   = { id=slot.id, count=slot.count }
                    slot.count  = slot.count + add
                    remaining   = remaining - add
                    notify(inv, i, old, slot)
                    if remaining == 0 then return 0 end
                end
            end
        end
    end

    -- Fill empty slots
    while remaining > 0 do
        local idx = firstEmptySlot(inv)
        if not idx then return remaining end  -- inventory full
        local add        = math.min(item.maxStack, remaining)
        inv.slots[idx]   = { id=id, count=add }
        remaining        = remaining - add
        notify(inv, idx, nil, inv.slots[idx])
    end

    return 0
end

-- -------------------------
-- Remove items from inventory
-- Returns: actually removed count
-- -------------------------
function Inventory.remove(inv, id, count)
    count   = count or 1
    local removed = 0

    for i = inv.size, 1, -1 do
        local slot = inv.slots[i]
        if slot and slot.id == id then
            local take  = math.min(slot.count, count - removed)
            local old   = { id=slot.id, count=slot.count }
            slot.count  = slot.count - take
            removed     = removed + take
            if slot.count == 0 then
                inv.slots[i] = nil
                notify(inv, i, old, nil)
            else
                notify(inv, i, old, slot)
            end
            if removed >= count then break end
        end
    end

    return removed
end

-- -------------------------
-- Count total of an item across all slots
-- -------------------------
function Inventory.count(inv, id)
    local total = 0
    for i = 1, inv.size do
        local slot = inv.slots[i]
        if slot and slot.id == id then
            total = total + slot.count
        end
    end
    return total
end

-- -------------------------
-- Check if inventory has at least `count` of item
-- -------------------------
function Inventory.has(inv, id, count)
    return Inventory.count(inv, id) >= (count or 1)
end

-- -------------------------
-- Move slot srcIdx in srcInv to dstIdx in dstInv
-- Handles swapping, stacking, partial moves
-- -------------------------
function Inventory.move(srcInv, srcIdx, dstInv, dstIdx)
    local src = srcInv.slots[srcIdx]
    local dst = dstInv.slots[dstIdx]

    if not src then return false end

    -- Same slot — no-op
    if srcInv == dstInv and srcIdx == dstIdx then return true end

    -- Stack onto same item type
    if dst and dst.id == src.id then
        local item  = registry[src.id]
        local space = item.maxStack - dst.count
        if space > 0 then
            local move     = math.min(space, src.count)
            local oldSrc   = { id=src.id, count=src.count }
            local oldDst   = { id=dst.id, count=dst.count }
            dst.count      = dst.count + move
            src.count      = src.count - move
            if src.count == 0 then
                srcInv.slots[srcIdx] = nil
                notify(srcInv, srcIdx, oldSrc, nil)
            else
                notify(srcInv, srcIdx, oldSrc, src)
            end
            notify(dstInv, dstIdx, oldDst, dst)
            return true
        end
    end

    -- Swap
    local oldSrc = src
    local oldDst = dst
    srcInv.slots[srcIdx] = dst
    dstInv.slots[dstIdx] = src
    notify(srcInv, srcIdx, oldSrc, dst)
    notify(dstInv, dstIdx, oldDst, src)
    return true
end

-- -------------------------
-- Split a stack: take `count` from slotIdx into first empty slot
-- -------------------------
function Inventory.split(inv, slotIdx, count)
    local slot = inv.slots[slotIdx]
    if not slot or slot.count <= 1 then return false end
    count = math.min(count or math.floor(slot.count/2), slot.count-1)

    local emptyIdx = firstEmptySlot(inv)
    if not emptyIdx or emptyIdx == slotIdx then return false end

    local old         = { id=slot.id, count=slot.count }
    slot.count        = slot.count - count
    inv.slots[emptyIdx] = { id=slot.id, count=count }
    notify(inv, slotIdx, old, slot)
    notify(inv, emptyIdx, nil, inv.slots[emptyIdx])
    return true
end

-- -------------------------
-- Clear entire inventory
-- -------------------------
function Inventory.clear(inv)
    for i = 1, inv.size do
        local old = inv.slots[i]
        inv.slots[i] = nil
        if old then notify(inv, i, old, nil) end
    end
end

-- -------------------------
-- Slot index <-> grid position helpers
-- -------------------------
function Inventory.slotToGrid(inv, idx)
    local col = ((idx-1) % inv.cols) + 1
    local row = math.floor((idx-1) / inv.cols) + 1
    return col, row
end

function Inventory.gridToSlot(inv, col, row)
    if col < 1 or col > inv.cols or row < 1 or row > inv.rows then
        return nil
    end
    return (row-1) * inv.cols + col
end

-- -------------------------
-- Equipment system
-- slots: list of slot names e.g. {"head","chest","mainhand"}
-- -------------------------
function Inventory.newEquipment(slotNames)
    local eq = { slots={} }
    for _, name in ipairs(slotNames) do
        eq.slots[name] = nil
    end
    return eq
end

function Inventory.equip(inv, invSlotIdx, eq, eqSlotName)
    local slot = inv.slots[invSlotIdx]
    if not slot then return false end

    local item = registry[slot.id]
    -- Optional: check if item has an equipSlot field matching eqSlotName
    if item.equipSlot and item.equipSlot ~= eqSlotName then
        return false
    end

    -- If something already equipped, swap back to inventory
    if eq.slots[eqSlotName] then
        local remainder = Inventory.add(inv, eq.slots[eqSlotName].id, eq.slots[eqSlotName].count)
        if remainder > 0 then return false end  -- no room
    end

    eq.slots[eqSlotName] = { id=slot.id, count=slot.count }
    inv.slots[invSlotIdx] = nil
    notify(inv, invSlotIdx, slot, nil)
    return true
end

function Inventory.unequip(eq, eqSlotName, inv)
    local equipped = eq.slots[eqSlotName]
    if not equipped then return false end

    local remainder = Inventory.add(inv, equipped.id, equipped.count)
    if remainder > 0 then return false end  -- inventory full

    eq.slots[eqSlotName] = nil
    return true
end

-- -------------------------
-- Debug: print inventory contents
-- -------------------------
function Inventory.debug(inv)
    local lines = { string.format("Inventory %dx%d:", inv.cols, inv.rows) }
    for i = 1, inv.size do
        local slot = inv.slots[i]
        if slot then
            local item = registry[slot.id]
            table.insert(lines, string.format(
                "  [%d] %s x%d (%s)",
                i, slot.id, slot.count, item and item.name or "?"))
        end
    end
    return table.concat(lines, "\n")
end

return Inventory
