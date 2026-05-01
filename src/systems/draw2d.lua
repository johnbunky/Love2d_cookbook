-- src/systems/draw2d.lua
--
-- Reusable 2-D drawing primitives.
-- No game logic, no skeleton knowledge — pure screen-space geometry.
-- Useful for characters, trees, terrain features, UI, particles, anything.
--
-- Every function expects screen-space coordinates.
-- Callers are responsible for projection (camera:toScreen) before calling.
-- Callers are responsible for love.graphics.setColor before calling,
-- EXCEPT the outlined variants (Draw.ocapsule, Draw.oplate, Draw.ocirc, Draw.obolt)
-- which take explicit fill/outline color args and set their own color.
--
-- Usage:
--   local Draw = require "src.systems.draw2d"
--   local sx, sy = camera:toScreen(bone.x, bone.y, bone.z)
--   Draw.ocapsule(ax,ay,r1, bx,by,r2, fill, outline)

local Draw = {}

-- ── coordinate guard ─────────────────────────────────────────────────────────
-- Returns true if (x,y) is a real, on-screen-ish number.
-- Use to skip drawing bones that projected to infinity or NaN.
function Draw.safe(x, y)
    return x == x and y == y        -- NaN check (NaN != NaN)
        and math.abs(x) < 5000
        and math.abs(y) < 5000
end

-- ── capsule ───────────────────────────────────────────────────────────────────
-- Filled tapered capsule between two screen points.
-- r1 = radius at (x1,y1),  r2 = radius at (x2,y2).
-- Draws the current love.graphics color — set it before calling.
--
-- Uses: character limbs, tree branches, rope, tentacles, hair strands,
--       soft-body blobs, health bars with rounded ends.
function Draw.capsule(x1,y1,r1, x2,y2,r2)
    local dx = x2-x1;  local dy = y2-y1
    local len = math.sqrt(dx*dx + dy*dy)
    if len < 0.5 then
        love.graphics.circle("fill", x1, y1, math.max(r1, r2), 10)
        return
    end
    local nx = -dy/len;  local ny = dx/len
    love.graphics.polygon("fill",
        x1+nx*r1, y1+ny*r1,
        x2+nx*r2, y2+ny*r2,
        x2-nx*r2, y2-ny*r2,
        x1-nx*r1, y1-ny*r1
    )
    love.graphics.circle("fill", x1, y1, r1, 10)
    love.graphics.circle("fill", x2, y2, r2, 10)
end

-- Outlined capsule: dark outline pass (r + thickness) then fill pass (r).
-- thickness: outline width in pixels (default 2.5)
function Draw.ocapsule(x1,y1,r1, x2,y2,r2, fill, outline, thickness)
    local t = thickness or 2.5
    love.graphics.setColor(outline)
    Draw.capsule(x1,y1, r1+t, x2,y2, r2+t)
    love.graphics.setColor(fill)
    Draw.capsule(x1,y1, r1,   x2,y2, r2)
end

-- ── plate ─────────────────────────────────────────────────────────────────────
-- Filled rectangle segment between two screen points.
-- w = half-width in pixels (uniform — use capsule if you need taper).
-- Uses push/rotate/rectangle internally — immune to LÖVE polygon triangulator
-- bugs that affect hand-rolled quads on short/vertical segments.
--
-- Uses: robot limbs, planks, blades, UI panels, terrain ledges.
function Draw.plate(x1,y1, x2,y2, w)
    if not (Draw.safe(x1,y1) and Draw.safe(x2,y2)) then return end
    local dx = x2-x1;  local dy = y2-y1
    local len = math.sqrt(dx*dx + dy*dy)
    if len < 1 then return end
    love.graphics.push()
    love.graphics.translate(x1, y1)
    love.graphics.rotate(math.atan2(dy, dx))
    love.graphics.rectangle("fill", 0, -w, len, w*2)
    love.graphics.pop()
end

-- Outlined plate.
-- thickness: outline width in pixels (default 2.0)
function Draw.oplate(x1,y1, x2,y2, w, fill, outline, thickness)
    local t = thickness or 2.0
    love.graphics.setColor(outline)
    Draw.plate(x1,y1, x2,y2, w+t)
    love.graphics.setColor(fill)
    Draw.plate(x1,y1, x2,y2, w)
end

