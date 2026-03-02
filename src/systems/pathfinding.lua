-- src/systems/pathfinding.lua
-- A* pathfinding on a 2D grid — zero LÖVE dependencies
-- Supports: diagonal movement, wall-cutting prevention, path smoothing
--
-- Usage:
--   local PF = require("src.systems.pathfinding")
--   local pf = PF.new(cols, rows, tileSize)
--   pf:setWalkable(col, row, true/false)
--   pf:setGrid(grid2d)           -- 2D array: 0=walkable, 1=wall
--   local path = pf:find(sc, sr, gc, gr)   -- {col,row} list or {}
--   local smooth = pf:smooth(path)
--   local wx, wy = pf:tileCenter(col, row)
--   local col, row = pf:worldToTile(wx, wy)

local PF = {}
PF.__index = PF

function PF.new(cols, rows, tileSize)
    local self = setmetatable({}, PF)
    self.cols     = cols
    self.rows     = rows
    self.tileSize = tileSize or 32
    self._grid    = {}
    -- Default: all walkable
    for i = 1, cols * rows do self._grid[i] = 0 end
    return self
end

-- -------------------------
-- Grid helpers
-- -------------------------
function PF:_idx(col, row)
    return (row - 1) * self.cols + col
end

function PF:inBounds(col, row)
    return col >= 1 and col <= self.cols
       and row >= 1 and row <= self.rows
end

function PF:setWalkable(col, row, walkable)
    if self:inBounds(col, row) then
        self._grid[self:_idx(col, row)] = walkable and 0 or 1
    end
end

function PF:isWalkable(col, row)
    if not self:inBounds(col, row) then return false end
    return self._grid[self:_idx(col, row)] == 0
end

-- Set from a flat array (1=wall, 0=open)
function PF:setGrid(flatGrid)
    self._grid = flatGrid
end

-- Set from a 2D array grid2d[row][col]
function PF:setGrid2D(grid2d)
    for r = 1, self.rows do
        for c = 1, self.cols do
            self._grid[self:_idx(c, r)] = (grid2d[r] and grid2d[r][c]) or 0
        end
    end
end

-- -------------------------
-- Coordinate helpers
-- -------------------------
function PF:tileCenter(col, row)
    return (col - 0.5) * self.tileSize,
           (row - 0.5) * self.tileSize
end

function PF:worldToTile(wx, wy)
    return math.floor(wx / self.tileSize) + 1,
           math.floor(wy / self.tileSize) + 1
end

-- -------------------------
-- A* search
-- Returns list of {col, row} from start to goal, or {} if no path
-- -------------------------
function PF:find(sc, sr, gc, gr)
    if not self:isWalkable(gc, gr) then return {} end
    if not self:inBounds(sc, sr)   then return {} end

    local function key(c, r) return c .. "," .. r end

    local open   = {}
    local closed = {}
    local gScore = {}
    local fScore = {}
    local parent = {}

    local function heuristic(ac, ar, bc, br)
        -- Octile distance
        local dc = math.abs(ac - bc)
        local dr = math.abs(ar - br)
        return math.max(dc, dr) + (math.sqrt(2) - 1) * math.min(dc, dr)
    end

    local sk = key(sc, sr)
    gScore[sk] = 0
    fScore[sk] = heuristic(sc, sr, gc, gr)
    table.insert(open, { c=sc, r=sr, f=fScore[sk] })

    local dirs = {
        {0,-1},{0,1},{-1,0},{1,0},
        {-1,-1},{1,-1},{-1,1},{1,1},
    }

    local iterations = 0
    while #open > 0 and iterations < 4000 do
        iterations = iterations + 1

        -- Pop lowest f
        local bestI, bestF = 1, open[1].f
        for i = 2, #open do
            if open[i].f < bestF then bestI=i; bestF=open[i].f end
        end
        local cur = table.remove(open, bestI)

        if cur.c == gc and cur.r == gr then
            -- Reconstruct
            local result = {}
            local k = key(gc, gr)
            while k do
                local c, r = k:match("(-?%d+),(-?%d+)")
                table.insert(result, 1, { col=tonumber(c), row=tonumber(r) })
                k = parent[k]
            end
            return result
        end

        local curKey = key(cur.c, cur.r)
        closed[curKey] = true

        for _, d in ipairs(dirs) do
            local nc, nr = cur.c + d[1], cur.r + d[2]
            if self:isWalkable(nc, nr) then
                -- Prevent diagonal wall-cutting
                local passable = true
                if d[1] ~= 0 and d[2] ~= 0 then
                    if not self:isWalkable(cur.c + d[1], cur.r)
                    or not self:isWalkable(cur.c, cur.r + d[2]) then
                        passable = false
                    end
                end
                if passable then
                    local nk = key(nc, nr)
                    if not closed[nk] then
                        local cost = (d[1] ~= 0 and d[2] ~= 0) and 1.414 or 1.0
                        local ng   = (gScore[curKey] or 0) + cost
                        if not gScore[nk] or ng < gScore[nk] then
                            gScore[nk] = ng
                            fScore[nk] = ng + heuristic(nc, nr, gc, gr)
                            parent[nk] = curKey
                            table.insert(open, { c=nc, r=nr, f=fScore[nk] })
                        end
                    end
                end
            end
        end
    end

    return {}
end

-- -------------------------
-- Path smoothing
-- Removes redundant waypoints using line-of-sight checks
-- -------------------------
function PF:smooth(rawPath)
    if #rawPath <= 2 then return rawPath end
    local smooth = { rawPath[1] }
    local i = 1
    while i < #rawPath do
        local j = #rawPath
        while j > i + 1 do
            local clear = true
            local steps = math.max(
                math.abs(rawPath[j].col - rawPath[i].col),
                math.abs(rawPath[j].row - rawPath[i].row)) * 2
            for s = 0, steps do
                local t  = s / steps
                local lc = math.floor(rawPath[i].col + (rawPath[j].col - rawPath[i].col) * t + 0.5)
                local lr = math.floor(rawPath[i].row + (rawPath[j].row - rawPath[i].row) * t + 0.5)
                if not self:isWalkable(lc, lr) then
                    clear = false
                    break
                end
            end
            if clear then break end
            j = j - 1
        end
        table.insert(smooth, rawPath[j])
        i = j
    end
    return smooth
end

-- -------------------------
-- Utility: path length in world units
-- -------------------------
function PF:pathLength(path)
    local len = 0
    for i = 2, #path do
        local ax, ay = self:tileCenter(path[i-1].col, path[i-1].row)
        local bx, by = self:tileCenter(path[i].col,   path[i].row)
        local dx, dy = bx - ax, by - ay
        len = len + math.sqrt(dx*dx + dy*dy)
    end
    return len
end

-- -------------------------
-- Utility: follow a path, returns current world target
-- agent = { col, row } current tile, speed in world units/sec
-- -------------------------
function PF:nextWaypoint(path, idx)
    if not path or #path == 0 then return nil, idx end
    idx = math.max(1, math.min(idx, #path))
    local wx, wy = self:tileCenter(path[idx].col, path[idx].row)
    return { x=wx, y=wy, col=path[idx].col, row=path[idx].row }, idx
end

return PF
