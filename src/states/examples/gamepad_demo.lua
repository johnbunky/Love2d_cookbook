-- src/states/examples/gamepad_demo.lua
-- Demonstrates: gamepad detection, buttons, axes, rumble, hot-plug

local Utils  = require("src.utils")
local Timer  = require("src.systems.timer")
local Example = {}

local W, H
local timer
local time = 0

-- State
local pads    = {}   -- connected joysticks
local padData = {}   -- per-joystick state cache

local function updatePadData(joystick)
    local id  = joystick:getID()
    local d   = padData[id] or {}
    padData[id] = d

    d.name    = joystick:getName()
    d.isGP    = joystick:isGamepad()
    d.axes    = {}
    d.buttons = {}
    d.hats    = {}

    -- Raw axes
    local axisCount = joystick:getAxisCount()
    for i = 1, axisCount do
        d.axes[i] = joystick:getAxis(i)
    end

    -- Raw buttons
    local btnCount = joystick:getButtonCount()
    for i = 1, btnCount do
        d.buttons[i] = joystick:isDown(i)
    end

    -- Hats
    local hatCount = joystick:getHatCount()
    for i = 1, hatCount do
        d.hats[i] = joystick:getHat(i)
    end

    -- Gamepad mapped buttons
    if d.isGP then
        local gpBtns = {
            "a","b","x","y",
            "back","guide","start",
            "leftstick","rightstick",
            "leftshoulder","rightshoulder",
            "dpup","dpdown","dpleft","dpright",
        }
        d.gpButtons = {}
        for _, btn in ipairs(gpBtns) do
            d.gpButtons[btn] = joystick:isGamepadDown(btn)
        end
        -- Gamepad axes
        local gpAxes = { "leftx","lefty","rightx","righty","triggerleft","triggerright" }
        d.gpAxes = {}
        for _, ax in ipairs(gpAxes) do
            d.gpAxes[ax] = joystick:getGamepadAxis(ax)
        end
    end
end

function Example.enter()
    W     = love.graphics.getWidth()
    H     = love.graphics.getHeight()
    timer = Timer.new()
    time  = 0
    pads  = love.joystick.getJoysticks()
    padData = {}
end

function Example.exit()
    Timer.clear(timer)
end

function Example.update(dt)
    Timer.update(timer, dt)
    time = time + dt
    pads = love.joystick.getJoysticks()
    for _, js in ipairs(pads) do
        updatePadData(js)
    end
end

-- -------------------------
-- Draw helpers
-- -------------------------
local function drawStick(cx, cy, ax, ay, radius, label)
    -- Dead zone ring
    love.graphics.setColor(0.12, 0.16, 0.26)
    love.graphics.circle("fill", cx, cy, radius)
    love.graphics.setColor(0.22, 0.32, 0.52)
    love.graphics.circle("line", cx, cy, radius)

    -- Deadzone indicator
    love.graphics.setColor(0.18, 0.25, 0.40)
    love.graphics.circle("line", cx, cy, radius*0.15)

    -- Stick position
    local sx = cx + ax * radius * 0.85
    local sy = cy + ay * radius * 0.85
    local mag = math.sqrt(ax*ax+ay*ay)
    local col = mag > 0.1 and {0.3,0.7,1.0} or {0.25,0.35,0.55}
    love.graphics.setColor(col)
    love.graphics.circle("fill", sx, sy, radius*0.22)
    love.graphics.setColor(0.5,0.75,1.0)
    love.graphics.circle("line", sx, sy, radius*0.22)

    -- Crosshair
    love.graphics.setColor(0.22, 0.32, 0.52)
    love.graphics.line(cx-radius, cy, cx+radius, cy)
    love.graphics.line(cx, cy-radius, cx, cy+radius)

    -- Label
    love.graphics.setColor(0.5, 0.65, 0.9)
    love.graphics.printf(label, cx-radius, cy+radius+4, radius*2, "center")
    love.graphics.printf(string.format("%.2f,%.2f", ax, ay),
        cx-radius, cy+radius+18, radius*2, "center")
end

