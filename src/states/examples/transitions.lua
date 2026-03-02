-- src/states/examples/transitions.lua
-- Demonstrates: fade, fadewhite, slideleft, slideright, circle, dissolve

local Utils   = require("src.utils")
local Example = {}

local scenes = {
    { bg={0.10,0.12,0.18}, text="SCENE 1", sub="Click or press 1-6 to transition to Scene 2", col={0.4,0.8,1.0} },
    { bg={0.12,0.18,0.10}, text="SCENE 2", sub="Click or press 1-6 to transition back to Scene 1", col={0.4,1.0,0.5} },
}

local current = 1

local effects = {
    { key="1", name="fade",       label="Fade black"  },
    { key="2", name="fadewhite",  label="Fade white"  },
    { key="3", name="slideleft",  label="Slide left"  },
    { key="4", name="slideright", label="Slide right" },
    { key="5", name="circle",     label="Circle wipe" },
    { key="6", name="dissolve",   label="Dissolve"    },
}

local W, H
local lastEffect = ""

-- Button layout  -  computed once, shared between draw() and hit testing
local BW, BH, GAP = 110, 40, 16
local buttons = {}  -- { x, y, w, h, ef }

local function buildButtons()
    buttons = {}
    local totalW = #effects * (BW + GAP) - GAP
    local startX = (W - totalW) / 2
    local by     = H - 120
    for i, ef in ipairs(effects) do
        table.insert(buttons, {
            x  = startX + (i-1) * (BW + GAP),
            y  = by,
            w  = BW,
            h  = BH,
            ef = ef,
        })
    end
end

local function triggerEffect(ef)
    if Transition.isActive() then return end
    lastEffect = ef.label
    local nextScene = current == 1 and 2 or 1
    Transition.to(Example, ef.name, 0.45, function()
        current = nextScene
    end)
end

function Example.enter()
    W = love.graphics.getWidth()
    H = love.graphics.getHeight()
    buildButtons()
end

function Example.exit() end
function Example.update(dt) end

function Example.draw()
    local scene = scenes[current]

    love.graphics.setColor(scene.bg)
    love.graphics.rectangle("fill", 0, 0, W, H)

    love.graphics.setColor(scene.col)
    love.graphics.printf(scene.text, 0, 160, W, "center")
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.printf(scene.sub, 0, 220, W, "center")

    if lastEffect ~= "" then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.printf("last: " .. lastEffect, 0, 265, W, "center")
    end

    -- Button panel
    love.graphics.setColor(0.15, 0.15, 0.22)
    love.graphics.rectangle("fill", 0, H-160, W, 160)

    local active = Transition.isActive()
    for _, btn in ipairs(buttons) do
        local hover = Input.isHover(btn.x, btn.y, btn.w, btn.h) and not active

        if active then
            love.graphics.setColor(0.22, 0.22, 0.28)
        elseif hover then
            love.graphics.setColor(0.4, 0.55, 0.8)
        else
            love.graphics.setColor(0.3, 0.45, 0.65)
        end
        love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 6, 6)

        love.graphics.setColor(hover and 0.8 or 0.5, hover and 0.9 or 0.7, 1.0)
        love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, 6, 6)

        local alpha = active and 0.4 or 1
        love.graphics.setColor(alpha, alpha, alpha)
        love.graphics.printf(
            "[" .. btn.ef.key .. "] " .. btn.ef.label,
            btn.x, btn.y + 12, btn.w, "center")
    end

    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.printf(
        "transitions work everywhere  -  just replace Gamestate.switch() with Transition.to()",
        0, H-32, W, "center")

    Utils.drawHUD("TRANSITIONS", "1-6 or click buttons    P pause    ESC back")
end

function Example.keypressed(key)
    for _, ef in ipairs(effects) do
        if key == ef.key then triggerEffect(ef); return end
    end
    Utils.handlePause(key, Example)
end

function Example.mousepressed(x, y, button)
    if button == 1 then
        for _, btn in ipairs(buttons) do
            if Input.isHover(btn.x, btn.y, btn.w, btn.h) then
                triggerEffect(btn.ef)
                return
            end
        end
    end
end

function Example.touchpressed(id, x, y)
    for _, btn in ipairs(buttons) do
        if x >= btn.x and x <= btn.x + btn.w
        and y >= btn.y and y <= btn.y + btn.h then
            triggerEffect(btn.ef)
            return
        end
    end
end

function Example.gamepadpressed(joystick, button)
    -- shoulder buttons cycle through effects
    if button == "rightshoulder" then
        local next = current == 1 and 2 or 1
        triggerEffect(effects[math.random(#effects)])
    end
end

return Example
