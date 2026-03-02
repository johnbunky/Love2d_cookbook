-- src/systems/vec3.lua
-- 3D vector math. Engine-agnostic, no LÖVE calls.
--
-- Usage:
--   local Vec3 = require("src.systems.vec3")
--   local a = Vec3.new(1, 0, 0)
--   local b = Vec3.new(0, 1, 0)
--   local c = Vec3.add(a, b)       --> {x=1, y=1, z=0}
--   local d = Vec3.cross(a, b)     --> {x=0, y=0, z=1}

local Vec3 = {}

-- -------------------------
-- Constructors
-- -------------------------
function Vec3.new(x, y, z)
    return { x = x or 0, y = y or 0, z = z or 0 }
end

function Vec3.zero()  return Vec3.new(0, 0, 0) end
function Vec3.one()   return Vec3.new(1, 1, 1) end
function Vec3.up()    return Vec3.new(0, 1, 0) end
function Vec3.right() return Vec3.new(1, 0, 0) end
function Vec3.fwd()   return Vec3.new(0, 0,-1) end

function Vec3.clone(v)
    return Vec3.new(v.x, v.y, v.z)
end

-- -------------------------
-- Basic operations
-- -------------------------
function Vec3.add(a, b)
    return Vec3.new(a.x+b.x, a.y+b.y, a.z+b.z)
end

function Vec3.sub(a, b)
    return Vec3.new(a.x-b.x, a.y-b.y, a.z-b.z)
end

function Vec3.scale(v, s)
    return Vec3.new(v.x*s, v.y*s, v.z*s)
end

function Vec3.neg(v)
    return Vec3.new(-v.x, -v.y, -v.z)
end

function Vec3.addScale(a, b, s)
    -- a + b*s  (common in integration)
    return Vec3.new(a.x+b.x*s, a.y+b.y*s, a.z+b.z*s)
end

-- -------------------------
-- Products
-- -------------------------
function Vec3.dot(a, b)
    return a.x*b.x + a.y*b.y + a.z*b.z
end

function Vec3.cross(a, b)
    return Vec3.new(
        a.y*b.z - a.z*b.y,
        a.z*b.x - a.x*b.z,
        a.x*b.y - a.y*b.x)
end

-- -------------------------
-- Length / normalization
-- -------------------------
function Vec3.lenSq(v)
    return v.x*v.x + v.y*v.y + v.z*v.z
end

function Vec3.len(v)
    return math.sqrt(v.x*v.x + v.y*v.y + v.z*v.z)
end

function Vec3.normalize(v)
    local l = Vec3.len(v)
    if l < 1e-9 then return Vec3.zero() end
    return Vec3.scale(v, 1/l)
end

function Vec3.dist(a, b)
    return Vec3.len(Vec3.sub(b, a))
end

function Vec3.distSq(a, b)
    return Vec3.lenSq(Vec3.sub(b, a))
end

-- -------------------------
-- Interpolation
-- -------------------------
function Vec3.lerp(a, b, t)
    return Vec3.new(
        a.x + (b.x-a.x)*t,
        a.y + (b.y-a.y)*t,
        a.z + (b.z-a.z)*t)
end

-- -------------------------
-- Reflection / projection
-- -------------------------
-- Reflect v around normal n (n must be normalized)
function Vec3.reflect(v, n)
    local d = 2 * Vec3.dot(v, n)
    return Vec3.sub(v, Vec3.scale(n, d))
end

-- Project v onto direction dir
function Vec3.project(v, dir)
    local d = Vec3.normalize(dir)
    return Vec3.scale(d, Vec3.dot(v, d))
end

-- -------------------------
-- Comparison
-- -------------------------
function Vec3.eq(a, b, eps)
    eps = eps or 1e-9
    return math.abs(a.x-b.x) < eps
       and math.abs(a.y-b.y) < eps
       and math.abs(a.z-b.z) < eps
end

function Vec3.isZero(v, eps)
    return Vec3.lenSq(v) < (eps or 1e-9)
end

-- -------------------------
-- Conversion helpers
-- -------------------------
function Vec3.toArray(v)
    return { v.x, v.y, v.z }
end

function Vec3.fromArray(t)
    return Vec3.new(t[1] or 0, t[2] or 0, t[3] or 0)
end

function Vec3.toString(v)
    return string.format("(%.3f, %.3f, %.3f)", v.x, v.y, v.z)
end

-- -------------------------
-- Component-wise ops
-- -------------------------
function Vec3.abs(v)
    return Vec3.new(math.abs(v.x), math.abs(v.y), math.abs(v.z))
end

function Vec3.min(a, b)
    return Vec3.new(math.min(a.x,b.x), math.min(a.y,b.y), math.min(a.z,b.z))
end

function Vec3.max(a, b)
    return Vec3.new(math.max(a.x,b.x), math.max(a.y,b.y), math.max(a.z,b.z))
end

function Vec3.clamp(v, lo, hi)
    return Vec3.new(
        math.max(lo.x, math.min(hi.x, v.x)),
        math.max(lo.y, math.min(hi.y, v.y)),
        math.max(lo.z, math.min(hi.z, v.z)))
end

return Vec3
