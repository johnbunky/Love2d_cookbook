-- src/systems/automata.lua
-- Engine-agnostic cellular automata grid + rule system
-- Supports binary (0/1) and multi-state (0-255) rules
-- No LOVE2D dependency — pure Lua

local Automata = {}
Automata.__index = Automata

------------------------------------------------------------------------
-- CONSTRUCTOR
------------------------------------------------------------------------

function Automata.new(w, h)
    local self = setmetatable({}, Automata)
    self.w          = w
    self.h          = h
    self.generation = 0
    self.wrap       = true   -- toroidal wrapping; set false for cave/fire

    -- cells[y][x] = integer value (0 = dead / empty)
    self.cells = {}
    self._buf  = {}          -- double-buffer; never touch directly
    for y = 1, h do
        self.cells[y] = {}
        self._buf[y]  = {}
        for x = 1, w do
            self.cells[y][x] = 0
            self._buf[y][x]  = 0
        end
    end
    return self
end

------------------------------------------------------------------------
-- SEEDING
------------------------------------------------------------------------

-- Fill with random 0/1 at the given density (0-1). Resets generation.
function Automata:fill(density)
    density = density or 0.45
    for y = 1, self.h do
        for x = 1, self.w do
            self.cells[y][x] = math.random() < density and 1 or 0
        end
    end
    self.generation = 0
    return self   -- chainable
end

-- Set all cells to 0.
function Automata:clear()
    for y = 1, self.h do
        for x = 1, self.w do
            self.cells[y][x] = 0
            self._buf[y][x]  = 0
        end
    end
    self.generation = 0
    return self
end

------------------------------------------------------------------------
-- CELL ACCESS
------------------------------------------------------------------------

-- get(x, y): safe read, respects self.wrap
function Automata:get(x, y)
    if self.wrap then
        x = ((x - 1) % self.w) + 1
        y = ((y - 1) % self.h) + 1
    elseif x < 1 or x > self.w or y < 1 or y > self.h then
        return 0
    end
    return self.cells[y][x]
end

-- set(x, y, v): safe write, no wrapping (out-of-bounds is a no-op)
function Automata:set(x, y, v)
    if x >= 1 and x <= self.w and y >= 1 and y <= self.h then
        self.cells[y][x] = v
    end
    return self
end

------------------------------------------------------------------------
-- NEIGHBOURHOOD HELPERS
------------------------------------------------------------------------

-- Count Moore neighbours (8-adjacent) whose value is > 0.
function Automata:neighbours(x, y)
    local n = 0
    for dy = -1, 1 do
        for dx = -1, 1 do
            if not (dx == 0 and dy == 0) then
                if self:get(x + dx, y + dy) > 0 then
                    n = n + 1
                end
            end
        end
    end
    return n
end

-- Count Moore neighbours equal to an exact target value.
function Automata:neighboursEq(x, y, target)
    local n = 0
    for dy = -1, 1 do
        for dx = -1, 1 do
            if not (dx == 0 and dy == 0) then
                if self:get(x + dx, y + dy) == target then
                    n = n + 1
                end
            end
        end
    end
    return n
end

------------------------------------------------------------------------
-- STEPPING
------------------------------------------------------------------------

-- Advance one generation using the provided rule function.
-- rule: function(grid, x, y) -> newValue
-- The rule is called for every cell simultaneously (double-buffered).
function Automata:step(rule)
    for y = 1, self.h do
        for x = 1, self.w do
            self._buf[y][x] = rule(self, x, y)
        end
    end
    self.cells, self._buf = self._buf, self.cells
    self.generation = self.generation + 1
    return self
end

------------------------------------------------------------------------
-- BUILT-IN RULES
------------------------------------------------------------------------
-- Each rule is a function(grid, x, y) -> newValue.
-- Pass directly to :step().

Automata.rules = {}

-- Classic Game of Life: B3/S23
-- Explosive early growth, settles into still lifes + oscillators
Automata.rules.conway = function(g, x, y)
    local v = g:get(x, y)
    local n = g:neighbours(x, y)
    if v > 0 then return (n == 2 or n == 3) and 1 or 0
    else          return n == 3              and 1 or 0 end
