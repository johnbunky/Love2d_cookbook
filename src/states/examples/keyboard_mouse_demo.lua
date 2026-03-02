-- src/states/examples/keyboard_mouse_demo.lua
-- Demonstrates: key events, held keys, mouse position, buttons, wheel, cursor

local Utils   = require("src.utils")
local Timer   = require("src.systems.timer")
local Example = {}

local W, H
local timer
local time = 0

-- -------------------------
-- State
-- -------------------------
local mouseX, mouseY   = 0, 0
local mouseButtons     = { false, false, false }
local wheelDelta       = 0
local wheelAccum       = 0
local recentKeys       = {}   -- { key, time }
local recentMouse      = {}   -- { x, y, time }
local MAX_TRAIL        = 40

local heldKeys         = {}   -- key -> true while held
local modifiers        = { ctrl=false, shift=false, alt=false }

-- Drawable character (moves with keys)
local cursor = { x=0, y=0, angle=0 }

-- Click ripples
local ripples = {}

local function addKey(key)
    table.insert(recentKeys, 1, { key=key, t=time })
    if #recentKeys > 12 then table.remove(recentKeys) end
end

local function addMouseTrail(x, y)
    table.insert(recentMouse, 1, { x=x, y=y, t=time })
    if #recentMouse > MAX_TRAIL then table.remove(recentMouse) end
end

-- -------------------------
-- Key display groups
-- -------------------------
local keyGroups = {
    {
        label = "Movement",
        keys  = { "w","a","s","d","up","down","left","right" },
        layout = {
            { key="w",     gx=1, gy=0 },
            { key="a",     gx=0, gy=1 },
            { key="s",     gx=1, gy=1 },
            { key="d",     gx=2, gy=1 },
            { key="up",    gx=4, gy=0 },
            { key="left",  gx=3, gy=1 },
            { key="down",  gx=4, gy=1 },
            { key="right", gx=5, gy=1 },
        },
    },
    {
        label = "Modifiers",
        keys  = { "lshift","rshift","lctrl","rctrl","lalt","ralt","space","tab" },
        layout = {
            { key="lshift", gx=0, gy=0, w=1.5 },
            { key="lctrl",  gx=0, gy=1 },
            { key="lalt",   gx=1, gy=1 },
            { key="space",  gx=2, gy=1, w=2 },
            { key="ralt",   gx=4, gy=1 },
            { key="rctrl",  gx=5, gy=1 },
            { key="rshift", gx=4, gy=0, w=1.5 },
            { key="tab",    gx=0, gy=0 },
        },
    },
}

-- -------------------------
-- Enter / Exit
-- -------------------------
function Example.enter()
    W      = love.graphics.getWidth()
    H      = love.graphics.getHeight()
    timer  = Timer.new()
    time   = 0
    cursor = { x=W/2, y=H/2, angle=0 }
    recentKeys  = {}
    recentMouse = {}
    ripples     = {}
    heldKeys    = {}
    wheelAccum  = 0
end

function Example.exit()
    Timer.clear(timer)
end

-- -------------------------
-- Update
-- -------------------------
function Example.update(dt)
    Timer.update(timer, dt)
    time = time + dt

    mouseX, mouseY = love.mouse.getPosition()
    addMouseTrail(mouseX, mouseY)

    -- Decay wheel
    wheelDelta = wheelDelta * 0.85

    -- Update modifiers
    modifiers.ctrl  = love.keyboard.isDown("lctrl","rctrl")
    modifiers.shift = love.keyboard.isDown("lshift","rshift")
    modifiers.alt   = love.keyboard.isDown("lalt","ralt")

    -- Move cursor with WASD / arrows
    local speed = 200
    local dx, dy = 0, 0
    if love.keyboard.isDown("w","up")    then dy = dy - 1 end
    if love.keyboard.isDown("s","down")  then dy = dy + 1 end
    if love.keyboard.isDown("a","left")  then dx = dx - 1 end
    if love.keyboard.isDown("d","right") then dx = dx + 1 end
    if dx ~= 0 or dy ~= 0 then
        local len = math.sqrt(dx*dx+dy*dy)
        cursor.x = Utils.clamp(cursor.x + dx/len*speed*dt, 20, W-20)
        cursor.y = Utils.clamp(cursor.y + dy/len*speed*dt, 20, H-20)
        cursor.angle = math.atan2(dy, dx)
    end

    -- Update ripples
    for i = #ripples, 1, -1 do
        local r = ripples[i]
        r.life = r.life - dt
        r.radius = r.radius + 80*dt
        if r.life <= 0 then table.remove(ripples, i) end
    end
