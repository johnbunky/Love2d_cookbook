-- src/states/examples/cellular_automata.lua
-- Interactive cellular-automata demo for the LOVE2D cookbook
--
-- ── CONTROLS ────────────────────────────────────────────────────────
--  SPACE        play / pause
--  R            reseed grid              C        clear grid
--  TAB          next rule                1-7      jump to rule
--  + / -        speed up / down
--  LMB          paint alive cells        RMB      erase cells
--  B            enter BIRTH edit mode    (rule 7 "Custom" only)
--  V            enter SURVIVE edit mode  (rule 7 "Custom" only)
--  0-8          (in edit mode) toggle that neighbour count
--  ESC          exit edit mode / back to menu
-- ────────────────────────────────────────────────────────────────────
--
-- NOTE on gamestate.lua's call() convention:
--   current[fn](...)  — no self passed.
--   All state functions must use DOT syntax: function state.foo()
--   Never colon syntax: function state:foo()  ← self would be nil

local Automata = require "src.systems.automata"

------------------------------------------------------------------------
-- CONFIG
------------------------------------------------------------------------
local CELL = 9
local GAP  = 1

local SPEEDS       = { 1, 0.5, 0.2, 0.1, 0.05, 0.025, 1/60 }
local SPEED_LABELS = { "1/s","2/s","5/s","10/s","20/s","40/s","60/s" }

local HUD_H = 56

------------------------------------------------------------------------
-- FIRE COLOUR LUT
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

------------------------------------------------------------------------
-- RULE + PALETTE DEFINITIONS
------------------------------------------------------------------------
local RULES = {
    {
        label = "Conway's Life", note = "B3/S23",
        seed  = 0.35, wrap = true,
        bg    = { 0.02, 0.03, 0.06 },
        color = function(v)
            if v == 0 then return 0.02, 0.03, 0.06 end
            return 0.18, 0.95, 0.65
        end,
        rule = Automata.rules.conway,
    },
    {
        label = "Cave Gen", note = "B5678/S45678",
        seed  = 0.47, wrap = false,
        bg    = { 0.06, 0.05, 0.03 },
        color = function(v)
            if v == 0 then return 0.06, 0.05, 0.03 end
            return 0.58, 0.52, 0.42
        end,
        rule = Automata.rules.cave,
    },
    {
        label = "Maze", note = "B3/S12345",
        seed  = 0.04, wrap = true,
        bg    = { 0, 0, 0 },
        color = function(v)
            if v == 0 then return 0, 0, 0 end
            return 0.25, 0.55, 1.00
        end,
        rule = Automata.rules.maze,
    },
    {
        label = "Coral", note = "B3/S45678",
        seed  = 0.07, wrap = true,
        bg    = { 0.02, 0.04, 0.14 },
        color = function(v)
            if v == 0 then return 0.02, 0.04, 0.14 end
            return 0.10, 0.82, 0.72
        end,
        rule = Automata.rules.coral,
    },
    {
        label = "Seeds", note = "B2/S",
        seed  = 0.30, wrap = true,
        bg    = { 0, 0, 0 },
        color = function(v)
            if v == 0 then return 0, 0, 0 end
            return 1.00, 0.92, 0.28
        end,
        rule = Automata.rules.seeds,
    },
    {
        label = "Fire Spread", note = "custom multi-state",
        seed  = 0.00, wrap = false,
        bg    = { 0, 0, 0 },
        color = function(v)
            local e = fireLUT[math.min(255, math.max(0, v))]
            return e[1], e[2], e[3]
        end,
        rule = Automata.rules.fire,
    },
    {
        label = "Custom", note = "B3/S23",
        seed  = 0.35, wrap = true,
        bg    = { 0.04, 0.00, 0.08 },
        color = function(v)
            if v == 0 then return 0.04, 0.00, 0.08 end
            return 0.85, 0.28, 1.00
        end,
        rule = nil,   -- built by rebuildCustom()
    },
}

------------------------------------------------------------------------
-- CUSTOM RULE EDITOR
------------------------------------------------------------------------
local customBirth   = { [3]=true }
local customSurvive = { [2]=true, [3]=true }

