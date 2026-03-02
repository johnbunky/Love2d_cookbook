-- src/systems/lighting.lua
-- 2D point lights, ambient color, attenuation. Engine-agnostic data layer.
-- Rendering is done by the caller using canvas/shaders.
--
-- Usage:
--   local Lighting = require("src.systems.lighting")
--   local scene = Lighting.newScene({ ambient={0.05,0.05,0.12} })
--
--   local torch = Lighting.addLight(scene, {
--       x=200, y=300,
--       r=1.0, g=0.7, b=0.3,
--       radius=180, intensity=1.0,
--   })
--
--   Lighting.update(scene, dt)             -- flicker etc.
--   local lights = Lighting.getVisible(scene, camX, camY, W, H)
--
--   -- Caller draws shadow/light canvas using lights list
--   for _, l in ipairs(lights) do
--       -- l.x, l.y, l.r, l.g, l.b, l.radius, l.intensity
--   end

local Lighting = {}

-- -------------------------
-- Scene
-- -------------------------
function Lighting.newScene(config)
    config = config or {}
    return {
        ambient = config.ambient or {0.08, 0.08, 0.12},
        lights  = {},
        nextId  = 1,
    }
end

-- -------------------------
-- Add a light
-- config:
--   x, y      : world position
--   r,g,b     : color (default warm white)
--   radius    : falloff radius in pixels (default 150)
--   intensity : brightness multiplier 0..1+ (default 1)
--   flicker   : flicker amplitude 0..1 (default 0 = steady)
--   flickerSpeed: hz (default 8)
--   castShadows : bool (hint for renderer, default false)
--   active    : bool (default true)
-- Returns: light handle (id)
-- -------------------------
function Lighting.addLight(scene, config)
    config = config or {}
    local id = scene.nextId
    scene.nextId = scene.nextId + 1
    local light = {
        id           = id,
        x            = config.x         or 0,
        y            = config.y         or 0,
        r            = config.r         or 1.0,
        g            = config.g         or 0.85,
        b            = config.b         or 0.6,
        radius       = config.radius    or 150,
        intensity    = config.intensity or 1.0,
        flicker      = config.flicker   or 0,
        flickerSpeed = config.flickerSpeed or 8,
        castShadows  = config.castShadows  or false,
        active       = config.active ~= false,
        _flickerT    = math.random() * math.pi * 2,
        _curIntensity= config.intensity or 1.0,
    }
    scene.lights[id] = light
    return id
end

-- -------------------------
-- Remove a light
-- -------------------------
function Lighting.removeLight(scene, id)
    scene.lights[id] = nil
end

-- -------------------------
-- Get light by id
-- -------------------------
function Lighting.getLight(scene, id)
    return scene.lights[id]
end

-- -------------------------
-- Move a light
-- -------------------------
function Lighting.setPos(scene, id, x, y)
    local l = scene.lights[id]
    if l then l.x, l.y = x, y end
end

-- -------------------------
-- Update: flicker, animations
-- -------------------------
function Lighting.update(scene, dt)
    for _, l in pairs(scene.lights) do
        if l.active and l.flicker > 0 then
            l._flickerT = l._flickerT + dt * l.flickerSpeed
            -- Perlin-ish flicker using sum of sines
            local noise =
                math.sin(l._flickerT * 1.0) * 0.5 +
                math.sin(l._flickerT * 2.3) * 0.3 +
                math.sin(l._flickerT * 5.1) * 0.2
            l._curIntensity = math.max(0,
                l.intensity + noise * l.flicker * l.intensity)
        else
            l._curIntensity = l.intensity
        end
    end
end

-- -------------------------
-- Get all active lights visible in viewport
-- Returns sorted list (brightest/largest first — good for shader slot limits)
-- -------------------------
function Lighting.getVisible(scene, camX, camY, vpW, vpH)
    camX = camX or 0
    camY = camY or 0
    vpW  = vpW  or 800
    vpH  = vpH  or 600
    local result = {}
    for _, l in pairs(scene.lights) do
        if l.active then
            -- Rough AABB cull
            local lx = l.x - camX
            local ly = l.y - camY
            if lx + l.radius >= 0 and lx - l.radius <= vpW
            and ly + l.radius >= 0 and ly - l.radius <= vpH then
                table.insert(result, l)
            end
        end
    end
    -- Sort by intensity*radius descending
    table.sort(result, function(a, b)
        return a._curIntensity * a.radius > b._curIntensity * b.radius
    end)
    return result
end

-- -------------------------
-- Compute attenuation factor at distance d from a light
-- Returns 0..1
-- -------------------------
function Lighting.attenuation(light, d)
    if d >= light.radius then return 0 end
    -- Smooth falloff: 1 at center, 0 at radius
    local t = 1 - (d / light.radius)
    return t * t * light._curIntensity
end

-- -------------------------
-- Sample total light color at a world point
-- Useful for CPU-side lighting (tinting sprites without shaders)
-- -------------------------
function Lighting.sampleAt(scene, wx, wy)
    local r = scene.ambient[1]
    local g = scene.ambient[2]
    local b = scene.ambient[3]
    for _, l in pairs(scene.lights) do
        if l.active then
            local dx   = wx - l.x
            local dy   = wy - l.y
            local d    = math.sqrt(dx*dx + dy*dy)
            local att  = Lighting.attenuation(l, d)
            if att > 0 then
                r = r + l.r * att
                g = g + l.g * att
                b = b + l.b * att
            end
        end
    end
    return math.min(1,r), math.min(1,g), math.min(1,b)
end

-- -------------------------
-- Set ambient color
-- -------------------------
function Lighting.setAmbient(scene, r, g, b)
    scene.ambient = {r, g, b}
end

-- -------------------------
-- Clear all lights
-- -------------------------
function Lighting.clear(scene)
    scene.lights = {}
    scene.nextId = 1
end

-- -------------------------
-- Count active lights
-- -------------------------
function Lighting.count(scene)
    local n = 0
    for _, l in pairs(scene.lights) do
        if l.active then n = n + 1 end
    end
    return n
end

return Lighting
