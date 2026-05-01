-- src/characters/skins/particles.lua
--
-- Particle skin: each bone emits small particles every frame.
-- Particles drift, shrink, and fade over their lifetime.
--
-- STATEFUL SKIN — needs update() called before draw() each frame.
-- State is stored in c.skin_state (a scratch table the skin owns).
-- humanoid_draw.lua calls Skin.update() automatically when present.
--
-- Profile keys (all optional):
--   profile.color                {r,g,b}   base particle color
--   profile.particles.count      number    particles emitted per bone per frame (def 1)
--   profile.particles.lifetime   number    seconds a particle lives (def 0.45)
--   profile.particles.speed      number    initial drift speed (def 18)
--   profile.particles.r          number    initial particle radius (def 3.5)
--   profile.particles.gravity    number    downward pull per second (def 30)
--   profile.particles.spread     number    emission cone half-angle radians (def math.pi)
--   profile.particles.emit_bones table     which bones emit (def: all limb endpoints)

local Particles = {}

-- ── which bones emit by default ──────────────────────────────────────────────
local DEFAULT_EMITTERS = {
    "near_hand", "far_hand",
    "near_foot", "far_foot",
    "near_elbow","far_elbow",
    "near_knee", "far_knee",
    "hip", "chest", "head",
}

-- ── particle pool helpers ─────────────────────────────────────────────────────

local function new_particle(bx, by, speed, spread, lifetime, r, col)
    local angle = math.random() * math.pi * 2
    -- bias upward (gravity will pull down anyway)
    local vx = math.cos(angle) * speed * (0.4 + math.random() * 0.6)
    local vy = math.sin(angle) * speed * (0.4 + math.random() * 0.6) - speed * 0.3
    return {
        x  = bx + (math.random()-0.5) * 4,
        y  = by + (math.random()-0.5) * 4,
        vx = vx,
        vy = vy,
        t  = 0,           -- age in seconds
        lt = lifetime * (0.7 + math.random() * 0.6),
        r  = r,
        col = col,
    }
end

-- ── update (called every frame before draw) ───────────────────────────────────

function Particles.update(bones, rig, profile, dt, c)
    -- init state table on character instance (lazy, once)
    if not c.skin_state then c.skin_state = { pool = {} } end
    local pool = c.skin_state.pool

    local pp    = profile.particles or {}
    local col   = profile.color
    local count = pp.count    or 1
    local lt    = pp.lifetime or 0.45
    local speed = pp.speed    or 18
    local r     = pp.r        or 3.5
    local grav  = pp.gravity  or 30
    local emitters = pp.emit_bones or DEFAULT_EMITTERS

    -- step existing particles
    local i = 1
    while i <= #pool do
        local p = pool[i]
        p.t  = p.t + dt
        p.x  = p.x + p.vx * dt
        p.y  = p.y + p.vy * dt
        p.vy = p.vy + grav * dt    -- gravity pulls screen-down
        p.vx = p.vx * (1 - dt * 2) -- drag
        if p.t >= p.lt then
            -- remove dead particle (swap with last for O(1) removal)
            pool[i] = pool[#pool]
            pool[#pool] = nil
        else
            i = i + 1
        end
    end

    -- emit new particles from each emitter bone
    for _, name in ipairs(emitters) do
        local bone = bones[name]
        -- bones table entries can be {x,y,z} or scalar (facing, left_near) — guard:
        if bone and type(bone) == "table" and bone.x then
            -- NOTE: we need screen coords here, but update() has no camera.
            -- Store world pos; draw() will project. Use a flag to defer.
            for _ = 1, count do
                if math.random() < 0.6 then   -- 60% chance per bone per frame
                    table.insert(pool, {
                        -- store world pos, projected in draw()
                        wx = bone.x + (math.random()-0.5) * 3,
                        wy = bone.y + (math.random()-0.5) * 3,
                        wz = bone.z + (math.random()-0.5) * 3,
                        -- screen-space drift (set in first draw)
                        x = nil, y = nil,
                        vx = (math.random()-0.5) * speed * 2,
                        vy = -math.abs(math.random() * speed),   -- bias upward
                        t  = 0,
                        lt = lt * (0.7 + math.random() * 0.6),
                        r  = r  * (0.6 + math.random() * 0.8),
                        col = { col[1], col[2], col[3] },
                        new = true,
                    })
                end
            end
        end
    end
end

-- ── draw ─────────────────────────────────────────────────────────────────────

function Particles.draw(bones, rig, profile, camera)
    if not camera then return end   -- safety

    -- find the character's state — we need to reach it.
    -- humanoid_draw passes `c` to update() but not to draw().
    -- Workaround: cache a reference on the module keyed by bones identity.
    -- (bones is rebuilt every frame, so we use the camera as a proxy anchor
    --  and store state on the module's per-call scratch.)
    -- Real fix: see NOTE at bottom of file.
    local pool = Particles._last_pool
    if not pool then return end

    for _, p in ipairs(pool) do
        -- project new particles on first draw
        if p.new then
            p.x, p.y = camera:toScreen(p.wx, p.wy, p.wz)
            p.new = false
        end

        local life = p.t / p.lt            -- 0=fresh, 1=dead
        local alpha = (1 - life) * 0.85
        local radius = p.r * (1 - life * 0.6)
        if radius > 0.3 then
            love.graphics.setColor(p.col[1], p.col[2], p.col[3], alpha)
            love.graphics.circle("fill", p.x, p.y, radius, 6)
        end
    end
end

-- ── bridge: update stores pool ref for draw ───────────────────────────────────
-- This is the awkward part of a stateful skin under the current interface.
-- update() runs first (has c), draw() runs second (no c).
-- Simplest fix that doesn't touch humanoid_draw: store on module between calls.
-- Per-frame so no stale data risk.

local _real_update = Particles.update
function Particles.update(bones, rig, profile, dt, c)
    _real_update(bones, rig, profile, dt, c)
    if c.skin_state then
        Particles._last_pool = c.skin_state.pool
    end
end

-- ── NOTE: cleaner long-term fix ───────────────────────────────────────────────
-- Pass c to draw() as well:  Skin.draw(bones, rig, profile, camera, c)
-- Then draw() does: local pool = c.skin_state and c.skin_state.pool
-- One-line change in humanoid_draw.lua:
--   c._skin_module.draw(bones, rig, p, camera, c)
-- All existing skins ignore the extra arg. Particles uses it.

return Particles
