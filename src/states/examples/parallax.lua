-- src/states/examples/parallax.lua
-- Demonstrates: multi-layer parallax scrolling, infinite wrap, depth illusion

local Utils   = require("src.utils")
local Example = {}

local W, H

-- -------------------------
-- Camera / scroll state
-- -------------------------
local camX     = 0
local camY     = 0
local camVX    = 60   -- auto-scroll speed (px/s)
local camVY    = 0
local autoScroll = true

-- -------------------------
-- Layer definition
-- Each layer has:
--   depth   : 0.0 (far/slow) .. 1.0 (near/fast)
--   color   : base draw color
--   elements: list of shapes drawn per tile
--   tileW   : how wide one tile is (for wrapping)
--   yOffset : vertical baseline
-- -------------------------
local layers = {}

local function makeLayers()
    layers = {
        -- Layer 1 — distant mountains (slowest)
        {
            depth   = 0.05,
            tileW   = W,
            yBase   = H * 0.55,
            draw    = function(ox, yBase)
                -- Mountain silhouette
                local peaks = {
                    {0.05,0}, {0.15,0.28}, {0.22,0.05}, {0.35,0.38},
                    {0.45,0.12}, {0.55,0.32}, {0.65,0.08}, {0.75,0.35},
                    {0.85,0.15}, {1.0,0.3},  {1.05,0}
                }
                love.graphics.setColor(0.18, 0.20, 0.32)
                local verts = {ox, yBase}
                for _, p in ipairs(peaks) do
                    table.insert(verts, ox + p[1]*W)
                    table.insert(verts, yBase - p[2]*H*0.35)
                end
                table.insert(verts, ox+W*1.05)
                table.insert(verts, yBase)
                love.graphics.polygon("fill", verts)
            end,
        },
        -- Layer 2 — mid mountains
        {
            depth   = 0.12,
            tileW   = W,
            yBase   = H * 0.60,
            draw    = function(ox, yBase)
                local peaks = {
                    {0,0.1},{0.08,0.30},{0.18,0.08},{0.28,0.35},
                    {0.4,0.15},{0.52,0.40},{0.62,0.10},{0.72,0.32},
                    {0.82,0.18},{0.92,0.28},{1.0,0.12},{1.05,0}
                }
                love.graphics.setColor(0.14, 0.17, 0.28)
                local verts = {ox, yBase}
                for _, p in ipairs(peaks) do
                    table.insert(verts, ox + p[1]*W)
                    table.insert(verts, yBase - p[2]*H*0.32)
                end
                table.insert(verts, ox+W*1.05)
                table.insert(verts, yBase)
                love.graphics.polygon("fill", verts)
            end,
        },
        -- Layer 3 — forest far
        {
            depth   = 0.25,
            tileW   = W,
            yBase   = H * 0.65,
            draw    = function(ox, yBase)
                love.graphics.setColor(0.10, 0.18, 0.14)
                -- rows of triangle trees
                for i = 0, 24 do
                    local tx = ox + i * (W/22)
                    local th = H * (0.06 + (i%3)*0.02)
                    love.graphics.polygon("fill",
                        tx-10, yBase,
                        tx,    yBase - th,
                        tx+10, yBase)
                end
            end,
        },
        -- Layer 4 — forest mid
        {
            depth   = 0.45,
            tileW   = W,
            yBase   = H * 0.70,
            draw    = function(ox, yBase)
                love.graphics.setColor(0.08, 0.22, 0.12)
                for i = 0, 18 do
                    local tx = ox + i * (W/16) + (i%2)*14
                    local th = H * (0.09 + (i%4)*0.015)
                    love.graphics.polygon("fill",
                        tx-14, yBase,
                        tx,    yBase - th,
                        tx+14, yBase)
                    -- second tier
                    love.graphics.polygon("fill",
                        tx-10, yBase - th*0.45,
                        tx,    yBase - th*0.85,
                        tx+10, yBase - th*0.45)
                end
            end,
        },
        -- Layer 5 — ground / grass strip
        {
            depth   = 0.7,
            tileW   = W,
            yBase   = H * 0.72,
            draw    = function(ox, yBase)
                -- Ground fill
                love.graphics.setColor(0.08, 0.18, 0.08)
                love.graphics.rectangle("fill", ox, yBase, W*1.05, H - yBase)
                -- Grass tufts
                love.graphics.setColor(0.12, 0.30, 0.10)
                for i = 0, 30 do
                    local tx = ox + i * (W/28)
                    love.graphics.rectangle("fill", tx, yBase-3, 4, 10)
                    love.graphics.rectangle("fill", tx+5, yBase-5, 3, 8)
                end
            end,
        },
        -- Layer 6 — near bushes (fastest)
        {
            depth   = 0.90,
            tileW   = W,
            yBase   = H * 0.72,
            draw    = function(ox, yBase)
                love.graphics.setColor(0.06, 0.26, 0.08)
                for i = 0, 10 do
                    local tx = ox + i * (W/9) + (i%3)*20
                    local r  = 22 + (i%3)*10
                    love.graphics.circle("fill", tx, yBase + 6, r)
                    love.graphics.circle("fill", tx+r*0.6, yBase+4, r*0.75)
                    love.graphics.circle("fill", tx-r*0.5, yBase+8, r*0.65)
                end
            end,
        },
    }
