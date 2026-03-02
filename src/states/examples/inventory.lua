-- src/states/examples/inventory.lua
-- Demonstrates: grid inventory, drag & drop, stacking, equipment, tooltips

local Utils     = require("src.utils")
local Inventory = require("src.systems.inventory")
local Example   = {}

local W, H

-- -------------------------
-- Register item types
-- icon  : short label (ASCII, works with default font)
-- color : {r,g,b} for slot tint
-- -------------------------
Inventory.register("sword",  { name="Iron Sword",    desc="A trusty blade.",       label="SWD", color={0.7,0.8,1.0}, maxStack=1,  weight=3.0, equipSlot="mainhand", damage=12 })
Inventory.register("shield", { name="Wooden Shield", desc="Basic protection.",     label="SHD", color={0.6,0.9,0.6}, maxStack=1,  weight=4.0, equipSlot="offhand",  defense=5 })
Inventory.register("helmet", { name="Leather Helm",  desc="Fits most heads.",      label="HLM", color={0.9,0.7,0.4}, maxStack=1,  weight=1.5, equipSlot="head",     defense=2 })
Inventory.register("potion", { name="Health Potion", desc="Restores 30 HP.",       label="POT", color={0.9,0.3,0.4}, maxStack=10, weight=0.3 })
Inventory.register("gold",   { name="Gold Coin",     desc="Shiny and valuable.",   label="GLD", color={1.0,0.85,0.2}, maxStack=999,weight=0.01 })
Inventory.register("arrow",  { name="Arrow",         desc="Ammunition for bows.",  label="ARW", color={0.7,0.6,0.5}, maxStack=50, weight=0.1 })
Inventory.register("bread",  { name="Bread",         desc="Restores 5 HP.",        label="BRD", color={0.9,0.75,0.5}, maxStack=5,  weight=0.2 })
Inventory.register("gem",    { name="Ruby Gem",      desc="Worth a fortune.",      label="GEM", color={1.0,0.3,0.5}, maxStack=5,  weight=0.1 })

-- -------------------------
-- Layout constants
-- -------------------------
local SLOT_SIZE = 52
local SLOT_PAD  = 4
local INV_COLS  = 5
local INV_ROWS  = 4
local HEADER_H  = 50

local function panelW(cols) return cols*(SLOT_SIZE+SLOT_PAD)+SLOT_PAD end
local function panelH(rows) return rows*(SLOT_SIZE+SLOT_PAD)+SLOT_PAD+HEADER_H end

-- Panels and inventories (set in enter)
local invPanel, chestPanel, eqPanel
local inv, chest, eq

-- Action log for debugging
local actionLog = {}
local function logAction(msg)
    table.insert(actionLog, 1, msg)
    if #actionLog > 5 then table.remove(actionLog) end
end

-- Tooltip
local tooltip = { visible=false, text="", x=0, y=0 }

-- -------------------------
-- Slot rect in screen space
-- -------------------------
local function slotRect(panel, idx)
    local col, row = Inventory.slotToGrid(panel.inv, idx)
    return {
        x = panel.x + SLOT_PAD + (col-1)*(SLOT_SIZE+SLOT_PAD),
        y = panel.y + HEADER_H  + SLOT_PAD + (row-1)*(SLOT_SIZE+SLOT_PAD),
        w = SLOT_SIZE, h = SLOT_SIZE,
    }
end

-- -------------------------
-- Hit tests
-- -------------------------
local function hitTestPanel(panel, x, y)
    for i = 1, panel.inv.size do
        local r = slotRect(panel, i)
        if x>=r.x and x<=r.x+r.w and y>=r.y and y<=r.y+r.h then
            return panel.inv, i
        end
    end
    return nil, nil
end

local function hitTestEquip(x, y)
    for name, r in pairs(eqPanel.slots) do
        if x>=r.x and x<=r.x+r.w and y>=r.y and y<=r.y+r.h then
            return name
        end
    end
    return nil
end

-- -------------------------
-- Draw one slot with item
-- -------------------------
local function drawSlot(r, slot, isGhost)
    -- Slot background
    love.graphics.setColor(0.08, 0.10, 0.16)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 4,4)
    love.graphics.setColor(0.20, 0.25, 0.38)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 4,4)

    if not slot or isGhost then return end

    local item = Inventory.getItem(slot.id)
    local c    = item.color or {0.7,0.7,0.7}

    -- Colored fill
    love.graphics.setColor(c[1]*0.3, c[2]*0.3, c[3]*0.3)
    love.graphics.rectangle("fill", r.x+2, r.y+2, r.w-4, r.h-4, 3,3)

    -- Label
    love.graphics.setColor(c[1], c[2], c[3])
    love.graphics.printf(item.label or "?", r.x, r.y + r.h/2 - 7, r.w, "center")

    -- Stack count
    if slot.count > 1 then
        love.graphics.setColor(1, 0.95, 0.4)
        love.graphics.printf(tostring(slot.count), r.x+2, r.y+r.h-16, r.w-4, "right")
    end
