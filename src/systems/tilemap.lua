-- src/tilemap.lua
-- Reusable tilemap module.
--
-- Usage (color mode — no assets needed):
--   local tm = Tilemap.new(MAP, 32)
--   Tilemap.draw(tm, cam)
--
-- Usage (tileset/sprite mode):
--   Tilemap.setTileset(tm, "tiles", 16, 16, {
--       [Tilemap.T.SOLID]   = {0, 0},   -- col, row on spritesheet (0-based)
--       [Tilemap.T.ONE_WAY] = {1, 0},
--       [Tilemap.T.HAZARD]  = {2, 0},
--       [Tilemap.T.COIN]    = {3, 0},
--   })
--   Tilemap.draw(tm, cam)   -- automatically uses sprites

local Camera  = require("src.systems.camera")
local Assets  = require("src.assets")
local Tilemap = {}

-- -------------------------
-- Tile type constants
-- -------------------------
Tilemap.T = {
    EMPTY   = 0,
    SOLID   = 1,
    ONE_WAY = 2,
    HAZARD  = 3,
    COIN    = 4,
}

-- Default fallback colors (used when no tileset is set)
Tilemap.defaultColors = {
    [1] = { fill={0.35,0.45,0.55}, line={0.25,0.35,0.45} },  -- SOLID
    [2] = { fill={0.55,0.70,0.40}, line={0.45,0.60,0.30} },  -- ONE_WAY
    [3] = { fill={0.80,0.25,0.25}, line={0.70,0.15,0.15} },  -- HAZARD
    [4] = { fill={0.90,0.80,0.20}, line={0.80,0.70,0.10} },  -- COIN
}

-- -------------------------
-- Create a new tilemap
-- -------------------------
function Tilemap.new(map, tileSize)
    local tm = {
        map      = map,
        tileSize = tileSize or 32,
        rows     = #map,
        cols     = #map[1],
        colors   = Tilemap.defaultColors,
        tileset  = nil,
    }
    tm.worldW = tm.cols * tm.tileSize
    tm.worldH = tm.rows * tm.tileSize
    return tm
end

-- -------------------------
-- Attach a spritesheet tileset
-- imageName : key for Assets.image()
-- tileW, tileH : size of each tile on the spritesheet in pixels
-- mapping : { [tileType] = {sheetCol, sheetRow} } — 0-based
-- -------------------------
function Tilemap.setTileset(tm, imageName, tileW, tileH, mapping)
    local img = Assets.image(imageName)
    if not img then
        print("[Tilemap] tileset image not found: " .. imageName)
        return
    end
    tileW = tileW or tm.tileSize
    tileH = tileH or tm.tileSize
    local quads = {}
    local iw, ih = img:getDimensions()
    for tileType, pos in pairs(mapping) do
        local sx = pos[1] * tileW
        local sy = pos[2] * tileH
        quads[tileType] = love.graphics.newQuad(sx, sy, tileW, tileH, iw, ih)
    end
    tm.tileset = { image=img, tileW=tileW, tileH=tileH, quads=quads }
end

-- -------------------------
-- Safe tile lookup
-- -------------------------
function Tilemap.getTile(tm, col, row)
    if row < 1 or row > tm.rows or col < 1 or col > tm.cols then
        return Tilemap.T.SOLID
    end
    return tm.map[row][col]
end

-- -------------------------
-- Set a tile value
-- -------------------------
function Tilemap.setTile(tm, col, row, value)
    if row >= 1 and row <= tm.rows and col >= 1 and col <= tm.cols then
        tm.map[row][col] = value
    end
end

-- -------------------------
-- Convert world position to tile coords
-- -------------------------
function Tilemap.worldToTile(tm, wx, wy)
    return math.floor(wx / tm.tileSize) + 1,
           math.floor(wy / tm.tileSize) + 1
end