local function drawTrigger(x, y, w, h, value, label)
    -- Background
    love.graphics.setColor(0.12, 0.16, 0.26)
    love.graphics.rectangle("fill", x, y, w, h, 4,4)
    -- Fill
    local fill = ((value+1)*0.5)  -- -1..1 ? 0..1 for triggers
    love.graphics.setColor(0.3, 0.65, 1.0)
    love.graphics.rectangle("fill", x, y + h*(1-fill), w, h*fill, 4,4)
    -- Border
    love.graphics.setColor(0.3, 0.45, 0.75)
    love.graphics.rectangle("line", x, y, w, h, 4,4)
    -- Label + value
    love.graphics.setColor(0.6, 0.75, 0.95)
    love.graphics.printf(label, x, y+h+4, w, "center")
    love.graphics.printf(string.format("%.2f", value), x, y+h+18, w, "center")
end

local function drawGPButton(x, y, r, label, pressed, color)
    color = color or {0.3,0.55,0.9}
    if pressed then
        love.graphics.setColor(color[1], color[2], color[3])
    else
        love.graphics.setColor(0.14, 0.18, 0.28)
    end
    love.graphics.circle("fill", x, y, r)
    love.graphics.setColor(pressed and 0.8 or 0.3,
                           pressed and 0.9 or 0.45,
                           pressed and 1.0 or 0.7)
    love.graphics.circle("line", x, y, r)
    love.graphics.setColor(pressed and 1 or 0.5,
                           pressed and 1 or 0.5,
                           pressed and 1 or 0.65)
    love.graphics.printf(label, x-r, y-7, r*2, "center")
end

local function drawDPad(cx, cy, r, hats, gpBtns)
    local dirs = {
        up    = {0,-1}, down  = {0,1},
        left  = {-1,0}, right = {1,0},
    }
    local active = {}
    if gpBtns then
        active.up    = gpBtns["dpup"]
        active.down  = gpBtns["dpdown"]
        active.left  = gpBtns["dpleft"]
        active.right = gpBtns["dpright"]
    end

    -- Cross shape
    love.graphics.setColor(0.14, 0.18, 0.28)
    love.graphics.rectangle("fill", cx-r*0.4, cy-r, r*0.8, r*2, 3,3)
    love.graphics.rectangle("fill", cx-r, cy-r*0.4, r*2, r*0.8, 3,3)

    for dir, offset in pairs(dirs) do
        local bx = cx + offset[1]*r*0.6
        local by = cy + offset[2]*r*0.6
        love.graphics.setColor(active[dir] and 0.3 or 0.20,
                               active[dir] and 0.65 or 0.28,
                               active[dir] and 1.0 or 0.45)
        love.graphics.rectangle("fill", bx-r*0.28, by-r*0.28, r*0.56, r*0.56, 3,3)
    end

    love.graphics.setColor(0.5, 0.65, 0.9)
    love.graphics.printf("D-Pad", cx-r, cy+r+4, r*2, "center")
end