local function rebuildCustom()
    local bstr, sstr = "", ""
    for i = 0, 8 do
        if customBirth[i]   then bstr = bstr .. i end
        if customSurvive[i] then sstr = sstr .. i end
    end
    local notation = "B" .. bstr .. "/S" .. sstr
    RULES[7].note  = notation
    RULES[7].rule  = Automata.parseBS(notation)
end
rebuildCustom()

------------------------------------------------------------------------
-- SIMULATION STATE  (module-level locals; reset in state.enter)
------------------------------------------------------------------------
local grid
local gW, gH
local ruleIdx  = 1
local paused   = false
local speedIdx = 4
local timer    = 0
local editMode = nil   -- nil | "birth" | "survive"

local fntBig, fntMed, fntSml

------------------------------------------------------------------------
-- PRIVATE HELPERS
------------------------------------------------------------------------
local function def() return RULES[ruleIdx] end

local function reseed()
    local d = def()
    grid.wrap = d.wrap
    grid:fill(d.seed)
    timer = 0
end

local function switchRule(idx)
    ruleIdx  = ((idx - 1) % #RULES) + 1
    editMode = nil
    reseed()
end

local function mouseCell()
    local mx, my = love.mouse.getPosition()
    return math.floor(mx / CELL) + 1,
           math.floor(my / CELL) + 1
end

local function paintBrush(cx, cy, value)
    for dy = -1, 1 do
        for dx = -1, 1 do
            grid:set(cx + dx, cy + dy, value)
        end
    end
end

-- Separated from state.draw so it can call love.graphics freely
-- without needing self.
local function drawHUD()
    local sw, sh = love.graphics.getDimensions()
    local barY   = gH * CELL
    local d      = def()

    love.graphics.setColor(0, 0, 0, 0.78)
    love.graphics.rectangle("fill", 0, barY, sw, sh - barY)

    love.graphics.setFont(fntBig)
    love.graphics.setColor(1, 1, 1, 0.92)
    love.graphics.print(
        string.format("[%d] %s   (%s)   gen %d   %s   %s",
            ruleIdx, d.label, d.note,
            grid.generation,
            SPEED_LABELS[speedIdx],
            paused and "|| PAUSED" or ">"),
        10, barY + 6)

    love.graphics.setFont(fntSml)
    love.graphics.setColor(0.52, 0.52, 0.52, 0.9)
    love.graphics.print(
        "SPACE pause   R reseed   C clear   TAB/1-7 rule   +/- speed" ..
        "   LMB paint   RMB erase   B birth   V survive (rule 7)   ESC menu",
        10, barY + 28)

    if editMode then
        local oy = barY - 54
        love.graphics.setColor(0, 0, 0, 0.65)
        love.graphics.rectangle("fill", 0, oy - 4, sw, 50)

        love.graphics.setFont(fntMed)
        love.graphics.setColor(1, 0.82, 0.18, 1)
        love.graphics.print(
            "EDIT  " ..
            (editMode == "birth" and "BIRTH (B)" or "SURVIVE (V)") ..
            "  --  press 0-8 to toggle    ESC to close",
            10, oy)

        for i = 0, 8 do
            local tbl = editMode == "birth" and customBirth or customSurvive
            local on  = tbl[i]
            local bx  = 10 + i * 30
            love.graphics.setColor(on and {0.25,0.12,0.45,1} or {0.10,0.10,0.10,1})
            love.graphics.rectangle("fill", bx, oy + 18, 24, 22, 3, 3)
            love.graphics.setFont(fntBig)
            love.graphics.setColor(on and {1,0.82,0.18,1} or {0.38,0.38,0.38,1})
            love.graphics.print(tostring(i), bx + 7, oy + 20)
        end

        love.graphics.setFont(fntMed)
        love.graphics.setColor(0.68, 0.68, 0.68, 0.85)
        love.graphics.print("->  " .. RULES[7].note, 290, oy + 22)
    end
end

------------------------------------------------------------------------
-- STATE TABLE  — dot syntax throughout (gamestate.lua passes no self)
------------------------------------------------------------------------
local state = {}

function state.enter()
    fntBig = love.graphics.newFont(15)
    fntMed = love.graphics.newFont(12)
    fntSml = love.graphics.newFont(10)

    local sw, sh = love.graphics.getDimensions()
    gW   = math.floor(sw / CELL)
    gH   = math.floor((sh - HUD_H) / CELL)
    grid = Automata.new(gW, gH)

    ruleIdx  = 1
    paused   = false
    speedIdx = 4
    timer    = 0
    editMode = nil

    switchRule(1)
end

function state.exit()
    -- grid / fonts will be GC'd; nothing else to release
end

function state.update(dt)
    local cx, cy = mouseCell()
    if love.mouse.isDown(1) then
        paintBrush(cx, cy, 1)
    elseif love.mouse.isDown(2) then
        paintBrush(cx, cy, 0)
    end

    if paused then return end

    timer = timer + dt
    local interval = SPEEDS[speedIdx]
    while timer >= interval do
        local d = def()
        if d.rule then grid:step(d.rule) end
        timer = timer - interval
    end
end

function state.draw()
    local d  = def()
    local bg = d.bg
    love.graphics.clear(bg[1], bg[2], bg[3])

    local cs = CELL - GAP
    for y = 1, gH do
        for x = 1, gW do
            local v = grid.cells[y][x]
            if v > 0 then
                local r, g, b = d.color(v)
                love.graphics.setColor(r, g, b)
                love.graphics.rectangle("fill",
                    (x-1)*CELL, (y-1)*CELL, cs, cs)
            end
        end
    end

    drawHUD()

    love.graphics.setColor(1, 1, 1, 1)
end

function state.keypressed(key)
    if editMode and tonumber(key) then
        local n = tonumber(key)
        if n <= 8 then
            local tbl = editMode == "birth" and customBirth or customSurvive
            tbl[n] = not tbl[n]
            rebuildCustom()
            ruleIdx   = 7
            grid.wrap = RULES[7].wrap
        end
        return
    end

    if     key == "space" then
        paused = not paused

    elseif key == "r" then
        reseed()

    elseif key == "c" then
        grid:clear()

    elseif key == "tab" then
        switchRule(ruleIdx + 1)

    elseif key == "=" or key == "+" or key == "kp+" then
        speedIdx = math.min(speedIdx + 1, #SPEEDS)

    elseif key == "-" or key == "kp-" then
        speedIdx = math.max(speedIdx - 1, 1)

    elseif key == "b" then
        ruleIdx  = 7
        editMode = editMode == "birth" and nil or "birth"

    elseif key == "v" then
        ruleIdx  = 7
        editMode = editMode == "survive" and nil or "survive"

    elseif key == "escape" then
        if editMode then
            editMode = nil
        else
            Gamestate.switch(States.menu)
        end

    elseif tonumber(key) then
        local n = tonumber(key)
        if n >= 1 and n <= #RULES then switchRule(n) end
    end
end

function state.resize(w, h)
    local nW = math.floor(w / CELL)
    local nH = math.floor((h - HUD_H) / CELL)
    if nW == gW and nH == gH then return end

    local old = grid
    gW, gH = nW, nH
    grid   = Automata.new(gW, gH)
    grid.wrap = old.wrap

    for y = 1, math.min(gH, old.h) do
        for x = 1, math.min(gW, old.w) do
            grid.cells[y][x] = old.cells[y][x]
        end
    end
end

------------------------------------------------------------------------
-- RECIPE NOTES
-- • Cave gen (rule 2): reseed, let run ~5 steps, pause.
--   grid.cells[y][x] is your dungeon map: 1=wall, 0=floor.
--
-- • Fire (rule 6): runs autonomously. LMB adds fuel, RMB cuts firebreaks.
--
-- • Seeds (rule 5): clear (C), click one cell, watch symmetric explosions.
--
-- • Custom (rule 7): press B then 0-8 to toggle birth counts live;
--   press V then 0-8 to toggle survive counts. Rule rebuilds each keypress.
--
-- • Performance — for grids > ~300x200 replace the rectangle loop with:
--     local img = love.image.newImageData(gW, gH)
--     local tex = love.graphics.newImage(img)
--     -- per step: img:setPixel(x-1, y-1, r, g, b, 1) for each cell
--     -- tex:replacePixels(img)
--     -- draw: love.graphics.draw(tex, 0, 0, 0, CELL, CELL)
------------------------------------------------------------------------

return state
