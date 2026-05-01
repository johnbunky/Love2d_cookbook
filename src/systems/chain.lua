-- src/systems/chain.lua
--
-- Reusable 3D verlet chain solver.
-- Useful for: ponytails, tails, scarves, ropes, hanging chains, cloth edges.
--
-- Each point stores current + previous position.
-- Each frame: integrate velocity, apply gravity, solve distance constraints.
-- The root point is pinned to an anchor every frame — the chain hangs from it.
--
-- USAGE:
--   local Chain = require "src.systems.chain"
--
--   -- create a 5-segment ponytail, each segment 10 units long:
--   local c = Chain.new({ segs=5, seg_len=10, gravity=280, damping=0.985 })
--   Chain.reset(c, rootX, rootY, rootZ)   -- snap straight down from root
--
--   -- every frame:
--   Chain.update(c, dt, rootX, rootY, rootZ)
--
--   -- read points (index 1 = root, #c.pts = tip):
--   for i, pt in ipairs(c.pts) do
--       print(pt.x, pt.y, pt.z)
--   end
--
-- TUNING:
--   seg_len   shorter = tighter/stiffer chain,  longer = looser/more sway
--   gravity   higher = heavier, falls faster
--   damping   0.99 = very floaty,  0.95 = snappy,  0.90 = heavy
--   iters     more iterations = stiffer constraints (2-4 is enough)

local Chain = {}

-- ── constructor ───────────────────────────────────────────────────────────────

-- opts:
--   segs     number   number of segments (points = segs + 1, root included)
--   seg_len  number   rest length of each segment in world units
--   gravity  number   downward acceleration (z-down, so applied as -z)  def 280
--   damping  number   velocity multiplier per frame (0-1)               def 0.982
--   iters    number   constraint solve iterations per frame              def 3
function Chain.new(opts)
    opts = opts or {}
    local c = {
        segs      = opts.segs      or 5,
        seg_len   = opts.seg_len   or 10,
        gravity   = opts.gravity   or 280,
        damping   = opts.damping   or 0.982,
        iters     = opts.iters     or 3,
        stiffness = opts.stiffness or 0,    -- 0=floppy rope, 0.3=hair, 0.8=rod
        pt_r      = opts.pt_r      or 2,    -- point radius for sphere collision
        pts       = {},
    }
    -- initialise all points at origin — caller should Chain.reset() immediately
    for i = 1, c.segs + 1 do
        c.pts[i] = { x=0, y=0, z=0, ox=0, oy=0, oz=0 }
    end
    return c
end

-- ── reset ─────────────────────────────────────────────────────────────────────
-- Snap the chain straight down from (rx, ry, rz) with zero velocity.
-- Call this on character spawn, teleport, or state change to avoid a pop.
function Chain.reset(c, rx, ry, rz)
    for i, pt in ipairs(c.pts) do
        local drop = (i-1) * c.seg_len
        pt.x  = rx;  pt.y  = ry;  pt.z  = rz - drop
        pt.ox = pt.x; pt.oy = pt.y; pt.oz = pt.z
    end
end

-- ── update ────────────────────────────────────────────────────────────────────
-- rx, ry, rz: root anchor world position (typically head/neck bone)
-- Chain.update(c, dt, rx, ry, rz, colliders)
--   colliders: optional array of {x,y,z,r} spheres to push chain points out of
function Chain.update(c, dt, rx, ry, rz, colliders)
    local pts  = c.pts
    local grav = c.gravity
    local damp = c.damping
    local n    = #pts

    -- 1. verlet integrate (skip root)
    for i = 2, n do
        local p  = pts[i]
        local vx = (p.x - p.ox) * damp
        local vy = (p.y - p.oy) * damp
        local vz = (p.z - p.oz) * damp
        p.ox = p.x;  p.oy = p.y;  p.oz = p.z
        p.x  = p.x + vx
        p.y  = p.y + vy
        p.z  = p.z + vz - grav * dt * dt
    end

    -- 2. pin root
    local root = pts[1]
    root.ox = rx;  root.oy = ry;  root.oz = rz
    root.x  = rx;  root.y  = ry;  root.z  = rz

    -- 3. constraint solve: distance + sphere collision
    local seg_len = c.seg_len
    for _ = 1, c.iters do
        -- distance constraints
        for i = 2, n do
            local a   = pts[i-1]
            local b   = pts[i]
            local ddx = b.x - a.x
            local ddy = b.y - a.y
            local ddz = b.z - a.z
            local dist = math.sqrt(ddx*ddx + ddy*ddy + ddz*ddz)
            if dist > 0.001 then
                local diff = (dist - seg_len) / dist
                b.x = b.x - ddx * diff
                b.y = b.y - ddy * diff
                b.z = b.z - ddz * diff
            end
        end

        -- sphere collision: push points outside each collider
        if colliders then
            for i = 2, n do   -- skip root — it's pinned anyway
                local p = pts[i]
                for _, sphere in ipairs(colliders) do
                    local ddx = p.x - sphere.x
                    local ddy = p.y - sphere.y
                    local ddz = p.z - sphere.z
                    local dist = math.sqrt(ddx*ddx + ddy*ddy + ddz*ddz)
                    local min_dist = sphere.r + (c.pt_r or 2)
                    if dist < min_dist and dist > 0.001 then
                        -- push point to surface of sphere
                        local push = (min_dist - dist) / dist
                        p.x = p.x + ddx * push
                        p.y = p.y + ddy * push
                        p.z = p.z + ddz * push
                    end
                end
            end
        end

        -- angular stiffness: pull each point toward the extrapolated straight line.
        -- stiffness=0 → pure floppy rope.  stiffness=0.5 → hair.  stiffness=0.9 → rod.
        if c.stiffness and c.stiffness > 0 then
            for i = 3, n do   -- need two previous points to define a direction
                local pp  = pts[i-2]
                local pa  = pts[i-1]
                local pb  = pts[i]
                local ddx = pa.x - pp.x
                local ddy = pa.y - pp.y
                local ddz = pa.z - pp.z
                local len = math.sqrt(ddx*ddx + ddy*ddy + ddz*ddz)
                if len > 0.001 then
                    -- ideal position: extrapolate previous segment direction
                    local ix = pa.x + (ddx/len) * seg_len
                    local iy = pa.y + (ddy/len) * seg_len
                    local iz = pa.z + (ddz/len) * seg_len
                    pb.x = pb.x + (ix - pb.x) * c.stiffness
                    pb.y = pb.y + (iy - pb.y) * c.stiffness
                    pb.z = pb.z + (iz - pb.z) * c.stiffness
                end
            end
        end

        -- re-pin root after each iteration
        root.x = rx;  root.y = ry;  root.z = rz
    end
end

return Chain