end

-- Cave / dungeon generation: B5678/S45678
-- Noisy fill → smooth stone walls. Run ~4 generations then stop.
-- Works best with wrap=false and seed ~0.45-0.50.
Automata.rules.cave = function(g, x, y)
    local v = g:get(x, y)
    local n = g:neighbours(x, y)
    if v > 0 then return n >= 4 and 1 or 0
    else          return n >= 5 and 1 or 0 end
end

-- Maze: B3/S12345
-- Grows long corridor-like tendrils from sparse seeds
Automata.rules.maze = function(g, x, y)
    local v = g:get(x, y)
    local n = g:neighbours(x, y)
    if v > 0 then return (n >= 1 and n <= 5) and 1 or 0
    else          return n == 3               and 1 or 0 end
end

-- Coral / Amoeba: B3/S45678
-- Dense blobs that grow outward slowly, like coral or lichen
Automata.rules.coral = function(g, x, y)
    local v = g:get(x, y)
    local n = g:neighbours(x, y)
    if v > 0 then return n >= 4 and 1 or 0
    else          return n == 3 and 1 or 0 end
end

-- Seeds: B2/S (all cells die each step, born only at exactly 2 neighbours)
-- Explosive symmetric patterns; every cell lives exactly one generation
Automata.rules.seeds = function(g, x, y)
    local n = g:neighbours(x, y)
    return (g:get(x, y) == 0 and n == 2) and 1 or 0
end

-- Fire spread: multi-state (0-255 = heat level)
-- Bottom row: random ignition. Heat rises with turbulent decay.
-- Use wrap=false. Values are NOT binary.
Automata.rules.fire = function(g, x, y)
    -- Heat source: re-ignite bottom row randomly each step
    if y == g.h then
        return math.random() < 0.55 and (170 + math.random(85)) or 0
    end

    -- Heat rises: sample the cell below and its neighbours
    local dn  = g:get(x,     y + 1)
    local dnl = g:get(x - 1, y + 1)
    local dnr = g:get(x + 1, y + 1)
    local cur = g:get(x,     y    )

    -- Take the hottest nearby influence, weighted for directionality
    local heat = math.max(dn, dnl * 0.55, dnr * 0.55, cur * 0.75)

    -- Decay + flicker
    heat = heat - (6 + math.random(20))
    if math.random() < 0.07 then heat = heat - 45 end   -- sudden snuff-out

    return math.max(0, math.floor(heat))
end

------------------------------------------------------------------------
-- B/S RULE FACTORY
------------------------------------------------------------------------
-- Build a rule function from standard Golly notation, e.g. "B36/S23".

function Automata.parseBS(notation)
    local bstr, sstr = notation:match("B([0-8]*)/S([0-8]*)")
    assert(bstr and sstr, "Invalid B/S notation: " .. tostring(notation))
    local birth, survive = {}, {}
    for c in bstr:gmatch("%d") do birth[tonumber(c)]   = true end
    for c in sstr:gmatch("%d") do survive[tonumber(c)] = true end
    return function(g, x, y)
        local v = g:get(x, y)
        local n = g:neighbours(x, y)
        if v > 0 then return survive[n] and 1 or 0
        else          return birth[n]   and 1 or 0 end
    end
end

------------------------------------------------------------------------
-- RULE METADATA  (display names, sensible defaults)
------------------------------------------------------------------------

Automata.meta = {
    conway = { label="Conway's Life", notation="B3/S23",      seed=0.35, wrap=true  },
    cave   = { label="Cave Gen",      notation="B5678/S45678",seed=0.47, wrap=false },
    maze   = { label="Maze",          notation="B3/S12345",   seed=0.04, wrap=true  },
    coral  = { label="Coral",         notation="B3/S45678",   seed=0.08, wrap=true  },
    seeds  = { label="Seeds",         notation="B2/S",        seed=0.28, wrap=true  },
    fire   = { label="Fire Spread",   notation="custom",      seed=0.00, wrap=false },
}

return Automata
