-- src/systems/ik.lua
-- Inverse and forward kinematics math. No state, no side effects.
-- Pure Lua — no engine dependencies.
--
-- FUNCTIONS:
--   IK.solve2(hx,hy, fx,fy, ul,ll, dir)              2-bone IK (leg / arm)
--   IK.solveLeg(hx,hy,hz, fx,fy,fz, ul,ll, px,py)   3D pole-vector leg IK
--   IK.fkChain(rx,ry, joints)                        FK chain (tail / spine)
--   IK.angleTo(ax,ay, bx,by)                         angle from a → b
--   IK.dist(ax,ay, bx,by)                            distance between two points

local IK = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- 2-bone IK solver  (leg, arm, any hinge chain in 2D / a single plane)
--
-- Given hip (hx,hy) and foot target (fx,fy) with bone lengths ul (upper) and
-- ll (lower), returns the knee position using the law of cosines.
--
-- dir:  1  = knee bends "forward" (human knee, use facing direction)
--      -1  = knee bends "backward" (bird leg, reverse-knee creatures)
-- ─────────────────────────────────────────────────────────────────────────────
function IK.solve2(hx, hy, fx, fy, ul, ll, dir)
    local dx = fx - hx
    local dy = fy - hy
    local d  = math.sqrt(dx*dx + dy*dy)

    -- clamp so the chain is always solvable (never fully extended or collapsed)
    local dmin = math.abs(ul - ll) + 0.5
    local dmax = ul + ll - 0.5
    if d < dmin then d = dmin end
    if d > dmax then d = dmax end

    -- law of cosines: angle at hip
    local cosA = (d*d + ul*ul - ll*ll) / (2 * d * ul)
    if cosA >  1 then cosA =  1 end
    if cosA < -1 then cosA = -1 end

    local base = math.atan2(dy, dx)
    local kang = base - (dir or 1) * math.acos(cosA)

    return hx + math.cos(kang) * ul,
           hy + math.sin(kang) * ul
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Multi-bone forward kinematics chain  (tail, trunk, tentacle, spine)
--
-- joints : list of { angle (radians), length (pixels) } from root outward
-- returns: list of { x, y } world positions; index 1 is the tip of joint 1
-- ─────────────────────────────────────────────────────────────────────────────
function IK.fkChain(rx, ry, joints)
    local result = {}
    local cx, cy = rx, ry
    for _, j in ipairs(joints) do
        cx = cx + math.cos(j.angle) * j.length
        cy = cy + math.sin(j.angle) * j.length
        result[#result + 1] = {x = cx, y = cy}
    end
    return result
end

-- ─────────────────────────────────────────────────────────────────────────────
-- 3-D pole-vector leg IK
--
-- World axes: x = right, y = depth, z = up (z-up convention)
-- The knee bends toward the pole direction in the ground plane.
-- Use the movement direction as the pole while moving, facing direction at rest.
--
-- Returns: knee world position (kx, ky, kz)
-- ─────────────────────────────────────────────────────────────────────────────
function IK.solveLeg(hx, hy, hz, fx, fy, fz, ul, ll, pole_x, pole_y)
    local dx = fx - hx
    local dy = fy - hy
    local dz = fz - hz
    local d3 = math.sqrt(dx*dx + dy*dy + dz*dz)

    local dmin = math.abs(ul - ll) + 0.5
    local dmax = ul + ll - 0.5
    if d3 < dmin then d3 = dmin end
    if d3 > dmax then d3 = dmax end

    -- law of cosines: angle at hip
    local cosA = (d3*d3 + ul*ul - ll*ll) / (2 * d3 * ul)
    if cosA >  1 then cosA =  1 end
    if cosA < -1 then cosA = -1 end
    local sinA = math.sqrt(math.max(0, 1 - cosA*cosA))

    -- unit vector hip → foot
    local ux = dx/d3
    local uy = dy/d3
    local uz = dz/d3

    -- project pole onto the plane perpendicular to the hip-foot axis
    local dot   =  pole_x*ux + pole_y*uy   -- pole_z = 0
    local perpx =  pole_x - dot*ux
    local perpy =  pole_y - dot*uy
    local perpz =         - dot*uz
    local plen  =  math.sqrt(perpx*perpx + perpy*perpy + perpz*perpz)

    if plen < 0.001 then
        -- pole is parallel to hip-foot axis — fall back to world-up perpendicular
        perpx = -uz;  perpy = 0;  perpz = ux
        plen  = math.sqrt(perpx*perpx + perpz*perpz)
        if plen < 0.001 then perpx = 1; perpy = 0; perpz = 0; plen = 1 end
    end
    perpx = perpx / plen
    perpy = perpy / plen
    perpz = perpz / plen

    local along = ul * cosA
    local perp  = ul * sinA

    return hx + along*ux + perp*perpx,
           hy + along*uy + perp*perpy,
           hz + along*uz + perp*perpz
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Utilities
-- ─────────────────────────────────────────────────────────────────────────────

-- Returns the angle (radians) of the vector from point a to point b.
function IK.angleTo(ax, ay, bx, by)
    return math.atan2(by - ay, bx - ax)
end

-- Returns the Euclidean distance between two points.
function IK.dist(ax, ay, bx, by)
    local dx = bx - ax
    local dy = by - ay
    return math.sqrt(dx*dx + dy*dy)
end

return IK
