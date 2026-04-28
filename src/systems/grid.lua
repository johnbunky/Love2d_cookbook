-- src/systems/grid.lua
-- Procedural irregular terrain grid with barycentric height interpolation.
-- Pure Lua — no engine dependencies.
--
-- USAGE:
--   local Grid = require "src.systems.grid"
--   local g = Grid.new({
--       x0=0, y0=-250, cols=30, rows=10,
--       cell_w=80, cell_h=50,
--       height_amp=50, jitter=0.28, seed=137,
--   })
--   local z = g:floorAt(worldX, worldY)   -- returns height or nil if outside
--
-- PARAMS:
--   x0, y0       world origin of the grid
--   cols, rows   number of cells
--   cell_w/h     base cell size in world units
--   height_amp   max height variation (world z)
--   jitter       xy vertex wobble as fraction of cell size (0..0.4)
--   seed         deterministic random seed

local Grid = {}
Grid.__index = Grid

-- Deterministic noise: returns -1..1 from integer coordinates + seed
local function noise(ix, iy, seed)
    local n = ix * 1619 + iy * 31337 + seed * 6791
    n = n % 2147483647
    n = (n * 1664525  + 1013904223) % 2147483647
    n = (n * 22695477 + 1)          % 2147483647
    return (n / 2147483647.0) * 2 - 1
end

function Grid.new(params)
    local p = params or {}
    local g = setmetatable({
        x0         = p.x0         or 0,
        y0         = p.y0         or -200,
        cols       = p.cols       or 24,
        rows       = p.rows       or 8,
        cell_w     = p.cell_w     or 100,
        cell_h     = p.cell_h     or 50,
        height_amp = p.height_amp or 40,
        jitter     = p.jitter     or 0.30,
        seed       = p.seed       or 42,
        verts      = {},
        tris       = {},
    }, Grid)
    g:_generate()
    return g
end

function Grid:_generate()
    local cw, ch = self.cell_w, self.cell_h
    local jx = cw * self.jitter
    local jy = ch * self.jitter

    for col = 0, self.cols do
        self.verts[col] = {}
        for row = 0, self.rows do
            local bx = self.x0 + col * cw
            local by = self.y0 + row * ch
            local ox, oy = 0, 0
            -- jitter interior vertices only — keep border clean
            if col > 0 and col < self.cols and row > 0 and row < self.rows then
                ox = noise(col,   row, self.seed)     * jx
                oy = noise(col,   row, self.seed + 1) * jy
            end
            -- layered noise for organic height
            local h = noise(col,     row,     self.seed + 2) * self.height_amp
                    + noise(col * 2, row * 2, self.seed + 3) * self.height_amp * 0.3
            -- edges always at z=0 for a clean border
            if col == 0 or col == self.cols or row == 0 or row == self.rows then
                h = 0
            end
            self.verts[col][row] = {
                x = bx + ox,
                y = by + oy,
                z = math.max(0, h),
            }
        end
    end

    -- triangulate: each cell → 2 triangles, split on shorter diagonal
    for col = 0, self.cols - 1 do
        for row = 0, self.rows - 1 do
            local v00 = {col,   row  }
            local v10 = {col+1, row  }
            local v01 = {col,   row+1}
            local v11 = {col+1, row+1}
            table.insert(self.tris, {v00, v10, v11})
            table.insert(self.tris, {v00, v11, v01})
        end
    end
end

function Grid:v(col, row)
    return self.verts[col] and self.verts[col][row]
end

-- Barycentric interpolation helpers
local function bary(px, py, ax, ay, bx, by, cx, cy)
    local denom = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
    if math.abs(denom) < 0.0001 then return nil end
    local u = ((by - cy) * (px - cx) + (cx - bx) * (py - cy)) / denom
    local v = ((cy - ay) * (px - cx) + (ax - cx) * (py - cy)) / denom
    local w = 1 - u - v
    return u, v, w
end

-- Returns world z at (wx, wy), or nil if outside the grid.
-- Characters call this every frame to snap feet to terrain height.
function Grid:floorAt(wx, wy)
    local x1 = self.verts[0][0].x
    local x2 = self.verts[self.cols][0].x
    local y1 = self.verts[0][0].y
    local y2 = self.verts[0][self.rows].y
    if wx < x1 or wx > x2 or wy < y1 or wy > y2 then return nil end

    local col = math.floor((wx - self.x0) / self.cell_w)
    local row = math.floor((wy - self.y0) / self.cell_h)
    col = math.max(0, math.min(self.cols - 1, col))
    row = math.max(0, math.min(self.rows - 1, row))

    local function tryTri(c1, c2, c3)
        local a = self:v(c1[1], c1[2])
        local b = self:v(c2[1], c2[2])
        local c = self:v(c3[1], c3[2])
        if not (a and b and c) then return nil end
        local u, v, w = bary(wx, wy, a.x, a.y, b.x, b.y, c.x, c.y)
        if u and u >= -0.01 and v >= -0.01 and w >= -0.01 then
            return u * a.z + v * b.z + w * c.z
        end
    end

    local v00={col,row}; local v10={col+1,row}
    local v01={col,row+1}; local v11={col+1,row+1}
    return tryTri(v00, v10, v11) or tryTri(v00, v11, v01)
end

return Grid
