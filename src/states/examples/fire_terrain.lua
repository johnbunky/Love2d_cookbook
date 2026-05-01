-- src/states/examples/fire_terrain.lua
-- Destructible terrain + fire spread  (cookbook demo)
--
-- Cell values in the automata grid:
--   0   = air / ash
--   1   = stone  (indestructible, fireproof)
--   2   = wood   (flammable, destructible)
--   10+ = fire   (heat 10-255, decays each step, spreads to adjacent wood)
--
-- Controls:
--   WASD / arrows   move player
--   LMB             trigger explosion at mouse cursor
--   R               regenerate level
--   ESC             back to menu

local Automata = require "src.systems.automata"

------------------------------------------------------------------------
-- CONFIG
------------------------------------------------------------------------
local CELL         = 14     -- pixels per cell
local HUD_H        = 44
local STEP_RATE    = 0.07   -- seconds between CA steps (~14 steps/sec)
local EXPLODE_R    = 5      -- explosion radius in cells
local PLAYER_SPEED = 140    -- px / sec
local PLAYER_R     = CELL * 0.55

-- cell type constants
local AIR      = 0
local STONE    = 1
local WOOD     = 2
local FIRE_MIN = 10   -- cells >= FIRE_MIN are "on fire"

------------------------------------------------------------------------
-- COLOUR PALETTE
------------------------------------------------------------------------
local fireLUT = {}
for i = 0, 255 do
    local t = i / 255
    fireLUT[i] = {
        math.min(1, t * 2.8),
        math.max(0, math.min(1, (t - 0.35) * 2.0)),
        math.max(0, math.min(1, (t - 0.75) * 4.0)),
    }
end

local C = {
    bg       = { 0.08, 0.07, 0.06 },
    stone    = { 0.42, 0.40, 0.38 },
    wood     = { 0.55, 0.35, 0.18 },
    ash      = { 0.18, 0.16, 0.14 },
    player   = { 0.20, 0.75, 1.00 },
    crosshair= { 1.00, 0.30, 0.10 },
    hud_bg   = { 0.00, 0.00, 0.00 },
    hud_txt  = { 1.00, 1.00, 1.00 },
    hud_hint = { 0.52, 0.52, 0.52 },
}

------------------------------------------------------------------------
-- FIRE CA RULE
------------------------------------------------------------------------
-- Stone:  immutable.
-- Wood:   ignites if a neighbour is on fire (probabilistic).
-- Fire:   decays by a random amount each step; extinguishes at < FIRE_MIN.
-- Air:    stays air (ash is purely visual, tracked in scorched[][]).
local function fireRule(g, x, y)
    local v = g:get(x, y)

    if v == STONE then return STONE end

    if v >= FIRE_MIN then
        local heat = v - (8 + math.random(12))
        if math.random() < 0.04 then heat = heat + math.random(30) end  -- flare
        return math.max(AIR, heat)
    end

    if v == WOOD then
        for dy = -1, 1 do
            for dx = -1, 1 do
                if not (dx == 0 and dy == 0) then
                    if g:get(x + dx, y + dy) >= FIRE_MIN then
                        if math.random() < 0.18 then
                            return 160 + math.random(80)
                        end
                    end
                end
            end
        end
        return WOOD
    end

    return AIR
end

------------------------------------------------------------------------
-- LEVEL GENERATION
------------------------------------------------------------------------
local function generateLevel(g)
    g:clear()
    local w, h = g.w, g.h

    -- stone border
    for x = 1, w do g:set(x, 1, STONE) ; g:set(x, h, STONE) end
    for y = 1, h do g:set(1, y, STONE) ; g:set(w, y, STONE) end

    -- stone pillars (indestructible cover)
    for _ = 1, math.floor(w * h * 0.025) do
        local px = math.random(3, w - 3)
        local py = math.random(3, h - 3)
        for dy = 0, math.random(1, 4) do
            for dx = 0, math.random(0, 2) do
                g:set(px + dx, py + dy, STONE)
            end
        end
    end

    -- wood walls and clusters (fuel)
    for _ = 1, math.floor(w * h * 0.055) do
        local px = math.random(2, w - 2)
        local py = math.random(2, h - 2)
        for dy = 0, math.random(0, 3) do
            for dx = 0, math.random(1, 5) do
                if g:get(px + dx, py + dy) == AIR then
                    g:set(px + dx, py + dy, WOOD)
                end
            end
        end
    end
end

