-- src/states/examples/virtual_joystick.lua
-- Demonstrates: on-screen virtual joystick + buttons for touch / mouse

local Utils     = require("src.utils")
local Timer     = require("src.systems.timer")
local VJoystick = require("src.systems.vjoystick")
local Example = {}

local W, H
local timer
local time = 0

-- -------------------------
-- Virtual joystick via VJoystick system
-- -------------------------
local VJ = VJoystick.new({ radius=70, knobR=28, deadzone=0.12, floating=true })

-- Virtual buttons
local VButtons = {
    { label="A", x=0, y=0, r=30, color={0.2,0.7,0.35}, pressed=false, action="jump"   },
    { label="B", x=0, y=0, r=30, color={0.7,0.2,0.25}, pressed=false, action="attack" },
    { label="X", x=0, y=0, r=30, color={0.2,0.35,0.8}, pressed=false, action="dash"   },
    { label="Y", x=0, y=0, r=30, color={0.6,0.6,0.15}, pressed=false, action="item"   },
}

-- Demo character
local char = {
    x=0, y=0,
    vx=0, vy=0,
    r=18,
    trail={},
    action=nil, actionT=0,
}

-- -------------------------
-- Layout buttons (top right cluster)
-- -------------------------
local function layoutButtons()
    local cx = W - 120
    local cy = H - 120
    local sp = 68
    VButtons[1].x = cx      ; VButtons[1].y = cy      -- A center
    VButtons[2].x = cx + sp ; VButtons[2].y = cy      -- B right
    VButtons[3].x = cx - sp ; VButtons[3].y = cy      -- X left
    VButtons[4].x = cx      ; VButtons[4].y = cy - sp -- Y top
end

-- -------------------------
-- Enter / Exit
-- -------------------------
function Example.enter()
    W, H = love.graphics.getWidth(), love.graphics.getHeight()
    timer = Timer.new()
    time  = 0
    char.x, char.y = W/2, H/2
    char.vx, char.vy = 0, 0
    char.trail = {}

    -- Default stick position: bottom left
    VJ.defaultX = 130
    VJ.defaultY = H - 130
    VJ._bx = VJ.defaultX
    VJ._by = VJ.defaultY
    VJ._kx = VJ.defaultX
    VJ._ky = VJ.defaultY

    layoutButtons()
end

function Example.exit()
    Timer.clear(timer)
end

-- -------------------------
-- Joystick helpers
-- -------------------------
local function vjActivate(x, y, id)
    local function clampX(v) return Utils.clamp(v, VJ.radius+10, W/2 - VJ.radius) end
    local function clampY(v) return Utils.clamp(v, VJ.radius+10, H - VJ.radius - 10) end
    VJ:activate(x, y, id, function(v, axis)
        return axis == "x" and clampX(v) or clampY(v)
    end)
end

local function vjMove(x, y, id)    VJ:move(x, y, id)    end
local function vjRelease(id)       VJ:release(id)        end

local function inButton(btn, x, y)
    local dx = x - btn.x
    local dy = y - btn.y
    return math.sqrt(dx*dx+dy*dy) <= btn.r
end

local function inJoystickZone(x, y)
    return x < W/2 and y > H*0.4
end

-- -------------------------
-- Update
-- -------------------------
function Example.update(dt)
    Timer.update(timer, dt)
    time = time + dt

    -- Keyboard fallback (so it works without touch)
    local kax, kay = 0, 0
    if love.keyboard.isDown("a","left")  then kax = kax - 1 end
    if love.keyboard.isDown("d","right") then kax = kax + 1 end
    if love.keyboard.isDown("w","up")    then kay = kay - 1 end
    if love.keyboard.isDown("s","down")  then kay = kay + 1 end
    if kax ~= 0 or kay ~= 0 then
        local len = math.sqrt(kax*kax+kay*kay)
        VJ:setAxes(kax/len, kay/len)
    elseif not VJ:isActive() then
        VJ:setAxes(0, 0)
    end

    -- Move character
    local ax, ay = VJ:axes()
    local speed = 220
    char.vx = Utils.lerp(char.vx, ax * speed, 12*dt)
    char.vy = Utils.lerp(char.vy, ay * speed, 12*dt)
    char.x  = Utils.clamp(char.x + char.vx*dt, char.r, W-char.r)
    char.y  = Utils.clamp(char.y + char.vy*dt, char.r, H-char.r)

    -- Trail
    table.insert(char.trail, 1, {x=char.x, y=char.y, t=time})
    if #char.trail > 30 then table.remove(char.trail) end

    -- Action decay
    if char.action then
        char.actionT = char.actionT - dt
        if char.actionT <= 0 then char.action = nil end
    end