end

-- -------------------------
-- Draw
-- -------------------------
local function drawKeyboard(ox, oy)
    local KW, KH = 36, 36
    local GAP    = 4

    local function drawKey(label, gx, gy, w, active)
        w = w or 1
        local kw  = KW*w + GAP*(w-1)
        local x   = ox + gx * (KW+GAP)
        local y   = oy + gy * (KH+GAP)
        local col = active and {0.3,0.65,1.0} or {0.18,0.22,0.32}
        love.graphics.setColor(col)
        love.graphics.rectangle("fill", x, y, kw, KH, 5,5)
        if active then
            love.graphics.setColor(0.5,0.8,1.0)
        else
            love.graphics.setColor(0.35,0.45,0.60)
        end
        love.graphics.rectangle("line", x, y, kw, KH, 5,5)
        love.graphics.setColor(active and 1 or 0.6, active and 1 or 0.6, active and 1 or 0.75)
        -- Shorten label for display
        local lbl = label
        if label == "up"    then lbl="?" end
        if label == "down"  then lbl="?" end
        if label == "left"  then lbl="?" end
        if label == "right" then lbl="?" end
        if label == "lshift" or label == "rshift" then lbl="SHFT" end
        if label == "lctrl"  or label == "rctrl"  then lbl="CTRL" end
        if label == "lalt"   or label == "ralt"   then lbl="ALT" end
        if label == "space" then lbl="SPACE" end
        love.graphics.printf(lbl:upper(), x+2, y+10, kw-4, "center")
    end

    -- WASD cluster
    drawKey("w",     1, 0, 1, love.keyboard.isDown("w"))
    drawKey("a",     0, 1, 1, love.keyboard.isDown("a"))
    drawKey("s",     1, 1, 1, love.keyboard.isDown("s"))
    drawKey("d",     2, 1, 1, love.keyboard.isDown("d"))

    -- Arrow cluster
    local ax = 4
    drawKey("up",    ax,   0, 1, love.keyboard.isDown("up"))
    drawKey("left",  ax-1, 1, 1, love.keyboard.isDown("left"))
    drawKey("down",  ax,   1, 1, love.keyboard.isDown("down"))
    drawKey("right", ax+1, 1, 1, love.keyboard.isDown("right"))

    -- Modifiers row
    local my = 3
    drawKey("lshift", 0,  my,   2, love.keyboard.isDown("lshift"))
    drawKey("lctrl",  0,  my+1, 1, love.keyboard.isDown("lctrl"))
    drawKey("lalt",   1,  my+1, 1, love.keyboard.isDown("lalt"))
    drawKey("space",  2,  my+1, 3, love.keyboard.isDown("space"))
    drawKey("ralt",   5,  my+1, 1, love.keyboard.isDown("ralt"))
    drawKey("rctrl",  6,  my+1, 1, love.keyboard.isDown("rctrl"))
    drawKey("rshift", 5,  my,   2, love.keyboard.isDown("rshift"))
end