end

-- -------------------------
-- Draw inventory panel
-- -------------------------
local function drawPanel(panel)
    -- Panel bg
    love.graphics.setColor(0.12, 0.15, 0.22)
    love.graphics.rectangle("fill", panel.x, panel.y, panel.w, panel.h, 6,6)
    love.graphics.setColor(0.25, 0.35, 0.55)
    love.graphics.rectangle("line", panel.x, panel.y, panel.w, panel.h, 6,6)

    -- Title
    love.graphics.setColor(0.5, 0.7, 1.0)
    love.graphics.printf(panel.title, panel.x, panel.y+8, panel.w, "center")

    -- Weight
    if panel.inv.maxWeight then
        local w = 0
        for i = 1, panel.inv.size do
            local s = panel.inv.slots[i]
            if s then
                local item = Inventory.getItem(s.id)
                w = w + (item.weight or 0) * s.count
            end
        end
        love.graphics.setColor(0.45, 0.55, 0.65)
        love.graphics.printf(
            string.format("%.1f / %.0f kg", w, panel.inv.maxWeight),
            panel.x, panel.y + HEADER_H - 18, panel.w, "center")
    end

    -- Slots
    for i = 1, panel.inv.size do
        local r     = slotRect(panel, i)
        local slot  = panel.inv.slots[i]
        local ghost = drag.active and drag.srcInv==panel.inv and drag.srcIdx==i
        drawSlot(r, slot, ghost)
    end
end

-- -------------------------
-- Draw equipment panel
-- -------------------------
local function drawEquipPanel()
    love.graphics.setColor(0.12, 0.15, 0.22)
    love.graphics.rectangle("fill", eqPanel.x, eqPanel.y, eqPanel.w, eqPanel.h, 6,6)
    love.graphics.setColor(0.25, 0.35, 0.55)
    love.graphics.rectangle("line", eqPanel.x, eqPanel.y, eqPanel.w, eqPanel.h, 6,6)
    love.graphics.setColor(0.5, 0.7, 1.0)
    love.graphics.printf("EQUIPPED", eqPanel.x, eqPanel.y+8, eqPanel.w, "center")

    for name, r in pairs(eqPanel.slots) do
        local equipped = eq.slots[name]
        drawSlot(r, equipped, false)
        -- slot label if empty
        if not equipped then
            love.graphics.setColor(0.3, 0.35, 0.5)
            love.graphics.printf(name, r.x, r.y + r.h/2 - 7, r.w, "center")
        end
        -- slot name above
        love.graphics.setColor(0.35, 0.45, 0.6)
        love.graphics.printf(name:upper(), r.x, r.y - 14, r.w, "center")
    end
end

-- -------------------------
-- Tooltip
-- -------------------------
local function makeTooltip(slot)
    if not slot then return "" end
    local item  = Inventory.getItem(slot.id)
    local lines = { item.name }
    if item.desc    then table.insert(lines, item.desc) end
    if item.damage  then table.insert(lines, "Damage:  "..item.damage) end
    if item.defense then table.insert(lines, "Defense: "..item.defense) end
    if item.weight  then table.insert(lines, string.format("Weight:  %.1f kg", item.weight)) end
    if slot.count > 1 then table.insert(lines, "Qty: "..slot.count) end
    return table.concat(lines, "\n")
end

local function drawTooltip()
    if not tooltip.visible or tooltip.text == "" then return end
    local lines = {}
    for line in tooltip.text:gmatch("[^\n]+") do table.insert(lines, line) end
    local tw = 170
    local th = #lines * 18 + 12
    local tx = math.min(tooltip.x + 14, W - tw - 4)
    local ty = math.min(tooltip.y + 14, H - th - 4)

    love.graphics.setColor(0.07, 0.09, 0.16, 0.97)
    love.graphics.rectangle("fill", tx, ty, tw, th, 4,4)
    love.graphics.setColor(0.3, 0.45, 0.7)
    love.graphics.rectangle("line", tx, ty, tw, th, 4,4)

    for i, line in ipairs(lines) do
        if i == 1 then love.graphics.setColor(1, 0.95, 0.6)
        else            love.graphics.setColor(0.78, 0.78, 0.85) end
        love.graphics.print(line, tx+8, ty+4+(i-1)*18)
    end