------------------------------------------------------------------------
-- SCORCHED OVERLAY
-- Tracks cells that were ever on fire so we can render ash beneath them.
-- A second boolean grid parallel to the automata grid.
------------------------------------------------------------------------
local function newScorched(w, h)
    local s = {}
    for y = 1, h do
        s[y] = {}
        for x = 1, w do s[y][x] = false end
    end
    return s
end

local function updateScorched(g, s)
    for y = 1, g.h do
        for x = 1, g.w do
            if g.cells[y][x] >= FIRE_MIN then s[y][x] = true end
        end
    end
end

------------------------------------------------------------------------
-- EXPLOSION
------------------------------------------------------------------------
local function explode(g, cx, cy)
    local r  = EXPLODE_R
    local r2 = r * r
    for dy = -r, r do
        for dx = -r, r do
            if dx*dx + dy*dy <= r2 then
                local v = g:get(cx + dx, cy + dy)
                if v ~= STONE then
                    -- inner core cleared; outer ring set ablaze
                    if dx*dx + dy*dy < (r * 0.55)^2 then
                        g:set(cx + dx, cy + dy, AIR)
                    else
                        g:set(cx + dx, cy + dy, 180 + math.random(60))
                    end
                end
            end
        end
    end
end

------------------------------------------------------------------------
-- PLAYER COLLISION
------------------------------------------------------------------------
local function cellTypeAt(g, px, py)
    local cx = math.floor(px / CELL) + 1
    local cy = math.floor(py / CELL) + 1
    if cx < 1 or cx > g.w or cy < 1 or cy > g.h then return STONE end
    return g.cells[cy][cx]
end

local function solid(v) return v == STONE or v == WOOD end

-- Simple AABB-style circle resolution: push out of solid cells.
local function resolvePlayer(g, px, py)
    local r = PLAYER_R
    local o = r * 0.6   -- offset for corner probes

    if solid(cellTypeAt(g, px - r, py - o))
    or solid(cellTypeAt(g, px - r, py    ))
    or solid(cellTypeAt(g, px - r, py + o)) then
        px = (math.floor((px - r) / CELL) + 1) * CELL + r + 1
    end

    if solid(cellTypeAt(g, px + r, py - o))
    or solid(cellTypeAt(g, px + r, py    ))
    or solid(cellTypeAt(g, px + r, py + o)) then
        px = math.ceil((px + r) / CELL) * CELL - r - 1
    end

    if solid(cellTypeAt(g, px - o, py - r))
    or solid(cellTypeAt(g, px    , py - r))
    or solid(cellTypeAt(g, px + o, py - r)) then
        py = (math.floor((py - r) / CELL) + 1) * CELL + r + 1
    end

    if solid(cellTypeAt(g, px - o, py + r))
    or solid(cellTypeAt(g, px    , py + r))
    or solid(cellTypeAt(g, px + o, py + r)) then
        py = math.ceil((py + r) / CELL) * CELL - r - 1
    end

    return px, py
end

------------------------------------------------------------------------
-- MODULE STATE
------------------------------------------------------------------------
local grid, scorched
local GW, GH
local stepTimer = 0
local player    = { x = 0, y = 0 }
local fntBig, fntSml

local function spawnPlayer()
    -- find a clear cell near the top-left to start in
    player.x = CELL * 3 + CELL / 2
    player.y = CELL * 3 + CELL / 2
end

local function reset()
    generateLevel(grid)
    scorched = newScorched(GW, GH)
    stepTimer = 0
    spawnPlayer()
end

------------------------------------------------------------------------
-- STATE  (dot syntax — gamestate.lua passes no self)
------------------------------------------------------------------------
local state = {}

function state.enter()
    fntBig = love.graphics.newFont(14)
    fntSml = love.graphics.newFont(10)

    local sw, sh = love.graphics.getDimensions()
    GW = math.floor(sw / CELL)
    GH = math.floor((sh - HUD_H) / CELL)

    grid      = Automata.new(GW, GH)
    grid.wrap = false

    reset()
end

function state.exit() end

function state.update(dt)
    -- player movement
    local dx, dy = 0, 0
    if love.keyboard.isDown("w", "up")    then dy = dy - 1 end
    if love.keyboard.isDown("s", "down")  then dy = dy + 1 end
    if love.keyboard.isDown("a", "left")  then dx = dx - 1 end
    if love.keyboard.isDown("d", "right") then dx = dx + 1 end

    if dx ~= 0 and dy ~= 0 then dx = dx * 0.707 ; dy = dy * 0.707 end

    player.x = player.x + dx * PLAYER_SPEED * dt
    player.y = player.y + dy * PLAYER_SPEED * dt
    player.x, player.y = resolvePlayer(grid, player.x, player.y)

    -- CA step
    stepTimer = stepTimer + dt
    if stepTimer >= STEP_RATE then
        stepTimer = stepTimer - STEP_RATE
        updateScorched(grid, scorched)
        grid:step(fireRule)
    end
