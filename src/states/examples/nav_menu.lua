-- src/states/examples/nav_menu.lua
-- Demonstrates: navigable menu, keyboard/mouse/gamepad, sub-menus,
--               animated selection, callbacks

local Utils  = require("src.utils")
local Timer  = require("src.systems.timer")
local Example = {}

local W, H
local timer
local currentMenu   -- stack top
local menuStack     = {}  -- push/pop for sub-menus
local selAnim       = {}  -- { x, y, w, h } lerped rect for selection highlight

-- -------------------------
-- Menu definition
-- Each item: { label, sub, action, value, min, max, step }
-- sub    ? push a sub-menu
-- action ? callback function
-- value  ? toggleable / slider
-- -------------------------
local MENUS = {}

MENUS.main = {
    title = "MAIN MENU",
    items = {
        { label="New Game",    action=function() print("New Game!") end },
        { label="Settings",    sub="settings" },
        { label="Audio",       sub="audio" },
        { label="Controls",    sub="controls" },
        { label="About",       sub="about" },
        { label="Quit",        action=function() love.event.quit() end },
    }
}

MENUS.settings = {
    title = "SETTINGS",
    items = {
        { label="Fullscreen",  toggle=true,  value=false },
        { label="VSync",       toggle=true,  value=true  },
        { label="Difficulty",  options={"Easy","Normal","Hard","Nightmare"}, optIdx=2 },
        { label="Language",    options={"English","Spanish","French","German"}, optIdx=1 },
        { label="Back",        back=true },
    }
}

MENUS.audio = {
    title = "AUDIO",
    items = {
        { label="Master Vol",  slider=true, value=80,  min=0, max=100, step=5 },
        { label="Music Vol",   slider=true, value=70,  min=0, max=100, step=5 },
        { label="SFX Vol",     slider=true, value=90,  min=0, max=100, step=5 },
        { label="Mute All",    toggle=true, value=false },
        { label="Back",        back=true },
    }
}

MENUS.controls = {
    title = "CONTROLS",
    items = {
        { label="Move",        info="WASD / Arrows / L-Stick" },
        { label="Jump",        info="Space / A button" },
        { label="Attack",      info="Z / X button" },
        { label="Pause",       info="P / Start" },
        { label="Back",        info="ESC / B button", back=true },
    }
}

MENUS.about = {
    title  = "ABOUT",
    items  = {
        { label="LÖVE2D Cookbook", info="v1.0" },
        { label="Engine",          info="LÖVE 11.x" },
        { label="Language",        info="Lua 5.4" },
        { label="Back",            back=true },
    }
}

-- -------------------------
-- Layout constants
-- -------------------------
local ITEM_H   = 48
local ITEM_W   = 320
local PANEL_PAD= 24

local function menuHeight(menu)
    return #menu.items * ITEM_H + PANEL_PAD * 2 + 40  -- +40 for title
end

local function itemY(menuY, idx)
    return menuY + PANEL_PAD + 40 + (idx-1) * ITEM_H
end

local function menuStartY(menu)
    return (H - menuHeight(menu)) / 2
end

-- -------------------------
-- Push a menu onto the stack
-- -------------------------
local function pushMenu(key, selIdx)
    local menu = MENUS[key]
    assert(menu, "unknown menu: " .. key)
    local state = {
        key    = key,
        menu   = menu,
        sel    = selIdx or 1,
        enterT = 0,    -- entry animation timer
    }
    table.insert(menuStack, state)
    currentMenu = state

    -- Animate selection rect to first item
    local mx    = W/2 - ITEM_W/2
    local my    = menuStartY(menu)
    selAnim.x   = mx
    selAnim.y   = itemY(my, state.sel) - 4
    selAnim.w   = ITEM_W
    selAnim.h   = ITEM_H

    Timer.after(timer, 0.01, function()
        state.enterT = 1
    end)
end

