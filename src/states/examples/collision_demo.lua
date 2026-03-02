-- src/states/examples/collision_demo.lua
-- Demonstrates: AABB, circle-circle, circle-rect collision detection
-- Drag shapes with mouse to test collisions interactively

local Utils   = require("src.utils")
local Timer   = require("src.systems.timer")
local Col     = require("src.systems.collision")
local Example = {}

local W, H
local shapes  = {}
local dragging = nil

-- -------------------------
-- Collision tests
-- -------------------------

-- Collision detection via Col system
local function shapesOverlap(a, b) return Col.overlap(a, b) end

-- -------------------------
-- Drawing
-- -------------------------

local function drawShape(s, hit)
    local cr, cg, cb = s.cr, s.cg, s.cb
    if hit then cr, cg, cb = 0.9, 0.25, 0.25 end

    if s.type == "rect" then
        love.graphics.setColor(cr, cg, cb, 0.5)
        love.graphics.rectangle("fill", s.x, s.y, s.w, s.h)
        love.graphics.setColor(cr, cg, cb)
        love.graphics.rectangle("line", s.x, s.y, s.w, s.h)
        -- label at center
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(s.label, s.x, s.y + s.h/2 - 8, s.w, "center")

    elseif s.type == "circle" then
        love.graphics.setColor(cr, cg, cb, 0.5)
        love.graphics.circle("fill", s.x, s.y, s.radius)
        love.graphics.setColor(cr, cg, cb)
        love.graphics.circle("line", s.x, s.y, s.radius)
        -- label at center
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(s.label, s.x - 50, s.y - 8, 100, "center")
    end
end

local function isInside(s, mx, my)
    return Col.pointInShape(mx, my, s)
end

-- -------------------------
-- State
-- -------------------------

function Example.enter()
    W = love.graphics.getWidth()
    H = love.graphics.getHeight()
    dragging = nil

    shapes = {
        -- Rect vs Rect
        { type="rect",   label="Rect A", x=80,  y=100, w=110, h=70,  cr=0.3, cg=0.5, cb=1.0 },
        { type="rect",   label="Rect B", x=240, y=120, w=110, h=60,  cr=0.3, cg=0.8, cb=0.5 },
        -- Circle vs Circle
        { type="circle", label="Circle A", x=150, y=320, radius=55,  cr=0.9, cg=0.7, cb=0.2 },
        { type="circle", label="Circle B", x=310, y=340, radius=45,  cr=0.8, cg=0.3, cb=0.9 },
        -- Circle vs Rect
        { type="circle", label="Circle C", x=520, y=180, radius=50,  cr=0.2, cg=0.9, cb=0.8 },
        { type="rect",   label="Rect C",   x=630, y=150, w=120, h=90, cr=1.0, cg=0.5, cb=0.2 },
        -- Free play
        { type="rect",   label="Rect D",   x=480, y=380, w=90,  h=90, cr=0.7, cg=0.4, cb=0.9 },
        { type="circle", label="Circle D", x=650, y=430, radius=50,  cr=0.9, cg=0.4, cb=0.4 },
    }
end

function Example.exit() end

function Example.update(dt)
    if dragging then
        local mx, my = love.mouse.getPosition()
        dragging.shape.x = mx - dragging.offX
        dragging.shape.y = my - dragging.offY
    end
end

function Example.draw()
    Utils.drawBackground()

    -- Compute hits
    local hit = {}
    for i = 1, #shapes do hit[i] = false end
    for i = 1, #shapes do
        for j = i+1, #shapes do
            if shapesOverlap(shapes[i], shapes[j]) then
                hit[i] = true
                hit[j] = true
            end
        end
    end

    -- Draw shapes
    for i, s in ipairs(shapes) do
        drawShape(s, hit[i])
    end

    -- Yellow closest-point line only for overlapping circle-rect pairs
    for i = 1, #shapes do
        for j = i+1, #shapes do
            local a, b = shapes[i], shapes[j]
            local c, rect = nil, nil
            if a.type == "circle" and b.type == "rect" then c, rect = a, b
            elseif a.type == "rect" and b.type == "circle" then c, rect = b, a end
            if c and rect and shapesOverlap(c, rect) then
                local nearX = Utils.clamp(c.x, rect.x, rect.x + rect.w)
                local nearY = Utils.clamp(c.y, rect.y, rect.y + rect.h)
                love.graphics.setColor(1, 1, 0, 0.8)
                love.graphics.line(c.x, c.y, nearX, nearY)
                love.graphics.setColor(1, 1, 0)
                love.graphics.circle("fill", nearX, nearY, 4)
            end
        end
    end

    -- Legend
    love.graphics.setColor(0.2, 0.2, 0.28)
    love.graphics.rectangle("fill", 0, 490, W, 70)

    local items = {
        { type="rect",   cr=0.3, cg=0.5, cb=1.0, label="Rect" },
        { type="circle", cr=0.9, cg=0.7, cb=0.2, label="Circle" },
        { type="circle", cr=0.2, cg=0.9, cb=0.8, label="Circle vs Rect" },
        { type="rect",   cr=0.9, cg=0.25,cb=0.25,label="Collision!" },
    }
    local x = 20
    for _, item in ipairs(items) do
        if item.type == "rect" then
            love.graphics.setColor(item.cr, item.cg, item.cb)
            love.graphics.rectangle("fill", x, 505, 18, 18)
            x = x + 24
        else
            love.graphics.setColor(item.cr, item.cg, item.cb)
            love.graphics.circle("fill", x + 9, 514, 9)
            x = x + 24
        end
        love.graphics.setColor(0.85, 0.85, 0.85)
        love.graphics.print("= " .. item.label, x, 505)
        x = x + love.graphics.getFont():getWidth("= " .. item.label) + 20
    end

    love.graphics.setColor(1, 1, 0)
    love.graphics.print("Yellow line = closest point on rect to circle (only on overlap)", 20, 535)

    Utils.drawHUD("COLLISION DEMO", "Drag shapes with mouse    P pause    ESC back")
end

function Example.keypressed(key)
    Utils.handlePause(key, Example)
end

function Example.mousepressed(x, y, button)
    if button == 1 then
        for i = #shapes, 1, -1 do
            local s = shapes[i]
            if isInside(s, x, y) then
                dragging = { shape = s, offX = x - s.x, offY = y - s.y }
                table.remove(shapes, i)
                table.insert(shapes, s)
                break
            end
        end
    end
end

function Example.mousereleased(x, y, button)
    if button == 1 then dragging = nil end
end


return Example