-- ── circle / ball ─────────────────────────────────────────────────────────────
-- Outlined circle. Simple wrapper for the common outline+fill pattern.
function Draw.ocirc(x, y, r, fill, outline, thickness)
    local t = thickness or 2.5
    love.graphics.setColor(outline)
    love.graphics.circle("fill", x, y, r+t, 12)
    love.graphics.setColor(fill)
    love.graphics.circle("fill", x, y, r,   12)
end

-- Shaded ball: base fill + dark shadow ellipse on one side +
-- light highlight ellipse on the other.
-- nx, ny: unit normal pointing toward the light source (screen space).
--         Defaults to top-left: (-0.6, -0.8).
-- Uses: heads, joints, fruit, planets, bubbles, eyes.
function Draw.ball(x, y, r, fill, outline, nx, ny, thickness)
    local lx = nx or -0.6
    local ly = ny or -0.8
    local t  = thickness or 2.5
    -- outline
    love.graphics.setColor(outline)
    love.graphics.circle("fill", x, y, r+t, 14)
    -- base fill
    love.graphics.setColor(fill)
    love.graphics.circle("fill", x, y, r, 14)
    -- shadow (offset away from light)
    love.graphics.setColor(fill[1]*0.40, fill[2]*0.40, fill[3]*0.40, 0.55)
    love.graphics.ellipse("fill", x - lx*r*0.30, y - ly*r*0.30, r*0.72, r*0.72)
    -- highlight (offset toward light)
    local hr = r * 0.42
    love.graphics.setColor(
        math.min(fill[1]*1.6+0.15, 1),
        math.min(fill[2]*1.6+0.15, 1),
        math.min(fill[3]*1.6+0.15, 1), 0.55)
    love.graphics.ellipse("fill", x + lx*r*0.28, y + ly*r*0.28, hr, hr)
end

-- ── bolt ─────────────────────────────────────────────────────────────────────
-- Small mechanical joint circle with a specular dot.
-- Uses: robot joints, screws, rivets, pivot points.
function Draw.bolt(x, y, r, col)
    if not Draw.safe(x, y) then return end
    love.graphics.setColor(0.10, 0.10, 0.12, 1)
    love.graphics.circle("fill", x, y, r+1.5, 8)
    love.graphics.setColor(col)
    love.graphics.circle("fill", x, y, r, 8)
    -- specular dot
    love.graphics.setColor(1, 1, 1, 0.45)
    love.graphics.circle("fill", x - r*0.28, y - r*0.28, r*0.32, 6)
    love.graphics.setColor(0, 0, 0, 0)   -- explicit reset — no color leak
end

-- ── polygon helpers ───────────────────────────────────────────────────────────
-- Outlined filled polygon. verts = flat array {x1,y1, x2,y2, ...}
-- Uses: custom shapes, terrain patches, UI panels, flags.
function Draw.opolygon(verts, fill, outline, thickness)
    local t = thickness or 2.0
    -- outline: scale verts outward from centroid
    local cx, cy, n = 0, 0, #verts/2
    for i = 1, #verts, 2 do cx = cx + verts[i]; cy = cy + verts[i+1] end
    cx = cx/n; cy = cy/n
    local ov = {}
    for i = 1, #verts, 2 do
        local dx = verts[i]-cx;   local dy = verts[i+1]-cy
        local d  = math.sqrt(dx*dx+dy*dy)
        local s  = (d+t)/math.max(d, 0.001)
        ov[i]   = cx + dx*s
        ov[i+1] = cy + dy*s
    end
    love.graphics.setColor(outline)
    love.graphics.polygon("fill", ov)
    love.graphics.setColor(fill)
    love.graphics.polygon("fill", verts)
end

-- ── hexagon ───────────────────────────────────────────────────────────────────
-- Outlined regular hexagon.
-- angle_offset: rotation in radians (default math.pi/6 = flat-top)
function Draw.ohex(x, y, r, fill, outline, thickness, angle_offset)
    local t  = thickness or 2.0
    local a0 = angle_offset or (math.pi/6)
    local function hex_verts(radius)
        local v = {}
        for i = 0, 5 do
            local a = a0 + i * math.pi/3
            v[i*2+1] = x + math.cos(a)*radius
            v[i*2+2] = y + math.sin(a)*radius
        end
        return v
    end
    love.graphics.setColor(outline)
    love.graphics.polygon("fill", hex_verts(r+t))
    love.graphics.setColor(fill)
    love.graphics.polygon("fill", hex_verts(r))
end

return Draw