end

-- -------------------------
-- Draw
-- -------------------------
local vjbx, vjby, vjkx, vjky, VJactive  -- updated each draw from VJ system

local function drawJoystick()
    -- Outer ring
    love.graphics.setColor(0.15, 0.20, 0.35, 0.6)
    love.graphics.circle("fill", vjbx, vjby, VJ.radius)
    love.graphics.setColor(0.3, 0.45, 0.75, 0.8)
    love.graphics.circle("line", vjbx, vjby, VJ.radius)

    -- Deadzone ring
    love.graphics.setColor(0.25, 0.35, 0.55, 0.4)
    love.graphics.circle("line", vjbx, vjby, VJ.radius * VJ.deadzone)

    -- Cross hairs
    love.graphics.setColor(0.25, 0.35, 0.55, 0.4)
    love.graphics.line(vjbx - VJ.radius, vjby, vjbx + VJ.radius, vjby)
    love.graphics.line(vjbx, vjby - VJ.radius, vjbx, vjby + VJ.radius)

    -- Direction line
    if VJactive and (math.abs(VJ:axisX()) > VJ.deadzone or math.abs(VJ:axisY()) > VJ.deadzone) then
        love.graphics.setColor(0.4, 0.65, 1.0, 0.5)
        love.graphics.line(vjbx, vjby, vjkx, vjky)
    end

    -- Knob
    local kCol = VJactive and {0.35,0.60,1.0} or {0.25,0.38,0.65}
    love.graphics.setColor(kCol)
    love.graphics.circle("fill", vjkx, vjky, VJ.knobR)
    love.graphics.setColor(0.55, 0.75, 1.0)
    love.graphics.circle("line", vjkx, vjky, VJ.knobR)

    -- Axis readout
    love.graphics.setColor(0.5, 0.65, 0.9)
    love.graphics.printf(
        string.format("%.2f, %.2f", VJ:axisX(), VJ:axisY()),
        vjbx - VJ.radius, vjby + VJ.radius + 6,
        VJ.radius*2, "center")
end

local function drawVButtons()
    for _, btn in ipairs(VButtons) do
        -- Glow when pressed
        if btn.pressed then
            love.graphics.setColor(btn.color[1], btn.color[2], btn.color[3], 0.35)
            love.graphics.circle("fill", btn.x, btn.y, btn.r*1.5)
        end
        -- Body
        love.graphics.setColor(btn.color[1]*(btn.pressed and 1.2 or 0.7),
                               btn.color[2]*(btn.pressed and 1.2 or 0.7),
                               btn.color[3]*(btn.pressed and 1.2 or 0.7),
                               btn.pressed and 1.0 or 0.75)
        love.graphics.circle("fill", btn.x, btn.y, btn.r)
        -- Border
        love.graphics.setColor(btn.color[1]*1.5, btn.color[2]*1.5, btn.color[3]*1.5, 0.9)
        love.graphics.circle("line", btn.x, btn.y, btn.r)
        -- Label
        love.graphics.setColor(1, 1, 1, btn.pressed and 1.0 or 0.8)
        love.graphics.printf(btn.label, btn.x-btn.r, btn.y-10, btn.r*2, "center")
    end
end