local function drawMouse(ox, oy)
    local MW, MH = 70, 100
    -- Body
    love.graphics.setColor(0.18, 0.22, 0.32)
    love.graphics.rectangle("fill", ox, oy, MW, MH, MW/2, MW/2)
    love.graphics.setColor(0.3, 0.4, 0.6)
    love.graphics.rectangle("line", ox, oy, MW, MH, MW/2, MW/2)

    -- Divider
    love.graphics.setColor(0.3, 0.4, 0.6)
    love.graphics.line(ox+MW/2, oy, ox+MW/2, oy+40)

    -- Buttons
    local cols = {
        { mouseButtons[1], 0.3,0.7,0.4 },  -- left: green
        { mouseButtons[2], 0.7,0.3,0.3 },  -- right: red
    }
    for i, btn in ipairs(cols) do
        if btn[1] then
            love.graphics.setColor(btn[2], btn[3], btn[4], 0.8)
            if i == 1 then
                love.graphics.rectangle("fill", ox, oy, MW/2, 40, MW/2, MW/2, 0, 0)
            else
                love.graphics.rectangle("fill", ox+MW/2, oy, MW/2, 40, 0, MW/2, 0, 0)
            end
        end
    end

    -- Scroll wheel
    local wheelY = oy + 50
    love.graphics.setColor(0.25, 0.32, 0.48)
    love.graphics.rectangle("fill", ox+MW/2-8, wheelY-12, 16, 24, 4,4)
    -- Wheel indicator
    local wy = Utils.clamp(wheelAccum*3, -8, 8)
    love.graphics.setColor(0.5, 0.7, 1.0)
    love.graphics.rectangle("fill", ox+MW/2-5, wheelY+wy-4, 10, 8, 2,2)

    -- Middle button
    if mouseButtons[3] then
        love.graphics.setColor(0.8, 0.8, 0.2, 0.8)
        love.graphics.rectangle("fill", ox+MW/2-8, wheelY-12, 16, 24, 4,4)
    end

    -- Labels
    love.graphics.setColor(0.5, 0.65, 0.9)
    love.graphics.printf("L", ox, oy+14, MW/2, "center")
    love.graphics.printf("R", ox+MW/2, oy+14, MW/2, "center")
end