-- -------------------------
-- Get solid rects overlapping a world rect
-- -------------------------
function Tilemap.getSolids(tm, x, y, w, h, includeOneWay)
    local T     = Tilemap.T
    local ts    = tm.tileSize
    local rects = {}
    local c1, r1 = Tilemap.worldToTile(tm, x, y)
    local c2, r2 = Tilemap.worldToTile(tm, x + w - 1, y + h - 1)
    for row = r1, r2 do
        for col = c1, c2 do
            local t = Tilemap.getTile(tm, col, row)
            if t == T.SOLID or (includeOneWay and t == T.ONE_WAY) then
                table.insert(rects, {
                    x      = (col-1) * ts,
                    y      = (row-1) * ts,
                    w      = ts,
                    h      = ts,
                    oneway = (t == T.ONE_WAY),
                })
            end
        end
    end
    return rects
end

-- -------------------------
-- Check if obj overlaps any tile of given type
-- -------------------------
function Tilemap.checkType(tm, obj, tileType, shrink)
    shrink = shrink or 2
    local c1, r1 = Tilemap.worldToTile(tm, obj.x + shrink,         obj.y + shrink)
    local c2, r2 = Tilemap.worldToTile(tm, obj.x + obj.w - shrink, obj.y + obj.h - shrink)
    for row = r1, r2 do
        for col = c1, c2 do
            if Tilemap.getTile(tm, col, row) == tileType then return true end
        end
    end
    return false
end

-- -------------------------
-- Remove all tiles of given type overlapping obj, return count
-- -------------------------
function Tilemap.collect(tm, obj, tileType)
    local count = 0
    local c1, r1 = Tilemap.worldToTile(tm, obj.x,         obj.y)
    local c2, r2 = Tilemap.worldToTile(tm, obj.x + obj.w, obj.y + obj.h)
    for row = r1, r2 do
        for col = c1, c2 do
            if Tilemap.getTile(tm, col, row) == tileType then
                Tilemap.setTile(tm, col, row, Tilemap.T.EMPTY)
                count = count + 1
            end
        end
    end
    return count
end

-- -------------------------
-- Draw visible tiles
-- Automatically uses tileset sprites if set, otherwise colored rects
-- -------------------------
function Tilemap.draw(tm, cam)
    local T  = Tilemap.T
    local ts = tm.tileSize
    local c1, r1, c2, r2

    if cam then
        c1, r1, c2, r2 = Camera.visibleTiles(cam, ts)
    else
        c1, r1, c2, r2 = 1, 1, tm.cols, tm.rows
    end

    c1 = math.max(1, c1)
    r1 = math.max(1, r1)
    c2 = math.min(tm.cols, c2)
    r2 = math.min(tm.rows, r2)

    local tileset = tm.tileset

    for row = r1, r2 do
        for col = c1, c2 do
            local t = tm.map[row][col]
            if t ~= T.EMPTY then
                local tx = (col-1) * ts
                local ty = (row-1) * ts

                if tileset and tileset.quads[t] then
                    -- Sprite mode
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.draw(
                        tileset.image, tileset.quads[t],
                        tx, ty, 0,
                        ts / tileset.tileW,
                        ts / tileset.tileH)
                else
                    -- Color fallback mode
                    local colors = tm.colors[t]
                    if colors then
                        love.graphics.setColor(colors.fill)
                        love.graphics.rectangle("fill", tx, ty, ts, ts)
                        love.graphics.setColor(colors.line)
                        love.graphics.rectangle("line", tx, ty, ts, ts)
                    end
                    if t == T.ONE_WAY then
                        love.graphics.setColor(0.65, 0.85, 0.50)
                        love.graphics.rectangle("fill", tx, ty, ts, 6)
                    end
                    if t == T.COIN then
                        love.graphics.setColor(0.95, 0.85, 0.10)
                        love.graphics.circle("fill", tx+ts/2, ty+ts/2, ts/2-4)
                        love.graphics.setColor(1, 1, 0.4)
                        love.graphics.circle("line", tx+ts/2, ty+ts/2, ts/2-4)
                    end
                end
            end
        end
    end
end

return Tilemap