function Example.draw()
    love.graphics.setColor(0.06, 0.08, 0.14)
    love.graphics.rectangle("fill", 0, 0, W, H)

    love.graphics.setColor(0.5, 0.7, 1.0)
    love.graphics.printf("GAMEPAD", 0, 20, W, "center")

    if #pads == 0 then
        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.printf("No gamepad detected", 0, H/2-20, W, "center")
        love.graphics.setColor(0.35, 0.45, 0.65)
        love.graphics.printf("Connect a controller and it will appear here", 0, H/2+8, W, "center")
        Utils.drawHUD("GAMEPAD", "Connect a controller    ESC back")
        return
    end

    -- Show first connected pad
    local js = pads[1]
    local d  = padData[js:getID()]
    if not d then
        Utils.drawHUD("GAMEPAD", "ESC back")
        return
    end

    -- Controller name
    love.graphics.setColor(0.6, 0.75, 1.0)
    love.graphics.printf(d.name .. (d.isGP and " [Gamepad mapped]" or " [Raw]"),
        0, 46, W, "center")

    if d.isGP and d.gpAxes and d.gpButtons then
        -- ---- Gamepad layout ----
        local cx = W/2
        local cy = H/2 + 20

        -- Left stick
        drawStick(cx-160, cy+30, d.gpAxes.leftx or 0, d.gpAxes.lefty or 0, 55, "L.Stick")

        -- Right stick
        drawStick(cx+60, cy+30, d.gpAxes.rightx or 0, d.gpAxes.righty or 0, 55, "R.Stick")

        -- Triggers
        drawTrigger(cx-260, cy-80, 30, 80, d.gpAxes.triggerleft  or -1, "LT")
        drawTrigger(cx+230, cy-80, 30, 80, d.gpAxes.triggerright or -1, "RT")

        -- Shoulders
        local function drawRect(x, y, w, h, pressed, label)
            love.graphics.setColor(pressed and 0.3 or 0.14,
                                   pressed and 0.6 or 0.2,
                                   pressed and 1.0 or 0.4)
            love.graphics.rectangle("fill", x, y, w, h, 4,4)
            love.graphics.setColor(0.5,0.7,1.0)
            love.graphics.rectangle("line", x, y, w, h, 4,4)
            love.graphics.setColor(1,1,1, pressed and 1 or 0.5)
            love.graphics.printf(label, x, y+6, w, "center")
        end
        drawRect(cx-230, cy-60, 60, 28, d.gpButtons["leftshoulder"],  "LB")
        drawRect(cx+170, cy-60, 60, 28, d.gpButtons["rightshoulder"], "RB")

        -- ABXY buttons
        local br  = 18
        drawGPButton(cx+170, cy-20, br, "Y", d.gpButtons["y"],  {0.7,0.7,0.2})
        drawGPButton(cx+195, cy+10, br, "B", d.gpButtons["b"],  {0.9,0.3,0.3})
        drawGPButton(cx+145, cy+10, br, "A", d.gpButtons["a"],  {0.3,0.8,0.4})
        drawGPButton(cx+170, cy+38, br, "X", d.gpButtons["x"],  {0.3,0.5,0.9})

        -- D-Pad
        drawDPad(cx-60, cy-20, 38, d.hats, d.gpButtons)

        -- Start/Back/Guide
        drawGPButton(cx-20, cy-30, 14, "?", d.gpButtons["back"],  {0.4,0.4,0.6})
        drawGPButton(cx+20, cy-30, 14, "?", d.gpButtons["start"], {0.4,0.4,0.6})
        drawGPButton(cx,    cy-50, 16, "?",  d.gpButtons["guide"], {0.9,0.6,0.2})

        -- Stick click
        drawGPButton(cx-160, cy+95, 14, "L3", d.gpButtons["leftstick"],  {0.35,0.5,0.8})
        drawGPButton(cx+60,  cy+95, 14, "R3", d.gpButtons["rightstick"], {0.35,0.5,0.8})

    else
        -- Raw display for non-mapped joysticks
        love.graphics.setColor(0.45, 0.55, 0.8)
        love.graphics.printf("Raw axes:", 60, 90, 200, "left")
        for i, v in ipairs(d.axes) do
            local bx = 60
            local by = 110 + (i-1)*22
            love.graphics.setColor(0.12, 0.16, 0.28)
            love.graphics.rectangle("fill", bx, by, 200, 14, 3,3)
            local fill = (v+1)*0.5 * 200
            love.graphics.setColor(0.3, 0.6, 1.0)
            love.graphics.rectangle("fill", bx, by, fill, 14, 3,3)
            love.graphics.setColor(0.6, 0.75, 1.0)
            love.graphics.printf(string.format("Axis %d: %.2f", i, v), bx+210, by, 120, "left")
        end

        love.graphics.setColor(0.45, 0.55, 0.8)
        love.graphics.printf("Buttons:", 60, 90 + #d.axes*22 + 10, 200, "left")
        for i, pressed in ipairs(d.buttons) do
            local bx = 60 + ((i-1)%16)*26
            local by = 110 + #d.axes*22 + 10 + math.floor((i-1)/16)*26
            love.graphics.setColor(pressed and 0.3 or 0.12,
                                   pressed and 0.7 or 0.18,
                                   pressed and 0.4 or 0.28)
            love.graphics.rectangle("fill", bx, by, 22, 22, 4,4)
            love.graphics.setColor(0.6,0.8,1.0)
            love.graphics.printf(tostring(i), bx, by+4, 22, "center")
        end
    end

    Utils.drawHUD("GAMEPAD",
        "Use your controller    " .. #pads .. " pad(s) connected    ESC back")
end

function Example.joystickadded(joystick)
    pads = love.joystick.getJoysticks()
end

function Example.joystickremoved(joystick)
    pads = love.joystick.getJoysticks()
    padData[joystick:getID()] = nil
end

function Example.keypressed(key)
    Utils.handlePause(key, Example)
end

return Example