end

-- -------------------------
-- Stars (fixed in sky, not scrolling)
-- -------------------------
local stars = {}
local function makeStars()
    stars = {}
    math.randomseed(42)
    for _ = 1, 120 do
        table.insert(stars, {
            x = math.random(0, W),
            y = math.random(0, H * 0.55),
            r = math.random() * 1.5 + 0.3,
            b = math.random(60, 100) / 100,
        })
    end
end

-- -------------------------
-- Enter
-- -------------------------
function Example.enter()
    W = love.graphics.getWidth()
    H = love.graphics.getHeight()
    camX, camY = 0, 0
    autoScroll = true
    makeLayers()
    makeStars()
end

function Example.exit() end

function Example.update(dt)
    if autoScroll then
        camX = camX + camVX * dt
        camY = camY + camVY * dt
    end

    -- Mouse drag
    if love.mouse.isDown(1) then
        local mx, my = love.mouse.getPosition()
        if Example._lastMX then
            camX = camX - (mx - Example._lastMX)
            camY = camY - (my - Example._lastMY)
        end
        Example._lastMX, Example._lastMY = mx, my
        autoScroll = false
    else
        Example._lastMX = nil
    end
end

-- -------------------------
-- Draw one layer at correct parallax offset
-- -------------------------
local function drawLayer(layer)
    -- How much this layer moves relative to camera
    local lx = camX * layer.depth
    local ly = camY * layer.depth * 0.3   -- vertical parallax is subtle

    -- Tile offset (wrap the layer)
    local tileW = layer.tileW
    local ox    = -(lx % tileW)
    local yBase = layer.yBase + ly

    -- Draw two tiles to cover seam
    layer.draw(ox,        yBase)
    layer.draw(ox + tileW, yBase)
end

function Example.draw()
    -- Sky gradient
    love.graphics.setColor(0.05, 0.06, 0.18)
    love.graphics.rectangle("fill", 0, 0, W, H * 0.72)

    -- Stars (no parallax — truly infinite)
    for _, s in ipairs(stars) do
        love.graphics.setColor(s.b, s.b, s.b, s.b)
        love.graphics.circle("fill", s.x, s.y, s.r)
    end

    -- Moon
    love.graphics.setColor(0.95, 0.92, 0.80)
    love.graphics.circle("fill", W * 0.8, H * 0.14, 28)
    love.graphics.setColor(0.05, 0.06, 0.18)
    love.graphics.circle("fill", W * 0.8 + 12, H * 0.14 - 6, 22)

    -- Parallax layers (back to front)
    for _, layer in ipairs(layers) do
        drawLayer(layer)
    end

    -- Depth indicator bars (right side)
    love.graphics.setColor(0.08, 0.10, 0.18, 0.85)
    love.graphics.rectangle("fill", W-140, 40, 130, #layers*22+16, 6,6)
    love.graphics.setColor(0.3, 0.45, 0.7)
    love.graphics.printf("DEPTH", W-140, 46, 130, "center")
    for i, layer in ipairs(layers) do
        local barW = math.floor(layer.depth * 100)
        love.graphics.setColor(0.15, 0.2, 0.35)
        love.graphics.rectangle("fill", W-132, 62+(i-1)*22, 100, 14, 2,2)
        love.graphics.setColor(
            Utils.lerp(0.3, 1.0, layer.depth),
            Utils.lerp(0.8, 0.3, layer.depth),
            0.4)
        love.graphics.rectangle("fill", W-132, 62+(i-1)*22, barW, 14, 2,2)
        love.graphics.setColor(0.7,0.7,0.7)
        love.graphics.print(string.format("%.2f", layer.depth), W-128, 62+(i-1)*22)
    end

    -- Scroll position
    love.graphics.setColor(0.35, 0.45, 0.6)
    love.graphics.printf(
        string.format("cam: %.0f, %.0f  |  %s",
            camX, camY,
            autoScroll and "auto" or "drag"),
        0, H - 48, W, "center")

    Utils.drawHUD("PARALLAX",
        "Drag to scroll    A auto-scroll    +/- speed    R reset    ESC back")
end

function Example.keypressed(key)
    if key == "r" then
        camX, camY  = 0, 0
        autoScroll  = true
    elseif key == "a" then
        autoScroll = not autoScroll
    elseif key == "=" or key == "+" then
        camVX = camVX + 20
    elseif key == "-" then
        camVX = math.max(0, camVX - 20)
    end
    Utils.handlePause(key, Example)
end

function Example.touchpressed(id, x, y)
    autoScroll = false
    Example._lastTX, Example._lastTY = x, y
end

function Example.touchmoved(id, x, y)
    if Example._lastTX then
        camX = camX - (x - Example._lastTX)
        camY = camY - (y - Example._lastTY)
    end
    Example._lastTX, Example._lastTY = x, y
end

return Example
