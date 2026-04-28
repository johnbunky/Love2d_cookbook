-- src/characters/grid_mesh.lua
-- Renders a Grid as a shaded triangle mesh via camera3d projection.
-- Height-based colour variation + subtle slope shading.
--
-- USAGE:
--   local GridMesh = require "src.characters.grid_mesh"
--   local mesh = GridMesh.new(grid, {
--       color      = {0.28, 0.42, 0.22},  -- high areas
--       dark_color = {0.18, 0.28, 0.14},  -- low areas
--       show_edges = true,
--   })
--   -- each frame:
--   mesh:draw(camera)   -- camera must have :toScreen(x,y,z)

local GridMesh = {}
GridMesh.__index = GridMesh

function GridMesh.new(grid, opts)
    opts = opts or {}
    return setmetatable({
        grid       = grid,
        base_col   = opts.color       or {0.28, 0.42, 0.22},
        dark_col   = opts.dark_color  or {0.18, 0.28, 0.14},
        edge_col   = opts.edge_color  or {0.22, 0.34, 0.18},
        show_edges = opts.show_edges ~= false,
    }, GridMesh)
end

local function lerpCol(a, b, t)
    return {
        a[1] + (b[1] - a[1]) * t,
        a[2] + (b[2] - a[2]) * t,
        a[3] + (b[3] - a[3]) * t,
    }
end

function GridMesh:draw(camera)
    local g    = self.grid
    local hmax = g.height_amp

    for _, tri in ipairs(g.tris) do
        local a = g:v(tri[1][1], tri[1][2])
        local b = g:v(tri[2][1], tri[2][2])
        local c = g:v(tri[3][1], tri[3][2])
        if a and b and c then
            local ax, ay = camera:toScreen(a.x, a.y, a.z)
            local bx, by = camera:toScreen(b.x, b.y, b.z)
            local cx, cy = camera:toScreen(c.x, c.y, c.z)

            -- height-based colour blend
            local avg_h = (a.z + b.z + c.z) / 3
            local t     = math.min(1, avg_h / hmax)
            local col   = lerpCol(self.dark_col, self.base_col, t)

            -- slope shading: steeper = darker
            local slope = math.abs(b.z - a.z) + math.abs(c.z - a.z)
            local shade = math.max(0.7, 1 - slope / 60)

            love.graphics.setColor(col[1]*shade, col[2]*shade, col[3]*shade, 0.92)
            love.graphics.polygon("fill", ax, ay, bx, by, cx, cy)

            if self.show_edges then
                love.graphics.setColor(
                    self.edge_col[1], self.edge_col[2], self.edge_col[3], 0.35)
                love.graphics.setLineWidth(0.5)
                love.graphics.polygon("line", ax, ay, bx, by, cx, cy)
            end
        end
    end
end

return GridMesh