end

-- -------------------------
-- Enter
-- -------------------------
function Example.enter()
    W = love.graphics.getWidth()
    H = love.graphics.getHeight()

    inv   = Inventory.new({ cols=INV_COLS, rows=INV_ROWS, maxWeight=50 })
    chest = Inventory.new({ cols=INV_COLS, rows=2 })
    eq    = Inventory.newEquipment({"head","mainhand","offhand"})

    Inventory.add(inv, "sword",  1)
    Inventory.add(inv, "potion", 5)
    Inventory.add(inv, "gold",   42)
    Inventory.add(inv, "arrow",  24)
    Inventory.add(inv, "bread",  3)
    Inventory.add(inv, "gem",    2)

    Inventory.add(chest, "helmet", 1)
    Inventory.add(chest, "shield", 1)
    Inventory.add(chest, "potion", 3)
    Inventory.add(chest, "gold",   100)

    -- Layout: eq | inv | chest stacked
    local pw   = panelW(INV_COLS)   -- 284
    local eqW  = 140
    local gap  = 14
    local totalW = eqW + gap + pw + gap + pw
    local startX = math.floor((W - totalW) / 2)
    local topY   = math.floor(H/2 - panelH(INV_ROWS)/2)

    -- Equipment panel
    local eqX = startX
    local eqH = 220
    eqPanel = {
        x = eqX, y = topY,
        w = eqW, h = eqH,
        slots = {
            head     = { x=eqX + eqW/2-SLOT_SIZE/2,    y=topY+HEADER_H,         w=SLOT_SIZE, h=SLOT_SIZE },
            mainhand = { x=eqX + 8,                     y=topY+HEADER_H+SLOT_SIZE+10, w=SLOT_SIZE, h=SLOT_SIZE },
            offhand  = { x=eqX + eqW-8-SLOT_SIZE,       y=topY+HEADER_H+SLOT_SIZE+10, w=SLOT_SIZE, h=SLOT_SIZE },
        }
    }

    -- Inventory panel
    invPanel = {
        title = "INVENTORY",
        x = startX + eqW + gap,
        y = topY,
        w = pw,
        h = panelH(INV_ROWS),
        inv = inv,
    }

    -- Chest panel (aligned top with inventory)
    chestPanel = {
        title = "CHEST",
        x = startX + eqW + gap + pw + gap,
        y = topY,
        w = pw,
        h = panelH(2),
        inv = chest,
    }

    drag    = { active=false }
    tooltip = { visible=false, text="" }
end

function Example.exit() end
function Example.update(dt) end

function Example.draw()
    love.graphics.setColor(0.08, 0.10, 0.14)
    love.graphics.rectangle("fill", 0, 0, W, H)

    drawPanel(invPanel)
    drawPanel(chestPanel)
    drawEquipPanel()

    -- Stats panel below chest
    local sx = chestPanel.x
    local sy = chestPanel.y + chestPanel.h + 10
    local sw = chestPanel.w
    love.graphics.setColor(0.12, 0.15, 0.22)
    love.graphics.rectangle("fill", sx, sy, sw, 80, 6,6)
    love.graphics.setColor(0.25, 0.35, 0.55)
    love.graphics.rectangle("line", sx, sy, sw, 80, 6,6)

    local dmg, def = 0, 0
    local mh = eq.slots["mainhand"]
    local oh = eq.slots["offhand"]
    local hd = eq.slots["head"]
    if mh then dmg = dmg + (Inventory.getItem(mh.id).damage  or 0) end
    if oh then def = def + (Inventory.getItem(oh.id).defense or 0) end
    if hd then def = def + (Inventory.getItem(hd.id).defense or 0) end

    love.graphics.setColor(0.5, 0.7, 1.0)
    love.graphics.printf("STATS", sx, sy+6, sw, "center")
    love.graphics.setColor(0.85, 0.85, 0.85)
    love.graphics.print(string.format(
        "Attack:  %d\nDefense: %d\nGold:    %d",
        dmg, def,
        Inventory.count(inv, "gold") + Inventory.count(chest, "gold")),
        sx+14, sy+26)

    -- Dragged item floating
    if drag.active and drag.item then
        local item = Inventory.getItem(drag.item.id)
        local c    = item.color or {0.8,0.8,0.8}
        local r    = { x=drag.x-SLOT_SIZE/2, y=drag.y-SLOT_SIZE/2, w=SLOT_SIZE, h=SLOT_SIZE }
        love.graphics.setColor(c[1]*0.4, c[2]*0.4, c[3]*0.4, 0.9)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 4,4)
        love.graphics.setColor(c[1], c[2], c[3], 0.95)
        love.graphics.printf(item.label or "?", r.x, r.y+r.h/2-7, r.w, "center")
        if drag.item.count > 1 then
            love.graphics.setColor(1, 0.95, 0.4)
            love.graphics.printf(tostring(drag.item.count), r.x+2, r.y+r.h-16, r.w-4, "right")
        end
    end

    drawTooltip()

    Utils.drawHUD("INVENTORY",
        "Drag to move    RMB quick-equip    R reset    P pause    ESC back")