function Example.draw()
    love.graphics.setColor(0.06, 0.08, 0.14)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Mouse trail
    for i, pt in ipairs(recentMouse) do
        local age   = time - pt.t
        local alpha = math.max(0, 0.6 - i/MAX_TRAIL)
        local r     = math.max(1, 6 - i*0.12)
        love.graphics.setColor(0.3, 0.6, 1.0, alpha)
        love.graphics.circle("fill", pt.x, pt.y, r)
    end

    -- Click ripples
    for _, rip in ipairs(ripples) do
        local alpha = rip.life * 0.8
        love.graphics.setColor(rip.r, rip.g, rip.b, alpha)
        love.graphics.circle("line", rip.x, rip.y, rip.radius)
    end

    -- Cursor (arrow shape)
    love.graphics.push()
    love.graphics.translate(cursor.x, cursor.y)
    love.graphics.rotate(cursor.angle)
    love.graphics.setColor(0.3, 0.85, 0.5)
    love.graphics.polygon("fill", 18,0, -10,10, -6,0, -10,-10)
    love.graphics.setColor(0.5,1.0,0.7)
    love.graphics.polygon("line", 18,0, -10,10, -6,0, -10,-10)
    love.graphics.pop()

    -- Real mouse cursor dot
    love.graphics.setColor(1, 0.4, 0.4)
    love.graphics.circle("fill", mouseX, mouseY, 5)
    love.graphics.setColor(1, 0.6, 0.6, 0.5)
    love.graphics.circle("line", mouseX, mouseY, 10)

    -- ---- Panels ----

    -- Keyboard panel (bottom left)
    local kbX, kbY = 20, H - 200
    love.graphics.setColor(0.06, 0.09, 0.18, 0.92)
    love.graphics.rectangle("fill", kbX-8, kbY-28, 320, 185, 6,6)
    love.graphics.setColor(0.3, 0.45, 0.75)
    love.graphics.rectangle("line", kbX-8, kbY-28, 320, 185, 6,6)
    love.graphics.setColor(0.5, 0.7, 1.0)
    love.graphics.print("Keyboard", kbX, kbY-22)
    drawKeyboard(kbX, kbY)

    -- Mouse panel (bottom right)
    local msX = W - 200
    local msY = H - 200
    love.graphics.setColor(0.06, 0.09, 0.18, 0.92)
    love.graphics.rectangle("fill", msX-12, msY-28, 200, 185, 6,6)
    love.graphics.setColor(0.3, 0.45, 0.75)
    love.graphics.rectangle("line", msX-12, msY-28, 200, 185, 6,6)
    love.graphics.setColor(0.5, 0.7, 1.0)
    love.graphics.print("Mouse", msX, msY-22)
    drawMouse(msX+20, msY)

    -- Mouse info
    love.graphics.setColor(0.6, 0.75, 0.95)
    love.graphics.print(string.format("X: %d  Y: %d", mouseX, mouseY), msX, msY+108)
    love.graphics.print(string.format("Wheel: %+.1f", wheelAccum), msX, msY+124)
    love.graphics.print(string.format("Btn: %s %s %s",
        mouseButtons[1] and "L" or ".",
        mouseButtons[2] and "R" or ".",
        mouseButtons[3] and "M" or "."), msX, msY+140)

    -- Modifiers display
    love.graphics.setColor(modifiers.shift and 0.3 or 0.15,
                           modifiers.shift and 0.8 or 0.35,
                           modifiers.shift and 0.4 or 0.2)
    love.graphics.rectangle("fill", msX, msY+156, 44, 18, 3,3)
    love.graphics.setColor(1,1,1, modifiers.shift and 1 or 0.4)
    love.graphics.printf("SHIFT", msX, msY+158, 44, "center")

    love.graphics.setColor(modifiers.ctrl and 0.3 or 0.15,
                           modifiers.ctrl and 0.5 or 0.25,
                           modifiers.ctrl and 0.9 or 0.4)
    love.graphics.rectangle("fill", msX+50, msY+156, 44, 18, 3,3)
    love.graphics.setColor(1,1,1, modifiers.ctrl and 1 or 0.4)
    love.graphics.printf("CTRL", msX+50, msY+158, 44, "center")

    love.graphics.setColor(modifiers.alt and 0.6 or 0.2,
                           modifiers.alt and 0.3 or 0.15,
                           modifiers.alt and 0.8 or 0.35)
    love.graphics.rectangle("fill", msX+100, msY+156, 44, 18, 3,3)
    love.graphics.setColor(1,1,1, modifiers.alt and 1 or 0.4)
    love.graphics.printf("ALT", msX+100, msY+158, 44, "center")

    -- Key event log
    local logX, logY = 20, 20
    love.graphics.setColor(0.06, 0.09, 0.18, 0.92)
    love.graphics.rectangle("fill", logX-4, logY-4, 240, 180, 6,6)
    love.graphics.setColor(0.3, 0.45, 0.75)
    love.graphics.rectangle("line", logX-4, logY-4, 240, 180, 6,6)
    love.graphics.setColor(0.5, 0.7, 1.0)
    love.graphics.print("Key events:", logX, logY)
    for i, ev in ipairs(recentKeys) do
        local age   = time - ev.t
        local alpha = math.max(0, 1 - age*0.4)
        love.graphics.setColor(0.7, 0.85, 1.0, alpha)
        love.graphics.print(ev.key, logX, logY + i*13)
    end

    Utils.drawHUD("KEYBOARD & MOUSE",
        "WASD / arrows move cursor    click ripple    scroll wheel    ESC back")
end

function Example.keypressed(key)
    heldKeys[key] = true
    addKey("? "..key)
    Utils.handlePause(key, Example)
end

function Example.keyreleased(key)
    heldKeys[key] = nil
    addKey("? "..key)
end

function Example.mousemoved(x, y, dx, dy)
    -- trail added in update
end

function Example.mousepressed(x, y, button)
    mouseButtons[button] = true
    addKey("mouse "..button.." ?")
    local cols = { {0.3,0.9,0.5}, {0.9,0.4,0.3}, {0.9,0.8,0.2} }
    local c    = cols[button] or {1,1,1}
    table.insert(ripples, {
        x=x, y=y, radius=5, life=1.0,
        r=c[1], g=c[2], b=c[3]
    })
end

function Example.mousereleased(x, y, button)
    mouseButtons[button] = false
    addKey("mouse "..button.." ?")
end

function Example.wheelmoved(x, y)
    wheelDelta = y
    wheelAccum = Utils.clamp(wheelAccum + y, -5, 5)
    addKey("wheel ".. (y>0 and "?" or "?") ..string.format("%+d",y))
end

return Example