local function popMenu()
    table.remove(menuStack)
    currentMenu = menuStack[#menuStack]
end

-- -------------------------
-- Selection helpers
-- -------------------------
local function selectItem(dir)
    if not currentMenu then return end
    local n = #currentMenu.menu.items
    currentMenu.sel = ((currentMenu.sel - 1 + dir) % n) + 1
end

local function activateItem(item)
    if not item then return end
    if item.back then
        popMenu()
    elseif item.sub then
        pushMenu(item.sub)
    elseif item.action then
        item.action()
    elseif item.toggle then
        item.value = not item.value
    elseif item.options then
        item.optIdx = (item.optIdx % #item.options) + 1
        item.value  = item.options[item.optIdx]
    end
end

local function adjustSlider(item, dir)
    if not item or not item.slider then return end
    item.value = Utils.clamp(item.value + dir * item.step, item.min, item.max)
end

-- -------------------------
-- State
-- -------------------------
function Example.enter()
    W = love.graphics.getWidth()
    H = love.graphics.getHeight()
    timer     = Timer.new()
    menuStack = {}
    pushMenu("main")
end

function Example.exit()
    Timer.clear(timer)
end

function Example.update(dt)
    Timer.update(timer, dt)
    if not currentMenu then return end

    local menu = currentMenu.menu
    local mx   = W/2 - ITEM_W/2
    local my   = menuStartY(menu)

    -- Lerp selection rect
    local targetY = itemY(my, currentMenu.sel) - 4
    selAnim.x = Utils.lerp(selAnim.x, mx,      16*dt)
    selAnim.y = Utils.lerp(selAnim.y, targetY, 16*dt)
    selAnim.w = Utils.lerp(selAnim.w, ITEM_W,  16*dt)
    selAnim.h = Utils.lerp(selAnim.h, ITEM_H,  16*dt)
end

function Example.draw()
    -- Background
    love.graphics.setColor(0.08, 0.10, 0.15)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Subtle grid
    love.graphics.setColor(0.11, 0.13, 0.18)
    for x = 0, W, 40 do love.graphics.line(x, 0, x, H) end
    for y = 0, H, 40 do love.graphics.line(0, y, W, y) end

    if not currentMenu then return end

    local menu  = currentMenu.menu
    local mx    = W/2 - ITEM_W/2
    local my    = menuStartY(menu)
    local mh    = menuHeight(menu)

    -- Panel shadow
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", mx+6, my+6, ITEM_W, mh, 8,8)

    -- Panel bg
    love.graphics.setColor(0.12, 0.15, 0.22)
    love.graphics.rectangle("fill", mx, my, ITEM_W, mh, 8, 8)
    love.graphics.setColor(0.25, 0.35, 0.55)
    love.graphics.rectangle("line", mx, my, ITEM_W, mh, 8, 8)

    -- Title
    love.graphics.setColor(0.5, 0.7, 1.0)
    love.graphics.printf(menu.title, mx, my + PANEL_PAD, ITEM_W, "center")

    -- Selection highlight (animated)
    love.graphics.setColor(0.2, 0.35, 0.6, 0.85)
    love.graphics.rectangle("fill", selAnim.x, selAnim.y, selAnim.w, selAnim.h, 5,5)
    love.graphics.setColor(0.4, 0.6, 1.0, 0.5)
    love.graphics.rectangle("line", selAnim.x, selAnim.y, selAnim.w, selAnim.h, 5,5)

    -- Items
    for i, item in ipairs(menu.items) do
        local iy  = itemY(my, i)
        local sel = (i == currentMenu.sel)
        local cx  = mx + ITEM_W/2

        -- Label
        love.graphics.setColor(sel and 1 or 0.7, sel and 1 or 0.7, sel and 1 or 0.7)
        love.graphics.printf(item.label, mx + 16, iy + 12, ITEM_W/2, "left")

        -- Right side value / info
        if item.toggle then
            love.graphics.setColor(item.value and 0.3 or 0.5,
                                   item.value and 0.9 or 0.4,
                                   item.value and 0.4 or 0.4)
            love.graphics.printf(item.value and "ON" or "OFF",
                mx, iy+12, ITEM_W-16, "right")

        elseif item.slider then
            -- Track
            local tw = 120
            local tx = mx + ITEM_W - 16 - tw
            local ty = iy + ITEM_H/2 - 3
            love.graphics.setColor(0.2, 0.2, 0.3)
            love.graphics.rectangle("fill", tx, ty, tw, 6, 3,3)
            love.graphics.setColor(0.3, 0.6, 1.0)
            local fill = ((item.value - item.min) / (item.max - item.min)) * tw
            love.graphics.rectangle("fill", tx, ty, fill, 6, 3,3)
            -- Value label
            love.graphics.setColor(0.7, 0.7, 0.8)
            love.graphics.printf(tostring(item.value), mx, iy+12, ITEM_W-16, "right")

        elseif item.options then
            love.graphics.setColor(0.4, 0.8, 0.6)
            love.graphics.printf(
                "? " .. item.options[item.optIdx] .. " ?",
                mx, iy+12, ITEM_W-16, "right")

        elseif item.info then
            love.graphics.setColor(0.45, 0.55, 0.7)
            love.graphics.printf(item.info, mx, iy+12, ITEM_W-16, "right")

        elseif item.sub then
            love.graphics.setColor(0.4, 0.5, 0.7)
            love.graphics.printf("?", mx, iy+12, ITEM_W-16, "right")

        elseif item.back then
            love.graphics.setColor(0.4, 0.4, 0.5)
            love.graphics.printf("?", mx, iy+12, ITEM_W-16, "right")
        end
    end

    -- Stack breadcrumb
    if #menuStack > 1 then
        local crumb = ""
        for _, s in ipairs(menuStack) do
            crumb = crumb .. (crumb=="" and "" or "  ?  ") .. s.menu.title
        end
        love.graphics.setColor(0.35, 0.45, 0.6)
        love.graphics.printf(crumb, 0, my - 28, W, "center")
    end

    Utils.drawHUD("NAV MENU",
        "?? navigate    ?? adjust    Enter/click confirm    ESC back    P pause")
end

function Example.keypressed(key)
    if not currentMenu then return end
    local item = currentMenu.menu.items[currentMenu.sel]

    if key == "up"   or key == "w" then selectItem(-1)
    elseif key == "down" or key == "s" then selectItem(1)
    elseif key == "left"  or key == "a" then adjustSlider(item, -1)
    elseif key == "right" or key == "d" then adjustSlider(item,  1)
    elseif key == "return" or key == "space" then activateItem(item)
    elseif key == "escape" then
        if #menuStack > 1 then popMenu()
        else Utils.handlePause(key, Example) end
    end

    Utils.handlePause(key, Example)
end

function Example.mousepressed(x, y, button)
    if not currentMenu or button ~= 1 then return end
    local menu = currentMenu.menu
    local mx2  = W/2 - ITEM_W/2
    local my2  = menuStartY(menu)

    for i, item in ipairs(menu.items) do
        local iy = itemY(my2, i)
        if x >= mx2 and x <= mx2+ITEM_W
        and y >= iy  and y <= iy+ITEM_H then
            currentMenu.sel = i
            activateItem(item)
            return
        end
    end
end

function Example.touchpressed(id, x, y)
    Example.mousepressed(x, y, 1)
end

function Example.gamepadpressed(joystick, btn)
    if not currentMenu then return end
    local item = currentMenu.menu.items[currentMenu.sel]
    if btn == "dpup"   then selectItem(-1)
    elseif btn == "dpdown"  then selectItem(1)
    elseif btn == "dpleft"  then adjustSlider(item, -1)
    elseif btn == "dpright" then adjustSlider(item,  1)
    elseif btn == "a" then activateItem(item)
    elseif btn == "b" then
        if #menuStack > 1 then popMenu() end
    end
end

return Example