end

-- -------------------------
-- Input
-- -------------------------
function Example.keypressed(key)
    if key == "r" then Example.enter() end
    Utils.handlePause(key, Example)
end

function Example.mousepressed(x, y, button)
    tooltip.visible = false

    if button == 1 then
        -- Inventory / chest panels
        for _, panel in ipairs({invPanel, chestPanel}) do
            local hinv, hidx = hitTestPanel(panel, x, y)
            if hinv and hidx and hinv.slots[hidx] then
                local slot = hinv.slots[hidx]
                drag.active = true
                drag.srcInv = hinv
                drag.srcIdx = hidx
                drag.item   = { id=slot.id, count=slot.count }
                drag.x, drag.y = x, y
                return
            end
        end
        -- Equip slots — drag back to inventory
        local eqName = hitTestEquip(x, y)
        if eqName and eq.slots[eqName] then
            local slot = eq.slots[eqName]
            if Inventory.unequip(eq, eqName, inv) then
                -- find the just-unequipped item in inv
                for i = 1, inv.size do
                    local s = inv.slots[i]
                    if s and s.id == slot.id then
                        drag.active = true
                        drag.srcInv = inv
                        drag.srcIdx = i
                        drag.item   = { id=s.id, count=s.count }
                        drag.x, drag.y = x, y
                        return
                    end
                end
            end
        end

    elseif button == 2 then
        -- Quick equip
        logAction("RMB at "..x..","..y)
        for _, panel in ipairs({invPanel, chestPanel}) do
            local hinv, hidx = hitTestPanel(panel, x, y)
            logAction("  panel hit: "..tostring(hidx).." slot: "..tostring(hinv and hinv.slots[hidx] and hinv.slots[hidx].id))
            if hinv and hidx and hinv.slots[hidx] then
                local item = Inventory.getItem(hinv.slots[hidx].id)
                logAction("  equipSlot: "..tostring(item.equipSlot))
                if item.equipSlot then
                    local ok = Inventory.equip(hinv, hidx, eq, item.equipSlot)
                    logAction("  equip result: "..tostring(ok))
                end
                return
            end
        end
        -- Quick unequip
        local eqName = hitTestEquip(x, y)
        logAction("  eqSlot hit: "..tostring(eqName))
        if eqName and eq.slots[eqName] then
            Inventory.unequip(eq, eqName, inv)
        end
    end
end

function Example.mousemoved(x, y)
    drag.x, drag.y = x, y
    tooltip.visible = false
    if drag.active then return end

    for _, panel in ipairs({invPanel, chestPanel}) do
        local hinv, hidx = hitTestPanel(panel, x, y)
        if hinv and hidx and hinv.slots[hidx] then
            tooltip.visible = true
            tooltip.text    = makeTooltip(hinv.slots[hidx])
            tooltip.x, tooltip.y = x, y
            return
        end
    end
    local eqName = hitTestEquip(x, y)
    if eqName and eq.slots[eqName] then
        tooltip.visible = true
        tooltip.text    = makeTooltip(eq.slots[eqName])
        tooltip.x, tooltip.y = x, y
    end
end

function Example.mousereleased(x, y, button)
    if button ~= 1 or not drag.active then return end

    -- Drop on inventory/chest
    for _, panel in ipairs({invPanel, chestPanel}) do
        local hinv, hidx = hitTestPanel(panel, x, y)
        if hinv and hidx then
            if not (hinv == drag.srcInv and hidx == drag.srcIdx) then
                Inventory.move(drag.srcInv, drag.srcIdx, hinv, hidx)
            end
            drag.active = false
            return
        end
    end

    -- Drop on equip slot
    local eqName = hitTestEquip(x, y)
    if eqName then
        local item = Inventory.getItem(drag.item.id)
        if item.equipSlot == eqName then
            Inventory.equip(drag.srcInv, drag.srcIdx, eq, eqName)
        end
        drag.active = false
        return
    end

    drag.active = false
end

function Example.touchpressed(id, x, y)
    Example.mousepressed(x, y, 1)
end

function Example.touchreleased(id, x, y)
    Example.mousereleased(x, y, 1)
end

return Example