end

function state.draw()
    love.graphics.clear(C.bg[1], C.bg[2], C.bg[3])

    local cs = CELL - 1

    for y = 1, GH do
        for x = 1, GW do
            local v  = grid.cells[y][x]
            local px = (x - 1) * CELL
            local py = (y - 1) * CELL

            if v == STONE then
                love.graphics.setColor(C.stone[1], C.stone[2], C.stone[3])
                love.graphics.rectangle("fill", px, py, cs, cs)

            elseif v == WOOD then
                love.graphics.setColor(C.wood[1], C.wood[2], C.wood[3])
                love.graphics.rectangle("fill", px, py, cs, cs)

            elseif v >= FIRE_MIN then
                local e = fireLUT[math.min(255, v)]
                love.graphics.setColor(e[1], e[2], e[3])
                love.graphics.rectangle("fill", px, py, cs, cs)

            elseif scorched[y][x] then
                love.graphics.setColor(C.ash[1], C.ash[2], C.ash[3])
                love.graphics.rectangle("fill", px, py, cs, cs)
            end
        end
    end

    -- player
    love.graphics.setColor(C.player[1], C.player[2], C.player[3])
    love.graphics.circle("fill", player.x, player.y, PLAYER_R)
    love.graphics.setColor(1, 1, 1, 0.45)
    love.graphics.circle("line", player.x, player.y, PLAYER_R)

    -- explosion preview circle at mouse
    local mx, my = love.mouse.getPosition()
    love.graphics.setColor(C.crosshair[1], C.crosshair[2], C.crosshair[3], 0.65)
    love.graphics.circle("line", mx, my, EXPLODE_R * CELL)
    love.graphics.setColor(C.crosshair[1], C.crosshair[2], C.crosshair[3], 0.12)
    love.graphics.circle("fill", mx, my, EXPLODE_R * CELL)

    -- HUD bar
    local sw, sh = love.graphics.getDimensions()
    local barY   = GH * CELL
    love.graphics.setColor(C.hud_bg[1], C.hud_bg[2], C.hud_bg[3], 0.80)
    love.graphics.rectangle("fill", 0, barY, sw, sh - barY)

    love.graphics.setFont(fntBig)
    love.graphics.setColor(C.hud_txt[1], C.hud_txt[2], C.hud_txt[3], 0.92)
    love.graphics.print("Destructible Terrain + Fire Spread", 10, barY + 6)

    love.graphics.setFont(fntSml)
    love.graphics.setColor(C.hud_hint[1], C.hud_hint[2], C.hud_hint[3])
    love.graphics.print(
        "WASD move   LMB explode   R regenerate   ESC menu",
        10, barY + 26)

    love.graphics.setColor(1, 1, 1, 1)
end

function state.mousepressed(mx, my, button)
    if button == 1 then
        local cx = math.floor(mx / CELL) + 1
        local cy = math.floor(my / CELL) + 1
        explode(grid, cx, cy)
    end
end

function state.keypressed(key)
    if key == "r" then
        reset()
    elseif key == "escape" then
        Gamestate.switch(States.menu)
    end
end

function state.resize(w, h)
    local nW = math.floor(w / CELL)
    local nH = math.floor((h - HUD_H) / CELL)
    if nW == GW and nH == GH then return end
    GW, GH    = nW, nH
    grid      = Automata.new(GW, GH)
    grid.wrap = false
    reset()
end

------------------------------------------------------------------------
-- RECIPE NOTES
--
-- Extracting a usable tilemap after fire burns through:
--   -- after N steps, cells that are AIR+scorched = destroyed floor
--   -- cells that are WOOD = intact fuel
--   -- cells that are STONE = permanent wall
--
-- Making fire spread faster / slower:
--   STEP_RATE = 0.03   → frantic (30 steps/sec)
--   STEP_RATE = 0.20   → slow creep
--
-- Adding a "wind" effect: bias ignition probability in the fireRule
--   by direction, e.g. multiply by (dx == 1 ? 2.0 : 0.5) for eastward wind.
--
-- Connecting to the dungeon recipe (automata.lua → cave gen):
--   1. generate cave map with Automata.rules.cave
--   2. copy result into a second grid as WOOD / STONE cells
--   3. run fire_terrain on that grid for environmental hazards
------------------------------------------------------------------------

return state
