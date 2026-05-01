-- src/characters/skins/particles.lua
--
-- Particle skin: emits particles from bone positions each frame.
-- STATEFUL — state lives in c.skin_state, owned by this skin.
-- humanoid_draw calls update() then draw(bones, rig, profile, camera, c).
--
-- TO BRIDGE YOUR EXISTING EMITTER SYSTEM:
--   Set profile.particles.emitter = emitters.sparks  (or any emitter table)
--   The skin will call emitter.spawn(sx, sy) each frame and skip its own pool.
--   Your global update/draw loop handles the rest — this skin just spawns.
--
-- Profile keys (all optional):
--   profile.color                  {r,g,b}   base particle color
--   profile.particles.emitter      table     your existing emitter (spawn bridging)
--   profile.particles.count        number    particles per bone per frame (def 1)
--   profile.particles.lifetime     number    seconds alive (def 0.45)
--   profile.particles.speed        number    initial drift speed px/s (def 18)
--   profile.particles.r            number    initial radius px (def 3.5)
--   profile.particles.gravity      number    downward pull px/s² (def 30)
--   profile.particles.emit_bones   table     bone names to emit from

local Particles = {}
local Draw = require "src.systems.draw2d"

local DEFAULT_EMITTERS = {
    "near_hand", "far_hand",
    "near_foot", "far_foot",
    "near_elbow","far_elbow",
    "near_knee", "far_knee",
    "hip", "chest", "head",
}

-- ── internal pool (used when no external emitter is set) ─────────────────────

local function init_state(c)
    if not c.skin_state then
        c.skin_state = { pool = {} }
    end
end

function Particles.update(bones, rig, profile, dt, c)
    init_state(c)
    local pool = c.skin_state.pool
    local pp   = profile.particles or {}
    local col  = profile.color

    -- if bridging to an external emitter, skip internal pool management
    if pp.emitter then return end

    local count    = pp.count    or 1
    local lt       = pp.lifetime or 0.45
    local speed    = pp.speed    or 18
    local r        = pp.r        or 3.5
    local grav     = pp.gravity  or 30
    local emitters = pp.emit_bones or DEFAULT_EMITTERS

    -- step existing particles
    local i = 1
    while i <= #pool do
        local p = pool[i]
        p.t  = p.t  + dt
        p.x  = p.x  + p.vx * dt
        p.y  = p.y  + p.vy * dt
        p.vy = p.vy + grav * dt       -- gravity
        p.vx = p.vx * (1 - dt * 2)   -- drag
        if p.t >= p.lt then
            pool[i] = pool[#pool];  pool[#pool] = nil
        else
            i = i + 1
        end
    end

    -- emit from each bone (world pos stored, projected in draw)
    for _, name in ipairs(emitters) do
        local bone = bones[name]
        if bone and type(bone) == "table" and bone.x then
            for _ = 1, count do
                if math.random() < 0.6 then
                    pool[#pool+1] = {
                        wx  = bone.x + (math.random()-0.5) * 3,
                        wy  = bone.y + (math.random()-0.5) * 3,
                        wz  = bone.z + (math.random()-0.5) * 3,
                        x   = nil, y = nil,   -- projected on first draw
                        vx  = (math.random()-0.5) * speed * 2,
                        vy  = -math.abs(math.random() * speed),
                        t   = 0,
                        lt  = lt * (0.7 + math.random() * 0.6),
                        r   = r  * (0.6 + math.random() * 0.8),
                        col = { col[1], col[2], col[3] },
                        new = true,
                    }
                end
            end
        end
    end
end

-- ── draw ─────────────────────────────────────────────────────────────────────

function Particles.draw(bones, rig, profile, camera, c)
    if not c then return end
    local pp = profile.particles or {}

    -- ── bridge mode: spawn into external emitter, return ─────────────────────
    -- Your global update/draw handles the pool — we just trigger spawns.
    if pp.emitter then
        local emitter  = pp.emitter
        local emitters = pp.emit_bones or DEFAULT_EMITTERS
        local count    = pp.count or 1
        for _, name in ipairs(emitters) do
            local bone = bones[name]
            if bone and type(bone) == "table" and bone.x then
                local sx, sy = camera:toScreen(bone.x, bone.y, bone.z)
                if Draw.safe(sx, sy) then
                    for _ = 1, count do
                        if math.random() < 0.6 and emitter.spawn then
                            emitter.spawn(sx, sy)
                        end
                    end
                end
            end
        end
        return   -- external system draws everything, we're done
    end

    -- ── internal pool draw ────────────────────────────────────────────────────
    init_state(c)
    local pool = c.skin_state.pool

    for _, p in ipairs(pool) do
        if p.new then
            p.x, p.y = camera:toScreen(p.wx, p.wy, p.wz)
            p.new = false
        end
        if Draw.safe(p.x, p.y) then
            local life   = p.t / p.lt
            local alpha  = (1 - life) * 0.85
            local radius = p.r * (1 - life * 0.6)
            if radius > 0.3 then
                love.graphics.setColor(p.col[1], p.col[2], p.col[3], alpha)
                love.graphics.circle("fill", p.x, p.y, radius, 6)
            end
        end
    end
end

return Particles