function Example.draw()
    vjbx, vjby   = VJ:base()
    vjkx, vjky   = VJ:knob()
    VJactive     = VJ:isActive()

    love.graphics.setColor(0.07, 0.09, 0.15)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Grid
    love.graphics.setColor(0.10, 0.13, 0.20)
    for x = 0, W, 48 do love.graphics.line(x,0,x,H) end
    for y = 0, H, 48 do love.graphics.line(0,y,W,y) end

    -- Character trail
    for i, pt in ipairs(char.trail) do
        local a = (1 - i/#char.trail) * 0.4
        love.graphics.setColor(0.3, 0.65, 0.9, a)
        love.graphics.circle("fill", pt.x, pt.y, char.r*(1-i/#char.trail)*0.8)
    end

    -- Character
    love.graphics.setColor(0.3, 0.7, 0.9)
    love.graphics.circle("fill", char.x, char.y, char.r)
    love.graphics.setColor(0.5, 0.9, 1.0)
    love.graphics.circle("line", char.x, char.y, char.r)

    -- Action flash
    if char.action then
        local a = char.actionT * 1.5
        love.graphics.setColor(1, 0.9, 0.3, a)
        love.graphics.printf(char.action:upper().. "!",
            char.x - 60, char.y - char.r - 28, 120, "center")
    end

    -- Joystick zone hint (faint)
    love.graphics.setColor(0.15, 0.20, 0.32, 0.25)
    love.graphics.rectangle("fill", 0, H*0.4, W/2, H*0.6, 8,8)
    love.graphics.setColor(0.25, 0.35, 0.55, 0.3)
    love.graphics.printf("drag here", 10, H*0.42, W/2-20, "center")

    drawJoystick()
    drawVButtons()

    -- Axis bar indicators (small, near joystick label)
    local bx = vjbx - VJ.radius
    local by = vjby + VJ.radius + 28
    love.graphics.setColor(0.12, 0.16, 0.28)
    love.graphics.rectangle("fill", bx, by, VJ.radius*2, 8, 3,3)
    love.graphics.setColor(0.3, 0.6, 1.0)
    local midX = bx + VJ.radius
    local _ax, _ay = VJ:axes()
    love.graphics.rectangle("fill", midX, by, _ax*VJ.radius, 8)
    love.graphics.setColor(0.12, 0.16, 0.28)
    love.graphics.rectangle("fill", bx, by+12, VJ.radius*2, 8, 3,3)
    love.graphics.setColor(1.0, 0.5, 0.3)
    love.graphics.rectangle("fill", midX, by+12, _ay*VJ.radius, 8)

    Utils.drawHUD("VIRTUAL JOYSTICK",
        "Drag left zone = joystick    Tap buttons A/B/X/Y    WASD keyboard fallback    ESC back")
end

-- -------------------------
-- Mouse input (simulates touch)
-- -------------------------
function Example.mousepressed(x, y, button)
    if button ~= 1 then return end
    -- Check buttons first
    for _, btn in ipairs(VButtons) do
        if inButton(btn, x, y) then
            btn.pressed = true
            char.action = btn.action
            char.actionT = 0.6
            return
        end
    end
    -- Joystick zone
    if inJoystickZone(x, y) then
        vjActivate(x, y, "mouse")
    end
end

function Example.mousemoved(x, y, dx, dy)
    if VJ:isActive() and VJ:touchId() == "mouse" then
        vjMove(x, y, "mouse")
    end
end

function Example.mousereleased(x, y, button)
    if button ~= 1 then return end
    vjRelease("mouse")
    for _, btn in ipairs(VButtons) do
        btn.pressed = false
    end
end

-- -------------------------
-- Touch input
-- -------------------------
function Example.touchpressed(id, x, y)
    for _, btn in ipairs(VButtons) do
        if inButton(btn, x, y) then
            btn.pressed = true
            char.action  = btn.action
            char.actionT = 0.6
            return
        end
    end
    if inJoystickZone(x, y) and not VJ:isActive() then
        vjActivate(x, y, id)
    end
end

function Example.touchmoved(id, x, y)
    if VJ:isActive() and VJ:touchId() == id then
        vjMove(x, y, "mouse")
    end
end

function Example.touchreleased(id, x, y)
    vjRelease(id)
    for _, btn in ipairs(VButtons) do
        if inButton(btn, x, y) then btn.pressed = false end
    end
end

function Example.keypressed(key)
    if key == "z" then
        VButtons[1].pressed = true
        char.action="jump"; char.actionT=0.6
    elseif key == "x" then
        VButtons[2].pressed = true
        char.action="attack"; char.actionT=0.6
    end
    Utils.handlePause(key, Example)
end

function Example.keyreleased(key)
    if key == "z" then VButtons[1].pressed = false end
    if key == "x" then VButtons[2].pressed = false end
end

return Example
