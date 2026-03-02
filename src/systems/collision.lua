-- src/systems/collision.lua
-- Pure collision detection — zero LÖVE dependencies
-- Shapes: { type="rect",   x, y, w, h }
--         { type="circle", x, y, radius }
--
-- Usage:
--   local Col = require("src.systems.collision")
--   Col.rectRect(a, b)        → bool
--   Col.circleCircle(a, b)    → bool
--   Col.circleRect(c, r)      → bool
--   Col.overlap(a, b)         → bool  (auto-dispatch by type)
--   Col.pointInRect(px,py, r) → bool
--   Col.pointInCircle(px,py,c)→ bool
--   Col.pointInShape(px,py,s) → bool
--   Col.rectRectMTV(a, b)     → dx, dy  (minimum translation vector)
--   Col.sweepRect(a, va, b)   → t (0..1 time of impact, or nil)

local Col = {}

-- -------------------------
-- Basic overlap tests
-- -------------------------
function Col.rectRect(a, b)
    return a.x < b.x + b.w
       and b.x < a.x + a.w
       and a.y < b.y + b.h
       and b.y < a.y + a.h
end

function Col.circleCircle(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local r  = a.radius + b.radius
    return dx*dx + dy*dy < r*r
end

function Col.circleRect(c, r)
    -- Nearest point on rect to circle center
    local nearX = math.max(r.x, math.min(c.x, r.x + r.w))
    local nearY = math.max(r.y, math.min(c.y, r.y + r.h))
    local dx    = c.x - nearX
    local dy    = c.y - nearY
    return dx*dx + dy*dy < c.radius * c.radius
end

-- Auto-dispatch by shape type
function Col.overlap(a, b)
    local at, bt = a.type, b.type
    if at == "rect"   and bt == "rect"   then return Col.rectRect(a, b)   end
    if at == "circle" and bt == "circle" then return Col.circleCircle(a, b) end
    if at == "circle" and bt == "rect"   then return Col.circleRect(a, b)  end
    if at == "rect"   and bt == "circle" then return Col.circleRect(b, a)  end
    return false
end

-- -------------------------
-- Point tests
-- -------------------------
function Col.pointInRect(px, py, r)
    return px >= r.x and px <= r.x + r.w
       and py >= r.y and py <= r.y + r.h
end

function Col.pointInCircle(px, py, c)
    local dx = px - c.x
    local dy = py - c.y
    return dx*dx + dy*dy <= c.radius * c.radius
end

function Col.pointInShape(px, py, s)
    if s.type == "rect"   then return Col.pointInRect(px, py, s)   end
    if s.type == "circle" then return Col.pointInCircle(px, py, s) end
    return false
end

-- -------------------------
-- Minimum Translation Vector (push-apart)
-- Returns dx, dy to move `a` out of `b`, or nil if not overlapping
-- -------------------------
function Col.rectRectMTV(a, b)
    if not Col.rectRect(a, b) then return nil end
    local overlapL = (a.x + a.w) - b.x
    local overlapR = (b.x + b.w) - a.x
    local overlapT = (a.y + a.h) - b.y
    local overlapB = (b.y + b.h) - a.y
    -- Pick smallest axis
    if overlapL < overlapR and overlapL < overlapT and overlapL < overlapB then
        return -overlapL, 0
    elseif overlapR < overlapT and overlapR < overlapB then
        return overlapR, 0
    elseif overlapT < overlapB then
        return 0, -overlapT
    else
        return 0, overlapB
    end
end

-- -------------------------
-- Swept AABB: moving rect `a` with velocity `va={dx,dy}` vs static rect `b`
-- Returns time of impact t in [0,1], and normal nx,ny — or nil if no hit
-- -------------------------
function Col.sweepRect(a, va, b)
    local dx, dy = va.dx or 0, va.dy or 0
    if dx == 0 and dy == 0 then return nil end

    -- Expand b by a's half-size (Minkowski sum)
    local ex = b.x - a.w/2
    local ey = b.y - a.h/2
    local ew = b.w + a.w
    local eh = b.h + a.h
    local cx = a.x + a.w/2
    local cy = a.y + a.h/2

    -- Ray vs expanded AABB
    local txEntry = dx ~= 0 and (ex         - cx) / dx or -math.huge
    local txExit  = dx ~= 0 and (ex + ew    - cx) / dx or  math.huge
    local tyEntry = dy ~= 0 and (ey         - cy) / dy or -math.huge
    local tyExit  = dy ~= 0 and (ey + eh    - cy) / dy or  math.huge

    if txEntry > txExit then txEntry, txExit = txExit, txEntry end
    if tyEntry > tyExit then tyEntry, tyExit = tyExit, tyEntry end

    local tEntry = math.max(txEntry, tyEntry)
    local tExit  = math.min(txExit,  tyExit)

    if tEntry > tExit or tEntry > 1 or tExit < 0 then return nil end

    local t  = math.max(0, tEntry)
    local nx = txEntry > tyEntry and (dx < 0 and 1 or -1) or 0
    local ny = txEntry < tyEntry and (dy < 0 and 1 or -1) or 0
    return t, nx, ny
end

-- -------------------------
-- Broad phase: filter a list to only shapes near a given shape
-- Uses bounding box for fast rejection
-- -------------------------
function Col.broadPhase(shape, list, margin)
    margin = margin or 0
    local bx, by, bw, bh
    if shape.type == "rect" then
        bx, by, bw, bh = shape.x, shape.y, shape.w, shape.h
    else
        bx = shape.x - shape.radius
        by = shape.y - shape.radius
        bw = shape.radius * 2
        bh = shape.radius * 2
    end
    local result = {}
    for _, s in ipairs(list) do
        if s ~= shape then
            local sx, sy, sw, sh
            if s.type == "rect" then
                sx, sy, sw, sh = s.x, s.y, s.w, s.h
            else
                sx = s.x - s.radius
                sy = s.y - s.radius
                sw = s.radius * 2
                sh = s.radius * 2
            end
            if bx < sx+sw+margin and sx < bx+bw+margin
            and by < sy+sh+margin and sy < by+bh+margin then
                table.insert(result, s)
            end
        end
    end
    return result
end

return Col
